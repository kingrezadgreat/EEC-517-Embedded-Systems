;********************************************************************
; lab10.asm
;
; Dan Simon
; Rick Rarick
; Cleveland State University
;
; This file demonstrates the use of various fixed point math routines.
;
;********************************************************************

	list    p=16f877
	include "p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC & _WRT_ON	
	
	__CONFIG   	config_1 & config_2		

;********************************************************************
; User-defined variables
;********************************************************************
	cblock	0x20
	
		Add1H		; DoubleAdd Variables
		Add1L
		Add2H
		Add2L
		SumH
		SumL

		Sub1H		; DoubleSub Variables
		Sub1L
		Sub2H
		Sub2L
		DiffH
		DiffL

		MultA		; Multiply Variables
		MultB
		MultCH
		MultCL
		MultTempH
		MultTempL
		MultCounter

		Dividend	; Divide Variables
		Divisor
		Quotient
		Remainder
		DivCounter

		temp1

	endc

;********************************************************************
; Start of executable code
;********************************************************************
	org	0x000
	nop					; Address 0 reserved for ICD
	
	;*********************************************************
	
	; Add1H : Add1L
	; Add2H : Add2H
	; -------------
	;  SumH : SumL
	
	; Initialize variables
	
	; 0xFFF8 + 0xF01F = 0x1F017
	
	call	TwosComp16 

	call	Abs


	movlw	0xFF		; Load 0xFFF8
	movwf	Add1H		
	movlw	0xF8
	movwf	Add1L
	
	movlw	0xF0		; Load 0xF01F
	movwf	Add2H
	movlw	0x0F
	movwf	Add2L	
	
	call	DoubleAdd	; Sum = 1F017

	movlw	0xFF
	sublw	.128
	
	;*********************************************************
	
	; Sub1H : Sub1L
	; Sub2H : Sub2H
	; -------------
	; DiffH : DiffL
	
	; Initialize variables

	; 0xFFF8 - 0xF01F = 0x0FD9

	movlw	0xFF		; Load 0xFFF8	
	movwf	Sub1H
	movlw	0xF8
	movwf	Sub1L
	
	movlw	0xF0		; Load 0xF01F
	movwf	Sub2H
	movlw	0x1F
	movwf	Sub2L		

	call	DoubleSub
	
	;*********************************************************
	
	movlw	.249		; 249 x 58 = 14442 = 0x386A
	movwf	MultA		; The result is returned in MultCH/MultCL
	movlw	.58
	movwf	MultB
	
	call	Multiply
	
	;*********************************************************

	movlw	.230		; 230 / 9 = 25 rem 5
	movwf	Dividend	; The quotient is returned in Quotient
	movlw	.9			; The remainder is returned in Remainder
	movwf	Divisor
	
	call	Divide
	
Loop	
;	call	Abs
	
	
	goto	Loop	

;********************************************************************
; DoubleAdd Routine 16-bit addition with carry bit
;********************************************************************
TwosComp16 
	movlw	0xFE
	movwf	MultCL 
	movlw	0xB2
	movwf	MultCH

	;movlw	MultCL 
	comf	MultCH, f
	comf	MultCL, w
	addlw	.1
	
	movwf	MultCL
	btfss	STATUS, C
	return
	
	movlw	.1
	addwf	MultCH, f

	return


Abs
	movlw	.147
	movwf	temp1
	btfss	temp1, 7
	retlw	temp1
	sublw	0
	movwf	temp1
	retlw	temp1	

DoubleAdd

	; Add1H : Add1L
	; Add2H : Add2H
	; -------------
	;  SumH : SumL
	
	; Add low bytes

	movf	Add1L, W	; W    = Add1L
	movwf	SumL		; SumL = Add1L
	movf	Add2L, W	; W    = Add2L
	addwf	SumL		; SumL = SumL + W = Add1L + Add2L
	
	; Add high bytes
	
	movf	Add1H, W	; W    = Add1H
	movwf	SumH		; SumH = Add1H
	movf	Add2H, W	; W    = Add2H
	
	btfsc	STATUS, C	; C = low-carry
	incfsz	Add2H, W	; If C = 0, goto label_1. 
						; If C = 1, W = Add2H + 1 (add low-carry to 
						; one of the high bytes.) If W = 0, goto
						; label_2, so SumH = Add1H. If W != 0, goto
						; label_1.
label_1
						
	addwf	SumH, F		; SumH = SumH + W = Add1H + Add2H.
						; Since the low-carry = 0, this addition will
						; properly set the high-carry. 	
label_2
	
	return	

;********************************************************************
; DoubleSub Routine
; This routine computes DiffH:DiffL = Sub1H:Sub1L - Sub2H:Sub2L
;********************************************************************
DoubleSub

	; Sub1H : Sub1L
	; Sub2H : Sub2H
	; -------------
	; DiffH : DiffL
	
	; Subtract low bytes

	movf	Sub1L, W	; W     = Sub1L
	movwf	DiffL		; DiffL = Sub1L
	movf	Sub2L, W	; W     = Sub2L
	subwf	DiffL		; DiffL = DiffL - W = Sub1L - Sub2L
	
	; Subtract high bytes
	
    movf    Sub1H, W
    movwf	DiffH
    movf	Sub2H, W
    
    btfss   STATUS, C	; Low Borrow check
    incfsz  Sub2H, W	; If C =  1, no borrow
    subwf   DiffH,F	

	return
	
;********************************************************************
; Multiply Routine
; This routine computes MultCH:MultCL = MultA * MultB
;********************************************************************
Multiply
	clrf	MultCH
	clrf	MultCL
	clrf	MultTempH
	movf	MultA, W
	movwf	MultTempL
	clrf	MultCounter
	incf	MultCounter, F	; MultCounter = 1, 10, 100, . . ., 10000000 (binary)
MultiplyLoop
	movf	MultCounter, W
	andwf	MultB, W
	btfsc	STATUS, Z
	goto	Multiply1
	movf	MultCH, W	; Compute MultC = MultC + MultTemp
	movwf	Add1H
	movf	MultCL, W
	movwf	Add1L
	movf	MultTempH, W
	movwf	Add2H
	movf	MultTempL, W
	movwf	Add2L
	call	DoubleAdd
	movf	SumH, W
	movwf	MultCH
	movf	SumL, W
	movwf	MultCL
Multiply1
	bcf		STATUS, C
	rlf		MultTempH, F	; MultTemp = 2 * MultTemp
	rlf		MultTempL, F
	btfsc	STATUS, C
	incf	MultTempH, F
	bcf		STATUS, C
	rlf		MultCounter, F	; If we've gone thru the loop 8 times, return
	btfss	STATUS, C
	goto	MultiplyLoop
	return
	
;********************************************************************
; Divide Routine
; This routine divides two numbers (Dividend / Divisor) and
; returns the result in Quotient and the remainder in Remainder.
;********************************************************************
Divide
	clrf	Quotient
	clrf	Remainder
	movlw	B'10000000'
	movwf	DivCounter		; DivCounter = 10000000, 01000000, ..., 00000001 (binary)
DivideLoop
	bcf		STATUS, C
	rlf		Remainder, F	; Remainder = 2 * Remainder + Dividend<i>
	rlf		Dividend, F
	btfsc	STATUS, C
	incf	Remainder, F
	movf	Divisor, W		; If Remainder >= Divisor, then
	subwf	Remainder, W	; Remainder = Remainder - Divisor and Quotient<i> = 1
	btfss	STATUS, C
	goto	Divide1
	movwf	Remainder
	movf	DivCounter, W
	iorwf	Quotient, F
Divide1	
	bcf		STATUS, C
	rrf		DivCounter, F	; If we've gone thru the loop 8 times, return
	btfss	STATUS, C
	goto	DivideLoop
	
	return

;********************************************************************
	end
;********************************************************************