;**********************************************************
; lab11.asm
;
; Dan Simon
; Rick Rarick
;
; Cleveland State University
;
; This file demonstrates the use of various floating point math routines.
; Each floating number is represented using the Modified IEEE 754 Floating
; Ppoint standard discussed in class.
;
; The floating-point numbers require 16-bits or two bytes, for example,
; <floatH : floatL>. 
;
; The floatH byte contains the biased exponent; the actual exponent is equal
; to ; floatH - 128, so floatH = 0 means an exponent of -128, and 
; floatH = 255 means an exponent of 127.
;
; The floatL byte contains the sign bit and the mantissa. The MSB of floatL is 
; the sign bit (0 = positive, 1 = negative) and the 7 b's of floatL contain
; the mantissa or fraction. The LSb bit contains the 2^-7 digit, the next 
; LSB contains the 2^-6 digit, etc.
;
;**********************************************************
	list p=16f877
	include "p16f877.inc"

;**********************************************************
; User-defined variables
;**********************************************************
	cblock	0x20

		; FloatAdd Variables
		
		FaddSgn		;		
		Fadd1e		; Fadd1 exponent
		Fadd1m		; Fadd1 mantissa
		Fadd2e
		Fadd2m
		Fsume
		Fsumm

		; FloatMult Varibles
		
		FMult1E		
		FMult1M
		FMult2E
		FMult2M
		FProductE
		FProductM
		
		; DoubleAdd Variables

		Add1H		
		Add1L
		Add2H
		Add2L
		SumH
		SumL
		
		; FixedMultiply Variables

		MultA		
		MultB
		MultCH
		MultCL
		MultTempH
		MultTempL
		MultCounter

		Temp1
		Temp2
	endc

;**********************************************************
; Start of executable code
;**********************************************************

	org		0x000
	nop					
	
	goto	Main 
	
	org		0x0004
    ;goto	InterruptServiceRoutine			
	
Main

	; Add breakpoints after the FloatAdd routines to see reault in the
	; Watch window.
		
	; Add two floats: 0x8450 + 0x8550

	movlw	0x84		; 0x8450 = 10 (decimal)
	movwf	Fadd2e
	movlw	0x50
	movwf	Fadd2m
	movlw	0x85		; 0x8550 = 20 (decimal)
	movwf	Fadd1e
	movlw	0x50
	movwf	Fadd1m
	
	;call	FloatAdd	; 0x8450 + 0x8550 = 0x8578 = 10 + 20 = 30	
	
	; *******************
	
	; Add two floats: 0x84D0 + 0x8550

	movlw	0x84		; 0x84D0 = -10 (decimal)
	movwf	Fadd2e
	movlw	0xD0
	movwf	Fadd2m
	movlw	0x85		; 0x8550 = 20 (decimal)
	movwf	Fadd1e
	movlw	0x50
	movwf	Fadd1m		
	
	;call	FloatAdd	; 0x84D0 + 0x8550 = 0x8528 = -10 + 20 = 10
						; 0x8528 (unnormalized) = 0x8450 (normalized) 
	
	; ******************
	
	; Add two floats: 0x85D0 + 0x8450

	movlw	0x85		; 0x85D0 = -20 (decimal)
	movwf	Fadd2e
	movlw	0xD0
	movwf	Fadd2m
	movlw	0x84		; 0x8450 = 10 (decimal)
	movwf	Fadd1e
	movlw	0x50
	movwf	Fadd1m		
	
	;call	FloatAdd	; 0x85D0 + 0x8450 = 0x85A8 = -20 + 10 = -10
						; 0x85A8 (unnormalized) = 0x84D0 (normalized)
	
	; *****************
	
	; Add two floats: 0x8269 + 0x81CA

	movlw	0x82		; 0x8269 = 3.28125 (decimal)
	movwf	Fadd2e
	movlw	0x69
	movwf	Fadd2m
	movlw	0x81		; 0x81CA = -1.15625 (decimal)
	movwf	Fadd1e
	movlw	0xCA
	movwf	Fadd1m		
	
	;call	FloatAdd	; 0x8269 + 0x81CA = 0x82A8 = -1.25 (incorrect)
						; The sum should be 2.1250 (decimal) but it does not work
						; because code needs to be added after FloatAdd5.
	
	; **************
	
	; Multiply two floats: 0x7F67 * 0xF0C2 

	movlw	0x7F		; 0x7F67 =  0.4023438	
	movwf	FMult1E
	movlw	0x67
	movwf	FMult1M
	movlw	0xF0		; 0xF0C2 = -2.677278E+33
	movwf	FMult2E
	movlw	0xC2
	movwf	FMult2M	
	
	call	FloatMult	; 0x7F67 * 0xF0C2 = 0xEFB5 (unnormalized)
						; = 0xEEEA (normalized)
						; = -1.074968E+33
	; **************
	
	; Multiply two floats: 0x7044 * 0x9955
	
	movlw	0x70		; 0x7044 = 8.106232E-06
	movwf	FMult1E
	movlw	0x44
	movwf	FMult1M
	movlw	0x99		; 0x9955 = 2.228224E+07
	movwf	FMult2E
	movlw	0x55
	movwf	FMult2M		
	
	call	FloatMult	; 0x7044 * 0x9955 = 0x892D (unnormalized)
						; = 0x885A (normalized)
						; = 180
						; 8.106232E-06 * 2.228224E+07 = 180.63
Loop	
	goto	Loop		; Loop forever, or until the user resets the PIC
	
;**********************************************************************
; FloatAdd Routine - floating point addition routine
;
; This routine adds the two floating point numbers in
; Fadd1 and Fadd2, and returns the result in Fsum.
; Fadd1e:Fadd1m contains the exponent and mantissa of the first addend.
; Fadd2e:Fadd2m contain the exponent and mantissa of the second addend.
; Fsume:Fsumm contain the exponent and mantissa of the sum.
; **********************************************************************

FloatAdd

	; Check whether the addends have same exponent (Fadd2e = Fadd1e)				

	movf	Fadd1e, W	
	subwf	Fadd2e, W	; W = Fadd2e - Fadd1e
						
	btfsc	STATUS, Z	; If W = Fadd2e - Fadd1e = 0 ( Z = 1 ),
	goto	FloatAdd2	; then Fadd2e = Fadd1e, so goto FloatAdd2.
	
	btfss	STATUS, C	; If Fadd2e > Fadd1e, then subwf sets 
	goto	FloatAdd1	; C = Not Borrow = 1. Otherwise, Fadd2e < Fadd1e,
						; so goto FloatAdd1 
	
	incf	Fadd1e, F	; If reach here, Fadd2e > Fadd1e, so the exponents 
						; are different. Increment (increase) the exponent  
						; of Fadd1e and right shift(decrease) the mantissa 
						; of Fadd1m.
						
	; Keep track of the Fadd1m sign bit while rotating.
	
	bcf		STATUS, C	
	
	btfsc	Fadd1m, 7	; If the Fadd1m sign bit is clear, then a
	bsf		STATUS, C	; zero will be rotated into bit-6 of Fadd1m when it
						; is rotated right. Since C = 0, it will be shifted 
	bcf		Fadd1m, 7	; into the sign bit when rrf is executed. 
	rrf		Fadd1m, F	; Then return to FloatAdd and test again.
						; If the Fadd1m sign bit is set, set C = 1 and clear 
	goto	FloatAdd	; bit-7 before rotating.
	
FloatAdd1

	; If reach here, Fadd2e < Fadd1e, so exponents are different. Increment
	; exponent and shift mantissa, then retry in FloatAdd.

	incf	Fadd2e, F	; Fadd2e < Fadd1e, so increment Fadd2e
	bcf		STATUS, C	; and right shift Fadd2m
	
	btfsc	Fadd2m, 7
	bsf		STATUS, C
	
	bcf		Fadd2m, 7
	rrf		Fadd2m, F
	
	goto	FloatAdd
	
FloatAdd2

	; If reach here, Fadd1e = Fadd2e. Now add mantissas.

	movf	Fadd1e, W	; Fadd1e = Fadd2e, so set Fsume = Fadd1e
	movwf	Fsume
	movf	Fadd1m, W	; Compare the signs of Fadd1m and Fadd2m
	xorwf	Fadd2m, W
	movwf	FaddSgn
	
	btfsc	FaddSgn, 7
	goto	DifferentSigns
	
	movf	Fadd1m, W	; Fadd1 and Fadd2 have the same sign
	movwf	FaddSgn
	movf	Fadd1m, W	; Remove the sign bit from Fadd1m
	andlw	B'01111111'
	movwf	Fadd1m
	movf	Fadd2m, W	; Remove the sign bit from Fadd2m
	andlw	B'01111111'
	movwf	Fadd2m
	addwf	Fadd1m, W	; Add the mantissas
	movwf	Fsumm
	
	btfss	Fsumm, 7	; Check if the sum overflowed into bit 7
	goto	FloatAdd3
	
	bcf		STATUS, C
	rrf		Fsumm, F	; Right shift Fsumm and increment Fsume
	btfsc	STATUS, C	; If the LSb of Fsumm was set before right shifting,
	incf	Fsumm, F	; then increment Fsumm for rounding
	incf	Fsume, F
	
FloatAdd3

	bcf		Fsumm, 7	; Set or clear the sign bit in Fsumm as required
	btfsc	FaddSgn, 7
	bsf		Fsumm, 7
	return				; Return to FloatAdd call.
	
DifferentSigns			; Fadd1 and Fadd2 have different signs

	btfsc	Fadd1m, 7
	goto	FloatAdd5
	
	movf	Fadd2m, W	; Fadd1 > 0 and Fadd2 < 0
	andlw	B'01111111'	; Remove the sign bit from Fadd2m
	movwf	Fadd2m	
	subwf	Fadd1m, W	; W = |Fadd1m| - |Fadd2m|
	
	btfss	STATUS, C
	goto	FloatAdd4
	
	movwf	Fsumm		; |Fadd1m| >= |Fadd2m|
	bcf		Fsumm, 7	; Clear the sign bit of the result
	return				; Return to FloatAdd call.
	
FloatAdd4				; |Fadd1m| < |Fadd2m|

	movf	Fadd1m, W
	subwf	Fadd2m, W	; W = |Fadd2m| - |Fadd1m|
	movwf	Fsumm
	bsf		Fsumm, 7	; Set the sign bit of the result
	return				; Return to FloatAdd call.
	
FloatAdd5				; Fadd1 < 0 and Fadd2 > 0 - code needs to be added

	return	

;****************************************************************
; FloatMult Routine - floating point multiplication routine
; This routine multiplies the two floating point numbers in
; FMult1 and FMult2, and returns the result in FProduct.
; The exponent of FMult1 is in FMult1E.
; The mantissa of FMult1 is in FMult1M.
; Similar for the exponent and mantissa of FMult2 and FProduct.
; **************************************************************

FloatMult

	movf	FMult1E, W
	addlw	0x80		; Subtract 128 to get 8-bit 2's comp of FMult1E
	movwf	FMult1E
	movf	FMult2E, W
	addlw	0x80		; Subtract 128 to get 8-bit 2's comp of FMult2E
	movwf	FMult2E
	addwf	FMult1E, W	; FMult1E + FMult2E = 8-bit 2's comp of FProductE
	addlw	0x80		; Add 128 to get the biased exponent
	movwf	FProductE	; Now we have the exponent of the product
	movf	FMult1M, W
	xorwf	FMult2M, W
	andlw	0x80
	movwf	FProductM	; Now we have the sign bit of the mantissa
	movlw	0x7F		; Remove the sign bit from FMult1M
	andwf	FMult1M, F
	movlw	0x7F		; Remove the sign bit from FMult2M
	andwf	FMult2M, F
	movf	FMult1M, W	; Now multiply FMult1M * FMult2M
	movwf	MultA
	movf	FMult2M, W
	movwf	MultB
	
	call	FixedMultiply
	
	bcf		STATUS, C	; Now right shift the 16-bit result 7 bits
	btfsc	MultCL, 7	; This is equivalent to left shifting one bit
	bsf		STATUS, C	; and taking the MSB of the result
	rlf		MultCH, W
	iorwf	FProductM, F
	
	call	Normalize

	return				; Return to FloatMult call


Normalize:

	movlw	.0
	btfsc	MultCL,7
	movlw	.1
	movwf	Temp1
	
Loop1
	movlw	MultCL
	movwf	Temp2
	btfss	Temp2, 6
	rlf		MultCL

	btfss	Temp2, 6
	bcf		MultCL,0
	
	;movlw	MultCH	
	btfss	Temp2, 6
	decf	MultCH,1	
	;movwf	MultCH
	
	btfss	Temp1,0
	bcf		MultCL,7

	btfsc	Temp1,0
	bsf		MultCL,7

	btfsc	MultCL, 6
	return
	goto	Loop1


; **********************************************************
; FixedMultiply Routine - Fixed point multiply routine
; This routine computes MultCH:MultCL = MultA * MultB
; **********************************************************

FixedMultiply

	clrf	MultCH
	clrf	MultCL
	clrf	MultTempH
	movf	MultA, W
	movwf	MultTempL
	clrf	MultCounter
	incf	MultCounter, F	; MultCounter = 1, 10, 100, . . ., 10000000 (binary)
	
FixedMultiplyLoop

	movf	MultCounter, W
	andwf	MultB, W
	btfsc	STATUS, Z
	goto	FixedMultiply1
	movf	MultCH, W		; Compute MultC = MultC + MultTemp
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
	
FixedMultiply1

	bcf		STATUS, C
	rlf		MultTempH, F	; MultTemp = 2 * MultTemp
	rlf		MultTempL, F
	btfsc	STATUS, C
	incf	MultTempH, F
	bcf		STATUS, C
	rlf		MultCounter, F	; If we've gone thru the loop 8 times, return
	btfss	STATUS, C
	goto	FixedMultiplyLoop
	return

;*******************************************************************
; DoubleAdd Routine - fixed point double precision addition routine
; This routine computes SumH/SumL = Add1H/Add1L + Add2H/Add2L
; ******************************************************************

DoubleAdd
	movf	Add1L, W
	addwf	Add2L, W
	movwf	SumL
	btfsc	STATUS, C
	incf	Add1H, F
	movf	Add1H, W
	addwf	Add2H, W
	movwf	SumH
	return

	end
