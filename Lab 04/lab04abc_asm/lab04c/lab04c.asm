;**********************************************************
; Lab04c.asm
; Dan Simon
; Cleveland State University
;
; This program uses the compare function of the CCP module
; to toggle the RC2 output.
;********************************************************************
; Assembler Directives
;********************************************************************
	list p=16f877
	include "p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   		config_1 & config_2		

;********************************************************************
; User-defined variables
;********************************************************************

	cblock		0x20		; Bank 0 assignments				
				OnFlag				
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
	banksel	TRISC		; Set register access to bank 1
	movlw	B'11111011'	; Set up RC2 as output
	movwf 	TRISC      	
	bsf		INTCON,GIE	; Enable the CCP1 interrupt
	bsf		INTCON,PEIE
	bsf		PIE1, CCP1IE
	banksel	PORTC		; Set register access back to bank 0
	bsf		PORTC, 2	; Set RC2/CCP1
	movlw	B'00110001'	; Enable Timer1 with a 1:8 prescale
	movwf	T1CON
	movlw	0xF4		; Set the Timer1 match to occur after
	movwf	CCPR1H		; 0xF424 = 62500 ticks.
	movlw	0x24		; (62500 x 8 = 500000 cycles = 0.5 sec @ 4 MHz)	
	movwf	CCPR1L		
	movlw	B'00001001'	; Clear RC2 on match
	movwf	CCP1CON		; CCP1CON = 0000 1001
	clrf	OnFlag	

;********************************************************************
; Main Routine
;********************************************************************

Main
	goto	Main		; Loop forever

;********************************************************************
; Interrupt Service Routine
;********************************************************************

Int_Svc_Rtn

	push
	
Poll
	btfsc	PIR1,CCP1IF	; Check for a CCP1 interrupt
	goto	Toggle
	
	pop
	retfie

;********************************************************************
; Toggle Routine
;*******************************************************************

Toggle
	bcf		PIR1, CCP1IF
	comf	OnFlag,F	; Complement the OnFlag variable
	clrf	TMR1H		; Reset the Timer1 registers
	clrf	TMR1L
	movlw	B'00001001'	; Clear RC2 on next match
	btfsc	OnFlag, 0	; OnFlag = 1 ?
	movlw	B'00001000'	; Yes, set RC2 on next match:  CCP1CON = 0000 1000
	movwf	CCP1CON		; No, clear RC2 on next match: CCP1CON = 0000 1001
	goto	Poll

;********************************************************************
	end  ; End of program
;*******************************************************************
