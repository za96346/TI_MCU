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
;  MSP430FR235x Demo -  eUSCI_A0 UART echo at 4800 baud using BRCLK = 32768Hz.
;
;  Description: This demo echoes back characters received via a PC serial port.
;  ACLK is used as UART clock source and the device is put in LPM3.
;  Note that level shifter hardware is needed to shift between RS232 and MSP
;  voltage levels.
;
;  The example code shows proper initialization of registers
;  and interrupts to receive and transmit data.
;  To test code in LPM3, disconnect the debugger.
;
;  ACLK = REFO = 32768Hz, MCLK = SMCLK = DCODIV ~1MHz.
;
;                MSP430FR2355
;             -----------------
;         /|\|                 |
;          | |                 |
;          --|RST              |
;            |                 |
;            |                 |
;            |     P1.7/UCA0TXD|----> PC (echo)
;            |     P1.6/UCA0RXD|<---- PC
;            |                 |
;
;   Darren Lu
;   Texas Instruments Inc.
;   Oct. 2016
;   Built with Code Composer Studio v6.2.0
;*******************************************************************************
            .cdecls C,LIST,"msp430.h"        ; Include device header file
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack                   ; Make stack linker segment ?known?

            .text                            ; Assemble to Flash memory
            .retain                          ; Ensure current section gets linked
            .retainrefs

RESET       mov.w   #__STACK_END,SP          ; Initialize stack pointer
            mov.w   #WDTPW+WDTHOLD,&WDTCTL   ; Stop WDT

            ; Disable the GPIO power-on default high-impedance mode
            ; to activate previously configured port settings
            bic.w   #LOCKLPM5,PM5CTL0

            bis.b   #0xFF,&P1DIR
            bis.b   #0xFF,&P2DIR
            bis.b   #0xFF,&P1REN
            bis.b   #0xFF,&P2REN
            bic.b   #0xFF,&P1OUT
            bic.b   #0xFF,&P2OUT

Go_on       bis.b   #BIT6+BIT7,&P1SEL0      ; Configure UART pins

            bis.w   #UCSWRST,&UCA0CTLW0     ; Configure UART
            bis.w   #UCSSEL_1,&UCA0CTLW0

            mov.b   #6,&UCA0BR0            ; 4800 baud
            clr.b   &UCA0BR1
            bis.w   #0xEE00,&UCA0MCTLW

            bic.w   #UCSWRST,&UCA0CTLW0     ; release from reset
            bis.w   #UCRXIE,&UCA0IE         ; enable RX interrupt

            nop
            bis.w   #LPM3+GIE,SR            ; Enable interrupt
            nop

;------------------------------------------------------------------------------
USCI_ISR ;    USCI Interrupt Service Routine
;------------------------------------------------------------------------------
            add.w   &UCA0IV,PC
            reti                            ; Vector  0: No interrupt
            jmp     UARTev                  ; Vector  2: USCI_UART_UCRXIFG
            reti                            ; Vector  4: USCI_UART_UCTXIFG
            reti                            ; Vector  6: USCI_UART_UCSTTIFG
            reti                            ; Vector  8: USCI_UART_UCTXCPTIFG

UARTev      bit.w   #UCTXIFG,&UCA0IFG       ; Test oscilator fault flag
            jz      UARTev
            mov.w   &UCA0RXBUF,&UCA0TXBUF
            nop
            reti
;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR            ; MSP430 RESET Vector
            .short  RESET                   ;
            .sect   USCI_A0_VECTOR          ; USCI_A0_VECTOR
            .short  USCI_ISR                ;
            .end
