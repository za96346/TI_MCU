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
;  MSP430FR235x Demo - ADC, Sample A1, 1.5V Shared Ref, Set P1.2 if A1 > 0.5V
;
;  Description: This example works on Single-Channel Single-Conversion Mode.
;  Software sets ADCSC to start sample and conversion - ADCSC automatically
;  cleared at EOC. ADC internal oscillator times sample (16x) and conversion.
;  In Mainloop MSP430 waits in LPM0 to save power until ADC conversion complete,
;  ADC_ISR will force exit from LPM0 in Mainloop on reti.
;  If A1 > 0.5V, P1.2 set, else reset.
;  ACLK = default REFO ~32768Hz, MCLK = SMCLK = default DCODIV ~1MHz.
;
;               MSP430FR2355
;            -----------------
;        /|\|                 |
;         | |                 |
;         --|RST              |
;           |                 |
;       >---|P1.1/A1      P1.0|--> LED
;
;
;   Cash Hao
;   Texas Instruments Inc.
;   November 2016
;   Built with Code Composer Studio v6.2.0
;*******************************************************************************
 .cdecls C,LIST,  "msp430.h"
;-------------------------------------------------------------------------------
            .def    RESET                             ; Export program entry-point to
                                                      ; make it known to linker.
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack                            ; Make stack linker segment ?known?

            .global _main
            .text                                     ; Assemble to Flash memory
            .retain                                   ; Ensure current section gets linked
            .retainrefs
_main
RESET       mov.w   #__STACK_END,SP                   ; Initialize stack pointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL            ; Stop WDT

SetupP1     bis.b   #BIT2,&P1DIR                      ; P1.2 output
            bic.b   #BIT2,&P1OUT                      ; P1.2 LED off
            bis.b   #BIT1,&P1SEL0                     ; ADC A1 pin
            bis.b   #BIT1,&P1SEL1
            bic.w   #LOCKLPM5,PM5CTL0                 ; Unlock I/O pins

SetupADC    mov.w   #ADCSHT_2|ADCON,&ADCCTL0          ; ADC on
            bis.w   #ADCSHP,&ADCCTL1                  ; ADCCLK = MODOSC; sampling timer
            bic.w   #ADCRES,&ADCCTL2                  ; clear ADCRES in ADCCTL
            bis.w   #ADCRES_2,&ADCCTL2                ; 12-bit conversion results
            bis.w   #ADCIE0,&ADCIE                    ; Enable ADC conv complete interrupt
            bis.w   #ADCINCH_1|ADCSREF_1,&ADCMCTL0    ; A1 ADC input select; Vref = 1.5V

            mov.b   #PMMPW_H,&PMMCTL0_H               ; Unlock the PMM registers
            mov.w   #INTREFEN+REFVSEL_0,&PMMCTL2      ; Enable internal 1.5V reference
PollREF     bit.w   #REFGENRDY,&PMMCTL2               ; Poll till internal reference settles
            jz      PollREF                           ;


Mainloop    bis.w   #ADCENC|ADCSC,&ADCCTL0            ; Start sampling/conversion
            nop
            bis.w   #LPM0+GIE,SR                      ; Enter LPM0 with interrupt
            nop

            cmp.w   #0555h,R5                         ; ADCMEM = A1 > 0.5V?
            jhs     L2
            bic.b   #BIT2,&P1OUT                      ; P1.2 = 0
            jmp     Mainloop
L2          bis.b   #BIT2,&P1OUT                      ; P1.2 = 1

            mov.w   #2500,R15                         ; Delay ~5000 cycles between conversions
L3          dec.w   R15                               ; Decrement R15
            jnz     L3                                ; Delay over?
            jmp     Mainloop                          ; Again

;-------------------------------------------------------------------------------
ADC_ISR;  ADC interrupt service routine
;-------------------------------------------------------------------------------
            add.w   &ADCIV,PC                         ; add offset to PC
            reti                                      ; No Interrupt
            reti                                      ; Conversion result overflow
            reti                                      ; Conversion time overflow
            reti                                      ; ADHI
            reti                                      ; ADLO
            reti                                      ; ADIN
            jmp     ADMEM
            reti
ADMEM       mov.w   &ADCMEM0,R5                       ; ADCIFG0
            bic.w   #CPUOFF,0(SP)                     ; Exit LPM0 on reti
            reti
            
;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
           .sect   RESET_VECTOR                       ; MSP430 RESET Vector
           .short  RESET
           .sect   ADC_VECTOR                         ; ADC Vector
           .short  ADC_ISR
           .end
