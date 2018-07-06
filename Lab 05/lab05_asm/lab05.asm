;********************************************************************
; lab05.asm
; Dan Simon
; Rick Rarick
; Cleveland State University
;
; This program demonstrates the use of the PWM module.
; The PWM period is a constant, and the on-time is adjusted
; by the RA0 analog input. The PWM output is on pin RC2/CCP1.
;
; PWM period = Tpwm = (Timer2 Prescale)*(PR2+1)*(4 Tosc)
;                   = 1 * 200 * 1.085 usec = 217 usec
;
; PWM frequency = Fpwm = 1 / 217 usec = 4608 Hz
;
; PWM on-time = (CCPR1L : CCP1CON<5:4>)*(Timer2 Prescale)*(Tosc)
;             = (1000 0000 00) * 1 * (0.271 µs)
;             = (512)*(0.271 usec) = 139 usec
;
;********************************************************************
; Assembler Directives
;********************************************************************

	list 	p=16f877
	include "p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   	config_1 & config_2	
	
;********************************************************************
; Begin executable code
;********************************************************************

	org		0x0000
	nop			; First instruction must be nop for debugger. 
				; (Datasheet, page 133)
						
;********************************************************************
; Initialization Routine
;********************************************************************
						
Init						
	movlw	B'01000001'	; A/D enabled at a frequency of Fosc/8
	banksel ADCON0		; ADCON0 in Bank 0
	movwf	ADCON0
			
	banksel	ADCON1		; ADCON1 in Bank 1
	movlw	B'00001110'	; Left justify A/D data, 1 analog channel
	movwf	ADCON1		; Use VDD and VSS for A/D references
	
	movlw	D'199'		; PWM period = (PR2+1)(Timer2 Prescale)(4 Tosc)	
	movwf	PR2			; PR2 in Bank 1
	
	movlw	B'10000000'	; PWM on-time = (DC)(Timer2 Prescale)(Tosc)
						; DC = CCPR1L : CCP1CON<5,4>
	banksel	CCPR1L		; CCPR1L in Bank 0						 
	movwf	CCPR1L		; CCPR1L = 1000 0000
	
	movlw	B'00001100'	; CCP1CON<5,4> = 00 (CCP1COn in Bank 0)
	movwf	CCP1CON		; DC = 10 0000 0000 
	 
	movlw	B'11111011' ; Set RC2 as output for PWM signal
	banksel TRISC		; TRISC in Bank 1
	movwf	TRISC		; PORTC = 1111 1011
	
	movlw	B'10000000'	; Set up Timer0 for A/D acquisition delay.
	movwf	OPTION_REG	; Timer0 prescaler = 2, rollover = 556 usec
	
	movlw	B'00000100'	; Timer2 prescaler = 1
	banksel	T2CON		; T2CON in Bank 0
	movwf	T2CON
	
;********************************************************************
; Main Routine
;********************************************************************
	
Main
	; Timer0 delay for A/D voltage acquisition
	
	btfss	INTCON,T0IF	; Test the TIMER0 interrupt flag bit (T0IF).
						; The INTCON register is in Bank 0.
						; If T0IF = 1 (TMR0 rollover), skip next
						; instruction (skip goto).  						
	goto	Main		
	
	bcf		INTCON,T0IF	; Clear the T0IF bit for the next interrupt.
	
	banksel ADCON0		; ADCON0 in Bank 0

	bsf		ADCON0,GO	; Start the A/D conversion

    btfss	PORTB, 0

    sleep
    
;org		.7000
	
WaitForConversion

	btfss	PIR1, ADIF	; Wait for conversion to complete
	;org     .7000
    goto	WaitForConversion
	
	bcf		PIR1, ADIF
	movf	ADRESH, W	; Get the A/D result
	movwf	CCPR1L		; Use the A/D result for the PWM duty cycle
	goto	Main		; Do it again

;********************************************************************
	end			; End of program
;********************************************************************
