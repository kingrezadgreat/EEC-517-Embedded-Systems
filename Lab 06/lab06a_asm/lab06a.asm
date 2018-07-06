;********************************************************************
; lab06a.asm
;
; Dan Simon
; Rick Rarick
;
; Cleveland State University
;
; This program uses the USART module in asynchronous mode
; to transmit a test pattern from the USART serial port
; transmit pin (RC6/TX) to the serial port of the PC. The
; test pattern consists of transmitting the characters 
; from A to Z, one character every half-second, at a
; transmission rate of 9600 baud.
;
;********************************************************************

	list 	p=16f877
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

	org		0x0000	; Reset vector
	nop				; Address 0 reserved for ICD
	goto	Main

;********************************************************************
; Interrupt vector
;********************************************************************

	org		0x0004		; Interrupt vector
	goto	IntService

;********************************************************************
; Main program 
;********************************************************************

Main
	call	Init		; Initialize everything
		
MainLoop	

	call	Delay_500ms
	
	movf	TX_temp, W	; W = TX_temp
	movwf	TXREG		; Transmit TX_temp. When a byte is moved
						; into TXREG, the USART immediately
						; transmits the byte from the PIC's TX pin to
						; the RX pin on the serial port on the PC.
								
	addlw	1			; W = TX_temp + 1
	movwf	TX_temp		; TX_temp = TX_temp + 1
	
	sublw	"Z" + 1		; W = "Z" + 1 - W
						; "Z" + 1 = 0x5A + 1 = 0x5B	(See note below).
						
	btfss	STATUS, Z	; If W = 0 (STATUS<Z> = 1), then 
						; TX_temp = "Z" + 1, so the character just 
						; sent was a "Z". Skip the next instruction
						; and reset TX_temp to "A".						
	goto	MainLoop	; Else goto MainLoop and send the next
						; character.	
	movlw	"A"			; Reset TX_temp to "A"
	movwf	TX_temp		; Transmit "A"

	goto	MainLoop	; Repeat indefinitely
	
	; Note: The assembler can perform many operations that are not
	; covered in this course. See Page 43 of the MPASM Assembler
	; User Guide.

;********************************************************************
; Init Routine
;********************************************************************

Init	

	banksel	RCSTA		; Enable the USART serial port
	bsf		RCSTA, SPEN

	banksel	TXSTA
	bcf		TXSTA, SYNC	; Set up the USART for asynchronous operation
	bsf		TXSTA, TXEN	; Transmit enabled. If the USART is enabled
						; (SPEN = 1), TRISC<RC6> is automatically 
						; cleared when TXEN is set. 
	bsf		TXSTA, BRGH	; High baud rate
	
	movlw	D'23'		; This sets the baud rate to 9600
	banksel	SPBRG		; assuming BRGH = 1 and Fosc = 3.6864 MHz
	movwf	SPBRG		; SPBRG = Fosc/(16*(Baud Rate)) - 1 = 23
	
						; TRISC<6> is automatically cleared when TXEN 
						; is set, if the USART is enabled.

	banksel	PIE1			; Enable the Timer2 interrupt for the
	bsf		PIE1, TMR2IE	; 1/2 sec delay.
	
	banksel	INTCON		; Enable global and peripheral interrupts
	bsf		INTCON, GIE
	bsf		INTCON, PEIE

	movlw	D'230'		; Set up the Timer2 Period register
	banksel	PR2			; Timer2 period = Prescaler * (PR2 + 1) *
	movwf	PR2			; Postscaler * 4 * Tosc = 4 * 231 * 2 * 
						; 1.085 usec = 2.00 ms.
	
	movlw	B'00001101'	; Postscale = 2, Timer2 ON, prescaler = 4
	banksel	T2CON		 
	movwf	T2CON		
		
	movlw	D'65'		; Initialize the serial port output to "A"
	movlw	"A"			; This is another way to load "A" into the
	movwf	TX_temp		; W register.
	return

;********************************************************************
; Delay_500ms Subroutine
;********************************************************************

; Create a 500 ms delay by calling a 10 ms delay 50 times.

Delay_500ms 

	movlw	d'50'			; Set Count = 50			
	movwf	DelayCount			
							
Loop50					
	
	call	Delay_10ms 		; Call DELAY_10ms 50 times = 500 ms
	
	decfsz	DelayCount, F	; Decrement DelayCount until 0. Then
	goto	Loop50			; exit loop.
	
	return
	
	; End DELAY_500ms subroutine					
	
;********************************************************************
; Delay_10ms Subroutine
;********************************************************************

; Delay_10ms uses five Timer2 overflow interrupts to create a 10 ms
; delay. Timer2 is configured in the Init Routine to overflow every
; 2.00 ms. 

Delay_10ms

	; Enable Timer2 interrupts during the DELAY_10ms subroutine.
	
	banksel 	PIE1			; PIE is in Bank 1
	bsf			PIE1, TMR2IE	; Enable Timer2 overflow interrupts.
	banksel		PORTC			; Return to Bank 0
	clrf		TMR2			; Reset TMR2 in Bank 0.
	
	;-------------------------------------------------------------
	
Loop5

	btfss	InterruptCount, 7	; InterruptCount starts at 0x04. It
								; is decremented in the Intterrupt
								; Service Routine until it reaches 0xFF, 
								; which will change bit 7 to a 1. 
								; 04 -> 03 -> 02 -> 01 -> 00 -> FF
								; Then we know that we have had five 
								; Timer2 interrupts.
																	
	goto	Loop5				; Loop until InterruptCount = 0xFF.	
	movlw	5					; Else Reset InterruptCount to 0x04 by
	addwf	InterruptCount, F	; adding 5 to it: 0xFF + 0x05 = 0x04
								; and exit loop.		
	
	; Disable Timer2 interrupts and exit the DELAY_10ms subroutine.
	
	banksel 	PIE1			; PIE is in Bank 1
	bcf			PIE1, TMR2IE	; Disable Timer2 interrupts
	banksel		PORTC			; Return to Bank 0
	
	return
	
	; End DELAY_10ms subroutine

;********************************************************************
; Interrupt Service Routine
;********************************************************************

IntService
	push
	
	bcf		PIR1, TMR2IF		; Clear the Timer2 interrupt flag
	
	decf	InterruptCount, F
	
	pop
	retfie

;********************************************************************
	end			; End of program
;********************************************************************