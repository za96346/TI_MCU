; --COPYRIGHT--,BSD_EX
;  Copyright (c) 2014, Texas Instruments Incorporated
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
;  MSP430FR235x Demo - Configure MCLK for 24MHz operation, and XT1 sourcing
;                                     FLLREF and ACLK. 
;
;  Description: Configure MCLK for 24MHz. FLL reference clock is XT1. At this 
;                    speed, the FRAM requires wait states. 
;                    ACLK = XT1 ~32768Hz, SMCLK = MCLK = 24MHz. 
;                    Toggle LED to indicate that the program is running.
;
;           MSP430FR2355
;         ---------------
;        |               |
;        |            XIN|--
;     /|\|               |  ~32768Hz
;      | |           XOUT|--
;      --|RST            |
;        |          P1.2 |---> LED
;        |               |
;        |          P1.0 |---> SMCLK = 24MHz
;        |          P1.1 |---> ACLK  = 32768Hz
;
;
;   Darren Lu
;   Texas Instruments Inc.
;   Oct. 2016
;   Built with Code Composer Studio v6.2
;******************************************************************************

;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h" ; Include device header file
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack                  ; Make stack linker segment ?known?
;-------------------------------------------------------------------------------
            .global _main
            .text                           ; Assemble to Flash memory
            .retain                         ; Ensure current section gets linked
            .retainrefs
_main
RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w   #WDTPW+WDTHOLD,&WDTCTL  ; Stop WDT

            ; Configure two FRAM waitstate as required by the device datasheet for MCLK
            ; operation at 24MHz(beyond 8MHz) _before_ configuring the clock system.
            mov.w   #FRCTLPW+NWAITS_2,&FRCTL0

XT1on       bis.b   #BIT6+BIT7,&P2SEL1      ; P2.6~P2.7: crystal pins
XT1chk      bic.w   #XT1OFFG+DCOFFG,&CSCTL7 ; Clear XT1,DCO fault flags
            bic.w   #OFIFG,&SFRIFG1         ; Clear fault flags
            bit.w   #OFIFG,&SFRIFG1         ; Test oscilator fault flag
            jnz     XT1chk                  ; If set, attempt to clear again
                                            ; If clear, continue

            bis.w   #SCG0,SR                ; Disable FLL
            bis.w   #SELREF__XT1CLK,&CSCTL3 ; Set XT1 as FLL reference source
            mov.w   #0,&CSCTL0              ; clear DCO and MOD registers
            bic.w   #DCORSEL_7,&CSCTL1      ; Clear DCO frequency select bits first
            bis.w   #DCORSEL_5,&CSCTL1      ; Set DCO = 16MHz, max in FR413x
            mov.w   #FLLD_0+487,&CSCTL2     ; DCODIV = 16MHz
            nop
            nop
            nop
            bic.w   #SCG0,SR                ; Enable FLL
Unlock      mov.w   &CSCTL7,R13
            and.w   #FLLUNLOCK0|FLLUNLOCK1,R13
            jnz     Unlock                  ; Check if FLL is locked
            
            mov.w   #SELMS__DCOCLKDIV+SELA__XT1CLK,&CSCTL4

            bis.b   #BIT0+BIT1+BIT2,&P1DIR   ; set ACLK/SMCLK/LED pin
            bis.b   #BIT0+BIT1,&P1SEL1

            ; Disable the GPIO power-on default high-impedance mode
            ; to activate previously configured port settings
            bic.w   #LOCKLPM5,PM5CTL0

Mainloop    xor.b   #BIT2,&P1OUT            ; toggle P1.2
            mov.w   #(65000), R13           ; Arbitrary delay to blink the LED
Delay1      sub.w   #1, R13
            jne     Delay1
            jmp     Mainloop                ; endless loop
;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR            ; MSP430 RESET Vector
            .short  RESET                   ;
            .end
