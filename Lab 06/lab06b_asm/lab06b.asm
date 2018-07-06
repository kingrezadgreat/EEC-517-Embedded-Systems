;**********************************************************
; Lab06b.asm
;
; Dan Simon
; Rick Rarick
; Cleveland State University
;
; This program receives bytes in the serial port.
; If a '0', '1', or '2' is received, then RC0, RC1, or RC2
; is asserted.  If an 'X' is received, then RC0, RC1, and RC2
; are all negated.  All other characters are ignored.
;
;**********************************************************

	list p=16f877
	include "p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   	config_1 & config_2

;********************************************************************
; User-defined variables
;********************************************************************

	cblock		0x20		; Bank 0 assignments				
				TX_temp
				DelayCount
				InterruptCount
	endc

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

	org		0x0000		; Reset vector
	nop
	goto	Main

;********************************************************************
; Interrupt vector
;********************************************************************

	org		0x0004		; interrupt vector
	goto	IntService

;********************************************************************
; Main program 
;********************************************************************

Main

	call	Init		; Initialize everything
	
MainLoop

	goto	MainLoop	; Repeat until an interrupt occurs when the
						; USART receives a byte on the RC7/RX pin.
						; The PIR1<RCIF> bit is set when the byte
						; has been transferred to RCREG. It is 
						; automatically cleared when RCREG is read. 

;********************************************************************
; Init Routine
;********************************************************************

Init	

	banksel	RCSTA		
	bsf		RCSTA, SPEN	; Enable the USART serial port
	bsf		RCSTA, CREN	; Enable serial port reception

	banksel	TXSTA
	bcf		TXSTA, SYNC	; Set up the USART for asynchronous operation
	bsf		TXSTA, BRGH	; High baud rate
	
	movlw	D'23'		; This sets the baud rate to 9600
	banksel	SPBRG		; assuming BRGH = 1 and Fosc = 3.6864 MHz
	movwf	SPBRG		; SPBRG = Fosc/(16*(Baud Rate)) - 1 = 23

	banksel	PIE1		; Enable the Serial Port Reception Interrupt
	bsf		PIE1, RCIE

	banksel	INTCON		; Enable global and peripheral interrupts
	bsf		INTCON, GIE
	bsf		INTCON, PEIE

	banksel	TRISC		; Set PortC bits 0, 1, and 2 as outputs
						; Set RC7/RX as an input pin

	movlw	B'11111000'
	movwf	TRISC

	banksel	PORTC		; Clear PortC bits 0, 1, and 2
	clrf	PORTC

	return

;********************************************************************
; Interrupt Service Routine
;********************************************************************

IntService
	push
	btfsc	PIR1, RCIF	; Check for a Serial Port Reception interrupt
	call	Receive
;	btfsc	...		; Check for another interrupt
;	call	...
;	btfsc	...		; Check for another interrupt
;	call	...
	pop
	retfie

;********************************************************************
; Receive Routine
;********************************************************************

Receive

	movf	RCREG, W	; Read and empty the RCREG register.
	
	sublw	D'48'		; W = 48 - W.  (ASCII "0" = 0x48)	
						
	btfsc	STATUS, Z	; Check if a "0" was received
	goto	LED0		; If so (W = 0, Z = 1), don't skip.
	
	movf	RCREG, W	; If not, read RCREG again.
	sublw	D'49'		; Check if a "1" was received
	btfsc	STATUS, Z
	goto	LED1
	
	movf	RCREG, W
	sublw	D'50'		; Check if a "2" was received
	btfsc	STATUS, Z
	goto	LED2
	
	movf	RCREG, W
	sublw	D'88'		; Check if an "X" was received
	btfsc	STATUS, Z
	goto	LEDOff
	return
	
LED0				; Turn on RC0

	movlw	B'00000001'
	movwf	PORTC
	return

LED1				; Turn on RC1
	movlw	B'00000010'
	movwf	PORTC
	return

LED2				; Turn on RC2
	movlw	B'00000100'
	movwf	PORTC
	return

LEDOff				; Turn off RC0, RC1, and RC2

	clrf	PORTC	
	return

;********************************************************************
	end			; End of program
;********************************************************************