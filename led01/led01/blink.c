#include <msp430.h>

void main(void) {
    WDTCTL = WDTPW | WDTHOLD;               // 停止看门狗定时器
    PM5CTL0 &= ~LOCKLPM5;                   // 禁用GPIO上电默认高阻抗模式
                                            // 以激活先前配置的端口设置
    P1DIR |= 0x01;                          // 将P1.0设置为输出方向
    P6DIR |= 0x01;                          // 将P6.0设置为输出方向

    for(;;) {
        volatile unsigned int i;

        P1OUT ^= 0x01;                      // 切换P1.0状态
        P6OUT ^= 0x01;                      // 同时切换P6.0状态

        i = 100000;                         // 软件延迟
        do i--;
        while(i != 0);
    }
}
