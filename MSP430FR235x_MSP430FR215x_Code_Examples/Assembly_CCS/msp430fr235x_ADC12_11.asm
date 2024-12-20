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
;  MSP430FR235x Demo - ADC, Sample A1, 1.5V Ref, TB0.1 Trig, Set P1.2 if A1>0.5V
;
;  Description: This example works on Repeat-Single-Channel Mode.
;  A1 is sampled 16/second (ACLK/1024) with reference to 1.5V.
;  Timer_B is run in upmode and TB1.1B is used to automatically trigger
;  ADC conversion. Internal oscillator times sample (16x) and conversion(13x).
;  Inside ADC_ISR if A1 > 0.5V, P1.2 is set, else reset. Normal mode is LPM3.
;  ACLK = XT1 = 32768Hz, MCLK = SMCLK = default DCODIV ~1MHz.
;  * An external watch crystal on XIN XOUT is required for ACLK *
;
;                MSP430FR2355
;             -----------------
;         /|\|              XIN|-
;          | |                 |  ~32768Hz
;          --|RST          XOUT|-
;            |                 |
;        >---|P1.1/A1      P1.2|--> LED
;
;
;   Cash Hao
;   Texas Instruments Inc.
;   November 2016
;   Built with Code Composer Studio v6.2.0
;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
            .global __STACK_END
            .sect   .stack                          ; Make stack linker segment ?known?

            .global _main
            .text                                   ; Assemble to Flash memory
            .retain                                 ; Ensure current section gets linked
            .retainrefs
_main

RESET       mov.w   #__STACK_END,SP                 ; Initialize stack pointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL          ; Stop WDT

SetupP1     bis.b   #BIT2,&P1DIR                    ; P1.2 output
            bic.b   #BIT2,&P1OUT                    ; Clear P1.2
            bis.b   #BIT1,&P1SEL0                   ; ADC A1 pin
            bis.b   #BIT1,&P1SEL1
            bis.b   #BIT6|BIT7,&P2SEL1              ; P2.6~P2.7: crystal pins
            bic.w   #LOCKLPM5,PM5CTL0               ; Unlock I/O pins

SetupXT1    mov.w   #SELA__XT1CLK,&CSCTL4           ; Set ACLK = XT1; MCLK = SMCLK = DCO
OSCFlag     bic.w   #XT1OFFG+DCOFFG,&CSCTL7         ; Clear XT1,DCO fault flags
            bic.w   #OFIFG,&SFRIFG1                 ; Clear fault flags
            bit.w   #OFIFG,&SFRIFG1                 ; Test oscilator fault flag
            jnz     OSCFlag

SetupADC    mov.w   #ADCMSC+ADCON,&ADCCTL0          ; ADCON
            mov.w   #ADCSHP+ADCSHS_2+ADCCONSEQ_2,&ADCCTL1  ; repeat single channel; TB1.1 trig sample start
            mov.w   #ADCRES_2,&ADCCTL2              ; 12-bit conversion results
            mov.w   #ADCSREF_1+ADCINCH_1,&ADCMCTL0  ; A0 ADC input select; Vref=1.5V
            bis.w   #ADCIE0,&ADCIE                  ; Enable ADC conversion interrupt

SetupREF    mov.b   #PMMPW_H,&PMMCTL0_H             ; Unlock the PMM registers
            mov.w   #INTREFEN|REFVSEL_0,&PMMCTL2    ; Enable internal 1.5V reference
            mov.w   #200,R15                        ; Delay ~400 cycles for reference settling
L2          dec.w   R15                             ; Decrement R15
            jnz     L2                              ; Delay over?

            bis.w   #ADCENC,&ADCCTL0                ; ADC Enable

SetupTB     mov.w   #1024-1,&TB1CCR0                ; PWM Period
            mov.w   #512-1,&TB1CCR1                 ; TB1.1 ADC trigger
            mov.w   #OUTMOD_4,&TB1CCTL1             ; TB1CCR0 toggle
            mov.w   #TBSSEL__ACLK+MC_1+TBCLR,&TB1CTL; ACLK, up mode
            nop
            bis.w   #LPM3+GIE,SR                    ; Enter LPM3 with interrupt
            nop
;-------------------------------------------------------------------------------
ADC_ISR;    ADC interrupt service routine
;-------------------------------------------------------------------------------
            add.w   &ADCIV,PC                       ; add offset to PC
            reti                                    ; No Interrupt
            reti                                    ; Conversion result overflow
            reti                                    ; Conversion time overflow
            reti                                    ; ADHI
            reti                                    ; ADLO
            reti                                    ; ADIN
            jmp     ADMEM
            reti
ADMEM       cmp.w   #0555h,&ADCMEM0                 ; ADCMEM = A0 < 0.5V?
            jhs     L3
            bic.b   #BIT2,&P1OUT                     ; P1.2 = 0
            reti
L3          bis.b   #BIT2,&P1OUT                     ; P1.2 = 1
            reti
            
;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR                    ; MSP430 RESET Vector
            .short  RESET
            .sect   ADC_VECTOR                      ; ADC Vector
            .short  ADC_ISR
            .end
