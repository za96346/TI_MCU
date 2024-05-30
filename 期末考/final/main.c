#include <msp430.h>

unsigned int ADC_Result;
#define DATA_PIN BIT0  // P2.0 為數據輸入
#define CLOCK_PIN BIT1 // P2.1 為時鐘
#define LATCH_PIN BIT2 // P2.2 為鎖存

// 定義七段顯示器的數字0-9的編碼（共陰）
const unsigned char digits[10] = {
  0x3F,  // 0
  0x06,  // 1
  0x5B,  // 2
  0x4F,  // 3
  0x66,  // 4
  0x6D,  // 5
  0x7D,  // 6
  0x07,  // 7
  0x7F,  // 8
  0x6F   // 9
};

void setupIO() {
  P2DIR |= DATA_PIN + CLOCK_PIN + LATCH_PIN;  // 設定為輸出模式
  P2OUT &= ~(DATA_PIN + CLOCK_PIN + LATCH_PIN);  // 初始化為低
}

void shiftOut(unsigned char data) {
  int i = 0;
  for (i = 0; i < 8; i++) {
    if (data & 0x80) // 檢查最高位
      P2OUT |= DATA_PIN;
    else
      P2OUT &= ~DATA_PIN;

    P2OUT |= CLOCK_PIN; // 時鐘上升沿
    P2OUT &= ~CLOCK_PIN; // 時鐘下降沿
    data <<= 1; // 左移一位
  }
}

void displayDigit(int num) {
  P2OUT &= ~LATCH_PIN; // 鎖存低
  shiftOut(digits[num]); // 輸出數字
  P2OUT |= LATCH_PIN; // 鎖存高
}

int main(void)
{
    WDTCTL = WDTPW | WDTHOLD;                                // Stop WDT

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

    while(1)
    {
        ADCCTL0 |= ADCENC | ADCSC;                           // Sampling and conversion start
        __bis_SR_register(LPM0_bits | GIE);                  // LPM0, ADC_ISR will force exit
        __no_operation();                                    // For debug only

        unsigned int tens = (ADC_Result / 100) % 10;  // Get tens digit
        unsigned int ones = ADC_Result % 10;  // Get units digit

        displayDigit(tens);  // 显示十位数
        __delay_cycles(50000);  // 短暂延迟
        displayDigit(ones);  // 显示个位数
        __delay_cycles(500000);  // 主延迟


        if (ADC_Result < 0x7FF)
            P1OUT &= ~BIT0;                                  // Clear P1.0 LED off
        else
            P1OUT |= BIT0;                                   // Set P1.0 LED on
        __delay_cycles(500000);
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
