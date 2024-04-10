#include <driverlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lightsensor.h"


/* Function Declarations */
void init_GPIO(void);

void init_EUSCI(void);

/**
 * main.c
 */
int main(void)
{
    /* Stop watchdog timer */
    WDT_A_hold(WDT_A_BASE);

    init_GPIO();
    init_EUSCI();
    lightsensor_init_ADC();
    lightsensor_init_SACOA();
	
    while(true)
    {
        __bis_SR_register(LPM0_bits + GIE);
        runningAvg = (( runningAvg * 9 ) + lightsensor_ADC_Result)/10;
        int diff = (runningAvg - calibratedADC)/4;

        if (diff < deadzone) {
            diff *= -1;
            // 当LED2亮时，将P5.2设置为高电平
            P5OUT |= BIT2;
        }
        else if (diff > deadzone) {
            // 当LED2熄灭时，将P5.2设置为低电平
            P5OUT &= ~BIT2;
        }
    }
}

void init_GPIO(void) {
    PMM_unlockLPM5();

    GPIO_clearInterrupt(GPIO_PORT_P2, GPIO_PIN3);

    // 将P5.2设置为输出模式
    P5DIR |= BIT2;  // 将P5.2设为输出
    P5OUT &= ~BIT2; // 初始状态设置为低电平
}

// Initialize EUSCI
void init_EUSCI(void)
{
    // Configure UCA1TXD and UCA1RXD
    GPIO_setAsPeripheralModuleFunctionInputPin(GPIO_PORT_P4, GPIO_PIN2, GPIO_PRIMARY_MODULE_FUNCTION);
    GPIO_setAsPeripheralModuleFunctionOutputPin(GPIO_PORT_P4, GPIO_PIN3, GPIO_PRIMARY_MODULE_FUNCTION);

    // Configure UART
    // ClockSource = SMCLK = 24MHz, Baudrate = 115200bps
    // http://software-dl.ti.com/msp430/msp430_public_sw/mcu/msp430/MSP430BaudRateConverter/index.html
    EUSCI_A_UART_initParam param = {0};
    param.selectClockSource = EUSCI_A_UART_CLOCKSOURCE_SMCLK;
    param.clockPrescalar = 13;
    param.firstModReg = 0;
    param.secondModReg = 37;
    param.parity = EUSCI_A_UART_NO_PARITY;
    param.msborLsbFirst = EUSCI_A_UART_LSB_FIRST;
    param.numberofStopBits = EUSCI_A_UART_ONE_STOP_BIT;
    param.uartMode = EUSCI_A_UART_MODE;
    param.overSampling = EUSCI_A_UART_OVERSAMPLING_BAUDRATE_GENERATION;

    if(STATUS_FAIL == EUSCI_A_UART_init(EUSCI_A1_BASE, &param))
    {
        return;
    }

    EUSCI_A_UART_enable(EUSCI_A1_BASE);

    EUSCI_A_UART_clearInterrupt(EUSCI_A1_BASE,
                                EUSCI_A_UART_RECEIVE_INTERRUPT);

    // Enable USCI_A0 RX interrupt
    EUSCI_A_UART_enableInterrupt(EUSCI_A1_BASE,
                                 EUSCI_A_UART_RECEIVE_INTERRUPT);      // Enable interrupt
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
