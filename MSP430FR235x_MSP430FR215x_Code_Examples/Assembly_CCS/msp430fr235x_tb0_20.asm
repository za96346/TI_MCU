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
;******************************************************************************
;  MSP430FR235x Demo - Timer0_B3, PWM TB0.1-2, Up/Down Mode, 32kHz ACLK
;
;  Description: This program generates two PWM outputs on P1.6,7 using
;  Timer_B configured for up/down mode. The value in TBCCR0, 128, defines the
;  PWM period/2 and the values in TBCCR1 and TBCCR2 the PWM duty cycles. Using
;  32kHz ACLK as TBCLK, the timer period is 7.8ms with a 75% duty cycle on
;  P1.7 and 25% on P1.6. Normal operating mode is LPM3.
;  ACLK = TBCLK = REFO = 32768Hz, MCLK = 1MHz(default)
;  ;* External watch crystal on XIN XOUT is required for ACLK *;
;
;           MSP430FR2355
;         ---------------
;     /|\|               |
;      | |               |
;      --|RST            |
;        |               |
;        |     P1.6/TB0.1|--> CCR1 - 75% PWM
;        |     P1.7/TB0.2|--> CCR2 - 25% PWM
;
;   Darren Lu
;   Texas Instruments Inc.
;   Oct. 2016
;   Built with Code Composer Studio v6.2
;******************************************************************************

            .cdecls C,LIST,"msp430.h" ; Include device header file
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack                  ; Make stack linker segment ?known?
    
            .global _main
            .text                           ; Assemble to Flash memory
            .retain                         ; Ensure current section gets linked
            .retainrefs
_main
    
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop WDT

            bis.b   #BIT6|BIT7,&P1DIR       ; P1.6 and P1.7 output
            bis.b   #BIT6|BIT7,&P1SEL1      ; P1.6 and P1.7 options select
            bic.w   #LOCKLPM5,&PM5CTL0      ; Unlock I/O pin

SetupC0     mov.w   #128,&TB0CCR0           ; PWM Period/2
SetupC1     mov.w   #OUTMOD_6,&TB0CCTL1     ; TB0CCR1 toggle/set
            mov.w   #32,&TB0CCR1            ; TB0CCR1 PWM Duty Cycle
SetupC2     mov.w   #OUTMOD_6,&TB0CCTL2     ; TB0CCR2 toggle/set
            mov.w   #96,&TB0CCR2            ; TB0CCR2 PWM duty cycle
SetupTB     mov.w   #TBSSEL_1+MC_3,&TB0CTL  ; ACLK, updown mode
                                            ;
Mainloop    bis.w   #LPM3,SR                ; Enter LPM3
            nop                             ; Required only for debugger
                                            ;
;-------------------------------------------------------------------------------
;            Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect    RESET_VECTOR           ; MSP430 RESET Vector
            .short    RESET                 ;
            .end
