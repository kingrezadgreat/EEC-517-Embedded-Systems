;********************************************************************
; lab04a.asm
; Dan Simon
; Rick Rarick
; Cleveland State University
;
; This program modulates the pulse width of the voltage on the PORTC 
; outputs based on the AN0 analog input. So if the PORTC outputs
; are connected to the LEDs, the LEDs will appear to dim and brighten
; as the analog voltage on AN0 changes between 0 and 5 volts. The 
; program uses the conept of toggling a flag to turn the pulse on
; and off.
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
	endc

	cblock		0x71 		; Common memory assignments.
				WTemp		; This cblock assigns the data memory  
				StatusTemp	; address 0x71 to the variable WTemp and
	endc					; 0x72 to StatusTemp. Addresses 0x70 through
							; 0x7F are common or shared memory addresses.
							; This means that if you read or write to
							; memory location 0x70, you automatically
							; read or write to 0xF0, 0x170 and 0x1F0.
							; However, these four addresses are 
							; reserved when using the debugger, so we
							; must start with 0x71.
							
;********************************************************************
; Macro definitions
;********************************************************************

; Save W and STATUS contents during interrupts

push macro

	 movwf	WTemp			; Save W in WTemp in common memory.
							; movwf does not change the STATUS Z-bit
	 
	 swapf	STATUS, W		; Swap the STATUS nibbles and save in W	
	 
	 movwf	StatusTemp		; Save swapped STATUS bits in the
							; StatusTemp register in common memory.	 
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
	
	movlw		B'11100000'	; Enable the GIE, PEIE, TMR0 interrupts.
	
	movwf		INTCON		; INTCON: all banks.

	clrf		PORTC		; Clear PORTC (PORTC: Bank 0, default)
	
	movlw		B'01000001'	; Fosc/8, A/D Channel 0, A/D enabled
	
	movwf		ADCON0		; ADCON0: Bank 0
	
	banksel	 	OPTION_REG	; Select Bank 1 
	
	movlw		B'10000011'	; TMR0 prescaler = 1:16 
							; TMR0 counts one tick for every 
							; 16 instruction cycles.
	
	movwf		OPTION_REG	; OPTION_REG: Bank 1
	
	clrf		TRISC		; All of the PORTC bits are outputs
							; TRISC: Bank 1

	movlw		B'00001110'	; A/D data left justified, 1 analog channel
	
	movwf		ADCON1		; VDD and VSS references. ADCON1: Bank 1
	
	banksel		OnFlag		; OnFlag: Bank 0
	
	clrf		OnFlag		; Initialize OnFlag to 0
	
;********************************************************************
; Main Routine
;********************************************************************

MAIN
	
	banksel	ADCON0		; ADCON0: Bank 0
	
	bsf		ADCON0, GO	; Start A/D conversion
	
WaitForConversion

	btfss	PIR1, ADIF	; Wait for conversion to complete.
						; PIR1 is in Bank 0.
							
	goto	WaitForConversion
	
	; Get the duty cycle
	
	bcf		PIR1, ADIF	; Clear the A/D interrupt flag
	
	movf	ADRESH, W	; Get A/D result. ADRESH: Bank 0
	
	movwf	DutyCycle	; Copy A/D result to DutyCycle
	
	goto	MAIN		; Repeat

;********************************************************************
; Interrupt Service Routine
;********************************************************************

Int_Svc_Rtn

	push					; Save W and STATUS
					
	btfsc	INTCON, T0IF	; Check the T0IF bit for a Timer0
							; interrupt. INTCON: all banks.
	
	call	Toggle			; If T0IF = 1, goto Toggle routine	
							; Otherwise, there are no Timer0
	pop						; interrupts, so restore W and STATUS
							; and return.
	retfie

;********************************************************************
; Toggle Routine
;********************************************************************

; Toggle the PORTC outputs between 0x00 and 0xFF by toggling 
; the OnFlag each time the subroutine is entered.

Toggle

	bcf		INTCON, T0IF	; Clear the Timer0 interrupt flag.
							; INTCON: all banks
							
	banksel	OnFlag			; OnFlag: Bank 0					
	
	comf	OnFlag, F		; Toggle OnFlag							
							
	clrw					; W = 0
	
	btfsc	OnFlag, 0		; Test OnFlag
	
	movlw	0xFF			; If OnFlag = 1, set W = 0xFF
	
	movwf	PORTC			; PORTC = W = 0x00 or 0xFF depending on
							; the value OnFlag. PORTC: Bank 0
	
	movf	DutyCycle, W	; Copy DutyCycle into W 
	
	btfsc	OnFlag, 0		; Test OnFlag
		
	sublw	0xFF			; If OnFlag = 1, 
							; W = 0xFF - W = (255-DutyCycle) 
								
	movwf	TMR0			; TMR0 = DutyCycle or (255-DutyCycle) 
							; depending on the value OnFlag.
							; TMR0: Bank 0	
	
	return					; Return to the interrupt routine.

;********************************************************************
	end			; End of program
;********************************************************************
	
