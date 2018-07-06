;********************************************************************
; lab04b.asm
; Dan Simon
; Rick Rarick
; Cleveland State University
;
; Lab04b is a modification of lab04a. The voltage on AN0 is still 
; used to modulate the pulse width of the voltage on PORTC, but 
; when you press the RB0 switch, the LEDs toggle on and off. 
; The pot controls the intensity of the
; LEDs when they are on. The RB0 external interrupt is set up as a 
; rising edge interrupt. Since RB0 is set up as an active low, the 
; LEDs toggle when you release the RB0 button. Lab04b.asm also 
; illustrates how multiple interrupts are handled in the interrupt
; service routine.
;
;********************************************************************
; Assembler Directives
;********************************************************************

	list		p = 16f877
	include		"p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   		config_1 & config_2	

;********************************************************************
; User-defined variables
;********************************************************************

	cblock		0x20		; Bank 0 assignments				
				DutyCycle
				OnFlag
				RB0Flag
	endc

	cblock		0x71 		; Common memory assignments.
				WTemp		; This cblock assigns the data memory  
				StatusTemp	; address 0x71 to the variable WTemp and
	endc					; 0x72 to StatusTemp. Addresses 0x70 through
							; 0x7F are common or shared memory addresses.
							; This means that if you read or write to
							; memory location 0x70, you automatically
							; read or  write to 0xF0, 0x170 and 0x1F0.
							; However, these four addresses are 
							; reserved when using the debugger, so it
							; is best to start with 0x71.
							
;********************************************************************
; Macro definitions
;********************************************************************

; Save W and STATUS contents during interrupts

push macro

	 movwf	WTemp			; Save W in WTemp in common memory
	 
	 swapf	STATUS, W		; Swap the STATUS nibbles and save in W	
	 
	 movwf	StatusTemp		; Save STATUS in StatusTemp in common
	 						; memory.	 
	 endm

pop	macro

	swapf 	StatusTemp, W	; Swap StatusTemp register into W							
							
	movwf	STATUS			; Copy W into STATUS
							; (Sets bank to original state)
	
	swapf	WTemp, F		; Swap W into WTemp
	
	swapf	WTemp, W		; Unswap WTemp into W
	
	endm							

;********************************************************************
; Begin executable code
;********************************************************************

	org		0x000		; Reset address
	
	nop					; Reserved for ICD
	
	goto	INIT

	org		0x0004		; Interrupt vector
	
	goto	Int_Svc_Rtn	; goto Interrupt Service Routine

;********************************************************************
; Initialization Routine
;********************************************************************

INIT
	
	movlw		B'11110000'	; Enable the GIE, PEIE, TMR0, and RB0
							; interrupts.

	movwf		INTCON		; INTCON: all banks.

	clrf		PORTC		; Clear PORTC (PORTC: Bank 0, default)
	
	movlw		B'01000001'	; Fosc/8, A/D Channel 0, A/D enabled
	
	movwf		ADCON0		; ADCON0: Bank 0
	
	banksel	 	OPTION_REG	; Select Bank 1 
	
	movlw		B'11000100'	; TMR0 prescaler = 1:32, RB0 interrupt
							; on rising edge							
	
	movwf		OPTION_REG	; OPTION_REG: Bank 1
	
	clrf		TRISC		; All of the PORTC bits are outputs
							; TRISC: Bank 1

	movlw		B'00001110'	; A/D data left justified, 1 analog channel
	
	movwf		ADCON1		; VDD and VSS references. ADCON1: Bank 1.
	
	banksel		OnFlag		; OnFlag: Bank 0.
	
	clrf		OnFlag		; Initialize OnFlag to 0.
	
	clrf		RB0Flag		; Initialize RB0Flag to 0.
	
;********************************************************************
; Main Routine
;********************************************************************

MAIN

	banksel		ADCON0		; ADCON0: Bank 0
	
	bsf			ADCON0, GO	; Start A/D conversion
	
WaitForConversion

	btfss		PIR1, ADIF	; Wait for conversion to complete
							; PIR1: Bank 0
							
	goto		WaitForConversion
	
	; Get the duty cycle
	
	bcf			PIR1, ADIF	; Clear the A/D interrupt flag
	
	movf		ADRESH, W	; Get A/D result. ADRESH: Bank 0
	
	movwf		DutyCycle	; Copy A/D result to DutyCycle
	
	goto		MAIN		; Repeat
	
;********************************************************************
; Interrupt Service Routine
;********************************************************************
;
; There are two sources for interrupts, Timer0 and and the RB0
; external interrupt. The following code polls the interrupt flags
; to determine which interrupt has occurred. 

Int_Svc_Rtn

	push						; Save W and STATUS
	
Poll_Int_Flags				
								; Check for Timer0 interrupt.
	btfsc	INTCON, T0IF		; T0IF = 1 ?
	goto	Toggle				; Yes, goto Toggle
	
								; No, check for RB0 interrupt.	
	btfsc	INTCON, INTF		; INTF = 1 ?
	goto	RB0Int				; Yes, got0 RB0Int	
	
	pop							; No, restore W and STATUS
								; and return.	
	retfie

;********************************************************************
; Toggle Routine
;********************************************************************

; Toggle the PORTC outputs between 0x00 and 0xFF by toggling 
; the OnFlag each time the subroutine is entered.

Toggle

	bcf		INTCON, T0IF	; Clear the interrupt flag.
							; INTCON: all banks.
							
	banksel RB0Flag			; RB0Flag: Bank 0.							
							
	btfsc	RB0Flag, 0		; If RB0 was pressed, don't do anything.
	
	goto	Int_Svc_Rtn		; Exit Toggle.

	comf	OnFlag, F		; Toggle OnFlag							
							
	clrw					; W = 0
	
	btfsc	OnFlag, 0		; Test OnFlag
	
	movlw	0xF0			; If OnFlag = 1, set W = 0xFF

	btfss	OnFlag, 0		; Test OnFlag

	movlw	0x0F

	movwf	PORTC			; PORTC = W = 0x00 or 0xFF depending on
							; the value OnFlag. PORTC: Bank 0
	
	movf	DutyCycle, W	; Copy DutyCycle into W 
	
	btfsc	OnFlag, 0		; Test OnFlag
		
	sublw	0xFF			; If OnFlag = 1, 
							; W = 0xFF - W = (255-DutyCycle) 
								
	movwf	TMR0			; TMR0 = DutyCycle or (255-DutyCycle) 
							; depending on the value OnFlag.
							; TMR0: Bank 0.	
	
	goto	Poll_Int_Flags	; Return to interrupt routine.
	
;********************************************************************
; RB0Int Routine
;********************************************************************

RB0Int

	bcf		INTCON, INTF	; Clear the interrupt flag
	
	banksel PORTC			; Bank 0
	
	clrf	PORTC			; Turn off the LEDs			
	
	comf	RB0Flag, F		; Toggle RB0Flag. RB0Flag: Bank 0.
	
	goto	Poll_Int_Flags	; Return to interrupt routine.

;********************************************************************
	end			; End of program
;********************************************************************
	
