;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; lab_03_LookupTable.asm
;
; Dan Simon
; Rick Rarick
;
; Cleveland State University
;
; This program sequentially illuminates the LEDs that are connected 
; to RC0, RC1, and RC2, and RC3 for one second and then repeats.
; This program demonstrates how a lookup table can be implemented
; in the PIC.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Assembler Directives
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	list 		p = 16f877
	
	include 	"p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   	config_1 & config_2
	
TableSize	EQU		D'8'	; The EQU directive assigns a literal 
							; (constant) value to the label 
							; 'TableSize'. The label 'TableSize'	
							; cannot be redefined with an EQU
							; directive later in code.						

;---------------------------------------------------------------------
		
; Allocate some General Purpose Registers (GPRs) for user variables. The
; values assigned to these variables can be changed in the code.

	cblock	0x20
	
		TableIndex		; 0x20 in data memory	
		Count 			; 0x21		
		CountOuter		; 0x22	
		CountInner		; 0x23
			
	endc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Begin executable code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

	org		0x0000		; Reset vector
	
	nop					
	
	goto	INIT		

	org		0x0004		; Unused interrupt vector
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initializtion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INIT	
	
	clrf		TableIndex		; TableIndex = 0
								; TableIndex address = 0x20 (Bank 0)																			
	
	banksel		TRISC			; Select Bank 1
	
	movlw		B'00000000'		; PORTC<3:0> configured as outputs
								
	movwf 		TRISC      		; Set TRISC = 1111 0000
	
	banksel		PORTC			; Return to Bank 0
	
	clrf		PORTC			; PORTC = 0000 0000
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MAIN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Continously cycle though the first four LEDs on PORTC with a 
; one-second delay. 

MAIN

	call	DELAY_500ms		; Delay 1 second
	call	DELAY_500ms		
	
	movf	TableIndex, W	; W = TableIndex
	
	call	LookupTable		; W now contains the index for the table.
							; Get the PORTC entry from the table and
							; and return it in W.
							 	
	movwf	PORTC			; PORTC = W
	
	incf	TableIndex, F	; TableIndex = TableIndex + 1
	
	; Test whether TableIndex = TableSize
	
	movf	TableIndex, W	; W = TableIndex	
	
	xorlw	TableSize		; TableIndex xor TableSize
							; The result of the xorlw is placed in W.
							; If W = 0, TableIndex = TableSize and
							; Z = 1. Otherwise, W != 0, 
							; TableIndex != TableSize, and Z = 0. 
	
	btfss	STATUS, Z		; Test: if Z = 1 (TableIndex = TableSize)
							; then skip the next instruction.
	
	goto 	MAIN			; If we reach this instruction, then Z = 0 
							; (TableIndex < TableSize), so get the
							; next table entry for PORTC.	
	
	clrf	TableIndex		; If we reach this instruction, then Z = 1,
							; so reset TableIndex = 0
	
	goto 	MAIN			; Repeat until HALT or Power Down.
	
	; End of Main Program Loop

;;;;;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Lookup Table 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; The table contains the LED bit patterns that are to be copied to
; PORTC in order to blink the LEDs connected to RC0, RC1, RC2, and RC3.
; Upon entering the subroutine, W contains the index of the LED
; which is to be turned on. W is added to the program counter
; which causes it to jump to the appropriate table entry. 
; The 'retlw' (return with literal in W) instruction copies the
; 8-bit PORTC table entry into W and then returns from the
; subroutine.

LookupTable

	addwf	PCL, F		; PCL = PCL + W + 1
	 
	retlw	B'01111111'	; W = 0  
	retlw	B'00011111'	; W = 0  
	retlw	B'00000111'	; W = 0  
	retlw	B'00000001'	; W = 0  
	retlw	B'00000000'	; W = 0  
	retlw	B'00000011'	; W = 0  
	retlw	B'00001111'	; W = 0  
	retlw	B'00111111'	; W = 0  
	  
	; End of LookupTable subroutine

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DELAY_500ms Subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; A precise timing interval can be generated using “brute force”
; instruction counting.

DELAY_500ms 

	movlw	d'50'			; Set Count = 50			
	movwf	Count			
							
Loop					
	
	call	DELAY_10ms 		; Call DELAY_10ms 50 times = 500 ms
	
	decfsz	Count, F		; 1 instruction	
	goto	Loop			; 2 instructions
	
	return					
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; End of DELAY_500ms subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DELAY_10ms 			

	movlw	d'10'
	movwf	CountOuter
	
OuterLoop
		
		movlw	d'230'					; 1 instruction	
		movwf	CountInner				; 1 instruction					
		
		;-------------------------------------------
InnerLoop
		
			nop							; 1 instruction			
			decfsz	CountInner, F		; 1 instruction	
			goto	InnerLoop			; 2 instructions
			
			; Approximate calculation: The InnerLoop code
			; will execute 230 times for a total of 
			; 4 * 230 = 920 instructions.
			
			; Else exit InnerLoop
			
		;-------------------------------------------								
										
		decfsz	CountOuter, F		; 1 instruction	
		goto	OuterLoop			; 2 instructions
		
		; The OuterLoop code will execute 10 times for a total
		; of 10 * ( 2 + 920 + 3 ) = 9250 instructions (approximately).
		; This gives a delay of 9250 * 1.0851 = 10.037 ms. (See below)

		; Else exit OuterLoop
			
	return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; End of DELAY_10ms subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	end		; End of program	           		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 