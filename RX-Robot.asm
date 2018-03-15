;***********************************************************
;*
;*	RX-Robot.asm
;*
;*	Receiver (Robot)
;*
;*	Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Jimwel Aguinaldo
;*	   Date: 3/16/18
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	waitcnt = r17			; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter
.def	currentState = r20		; Current State of BumpBot
.def	verifiedID = r21		; Verify Bot Identification

.equ	WTime = 100				; Time to wait in wait loop
.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

//.equ	BotAddress = 0b00110101	;(Enter your robot's address here (8 bits))
.equ	BotAddress = 41
;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

;Should have Interrupt vectors for:
;- Left whisker
.org	$0002	; INT0
		rcall HitLeft
		reti

;- Right whisker
.org	$0004	; INT1
		rcall HitRight
		reti

;- USART receive
.org	$003C					; USART1, Rx Complete
		rcall USART_Recieve
		reti

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi mpr, high(RAMEND)
	out SPH, mpr
	ldi mpr, low(RAMEND)
	out SPL, mpr

	;I/O Ports
		;Initialize Port B for output
		ldi mpr,$FF	; Write 1's in bit 0-3 in PORT B to set as output
		out DDRB, mpr
		; Initialize Port D for input
		ldi mpr, (0<<WskrL)|(0<<WskrR)|(0<<PD2)		; Set WskrL, WiskrR, and pin2 (RXD1) for input
		out DDRD, mpr
		ldi mpr, (1<<WskrL)|(1<<WskrR)
		out PORTD, mpr 

	;USART1
	; Set double data rate
		ldi mpr, (1<<U2X1) ; Set double data rate
		sts UCSR1A, mpr 
		;Set baudrate at 2400bps
		ldi mpr, high(832)			; Load high byte of 416
		sts UBRR1H, mpr				
		ldi mpr, low(832)			; Load low byte of 416
		sts UBRR1L, mpr				

		;Enable receiver and enable receive interrupts
		ldi mpr, (1<<RXCIE1 | 1<<RXEN1 | 0<<TXEN1)
		sts UCSR1B, mpr

		;Set frame format: 8 data bits, 2 stop bits
		ldi mpr, (1<<UCSZ11 | 1<<UCSZ10 | 1<<USBS1)
		sts UCSR1C, mpr

	;External Interrupts
		;Set the External Interrupt Mask
		ldi mpr, (1<<INT0)|(1<<INT1)
		out EIMSK, mpr

		;Set the Interrupt Sense Control to falling edge detection
		ldi mpr, 0b10101010
		sts EICRA, mpr

	;Other
	ldi currentState, MovFwd		; Initialize currentState 
	out PORTB, currentState	
	ldi verifiedID, $00				; correct ID == False 
	
	sei		; Enable Global Interrupts

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		
		out PORTB, currentState

		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;***********************************************************
;* USART Recieve (interrupt driven)
;***********************************************************
USART_Recieve:
	
	lds mpr, UDR1				; Get message from USART recieve	
	sbrc mpr, 7					; If bit 7 == 1
	rjmp USART_Recieve_Action	;	then, skip to recieve action code. Else, continue to recieve BotID

USART_Recieve_BotID:

	cpi mpr, BotAddress			; If recieved message != BotID
	brne ReturnFromRecieve		;	Then, return.
	ldi verifiedID, $01			;	 Else, activate recieve action.
	rjmp ReturnFromRecieve 
	
USART_Recieve_Action:

	cpi verifiedID, $01			; If BotIDrecieved != BotID
	brne ReturnFromRecieve		;	Then, return. Else, activate recieve action.		

	mov currentState, mpr		; Recieve Action address second
	lsl currentState			; shift action code to the left
	clr verifiedID				; clear verifiedID
	
ReturnFromRecieve:
	ret					; Return from interrupt service

;***********************************************************
;* Right Whisker Interrupt
;***********************************************************
HitRight:
	push mpr				; Save mpr register
	push waitcnt			; Save wait register
	in mpr, SREG			; Save program state
	push mpr				; Move Backwards for a second
	
	ldi mpr, MovBck			; Load Move Backwards command
	out PORTB, mpr			; Send command to port
	ldi waitcnt, WTime		; Wait for 1 second
	rcall Wait				; Call wait function
							; Turn left for a second
	ldi mpr, TurnL			; Load Turn Left Command
	out PORTB, mpr			; Send command to port
	ldi waitcnt, WTime		; Wait for 1 second
	rcall Wait				; Call wait function
	pop mpr					; Restore program state
	cli
	out SREG, mpr 
	pop waitcnt				; Restore wait register
	pop mpr

;***********************************************************
;* Left Whisker Interrupt
;***********************************************************
HitLeft:
	push mpr				; Save mpr register
	push waitcnt			; Save wait register
	in mpr, SREG			; Save program state
	push mpr 
	
	; Move Backwards for a second
	ldi mpr, MovBck			; Load Move Backwards command
	out PORTB, mpr			; Send command to port
	ldi waitcnt, WTime		; Wait for 1 second
	rcall Wait				; Call wait function
	
	; Turn left for a second
	ldi mpr, TurnR			; Load Turn right Command
	out PORTB, mpr			; Send command to port
	ldi waitcnt, WTime		; Wait for 1 second
	rcall Wait				; Call wait function
	pop mpr					; Restore program state
	cli
	out SREG, mpr			;
	pop waitcnt				; Restore wait register
	pop mpr
							; Restore mpr
	ret						; Return from subroutine

Wait:
	push waitcnt			; Save wait register
	push ilcnt				; Save ilcnt register
	push olcnt				; Save olcnt register

	Loop:   ldi olcnt, 224			; load olcnt register
	OLoop:  ldi ilcnt, 237			; load ilcnt register
	ILoop:  dec ilcnt				; decrement ilcnt
			brne ILoop				; Continue Inner Loop
			dec olcnt				; decrement olcnt
			brne OLoop				; Continue Outer Loop
			dec waitcnt				; Decrement wait
			brne Loop				; Continue Wait loop
			pop olcnt				; Restore olcnt register
			pop ilcnt				; Restore ilcnt register
			pop waitcnt				; Restore wait register
			ret						; Return from subroutine

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************
