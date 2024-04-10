#include "driverlib.h"
#include "lightsensor.h"

unsigned int lightsensor_ADC_Result = 0;          // ADC conversion result
int calibratedADC = 500;
int deadzone = 5;
int runningAvg = 500;

/**
 * lightsensor_init_SACOA 函数的作用是初始化Sigma-Delta 模数转换器（SAC - Sigma-Delta Analog-to-Digital Converter）的运算放大器（OA）。这个函数主要负责配置运算放大器的输入、输出和电源模式，以便与光传感器一起使用。具体来说，函数的作用包括：
    1. 设置外设功能的GPIO：通过GPIO_setAsPeripheralModuleFunctionInputPin函数，选择特定的GPIO引脚用于运算放大器的正负输入。这一步确保了运算放大器能够接收来自光传感器的模拟信号。
    2. 初始化运算放大器模块：使用SAC_OA_init函数配置运算放大器的正负输入源。例如，设置正输入和负输入都来自外部源，或者正输入来自外部，负输入来自内部的可编程增益放大器（PGA）。
    3. 选择电源模式：通过SAC_OA_selectPowerMode函数选择运算放大器的电源模式，例如选择低速低功耗模式以减少整体功耗。
    4. 启用运算放大器和SAC模块：使用SAC_OA_enable和SAC_enable函数来启用运算放大器和SAC模块，使其开始工作。
    5. 通过以上步骤，lightsensor_init_SACOA 函数确保了运算放大器正确配置，并能够处理来自光传感器的模拟信号。这对于光传感器的信号调节非常重要，因为运算放大器可以用来放大或调整传感器的信号，以便更适合于后续的模数转换（ADC）。
*/
void lightsensor_init_SACOA(void) {
    //Configure Op-Amp functionality
    GPIO_setAsPeripheralModuleFunctionInputPin(
        GPIO_PORT_P3,
        GPIO_PIN1 | GPIO_PIN3 | GPIO_PIN2,
        GPIO_TERNARY_MODULE_FUNCTION
    );

    //Select external source for both positive and negative inputs
    SAC_OA_init(
        SAC2_BASE,
        SAC_OA_POSITIVE_INPUT_SOURCE_EXTERNAL,
        SAC_OA_NEGATIVE_INPUT_SOURCE_EXTERNAL
    );

    //Select low speed and low power mode
    SAC_OA_selectPowerMode(
        SAC2_BASE,
        SAC_OA_POWER_MODE_LOW_SPEED_LOW_POWER
    );

    SAC_OA_enable(SAC2_BASE);                  // Enable SAC2 OA
    SAC_enable(SAC2_BASE);                     // Enable SAC2

    //Select external source for both positive and negative inputs
    SAC_OA_init(
        SAC0_BASE,
        SAC_OA_POSITIVE_INPUT_SOURCE_PAIR_OA,
        SAC_OA_NEGATIVE_INPUT_SOURCE_PGA
    );

    SAC_OA_enable(SAC0_BASE);                  // Enable SAC0 OA
    SAC_enable(SAC0_BASE);                     // Enable SAC0
}

/**
 * lightsensor_init_ADC函数的作用是初始化模数转换器（ADC）模块，使其准备好进行光传感器信号的数字化。这个函数主要负责配置ADC的各种参数，以确保正确、有效地读取模拟信号并将其转换为数字值。具体来说，这个函数执行以下操作：
    1. 配置ADC模块：通过ADC_init函数，设置ADC的基本参数，如采样/保持信号源、时钟源和时钟分频器。这些设置影响ADC的采样速率和准确性。
    2. 设置采样时间：通过ADC_setupSamplingTimer函数，配置ADC的采样/保持时间。这个时间决定了ADC在转换前保持输入信号稳定的时间长度，对于提高转换精度非常重要。
    3. 选择分辨率：通过ADC_setResolution函数，设置ADC的分辨率（例如12位）。分辨率决定了ADC可以区分的最小电压变化，高分辨率意味着更精细的测量结果。
    4. 配置内存缓冲区：通过ADC_configureMemory函数，设置ADC模块的内存缓冲区，以存储转换结果。这包括选择输入通道、正负参考电压等。
    5. 清除和使能中断：通过ADC_clearInterrupt和ADC_enableInterrupt函数，清除旧的中断标志并使能新的中断。这样，当ADC完成一个转换周期后，可以生成一个中断信号。
    6. 启动转换：虽然在lightsensor_init_ADC函数中没有直接启动ADC转换，但通过配置完毕后，系统就准备好根据其他函数（如主循环中的lightsensor函数）的触发来启动和进行ADC转换。
    总之，lightsensor_init_ADC函数确保ADC模块被正确配置，能够准确地读取光传感器产生的模拟信号并将其转换为数字值，以便后续处理和分析。这是实现光传感器功能的关键步骤之一。
*/
void lightsensor_init_ADC(void) {
    ADC_init(
        ADC_BASE,
        ADC_SAMPLEHOLDSOURCE_2,
        ADC_CLOCKSOURCE_ADCOSC,
        ADC_CLOCKDIVIDER_1
    );

    ADC_enable(ADC_BASE);

    ADC_setupSamplingTimer(
        ADC_BASE,
        ADC_CYCLEHOLD_16_CYCLES,
        ADC_MULTIPLESAMPLESDISABLE
    );
    ADC_setResolution(
        ADC_BASE,
        ADC_RESOLUTION_12BIT
    );

    ADC_configureMemory(
        ADC_BASE,
        ADC_INPUT_VEREF_P,
        ADC_VREFPOS_AVCC,
        ADC_VREFNEG_AVSS
    );

    ADC_clearInterrupt(
        ADC_BASE,
        ADC_COMPLETED_INTERRUPT
    );

    ADC_enableInterrupt(
        ADC_BASE,
        ADC_COMPLETED_INTERRUPT
    );

    Timer_B_outputPWMParam param2 = {0};
    param2.clockSource = TIMER_B_CLOCKSOURCE_ACLK;
    param2.clockSourceDivider = TIMER_B_CLOCKSOURCE_DIVIDER_1;
    param2.timerPeriod = TIMER_PERIOD;
    param2.compareRegister = TIMER_B_CAPTURECOMPARE_REGISTER_1;
    param2.compareOutputMode = TIMER_B_OUTPUTMODE_TOGGLE_RESET;
    param2.dutyCycle = DUTY_CYCLE;

    Timer_B_outputPWM(TIMER_B1_BASE, &param2);
    ADC_startConversion(ADC_BASE, ADC_REPEATED_SINGLECHANNEL);
}

// ADC interrupt service routine
#if defined(__TI_COMPILER_VERSION__) || defined(__IAR_SYSTEMS_ICC__)
#pragma vector=ADC_VECTOR
__interrupt void ADC_ISR(void)
#elif defined(__GNUC__)
void __attribute__ ((interrupt(ADC_VECTOR))) ADC_ISR (void)
#else
#error Compiler not supported!
#endif
{
    if (__even_in_range(ADCIV,ADCIV_ADCIFG) == ADCIV_ADCIFG) {
        lightsensor_ADC_Result = ADCMEM0;
        __bic_SR_register_on_exit(LPM3_bits);              // Sleep Timer Exits LPM3
    }
}
