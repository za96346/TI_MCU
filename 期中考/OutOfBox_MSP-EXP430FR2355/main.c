#include <driverlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <jsmn.h>

#include "lightsensor.h"
#include "functiongenerator.h"

/* Constants */
#define MAX_STR_LEN         256

/* UART variables */
jsmn_parser p;
jsmntok_t t[64]; /* We expect no more than 64 tokens */
bool rxStringReady = false;
char rxString[MAX_STR_LEN];
char txString[MAX_STR_LEN];

/* Function Declarations */
void init_GPIO(void);
void init_CS(void);
void init_EUSCI(void);

void transmitString(char *);
void receiveString(char);
static int jsoneq(const char *, jsmntok_t *, const char *);

/**
 * main.c
 */
int main(void)
{
    /* Stop watchdog timer */
    WDT_A_hold(WDT_A_BASE);

    init_GPIO();
    init_CS();
    init_EUSCI();
	
    while(1)
    {
        lightsensor();
    }
}

void init_GPIO(void) {
    /* Initialize all GPIO to output low for minimal LPM power consumption */
    GPIO_setAsOutputPin(GPIO_PORT_PA, GPIO_PIN_ALL16);
    GPIO_setAsOutputPin(GPIO_PORT_PB, GPIO_PIN_ALL16);
    GPIO_setAsOutputPin(GPIO_PORT_PC, GPIO_PIN_ALL16);
    GPIO_setAsOutputPin(GPIO_PORT_PD, GPIO_PIN_ALL16);
    GPIO_setAsOutputPin(GPIO_PORT_PE, GPIO_PIN_ALL16);

    GPIO_setOutputLowOnPin(GPIO_PORT_PA, GPIO_PIN_ALL16);
    GPIO_setOutputLowOnPin(GPIO_PORT_PB, GPIO_PIN_ALL16);
    GPIO_setOutputLowOnPin(GPIO_PORT_PC, GPIO_PIN_ALL16);
    GPIO_setOutputLowOnPin(GPIO_PORT_PD, GPIO_PIN_ALL16);
    GPIO_setOutputLowOnPin(GPIO_PORT_PE, GPIO_PIN_ALL16);

    PMM_unlockLPM5();

    GPIO_clearInterrupt(GPIO_PORT_P2, GPIO_PIN3);
}

void init_CS(void) {
    FRCTL0 = FRCTLPW | NWAITS_2 ;                // 设置FRAM等待状态。当主时钟（MCLK）频率超过8MHz时，需要增加等待状态以满足FRAM的时序要求。

    P2SEL1 |= BIT6 | BIT7;                       // 配置P2.6和P2.7引脚作为晶体振荡器引脚，用于外部时钟源。
    do
    {
        CSCTL7 &= ~(XT1OFFG | DCOFFG);           // Clear XT1 and DCO fault flag
        SFRIFG1 &= ~OFIFG;
    } while (SFRIFG1 & OFIFG);                   // 循环检测并清除振荡器故障标志，确保时钟源稳定。

    __bis_SR_register(SCG0);                     // 禁用频率锁定环（FLL），准备进行时钟设置
    CSCTL3 |= SELREF__XT1CLK;                    // Set XT1 as FLL reference source
    CSCTL0 = 0;                                  // clear DCO and MOD registers
    CSCTL1 = DCORSEL_7;                         // Set DCO = 24MHz
    CSCTL2 = FLLD_0 + 731;                       // DCOCLKDIV = 24MHz
    __delay_cycles(3);
    __bic_SR_register(SCG0);                     // 重新启用FLL，完成时钟设置
    while(CSCTL7 & (FLLUNLOCK0 | FLLUNLOCK1));   // 循环等待直到FLL锁定，确保时钟稳定

    CSCTL4 = SELMS__DCOCLKDIV | SELA__XT1CLK;   // set XT1 (~32768Hz) as ACLK source, ACLK = 32768Hz
                                                 // default DCOCLKDIV as MCLK and SMCLK source
    
    P3DIR |= BIT4;
    P3SEL0 |= BIT4;
    P3SEL1 &= ~BIT4;
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
    switch(__even_in_range(ADCIV,ADCIV_ADCIFG))
    {
        case ADCIV_NONE:
            break;
        case ADCIV_ADCOVIFG:
            break;
        case ADCIV_ADCTOVIFG:
            break;
        case ADCIV_ADCHIIFG:
            break;
        case ADCIV_ADCLOIFG:
            break;
        case ADCIV_ADCINIFG:
            break;
        case ADCIV_ADCIFG:
            lightsensor_ADC_Result = ADCMEM0;
            __bic_SR_register_on_exit(LPM3_bits);              // Sleep Timer Exits LPM3
            break;
        default:
            break;
    }
}

// EUSCI interrupt service routine
#if defined(__TI_COMPILER_VERSION__) || defined(__IAR_SYSTEMS_ICC__)
#pragma vector=USCI_A1_VECTOR
__interrupt void USCI_A1_ISR(void)
#elif defined(__GNUC__)
void __attribute__ ((interrupt(USCI_A1_VECTOR))) USCI_A1_ISR (void)
#else
#error Compiler not supported!
#endif
{
    switch(__even_in_range(UCA1IV,USCI_UART_UCTXCPTIFG))
    {
        case USCI_NONE: break;
        case USCI_UART_UCRXIFG:
            functiongenerator_disable();
            Timer_B_stop(TIMER_B0_BASE);
            // Read buffer
            receiveString(UCA1RXBUF);

            if (rxStringReady)
            {
                int i;
                int r;
                jsmn_init(&p);
                r = jsmn_parse(&p, rxString, strlen(rxString), t, sizeof(t)/sizeof(t[0]));

                // Loop over keys of JSON object
                for (i = 1; i < r; i++) {
                    if (jsoneq(rxString, &t[i], "inputSignalSource") == 0) {
                        // input signal source received from PC
                        inputSignalSource = strtol( rxString+t[i+1].start, NULL, 10);
                        if (inputSignalSource == 1)
                            opAmpMode = 0;
                        else if (inputSignalSource == 2)
                            opAmpMode = 1;
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "signalType") == 0) {
                        // New Signal Frequency received from PC
                        signalType = strtol( rxString+t[i+1].start, NULL, 10);
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "signalFreq") == 0) {
                        // New Signal Frequency received from PC
                        signalFreq = strtol( rxString+t[i+1].start, NULL, 10);
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "signalAmp") == 0) {
                        // New Signal Amplitude received from PC
                        signalAmp = strtol( rxString+t[i+1].start, NULL, 10);
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "dacFreq") == 0) {
                        // New DAC Sample Frequency received from PC
                        dacFreq = strtol( rxString+t[i+1].start, NULL, 10);
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "adcFreq") == 0) {
                        // New ADC Sample Frequency received from PC
                        adcFreq = strtol( rxString+t[i+1].start, NULL, 10);
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "opAmpMode") == 0) {
                        // New ADC Sample Frequency received from PC
                        opAmpMode = strtol( rxString+t[i+1].start, NULL, 10);
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "opAmpGain") == 0) {
                        // New ADC Sample Frequency received from PC
                        opAmpGain = strtol( rxString+t[i+1].start, NULL, 10);
                        i++;
                    }
                    if (jsoneq(rxString, &t[i], "mode") == 0) {
                        __bic_SR_register_on_exit(LPM3_bits);
                        i++;
                    }
                }

                Timer_B_startCounter(TIMER_B0_BASE, TIMER_B_UP_MODE);
                lightsensor_init_ADC();

                rxStringReady = false;
            }
            break;
        case USCI_UART_UCTXIFG: break;
        case USCI_UART_UCSTTIFG: break;
        case USCI_UART_UCTXCPTIFG: break;
        default: break;
    }
}

// Transmits string buffer through EUSCI UART
void transmitString(char *str)
{
    unsigned int i = 0;
    for(i = 0; i < strlen(str); i++)
    {
        if (str[i] != 0)
        {
            // Transmit Character
            while (EUSCI_A_UART_queryStatusFlags(EUSCI_A1_BASE, EUSCI_A_UART_BUSY));
            EUSCI_A_UART_transmitData(EUSCI_A1_BASE, str[i]);
        }
    }
}

// Receives strings terminated with \n
void receiveString(char data) {
    static bool rxInProgress = false;
    static unsigned int charCnt = 0;

    if(!rxInProgress){
        if ((data != '\n') ){
            rxInProgress = true;
            charCnt = 0;
            rxString[charCnt] = data;
        }
    }else{ // in progress
        charCnt++;
        if((data != '\n')){
            if (charCnt >= MAX_STR_LEN){
                rxInProgress = false;
            }else{
                rxString[charCnt] = data;
            }
        }else{
            rxInProgress = false;
            rxString[charCnt] = '\0';
            // String receive complete
            rxStringReady = true;
        }
    }
}

// Compare JSON keys
static int jsoneq(const char *json, jsmntok_t *tok, const char *s) {
    if (tok->type == JSMN_STRING && (int) strlen(s) == tok->end - tok->start &&
            strncmp(json + tok->start, s, tok->end - tok->start) == 0) {
        return 0;
    }
    return -1;
}
