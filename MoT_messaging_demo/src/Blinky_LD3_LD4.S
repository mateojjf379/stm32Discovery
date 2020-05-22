@; Blinky_LD3_LD4.S wmh 2018-10-24 : adds 'initPG13PG14()' and 'togglePG14()' functions for red LED of STM32F429I-DISC1 board
@; Blinky_LD3.S wmh 2018-08-17 :  functions initializing and controlling LD3, the green LED at port pin PG13 on the STM32F429I-DISC1 board
@;
	@; uppercse 'S' file extension tells GCC to use preprocessor
@;	#include <stdint.h>
@;	#define   __I     volatile const 	/*!< Defines 'read only' permissions */
@;	#define     __O     volatile		/*!< Defines 'write only' permissions */
@;	#define     __IO    volatile		/*!< Defines 'read / write' permissions */
@;	#include "stm32f4xx.h"

	@; from constants defined in stm32f4xx.h (and myinclude03.h) 
	.equ	PERIPH_BASE,	0x40000000  @; Base address of : AHB/ABP Peripherals  
	.equ	AHB1PERIPH_BASE,(PERIPH_BASE + 0x00020000)

	.equ	RCC_BASE,(AHB1PERIPH_BASE + 0x3800)
	.equ 	RCC_AHB1ENR,0x30	@;RCC AHB1 peripheral clock enable register, Address offset: 0x30 

	.equ	GPIOG_BASE,(AHB1PERIPH_BASE + 0x1800)
	.equ	MODER,	0x00	@;  GPIO port mode register,	Address offset:	0x00	      
	.equ	OTYPER,	0x04	@;  GPIO port output type register,	Address offset:	0x04	      
	.equ	OSPEEDR,0x08	@;  GPIO port output speed register,	Address offset:	0x08	      
	.equ	OPUPDR,	0x0C	@;  GPIO port pull-up/pull-down register,	Address offset:	0x0C
	.equ	IDR,	0x10	@;  GPIO port input data register,	Address offset:	0x10	      
	.equ	ODR,	0x14	@;  GPIO port output data register,	Address offset:	0x14	      
	.equ	BSRR,	0x18	@;  GPIO port bit set/reset register,	Address offset:	0x18	      
	.equ	LCKR,	0x1C	@;  GPIO port configuration lock register,	Address offset:	0x1C	      
	.equ	AFRL,	0x20	@;  GPIO alternate function register low,	Address offset:	0x20
	.equ	AFRH,	0x24	@;  GPIO alternate function register high,	Address offset:	0x24 

	
	.syntax unified				@; ARM Unified Assembler Language (UAL) is allowed 
	.thumb						@; here we're use thumb instructions only

.macro MOV_imm32 reg, constant
	movw \reg, #:lower16:\constant
	movt \reg, #:upper16:\constant
.endm
	
	
.macro initGPIOx_out GPIOx_BASE, pin
	@; configuring GPIOx pin
	MOV_imm32 r3,\GPIOx_BASE
	
	@; configure GPIOx pin as an output
	ldr r2,[r3,#MODER]
	bic r2,#(3<<(2*\pin))	@;clear current value if any of GPIOx pin mode
	orr	r2,#(1<<(2*\pin))	@;set new value of GPIOx pin mode to general purpose  output
	str r2,[r3,#MODER]	@; ..
	
	@; configure output on GPIOx pin as push/pull
	ldr r2,[r3,#OTYPER]
	bic r2,#(1<<(1*\pin))	@;clear control bit 
	str r2,[r3,#OTYPER]	@; ..

	@; configure output on GPIOx pin as high speed 
	ldr r2,[r3,#OSPEEDR]
	bic r2,#(3<<(2*\pin))	@;clear current value if any of control bits
	orr	r2,#(2<<(2*\pin))	@;set new value of GPIOx pin mode high speed
	str r2,[r3,#OSPEEDR]@; ..

	@; configure output on GPIOx pin as no pullup, pulldown
	ldr r2,[r3,#OPUPDR]
	bic r2,#(3<<(2*\pin))	@;clear current value if any of control bits
	str r2,[r3,#OPUPDR]	@; ..
.endm	
	
	.text
  
	.global initPG13PG14 
	.thumb_func
initPG13PG14: @;configure PG13 (LD3) and PG14 (LD4) as outputs
	@; make sure GPIOG is enabled
	MOV_imm32 r3,RCC_BASE
	ldr r2,[r3,#RCC_AHB1ENR]
	orr r2,#(1<<6)		@; set enable bit
	str r2,[r3,#RCC_AHB1ENR]
	
	@; configuring PG13
	initGPIOx_out GPIOG_BASE,13 

	@; configuring PG14
	initGPIOx_out GPIOG_BASE,14 
	
	bx lr

	
	.global togglePG13
	.thumb_func
togglePG13: @;flip PG13  to opposite state

	@; accessing PG13
	MOV_imm32 r3,GPIOG_BASE

	@; configure output on PG13 as high speed 
	ldr r2,[r3,#IDR]		@;get current GPIOG port values
	eor r2,r2,#(1<<(1*13))	@;toggle bit 13 
	str r2,[r3,#ODR]		@;update GPIOG port values
	
	bx lr

	.global togglePG14
	.thumb_func
togglePG14: @;flip PG14  to opposite state

	@; accessing PG14
	MOV_imm32 r3,GPIOG_BASE

	@; configure output on PG13 as high speed 
	ldr r2,[r3,#IDR]		@;get current GPIOG port values
	eor r2,r2,#(1<<(1*14))	@;toggle bit 14 
	str r2,[r3,#ODR]		@;update GPIOG port values
	
	bx lr

	.global setRedLED
	.thumb_func
setRedLED: @;red LED 'on'
	@; accessing PG14 = RedLED
	MOV_imm32 r3,GPIOG_BASE	@;set bit 14 of GPIOG
	mov r2,#(1<<(1*14))		@; ..
	str r2,[r3,#BSRR]		@; ..
	bx lr

		.global resetRedLED
	.thumb_func
resetRedLED: @;red LED 'off'
	@; accessing PG14 = RedLED
	MOV_imm32 r3,GPIOG_BASE	@;reset bit 14 of GPIOG
	mov r2,#(1<<((1*14)+16))@; ..
	str r2,[r3,#BSRR]		@; ..
	bx lr


	.global setGreenLED
	.thumb_func
setGreenLED: @;red LED 'on'
	@; accessing PG14 = RedLED
	MOV_imm32 r3,GPIOG_BASE	@;set bit 13 of GPIOG
	mov r2,#(1<<(1*13))		@; ..
	str r2,[r3,#BSRR]		@; ..
	bx lr

		.global resetGreenLED
	.thumb_func
resetGreenLED: @;red LED 'off'
	@; accessing PG14 = RedLED
	MOV_imm32 r3,GPIOG_BASE	@;reset bit 13 of GPIOG
	mov r2,#(1<<((1*13)+16))@; ..
	str r2,[r3,#BSRR]		@; ..
	bx lr
