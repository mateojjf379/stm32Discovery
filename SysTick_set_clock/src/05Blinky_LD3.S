@; 05Blinky_LD3.S wmh 2019-02-17 : adds functions setPG13(), resetPG13()
@; Blinky_LD3.S wmh 2018-08-17 :  functions initializing and controlling LD3, the green LED at port pin PG13 on the STM32F429I-DISC1 board
@;
	@; uppercase 'S' file extension tells GCC to use preprocessor
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

	.text
  
	.global initPG13
	.thumb_func
initPG13: @;configure PG13 as an output
	
	@; make sure GPIOG is enabled
	ldr r3,=RCC_BASE
	ldr r2,[r3,#RCC_AHB1ENR]
	orr r2,#(1<<6)		@; set enable bit
	str r2,[r3,#RCC_AHB1ENR]
	
	@; configuring PG13
	ldr r3,=GPIOG_BASE
	
	@; configure PG13 as an output
	ldr r2,[r3,#MODER]
	bic r2,#(3<<(2*13))	@;clear current value if any of PG13 mode
	orr	r2,#(1<<(2*13))	@;set new value of PG13 mode to general purpose  output
	str r2,[r3,#MODER]	@; ..
	
	@; configure output on PG13 as push/pull
	ldr r2,[r3,#OTYPER]
	bic r2,#(1<<(1*13))	@;clear control bit 
	str r2,[r3,#OTYPER]	@; ..

	@; configure output on PG13 as high speed 
	ldr r2,[r3,#OSPEEDR]
	bic r2,#(3<<(2*13))	@;clear current value if any of control bits
	orr	r2,#(2<<(2*13))	@;set new value of PG13 mode high speed
	str r2,[r3,#OSPEEDR]@; ..

	@; configure output on PG13 as no pullup, pulldown
	ldr r2,[r3,#OPUPDR]
	bic r2,#(3<<(2*13))	@;clear current value if any of control bits
	str r2,[r3,#OPUPDR]	@; ..

	bx lr

	
	.global togglePG13
	.thumb_func
togglePG13: @;flip PG13  to opposite state
	ldr r3,=GPIOG_BASE		@;port G
	ldr r2,[r3,#IDR]		@;get current GPIOG port values
	eor r2,r2,#(1<<(1*13))	@;toggle bit 13 
	str r2,[r3,#ODR]		@;update GPIOG port values
	bx lr
	
	.global setPG13
	.thumb_func
setPG13: @; PG13 = 1 
	ldr r3,=GPIOG_BASE		@;port G
	mov r2,#(1<<(1*13))		@; bit BS13 
	str r2,[r3,#BSRR]		@;  is written
	bx lr

	.global resetPG13
	.thumb_func
resetPG13: @; PG13 = 0 
	ldr r3,=GPIOG_BASE		@;port G
	mov r2,#(1<<(16+1*13))	@; bit BR13 
	str r2,[r3,#BSRR]		@;  is written
	bx lr
	
