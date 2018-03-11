;***********************************************************
;*
;*	TX-Remote.asm
;*
;*	Enter the description of the program here
;*
;*	This is the TRANSMIT skeleton file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Jimwel Aguinaldo and Blake Hudson
;*	   Date: 3/5/18
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	BotID = r17				; Bot Address

.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit
; Use these action codes between the remote and robot
//.equ	BotAddress = 0b00110101		; Robot Address
.equ	BotAddress = 41
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ	Freeze =  0b11111000							;0b11111000	Freeze Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi mpr, low(RAMEND)
	out SPL, mpr
	ldi mpr, high(RAMEND)
	out SPL, mpr

	; I/O Ports
	ldi mpr, $FF	; Write 1's in bit 0-3 in PORT B to set as output
	out DDRB, mpr															; that will be used to indicated speed of tekbot

	; Initialize Port D for input
	ldi mpr, 0b00001000		; Write 0's to DDRD to set up for input (Left and Right Whiskers)
	out DDRD, mpr			; and write 1 to pin 3 for TXD1 (output)
	ldi mpr, 0b11110011		; Write 1's to PORTD to set up pull-up resistor
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
		;Enable transmitter
		ldi mpr, (1<<TXEN1)			; Transmitter Enable Bit
		sts UCSR1B, mpr				; USCSR1B is in Extended I/O space (use sts)
		;Set frame format: 8 data bits, 2 stop bits
		ldi mpr, (1<<UCSZ11 | 1<<UCSZ10 | 1<<USBS1)
		sts UCSR1C, mpr

	;Other
	ldi BotID, BotAddress
				

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		//in mpr, PIND
			
		sbis PIND, 0
		rjmp Halt1
		
		sbis PIND, 4
		rjmp TurnLeft
		
		sbis PIND, 5
		rjmp TurnRight
		
		sbis PIND, 6
		rjmp MoveBck
		
		sbis PIND, 7
		rjmp MoveFwd

		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;-----------------------------------------------------------
; Func:	MoveFwd
; Desc:	Move Forward
;-----------------------------------------------------------
MoveFwd:
		ldi mpr, MovFwd
		lsl mpr	
		out PORTB, mpr
				
		lds mpr, UCSR1A
		sbrs mpr, UDRE1					; Loop until UDR1 is empty
		rjmp MoveFwd
		sts UDR1, BotID				

MoveFwd2:		
		
		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp MoveFwd2
		ldi mpr, MovFwd				; Move Action Code (Move Forward) to UDR1		
		sts UDR1, mpr
		
		ret						; End a function with RET
;-----------------------------------------------------------
; Func:	MoveBck
; Desc:	Move Backward
;-----------------------------------------------------------
MoveBck:	
		ldi mpr, MovBck
		lsl mpr
		out PORTB, mpr

		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp MoveBck
		sts UDR1, BotID				

MoveBck2:		
		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp MoveBck2
		ldi mpr, MovBck				; Move Action Code (Move Back) to UDR1
		sts UDR1, mpr

		ret							; End a function with RET

;-----------------------------------------------------------
; Func:	TurnRight
; Desc:	Turn Right
;-----------------------------------------------------------
TurnRight:	
		ldi mpr, TurnR
		lsl mpr
		out PORTB, mpr

		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp TurnRight
		sts UDR1, BotID				

TurnRight2:		
		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp TurnRight2
		ldi mpr, TurnR				; Move Action Code (Turn Right) to UDR1
		sts UDR1, mpr

		ret							; End a function with RET
;-----------------------------------------------------------
; Func:	TurnLeft
; Desc:	Turn Left
;-----------------------------------------------------------
TurnLeft:	
		ldi mpr, TurnL
		lsl mpr
		out PORTB, mpr
		
		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp TurnLeft
		sts UDR1, BotID

TurnLeft2:
		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp TurnLeft2
		ldi mpr, TurnL				; Move Action Code (Turn Left) to UDR1
		sts UDR1, mpr
	
		ret							; End a function with RET

;-----------------------------------------------------------
; Func:	Halt
; Desc:	Halt
;-----------------------------------------------------------
Halt1:	
		ldi mpr, Halt
		lsl mpr
		out PORTB, mpr

		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp Halt1
		ldi mpr, BotAddress				; Move Robot address to UDR1
		sts UDR1, mpr

Halt2:
		lds mpr, UCSR1A
		sbrs mpr, UDRE1				; Loop until UDR1 is empty
		rjmp Halt2
		ldi mpr, Halt				; Move Action Code (Halt) to UDR1
		sts UDR1, mpr
	
		ret							; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************