;********************************************************
; lab08.asm
;
; Unipolar Stepper Motor Controller (Driver).
;
; Step control type: Full-step, two-coil excitation, high torque.
;
; Adapted from www.interq.or.jp/japan/se-inoue/e_step.htm
; Written by Seiichi Inoue for the PIC16F84A.
; Modified by Dan Simon and Rick Rarick for the PIC16F877.
;
; Caution: When the program is halted, reset the program, otherwise
; the PORTD bits will continue to provide power to the motor and
; the LM7805 regulator may become very hot (depending on the motor
; specifications.)
;
;********************************************************************
; Assembler Directives
;********************************************************************
        
	list	p=pic16f877
	include	p16f877.inc
	
config_1	EQU 	_CP_OFF & _CPD_OFF & _LVP_OFF & _WDT_OFF 
	
config_2 	EQU 	_BODEN_OFF & _PWRTE_OFF & _XT_OSC & _WRT_ON	
	
	__CONFIG   	config_1 & config_2
;-----------------------------------------------------------------------------------------
WaitTime	equ		d'32'	; Wait 50 ms between each motor step	

Position1	equ		b'0101'	; step motor position 1
Position2	equ		b'1001'	; step motor position 2
Position3	equ		b'1010'	; step motor position 3
Position4	equ		b'0110'	; step motor position 4	

;********************************************************************
; User-defined variables
;********************************************************************

	cblock  0x20
		mode		; Operation mode: 0 = stop, 1 = CW, 2 = CCW		
		count1		; Wait counter
		count2		; Wait counter (for 1 msec loop)
	endc

;********************************************************************
; Begin executable code
;********************************************************************

	org		0x0000		; Reset Vector
	nop					; Reserved for ICD
	goto	INIT

	org		0x0004		; Interrupt Vector
	
;********************************************************************
; Initialization Routine
;********************************************************************

INIT
	banksel	TRISD			; Set RD0, RD1, RD2, RD3 as outputs
	movlw	b'11110000'		; for motor drive
	movwf	TRISD          	
	
	banksel	PORTD
	clrf    mode            ; mode = 0 = stop
	clrf    count1          ; Clear counter
	clrf    count2          ; Clear counter
	
	movlw	Position1
	movwf   PORTD           ; Write PORTD, move to Position1

;********************************************************************
; Main Routine
;********************************************************************

START

;*************  Check buttons for mode status and set mode  ***********
;
; Note: Direction of rotation also depends on motor wiring.
;
; Manually set mode = 2

		movlw   d'2'            ; Set counter-clockwise (CCW) mode looking
								; into the rotor shaft.
		movwf   mode            ; mode = 2

;********************  Motor drive (Step control)  ********************

drive
	; If mode = 0, stop motor and return to START and loop.

	movf    mode, W			; W = mode
	bz      START         	; Branch to START if W = 0							

	; Otherwise, delay for WaitTime seconds between motor steps	

	movlw   WaitTime		; Set loop count (1 ms units, approximately)
	movwf   count1          ; count1 = WaitTime  = 50 (ms)
	
DelayLoop 
   
	call    delay_1ms 		; 1 ms delay
	decfsz  count1, F       ; count1 = count1 - 1
	goto    DelayLoop       ; If count1 = 0, exit loop.

;***********************************************
; Drive Logic - See lecture slides for flow chart

	movf    PORTD, W        ; W = PORTD
	sublw	Position1		; W = Position1 - W = Position1 - PORTD
	bnz     drive2          ; Branch to drive2 if W not = 0. 
	movf    mode, W         ; W = mode
	
	sublw   d'1'            ; W = 1 - W 
	bz      drive1          ; If W = 0, goto drive1 to rotate motor one step CW,
	movlw	Position2		; else W = Position2 to rotate one step CCW.
	goto    drive_end       ; Jump to the PORTD write routine to rotate motor
							; one step CCW.	
drive1
	movlw   Position4		; W = Position4 to rotate motor one step CW.
	goto    drive_end       ; Jump to PORTD write routine to rotate motor
							; one step CCW.	
drive2
	movf    PORTD, W        ; W = PORTD
	sublw	Position4		; W = Position4 - W = Position4 - PORTD
	bnz     drive4          ; Branch to drive4 if W not = 0. 
	movf    mode, W         ; W = mode

	sublw   d'1'            ; W = 1 - W 
	bz      drive3          ; If W = 0, goto drive1 to rotate motor one step CW,
	movlw	Position1		; else W = Position1 to rotate one step CCW.
	goto    drive_end       ; Jump to PORTD write routine to rotate motor
							; one step CCW.	
drive3
	movlw   Position3		; Set CW data
	goto    drive_end       ; Jump to PORTD write
	
drive4
	movf    PORTD, W        ; Read PORTD
	sublw	Position3
	bnz     drive6          ; Unmatch
	movf    mode, W         ; Read mode
	sublw   d'1'            ; CW ?
	bz      drive5          ; Yes. CW
	movlw	Position4
	goto    drive_end       ; Jump to PORTD write
	
drive5
	movlw   Position2		; Set CW data
	goto    drive_end       ; Jump to PORTD write
	
drive6
	movf    PORTD, W        ; Read PORTD
	sublw	Position2	
	bnz     drive8          ; Unmatch
	movf    mode, W         ; Read mode
	sublw   d'1'            ; CW ?
	bz      drive7          ; Yes. CW
	movlw	Position3
	goto    drive_end       ; Jump to PORTD write
	
drive7
	movlw   Position1		; Set CW data
	goto    drive_end       ; Jump to PORTD write
	
drive8
	movlw	Position1

;********************************************************************
; PORTD Write Routine (sends step control to motor)
;********************************************************************
	
drive_end

	movwf   PORTD         	; Write PORTD
	goto    START           ; Jump to START

;********************************************************************
; 1 msec Delay Subroutine (approximate)
;********************************************************************

; Assuming that the clock speed is 3.6864 MHz

delay_1ms

	movlw   d'184'          ; Set loop count
	movwf   count2          ; Save loop count
	
delay_1ms_loop	

	nop                     ; (1 instr.)
	nop                     ; (1 instr.)
	decfsz  count2, F       ; count2 - 1 = 0 ? (1 instr.)
	goto    delay_1ms_loop	; No - Continue  (2 instr.)
	return                  ; Yes - Return   

	; 5 instructions / loop = 5 * 1.085 = 5.425 us / loop
	; 1 ms / 5.425 us per loop = 184.3 loops

;********************************************************************
	end			; End of program
;********************************************************************

