//***************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programación de Microcontroladores
// contador_pcint.asm
// Autor: Larsson González
// Proyecto: Contador binario de 4bits con interrupciones PCINT
// Hardware: ATMega328p
// Created: 9/2/2024 00:54:11
//***************************************************************
.include "M328PDEF.inc"
.cseg
.org 0x0000
	JMP MAIN
.org 0x0006
	JMP ISR_PCINT0
.org 0x0020
	JMP ISR_TIMER0_OVF
	

MAIN:
//***************************************************************
// STACK POINTER
//***************************************************************
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R17, HIGH(RAMEND)
OUT SPH, R17

//***************************************************************
// PROGRAMA PRINCIPAL I/O
//***************************************************************
SETUP:
	SEI	;Habilita las interrupciones globales
	
	LDI R25, 0b10000000
	LDI R25, (1<<CLKPCE)
	STS CLKPR, R25
	LDI R25, 0b00000001
	STS CLKPR, R25

	;Se configura el puerto C como salidas (LEDS)
	LDI R16, 0b00001111
	OUT DDRC, R16
	;LDI R20, 0 ;Contador

	;Se configura como pull ups PB0(D8) y PB1(D9) (contador) - PB2(Display1) y PB4(Display2) como salidas del display
	SBI PORTB, PB0
	CBI DDRB, PB0	;PB0 para incrementar
	SBI PORTB, PB1
	CBI DDRB, PB1	;PB1 para decrementar
	SBI PORTB, PB2	;PB2 como salida del display1
	SBI PORTB, PB4	;PB4 como salida del display2

	;Se configura el puerto D como salidas (Display)
	LDI R16, 0b11111111
	OUT DDRD, R21
	
	;Habilitando las ISR de los PCINT
	LDI R16, (1<<PCIE0)
	STS PCICR, R16
	;Habilitando los PCINT
	LDI R16, (1<<PCINT0) | (1<<PCINT1)
	STS PCMSK0, R16
	SBI PINB, PB2

	LDI R19, 0	;Contador display
	LDI R20, 0	;Contador push button
	LDI R21, 0	;Contador de unidades
	LDI R22, 0	;Contador de decenas
	LDI R25, 0
	CALL INIT_TIMER0


//***************************************************************
//  LOOP
//***************************************************************

LOOP:
	
	OUT PORTC, R20	;Salida del puerto C para leds

	;Verifica el timer0 y las unidades
	CPI R21, 10
	BREQ RESET
	CPI R23, 50
	BREQ DISPLAY1
	
	CALL ESPERAR
	SBI PINB, PB2	;Enciende display1
	SBI PINB, PB4	;Apagar display2

	;Tabla para mostrar valores en el display1
	LDI ZH, HIGH(TABLA7SEG<<1)
	LDI ZL, LOW(TABLA7SEG<<1)
	ADD ZL, R21	;Registro donde se aumenta (contador unidades)
	LPM R25, Z
	OUT PORTD, R25

	CALL ESPERAR
	SBI PINB, PB2	;Apagar display1
	SBI PINB, PB4	;Enciende display2

	;Tabla para mostrar valores en el display 2
	LDI ZH, HIGH(TABLA7SEG<<1)
	LDI ZL, LOW(TABLA7SEG<<1)
	ADD ZL, R22	;Registro donde se aumenta (contador de decenas)
	LPM R25, Z
	OUT PORTD, R25

	;Cuando el contador de decenas llega a 6 se resetea y empieza todo de nuevo
	CALL ESPERAR
	CPI R22, 6
	BREQ RESET1

	
	RJMP LOOP

//**************************************************************
// SUBRUTINAS NORMALES
//**************************************************************
ESPERAR:
	LDI R19, 255
	TIEMPO:
		DEC R19
		BRNE TIEMPO

	RET

;Reset contador de unidades
RESET: 
	LDI R21, 0
	INC R22
	RJMP LOOP

DISPLAY1:
	INC R21
	LDI R23, 0
	RJMP LOOP

;Reset contador de decenas
RESET1:
	CALL ESPERAR
	LDI R21, 0
	LDI R22, 0

//**************************************************************
// SUBRUTINA DE INICIO DE TIMER0
//**************************************************************
INIT_TIMER0:
	LDI R26, 0
	OUT TCCR0A, R26	;Modo normal 

	LDI R26, (1<<CS02)|(1<<CS00)
	OUT TCCR0B, R26	;Prescaler 1024

	LDI R26, 100
	OUT TCNT0, R26

	LDI R26, (1<<TOIE0)
	STS TIMSK0, R26

	RET

//***************************************************************
// SUBRUTINAS DE INTERRUPCION PCINT0
//***************************************************************
ISR_PCINT0:
	PUSH R16
	IN R16, SREG
	PUSH R16

	IN R18, PINB	;Leemos el puerto b

ANTIREBOTE:
	LDI R17, 215

	DELAY:
		DEC R17
		BRNE DELAY

	SBIS PINB, PB0 ;Se lee de nuevo el estado de boton
	RJMP ANTIREBOTE

	SBRC R18, PB0	;verificamos si el botn esta presionado
	RJMP BTN1

;Se configura la parte del antirebote del boton 1
/*ANTIREBOTE:
	LDI R17, 215

	DELAY:
		DEC R17
		BRNE DELAY

	SBIS PINB, PB0 ;Se lee de nuevo el estado de boton
	RJMP ANTIREBOTE*/

	INC R20		;incrementar el contador
	CPI R20, 16		;compara si el contador llego a 16
	BRNE EXIT
	LDI R20, 15		;cuando el contador llego a 16 lo reinicia
	RJMP EXIT

ANTIREBOTE2:
	LDI R17, 215

	DELAY2:
		DEC R17
		BRNE DELAY2

	SBIS PINB, PB1
	RJMP ANTIREBOTE2

BTN1:
	SBRC R18, PB1	;Verifica el botn 1
	RJMP EXIT

/*ANTIREBOTE2:
	LDI R17, 215

	DELAY2:
		DEC R17
		BRNE DELAY2

	SBIS PINB, PB1
	RJMP ANTIREBOTE2*/

	DEC R20
	CPI R20, -1
	BRNE EXIT
	LDI R20, 0

EXIT:
	;OUT PORTC, R20
	SBI PCIFR, PCIF0

	POP R16
	OUT SREG, R16
	POP R16
	RETI


//*********************************************************
// SUBRUTINA DE INTERRUPCION TIMER0
//*********************************************************
ISR_TIMER0_OVF:
	PUSH R17
	IN R17, SREG
	PUSH R17

	LDI R16, 100	;Valor de desbordamiento
	OUT TCNT0, R16	;Cargarmos el valor inicial del contador
	SBI TIFR0, TOV0	;Se borra la bandera 
	INC R23
	

	POP R17
	OUT SREG, R17
	POP R17
	RETI




//*************************************************************************************************************
TABLA7SEG: .DB 0x7E, 0x0C, 0xB6, 0x9E, 0xCC, 0xDA, 0xFA, 0x0E, 0xFE, 0xCE, 0xEE, 0xF8, 0x72, 0xBC, 0xF2, 0xE2
//*************************************************************************************************************
