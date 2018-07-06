;**********************************************************
;*  lab02.asm
;*
;*  This program is based on tut877.asm, which is
;*  installed with MPLAB v5.70.
;*
;*  Modified by Dan Simon
;*          and Rick Rarick
;*
;*  This program configures the ADC Module on the PIC to 
;*  convert a voltage signal of 0 - 5 Vdc applied to Pin 2
;*  (AN0, A/D channel 0) to the equivalent 8-bit binary value and 
;*  display the results on 8 LEDs on PORTC.  
;*  A pushbutton is connected to PORTB<0> (RB0) so that when pressed,
;*  PORTB<0> is low and the 8 PORTC bits are set to 0 (LEDs off).
;*
;**********************************************************

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Assembler Directives
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	list p=16f877
	include "p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   	config_1 & config_2
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Begin executable code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
		
	org	0x000			; Start at the reset vector
	nop					; Reserved for compatibility with older ICDs

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initializations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
Init
	banksel PORTC		; Default --- Bank 0
	movlw	B'11111111'
    movwf	PORTC		
	
	; Set up the Timer0 control register.
	
	banksel OPTION_REG	; Switch to Bank 1
	movlw	B'10010111'	; Use the internal instruction clock,
						; prescaler is assigned to Timer0,
	movwf	OPTION_REG	; prescaler - 1:256
	
	; Set up PORTB for input on RB0 and PORTC for output to LEDs

	bsf		TRISB, 0	; TRISB is in Bank 1. RB0 input.
	
	clrf	TRISC		; TRISC is in Bank 1. All pins output.				

	banksel PORTC		; Return to default Bank 0
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Main program
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
InitMain
	clrf	TMR0
    bcf		INTCON,T0IF

Main
	btfss	INTCON,T0IF	; Test the TIMER0 interrupt flag bit (T0IF).

	goto	Main

  	bcf		INTCON,T0IF	; Clear the T0IF bit for the next interrupt.

    decfsz	PORTC

	goto	InitMain		
	
	
LoopUntilPressed			; Loop if PORTB<0> = 0 (button pressed)

	btfsc	PORTB, 0	; If PORTB<0> = 0, skip the "goto" instruction.
	
	goto	LoopUntilPressed

InitAgain
	movlw	B'11111111'
    movwf	PORTC		
	goto	Main		

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; End program
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

	end					; End of program
