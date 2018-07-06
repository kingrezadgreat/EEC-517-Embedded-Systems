;********************************************************************
; lab09.asm
;
; Dan Simon,
; Rick Rarick
; Cleveland State University
;
; Debounce the RB0 button.
; Every time you press RB0, the next PORTC LED should turn on.
; If you remove the leading semicolons from the 6 commented lines in the
; RB0Int Routine, then switch debouncing will be in effect.
; You should then see an improvement in the switch bounce behavior of RB0.
;
;********************************************************************

	list 	p = 16f877
	include "p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC & _WRT_ON	
	
	__CONFIG   	config_1 & config_2		

;********************************************************************
; User-defined variables
;********************************************************************
		
	cblock		0x71 		; Common memory assignments.
				WTemp		; This cblock assigns the data memory  
				StatusTemp	; address 0x71 to the variable WTemp and
	endc					; 0x72 to StatusTemp. 
							
;********************************************************************
; Macro definitions
;********************************************************************

; Save W and STATUS contents during interrupts

push macro

	 movwf	WTemp			; Save W in WTemp in common memory	 
	 swapf	STATUS, W		; Swap the STATUS nibbles and save in W	 
	 movwf	StatusTemp		; Save STATUS in StatusTemp in common	 
	 endm					; memory.

pop	macro

	swapf 	StatusTemp, W	; Swap StatusTemp register into W							
	movwf	STATUS			; Copy W into STATUS							
	swapf	WTemp, F		; Swap W into WTemp	
	swapf	WTemp, W		; Unswap WTemp into W	
	endm							

;********************************************************************
; Begin executable code
;********************************************************************

	org		0x000
	nop
	goto	INIT

;********************************************************************
; Interrupt vector

	org		0x004		
	goto	INT_SVC		; Goto the interrupt service routine

;********************************************************************
; Initializatio Routine
;********************************************************************

INIT


	movlw	0x9B 			; Low byte of Flash EEPROM address
	banksel	EEADR 			; Bank 2
	movwf	EEADR			; EEADR = 0xA0

	movlw	0x01 			; High byte of Flash EEPROM address
	movwf	EEADRH 			; EEADRH = 0x1E
	
	banksel	EECON1 			; Bank 3
	bsf 	EECON1, EEPGD 	; Access Program memory
	bsf 	EECON1, RD 		; Start read operation
	nop 					; Two NOPs required. See page 44,
	nop 					; in data sheet
	
	banksel	EEDATA 			; Bank 2
	movf	EEDATA, W 		;

	banksel	PORTC
	movwf	PORTC			; DATAL = 	EEDATA
	;movf 	EEDATH, W 		;
	;movwf	PORTC			; DATAH = EEDATH


	


	banksel	INTCON
	bsf		INTCON, GIE
	bsf		INTCON, PEIE
	bsf		INTCON, INTE	; Enable the RB0/INT interrupt

	;clrf	PORTC			; Initialize the LEDs to all off
	
	;movwf	PORTC 

	movlw	B'00110001'		; Enable Timer1 with a 1:8 prescale
	movwf	T1CON
	
	movlw	0xC3			; Set the Timer1 match to occur after 
	movwf	CCPR1H			; 0xC350 = 50000 ticks
	movlw	0x50			; 50000 x 8 = 400,000 cycles =  
	movwf	CCPR1L			; 400,000 x 1.085 = 0.434 sec @ 3.6864 MHz
	
	movlw	B'00001010'		; 1010 -> Compare mode, generate a CCP1 
	movwf	CCP1CON			; interrupt on match.

	banksel	TRISB			; Use RB0 as an interrupt
	movlw	B'00000001'	
	movwf	TRISB
	
	clrf	TRISC			; The PORTC pins are all outputs for LEDs
	bcf		OPTION_REG, INTEDG	; Interrupt on the falling edge of RB0


;********************************************************************
; Main Routine
;********************************************************************
Main
	
	goto	Main		; Infinite Loop

;********************************************************************
; Interrupt Service Routine
;********************************************************************
INT_SVC

	push
	btfsc	INTCON, INTF	; Check for an RB0/INT interrupt
	call	RB0Int
	
	btfsc	PIR1, CCP1IF	; Check for a CCP1 interrupt
	call	CCP1Int

	pop
	retfie

;********************************************************************
; RB0Int Routine
;********************************************************************
;
; This routine disables any further interrupts from RB0, starts the
; CCP1 debounce timer, enables CCP1 timer interrupts, and turns on 
; the next LED.

RB0Int

	banksel	INTCON
	btfss	INTCON, INTE	; Don't check for an RB0/INT interrupt,
	return					; unless the RB0/INT interrupt is enabled
	
	bcf		INTCON, INTF	; Clear the interrupt flag

	bcf		INTCON, INTE	; Disable the RB0/INT interrupt
	clrf	TMR1H			; Reset the Timer1 registers
	clrf	TMR1L			;
	bcf		PIR1, CCP1IF	; Clear any pending CCP1 interrupts
	banksel	PIE1			;
	bsf		PIE1, CCP1IE	; Enable the CCP1 interrupt

	banksel	STATUS			; Turn on the next LED
	bcf		STATUS, C		; Carry bit must be set and cleared
	rlf		PORTC,  F		; manually in code.
	movf	PORTC,  F		; Test whether PORTC = 0.
	btfsc	STATUS, Z		; If PORTC = 0, set PORTC = 1.
	incf	PORTC,  F		; Otherwise, skip and return to Main
	


	push 

	movlw	0x9B			; Low byte of Flash EEPROM address
	banksel	EEADR 			; Bank 2
	movwf	EEADR 			; EEADR = 0xA0
	movlw	0x01			; High byte of Flash EEPROM address
	movwf	EEADRH 			; EEADRH = 0x1E

	
	banksel	PORTC
	movf	PORTC, W;
	banksel	EEDATA
	movwf	EEDATA 			; EEDATA = 0xA2
	;movlw	PORTC;
	;movwf	EEDATH 			; EEDATH = 0x2B

	banksel	EECON1			; Bank 3
	bsf		EECON1, EEPGD 	; Access Program memory
	bsf		EECON1, WREN 	; Enable writes to Flash EEPROM
	bcf		INTCON, GIE 	; Disable interrupts

	movlw	0x55 			; These seven instructions are required for
	movwf	EECON2 			; every write to Flash EEPROM.
	movlw	0xAA ;
	movwf	EECON2 			;
	bsf		EECON1, WR 		; Start write operation
	nop;
	nop;

	bsf		INTCON, GIE 	; Enable interrupts
	bcf		EECON1, WREN 	; Disable writes

	pop


	return

;********************************************************************
; CCP1Int Routine
;********************************************************************
;
; This routine is entered after the debounce timer delay of about 
; 434 ms. The timer interrupts are then disabled and RB0
; interrupts are enabled.

CCP1Int

	banksel	PIE1			; Don't check for a CCP1 interrupt
	btfss	PIE1, CCP1IE	; unless the CCP1 interrupt is enabled
	return
	
	banksel	INTCON
	bcf		INTCON, INTF	; Clear any pending RB0/INT interrupts
	bsf		INTCON, INTE	; Enable the RB0/INT interrupt
	
	banksel	PIE1
	bcf		PIE1, CCP1IE	; Disable the CCP1 interrupt
	return

;********************************************************************
	end
;********************************************************************