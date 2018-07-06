;********************************************************************
; lab07_keypad.asm
;
; Dan Simon
; Rick Rarick
; Cleveland State University
;
; This program scans a keypad connected to PORTD.  
; When a key press is detected, the result is sent from the SPI
; serial port on the PIC to the 7-segment LED display.
; The keypad is a standard Grayhill 12 button model# 96AB2.
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
; User-defined variables
;********************************************************************

	cblock		0x20		; Bank 0 assignments				
				Row
				Col
				RowMask
				Key
				OldKey
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
	call	Init	
	
MainLoop

	call	KeyScan		; Scan the keypad to get pressed key
	
	movwf	Key			; Key = W ( 0 <= Key <= 12 ). 
						; W = 0 means no key was pressed
	
	subwf	OldKey, W	; W = OldKey - W (Don't change OldKey)	

	btfsc	STATUS, Z	; If Key = OldKey, Z = 1, so don't skip,
	goto	MainLoop	; that is, return to MainLoop.
		
	call 	DisplayKey	; Otherwise, Key != OldKey, so display
						; Key.
	goto	MainLoop

;**********************************************************************
; KeyScan Routine
;**********************************************************************

; Loop through the four rows of the keypad, setting each row low, one
; at a time, and checking for a low column corresponding to a pressed
; key. If a key was pressed, save the row and column.
;
; Then calculate the numerical value of the key ( 1 <= key <= 12 )
; using the formula
;
;  W = 3 * Row + Col - 7
;
; Return 0 in the W register if no key is pressed.

KeyScan

	movlw	1			; Initialize Row to 1
	movwf	Row
	
	movlw	B'00000010'	; Initialize RowMask = 0000 0010,
	movwf	RowMask		; that is, RD1 = 1. RowMask keeps
						; track of which row we are checking.	
RowLoop

	; The RowMask bit is shifted left each time through the RowLoop.
	; If no key is pressed, we cycle though the rows until 
	; RowMask = 0001 0000. This means that no key was pressed,
	; so exit the KeyScan routine and return with W = 0.
						
	btfsc	RowMask, 5	
	retlw	0						 
	
	movf	RowMask, W	; Otherwise, W = RowMask
	
	movwf	PORTD		; Example: If RD1 = 1, then PORTD = 0000 0010
	
	comf	PORTD, F	; So PORTD = 1111 1101 which sets Row 1 low.
	
	; For the current row, we check the columns to see if any
	; column is low.						
	
	movlw	5			; W = 5 = Col. We now use W to store the Col
						; value beginning with 5, since the columns
						; are numbered Col5, Col6, and Col7.
	
	btfss	PORTD, 7	; Check Col7. If Col7 = 1, skip.
	goto	Col7		; If Col7 = 0, jump out of RowLoop
	
	btfss	PORTD, 6	; Check Col6. If Col6 = 1, skip.
	goto	Col6		; 
	
	btfss	PORTD, 5	; Check Col5. If Col5 = 1, skip.
	goto	Col5
	
	incf	Row, F		
	
	bcf		STATUS, C
	rlf		RowMask, F	; Rotate the RowMask byte one bit left.
	
	goto	RowLoop		; If we reach here, no column was low,
						; return and check next row.
	
	;*********************************************
	; End of row loop
	;*********************************************
	
	; If we reach here, one of the columns was low, and W = 5. 
	; Determin which one and calculate the key number:
	; Key = 3 * Row + Col - 7
	
Col7
	addlw	1			; W = W + 1. If we reach here, Col7 was low.
	 						
Col6
	addlw	1			; W = W + 1
	
Col5
	movwf	Col			; Col = W ( 5, 6, or 7 )
	
	movf	Row, W		; Row 
	
	addwf	Row, W		; Row + Row
	
	addwf	Row, W		; Row + Row + Row
	
	addwf	Col, W		; 3 * Row + Col
	
	addlw	0xF9		; Subtract 7 from W using modular arithmetic.
						; Example: W = 19
						; W + 0xF9 = 19 + 249 = 268 mod(256)
						; = 12 = 19 - 7.
	
	return				; Return from KeyScan. W = 3 * Row + Col - 7.

;**********************************************************************
; DisplayKey Routine
;**********************************************************************
	
DisplayKey

	movf	Key, F		; Check whether Key = 0. If so, no key was
	btfsc	STATUS, Z	; pressed, so don't display anything and return.
	return

	movf	Key, W		; Otherwise, W = Key
	
	movwf	OldKey		; Save key
	
	; W now contains the index for the table plus 1. Decrement W,
	; get the segment entry from the table, and return it in W.
	
	addlw  0xFF				; W = W + 255 = W - 1 mod(256)
	
	call	SegmentTable	; Get the LED segments corresponding
							; to the Key pressed ( 1 though 8 ).
	
	movwf	SSPBUF			; Send LED segments via SPI to the display
	
	return					; Return from DisplayKey
	
;**********************************************************************
; SegmentTable Routine
;**********************************************************************

SegmentTable

	; Table contains the LED display input values for each of 
	; the LED segments.
	
	addwf	PCL, F		; PCL = PCL + W + 1	
	
	retlw	B'11111001'		; W = 0,  A segment   B'11111110'  1
	retlw	B'10100100'		; W = 1,  B segment   B'11111101'  2
	retlw	B'10110000'		; W = 2,  C segment   B'11111011'  3
	retlw	B'10011001'		; W = 3,  D segment   B'11110111'  4
	retlw	B'10010010'		; W = 4,  E segment   B'11101111'  5
	retlw	B'10000010'		; W = 5,  F segment   B'11011111'  6
	retlw	B'11111000'		; W = 6,  G segment   B'10111111'  7
	retlw	B'10000000'		; W = 7,  DP segment  B'01111111'  8
	retlw	B'10010000'  	; W = 8,  off	 					9
	retlw	0xFF			; W = 9,  off						x
	retlw	B'11000000'		; W = 10, off                      0
	retlw	0xFF			; W = 11, off
	
;********************************************************************
; Init Routine
;********************************************************************

; This subroutine performs all initializations of variables 
; and registers.

Init

	; Set up PORTC for SPI
	
	banksel	TRISC		
	bcf 	TRISC, 3	; RC3/SDO, SPI data out
	bcf		TRISC, 5	; RC5/SCK, synchronous clock output
	
	; Set up PORTD for keypad
	
	movlw	B'11100001'	; Keypad bits 1-4 are considered rows (output).
	movwf	TRISD		; Bits 5-7 are considered columns (input).
	
	; Set up SPI
		
	banksel	SSPCON		; Set up SSP control register
	movlw	B'00110000'	; SPI eneable, SCK will idle high, 
	movwf	SSPCON		; SPI master mode, SCK = FOSC/4
	
	banksel SSPSTAT		; Set up SSP status register, 
	movlw	B'00000000'	; Default value. SMP = 0, 
	movfw	SSPSTAT		; CKE = 0, transmit on falling edge	

	banksel	PORTC
	
	; Initialize user variables
	
	movlw	0x00
	movwf	OldKey		
	
	movlw	0xFF
	movwf	SSPBUF
	
	return	; from Init routine			
	
;**********************************************************************
	end		; End of Program
;**********************************************************************

	
