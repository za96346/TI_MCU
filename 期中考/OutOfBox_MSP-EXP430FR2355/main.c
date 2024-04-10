#include <driverlib.h>
#include "lightsensor.h"
#include "stdio.h"


void init_GPIO(void) {
    PMM_unlockLPM5();
    GPIO_clearInterrupt(GPIO_PORT_P2, GPIO_PIN3);

    // 将P5.2设置为输出模式
    P5DIR |= BIT2;  // 将P5.2设为输出
    P5OUT &= ~BIT2; // 初始状态设置为低电平
}

/**
 * main.c
 */
int main(void)
{
    /* Stop watchdog timer */
    WDT_A_hold(WDT_A_BASE);

    init_GPIO();
    lightsensor_init_SACOA();
    lightsensor_init_ADC();
	
    while(true)
    {
        __bis_SR_register(LPM0_bits + GIE);
        runningAvg = (( runningAvg * 9 ) + lightsensor_ADC_Result)/10;
        int diff = (runningAvg - calibratedADC) / 4;

        if (diff < deadzone) {
            // 将P5.2设置为高电平
            P5OUT |= BIT2;
        } else {
            // 将P5.2设置为低电平
            P5OUT &= ~BIT2;
        }
    }
}