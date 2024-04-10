#include "driverlib.h"
#include "lightsensor.h"

/* FRAM Variable that stores lightsensor ADC results*/
#if defined(__TI_COMPILER_VERSION__)
#pragma PERSISTENT(lightsensor_ADC_Result)
#elif defined(__IAR_SYSTEMS_ICC__)
__persistent
#endif
unsigned int lightsensor_ADC_Result = 0;          // ADC conversion result

void lightsensor_init_SACOA(void) {
    //Configure Op-Amp functionality
    GPIO_setAsPeripheralModuleFunctionInputPin(GPIO_PORT_P3,
                                               GPIO_PIN1 | GPIO_PIN3 | GPIO_PIN2,
                                               GPIO_TERNARY_MODULE_FUNCTION);

    //Select external source for both positive and negative inputs
    SAC_OA_init(SAC2_BASE, SAC_OA_POSITIVE_INPUT_SOURCE_EXTERNAL,
                SAC_OA_NEGATIVE_INPUT_SOURCE_EXTERNAL);

    //Select low speed and low power mode
    SAC_OA_selectPowerMode(SAC2_BASE, SAC_OA_POWER_MODE_LOW_SPEED_LOW_POWER);

    SAC_OA_enable(SAC2_BASE);                  // Enable SAC2 OA
    SAC_enable(SAC2_BASE);                     // Enable SAC2

    //Select external source for both positive and negative inputs
    SAC_OA_init(SAC0_BASE, SAC_OA_POSITIVE_INPUT_SOURCE_PAIR_OA,
                SAC_OA_NEGATIVE_INPUT_SOURCE_PGA);

    SAC_OA_enable(SAC0_BASE);                  // Enable SAC0 OA
    SAC_enable(SAC0_BASE);                     // Enable SAC0
}

void lightsensor_init_ADC(void) {
    //Initialize the ADC Module
    /*
     * Base Address for the ADC Module
     * Use TB1.1B as sample/hold signal to trigger conversion
     * USE MODOSC 5MHZ Digital Oscillator as clock source
     * Use default clock divider of 1
     */
    ADC_init(ADC_BASE,
             ADC_SAMPLEHOLDSOURCE_2,
             ADC_CLOCKSOURCE_ADCOSC,
             ADC_CLOCKDIVIDER_1);

    ADC_enable(ADC_BASE);

    /*
     * Base Address for the ADC Module
     * Sample/hold for 16 clock cycles
     * Do not enable Multiple Sampling
     */
    ADC_setupSamplingTimer(ADC_BASE,
                           ADC_CYCLEHOLD_16_CYCLES,
                           ADC_MULTIPLESAMPLESDISABLE);

    /*
     * Base Address for the ADC Module
     * Useing 12bit resolution
     */
    ADC_setResolution(ADC_BASE,
                      ADC_RESOLUTION_12BIT);

    //Configure the Memory Buffer
    /*
     * Base Address for the ADC Module
     * Use input A1
     * Use positive reference of AVcc
     * Use negative reference of AVss
     */
    ADC_configureMemory(ADC_BASE,
                        ADC_INPUT_VEREF_P,
                        ADC_VREFPOS_AVCC,
                        ADC_VREFNEG_AVSS);

    ADC_clearInterrupt(ADC_BASE,
                       ADC_COMPLETED_INTERRUPT);

    //Enable the Memory Buffer Interrupt
    ADC_enableInterrupt(ADC_BASE,
                        ADC_COMPLETED_INTERRUPT);

    // Generate sample/hold signal to trigger ADC conversion
    Timer_B_outputPWMParam param2 = {0};
    param2.clockSource = TIMER_B_CLOCKSOURCE_ACLK;
    param2.clockSourceDivider = TIMER_B_CLOCKSOURCE_DIVIDER_1;
    param2.timerPeriod = TIMER_PERIOD;
    param2.compareRegister = TIMER_B_CAPTURECOMPARE_REGISTER_1;
    param2.compareOutputMode = TIMER_B_OUTPUTMODE_TOGGLE_RESET;
    param2.dutyCycle = DUTY_CYCLE;
    Timer_B_outputPWM(TIMER_B1_BASE, &param2);

    //Enable and Start the conversion
    //in Single-Channel, Single Conversion Mode
    ADC_startConversion(ADC_BASE, ADC_REPEATED_SINGLECHANNEL);
}
