#include <msp430.h>

unsigned int ADC_Result;

// 單個 adc gpio 初始話
void adcGpioInit(void)
{
    // Configure GPIO
    P1DIR |= BIT0;                                           // Set P1.0/LED to output direction
    P1OUT &= ~BIT0;                                          // P1.0 LED off

    // Configure ADC A1 pin
    P1SEL0 |= BIT1;
    P1SEL1 |= BIT1;

    // Disable the GPIO power-on default high-impedance mode to activate
    // previously configured port settings
    PM5CTL0 &= ~LOCKLPM5;

    // Configure ADC12
    ADCCTL0 |= ADCSHT_2 | ADCON;                             // ADCON, S&H=16 ADC clks
    ADCCTL1 |= ADCSHP;                                       // ADCCLK = MODOSC; sampling timer
    ADCCTL2 &= ~ADCRES;                                      // clear ADCRES in ADCCTL
    ADCCTL2 |= ADCRES_2;                                     // 12-bit conversion results
    ADCMCTL0 |= ADCINCH_1;                                   // A1 ADC input select; Vref=AVCC
    ADCIE |= ADCIE0;                                         // Enable ADC conv complete interrupt
}

// 七段顯示器初始化
void sevenSegmentInit(void)
{
    P3DIR |= 0xFF; // 將 P3.0 - P3.7 設為輸出
    P5DIR |= 0x0F; // 將 P5.0 - P5.3 設為輸出
    P6DIR |= 0x0F; // 將 P6.0 - P6.3 設為輸出
}

// 七段顯示器顯示雙位數字
void displayDigit(int thousand, int hundred, int ten, int one)
{
    P3OUT = (ten << 4) | one;
    P5OUT = (0 << 4 ) | hundred;
    P6OUT = (0 << 4) | thousand;

}

int main(void)
{
    WDTCTL = WDTPW | WDTHOLD;                                // Stop WDT
    sevenSegmentInit();
    adcGpioInit();

    while(1)
    {
        ADCCTL0 |= ADCENC | ADCSC;                           // Sampling and conversion start
        __bis_SR_register(LPM0_bits | GIE);                  // LPM0, ADC_ISR will force exit
        __no_operation();                                    // For debug only

        unsigned int thousand = (ADC_Result / 1000) % 10;  // Get t digit
        unsigned int hundred = (ADC_Result / 100) % 10;  // Get h digit
        unsigned int tens = (ADC_Result / 10) % 10;  // Get tens digit
        unsigned int ones = ADC_Result % 10;  // Get units digit

        displayDigit(thousand, hundred, tens, ones);  // 显示十位数

        __delay_cycles(1000000);
    }
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
            ADC_Result = ADCMEM0;

            __bic_SR_register_on_exit(LPM0_bits);            // Clear CPUOFF bit from LPM0
            break;
        default:
            break;
    }
}
