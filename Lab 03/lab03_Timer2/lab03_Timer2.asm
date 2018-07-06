;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; lab03_Timer2.asm
;
; Dan Simon
; Rick Rarick
;
; Cleveland State University
;
; This program repeatedly blinks the LEDs that are connected 
; to RC0, RC1, and RC2, and RC3 in order. This program demonstrates
; how use Timer2 and interrupts for the 10 ms delay routine. But 
; there is a bug in the program which must be fixed for proper
; operation.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Assembler Directives
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	list 		p = 16f877
	
	include 	"p16f877.inc"
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC	
	
	__CONFIG   	config_1 & config_2
	
TableSize	EQU		D'4'	; The EQU directive assigns a literal 
							; (constant) value to the label 
							; 'TableSize'. The label 'TableSize'	
							; cannot be redefined with an EQU
							; directive later in code.

; -----------------------------------------------------------------		
; Allocate some General Purpose Registers for user variables. The 
; values assigned to these variables can be changed in the code.

	cblock	0x20
	
		TableIndex		; 0x20 in data memory	
		Count 			; 0x21		
		InterruptCount	; 0x22	
					
	endc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Begin program
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

	org		0x0000		; Reset vector
	
	nop					; Reserved for compatibility with older ICDs
	
	goto	INIT		

	org		0x0004		; Interrupt vector
	
	goto	InterruptServiceRoutine
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Initializtion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INIT
	
	clrf		TableIndex		; TableIndex = 0
								; TableIndex adress = 0x20 (Bank 0)

	banksel		TRISC			; Select Bank 1
	
	clrf 		TRISC      		; TRISC = 0000 0000 (all bits of 
								; PORTC configured as outputs)
		
	; Enable interrups ---------------------------------------
	
	bsf			INTCON, GIE		; Enable global interrupts
								; INTCON is in all four banks.
	
	bsf			INTCON, PEIE	; Enable peripheral interrupts		
	
	; Set up Timer2 -----------------------------------------
	
	movlw	D'229'			; Set up the Timer2 Period register.
							; See slides for the 229 calculation
	movwf	PR2				; PR2 is in Bank 1.
	
	movlw	B'00001101'		; Timer2 --- postscaler = 2, enabled,
	
	banksel	T2CON
					 	; prescaler = 4						 				 						 					 						 
	movwf	T2CON
	
	movlw	0x04			; Initialize the interrupt counter.
							; We need five Timer2 interrupts of
							; 2 ms each to achieve a 10 ms delay.
							; (See delay_10ms routine below).
	
	movwf	InterruptCount			
	
	; -------------------------------------------------------
	
	banksel		PORTC		; Return to Bank 0
	
	clrf		PORTC		; PORTC = 0000 0000 (LEDs off)
	
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
							; The result of the xor is placed in W.
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
	 
	retlw	B'00000001'	; W = 0  
	retlw	B'00000010'	; W = 1   
	retlw	B'00000100'	; W = 2
	retlw	B'00001000'	; W = 3
	  
	; end LookupTable

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DELAY_500ms Subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Create a 500 ms delay by calling a 10 ms delay 50 times.

DELAY_500ms 

	movlw	d'50'			; Set Count = 50			
	movwf	Count			
							
Loop					
	
	call	DELAY_10ms 		; Call DELAY_10ms 50 times = 500 ms
	
	decfsz	Count, F		; 1 instruction	
	goto	Loop			; 2 instructions
	
	return
	
	; End DELAY_500ms subroutine					
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DELAY_10ms subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; DELAY_10ms uses five Timer2 overflow interrupts to create a 10 ms
; delay instead of instruction counting as used in previous labs. 
; Timer2 is configured to overflow every 2 ms. 

DELAY_10ms

	; Enable Timer2 interrupts during the DELAY_10ms subroutine.
	
	banksel 	PIE1			; PIE is in Bank 1
	bsf			PIE1, TMR2IE	; Enable Timer2 interrupts
	banksel		PORTC			; Return to Bank 0
	
	;-------------------------------------------------------------

	btfss	InterruptCount, 7	; Test bit 7.
								; InterruptCount starts at 
								; 0x04 = 0000 0100. It is decremented
								; in the Intterrupt Service Routine
								; each time Timer2 rolls over until it
								; rolls over from 0x00 = 0000 0000 to 
								; 0xFF = 1111 1111, which will change
								; bit 7 to a 1:
								; 04 -> 03 -> 02 -> 01 -> 00 -> FF
								;
								; 0000 0100		->
								; 0000 0011		->
								; 0000 0010		->
								; 0000 0001		->
								; 0000 0000		->
								; 1111 1111
								
								; Then we know that we have had five 
								; Timer2 interrupts.
									
	goto	DELAY_10ms			; Loop until InterruptCount = 0xFF.
	
	movlw	5					; Reset InterruptCount to 0x04 by
								; adding 5 to it: 0xFF + 0x05 = 0x04	
	addwf	InterruptCount, F		
	
	; Disable Timer2 interrupts and exit the DELAY_10ms subroutine.
	
	banksel 	PIE1			; PIE is in Bank 1
	bcf			PIE1, TMR2IE	; Disable Timer2 interrupts
	banksel		PORTC			; Return to Bank 0
	
	return
	
	; End DELAY_10ms subroutine

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt Service Routine (ISR)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; When an interrupt occurs, the Global interrupt Enable (GIE) bit is
; automatically cleared in hardware to disable any further 
; interrupts. This is to prevent a second interrupt while handling
; the first. In other words, nested interrupts are not permitted.
; In order for interrupts to be enabled again, the GIE bit must be
; set manually in software, or a 'retfie' (return with interrupt
; enabled) instruction must be executed.  

InterruptServiceRoutine
	
	btfsc	PIR1, TMR2IF	; Check the Timer2 Interrupt Flag to be
							; sure that the interrupt came from 
							; Timer2. We need this test in case 
							; interrupts from other peripherals are
							; enabled. PIR1 is in Bank 0.	
		
	bcf		PIR1, TMR2IF	; Clear the Timer2 interrupt flag
	
	decf	InterruptCount, F
	
	retfie					; Return from Interrupt Service Routine
							; and enable global interrupts.
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	end		; End of program	         		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;