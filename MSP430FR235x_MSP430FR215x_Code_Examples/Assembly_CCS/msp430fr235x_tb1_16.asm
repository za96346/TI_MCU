; --COPYRIGHT--,BSD_EX
;  Copyright (c) 2016, Texas Instruments Incorporated
;  All rights reserved.
;
;  Redistribution and use in source and binary forms, with or without
;  modification, are permitted provided that the following conditions
;  are met:
;
;  *  Redistributions of source code must retain the above copyright
;     notice, this list of conditions and the following disclaimer.
;
;  *  Redistributions in binary form must reproduce the above copyright
;     notice, this list of conditions and the following disclaimer in the
;     documentation and/or other materials provided with the distribution.
;
;  *  Neither the name of Texas Instruments Incorporated nor the names of
;     its contributors may be used to endorse or promote products derived
;     from this software without specific prior written permission.
;
;  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
;  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
;  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
;  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
;  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
;  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
;  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; ******************************************************************************
;
;                        MSP430 CODE EXAMPLE DISCLAIMER
;
;  MSP430 code examples are self-contained low-level programs that typically
;  demonstrate a single peripheral function or device feature in a highly
;  concise manner. For this the code may rely on the device's power-on default
;  register values and settings such as the clock configuration and care must
;  be taken when combining code from several examples to avoid potential side
;  effects. Also see www.ti.com/grace for a GUI- and www.ti.com/msp430ware
;  for an API functional library-approach to peripheral configuration.
;
; --/COPYRIGHT--
;*******************************************************************************
;  MSP430FR235x Demo - Timer1_B3, PWM TB1.1-2, Up Mode, DCO SMCLK
;
;  Description: This program generates two PWM outputs on P2.0,P2.1 using
;  Timer1_B configured for up mode. The value in CCR0, 1000-1, defines the PWM
;  period and the values in CCR1 and CCR2 the PWM duty cycles. Using ~1MHz
;  SMCLK as TBCLK, the timer period is ~1ms with a 75% duty cycle on P2.0
;  and 25% on P2.1.
;  ACLK = n/a, SMCLK = MCLK = TBCLK = 1MHz
;
;
;           MSP430FR2355
;         ---------------
;     /|\|               |
;      | |               |
;      --|RST            |
;        |               |
;        |     P2.0/TB1.1|--> CCR1 - 75% PWM
;        |     P2.1/TB1.2|--> CCR2 - 25% PWM
;
;  
;   Darren Lu
;   Texas Instruments Inc.
;   Oct. 2016
;   Built with Code Composer Studio v6.2
;******************************************************************************
            .cdecls C,LIST,"msp430.h"                       ; Include device header file
;-------------------------------------------------------------------------------
            .def    RESET                                   ; Export program entry-point to
                                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack                                  ; Make stack linker segment ?known?

            .global _main
            .text                                           ; Assemble to Flash memory
            .retain                                         ; Ensure current section gets linked
            .retainrefs
_main

RESET       mov.w   #__STACK_END,SP                         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL                  ; Stop WDT

            bis.b   #BIT0+BIT1,&P2DIR                       ; P2.0 and P2.1 output
            bis.b   #BIT0+BIT1,&P2SEL0                      ; P2.0 and P2.1 options select
            bic.w   #LOCKLPM5,&PM5CTL0                      ; Unlock I/O pin
                                                            
            mov.w   #1000-1,&TB1CCR0                        ; PWM period
            mov.w   #OUTMOD_7,&TB1CCTL1                     ; CCR1 reset/set
            mov.w   #750,&TB1CCR1                           ; CCR1 PWM duty cycle
            mov.w   #OUTMOD_7,&TB1CCTL2                     ; CCR2 reset/set
            mov.w   #250,&TB1CCR2                           ; CCR2 PWM duty cycle
            mov.w   #TBSSEL__SMCLK|MC__UP|TBCLR,&TB1CTL     ; SMCLK, up mode, clear TAR

Mainloop    bis.w   #LPM0,SR                                ; Enter LPM0
            nop                                             ; For debugger

;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR                            ; MSP430 RESET Vector
            .short  RESET
            .end
