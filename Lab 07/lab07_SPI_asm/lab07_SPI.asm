;********************************************************************
; lab07_SPI.asm
;
; Dan Simon
; Rick Rarick
; Cleveland State University
;
; This program illuminates each segment of the first digit of a 
; two-digit LED display in the seguence ABCDEFG(DP). It uses the PIC
; Master Synchronous Serial Port (MSSP) in the Serial Peripheral
; Interface (SPI) Master mode to send serial data to a 74164 shift 
; register acting as an SPI slave device to convert the serial data 
; to parallel data. The parallel data is then sent to a seven-segment 
; LED display to illuminate one of the segments every second.
; Assumes a 3.6864 MHz clock.
;
;********************************************************************
; Assmbler Directives
;********************************************************************

	list 	p = 16f877
	
	include "p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   	config_1 & config_2

;********************************************************************
; User-defined variables
;********************************************************************

	cblock		0x20		; Bank 0 assignments				
				TableIndex
				InterruptCount
				DelayCount
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
; Main routine
;********************************************************************

Main
	call	Init			; Initialize everything
	
MainLoop
	
	call	Delay_500ms	
	
	movf	TableIndex, W	; W = TableIndex
	
	call	SegmentTable	; W now contains the index for the table.
							; Get the segment entry from the table and
							; and return it in W.
							 	
	movwf	SSPBUF			; SSPBUF = W
	
	call	Delay_500ms		; Wait for transmission
	
	incf	TableIndex, F	; TableIndex = TableIndex + 1
	
	movf	TableIndex, W	; W = TableIndex	
	
	sublw	D'8'			; W = 8 - W. If W = 0, Z = 1, otherwise,
							; Z = 0. 
	
	btfss	STATUS, Z		; Skip next if Z = 1 (TableIndex = 8)
	
	goto 	MainLoop		; If we reach this instruction, Z = 0 
							; (TableIndex < 8), so get the
							; next table entry for the display.	
	
	clrf	TableIndex		; If Z = 1, reset TableIndex = 0	

	goto	MainLoop

;********************************************************************
; Init
;********************************************************************

Init	
	; Set up interrupts. INTCON is in all banks
	
	bsf		INTCON, GIE		; Enable global interrupts
	bsf		INTCON, PEIE	; Enable peripheral interrupts
	
	banksel	PIE1			; PIE1 is in Bank 1.
	bsf		PIE1, TMR2IE	; Enable the Timer2 interrupt
	
	; Set up Timer2	
	movlw	D'229'		; Set up the Timer2 Period register
	movwf	PR2			; PR2 is in Bank 1
	
	banksel	T2CON		; T2CON is in Bank 0	
	movlw	B'00001101'	; prescaler = 4, postscaler = 2
	movwf	T2CON
	
	; Set up SPI	
	banksel	SSPCON		; Set up SSP control register
	movlw	B'00110000'	; SPI eneable, SCK will idle high, 
	movwf	SSPCON		; SPI master mode, SCK = FOSC/4
	
	banksel SSPSTAT		; Set up SSP status register, 
	movlw	B'00000000'	; SMP = 0, sample input in middle of bit.
	movfw	SSPSTAT		; CKE = 0, transmit on rising edge.
		
	; Set up PORTC for SPI	
	banksel	TRISC		
	bcf 	TRISC, 3	; RC3/SDO, SPI data out
	bcf		TRISC, 5	; RC5/SCK, synchronizing clock output
	
	; Intialize user variables	
	banksel	PORTC		; Bank 0	
	movlw	D'8'
	movwf	InterruptCount	
	clrf	TableIndex	; TableIndex is in Bank 0	

	return

;********************************************************************
; SegmentTable
;********************************************************************

SegmentTable

	; This lookup table contains the LED display input values for 
	; each of the LED segments.
	
	addwf	PCL, F		; PCL = PCL + W + 1	
	
	retlw	B'11111110'		; W = 0,  A segment 
	retlw	B'11111101'		; W = 1,  B segment
	retlw	B'11111011'		; W = 2,  C segment	
	retlw	B'11110111'		; W = 3,  D segment	
	retlw	B'11101111'		; W = 4,  E segment
	retlw	B'11011111'		; W = 5,  F segment
	retlw	B'10111111'		; W = 6,  G segment
	retlw	B'01111111'		; W = 7,  DP segment	

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
	movlw	5					; Else reset InterruptCount to 0x04 by
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