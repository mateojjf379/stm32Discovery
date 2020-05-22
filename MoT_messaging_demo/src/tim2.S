@; stm32f767xx_TIM2_CH4_PWM_IRQ_demo01.S wmh 2017-11-01 : moves TIM2 PWM output to PA3 (TIM2 CH4) so TIM5 PWM input can occur on CH1,2 on PA0
@; stm32f767xx_TIM2_demo03.S wmh 2017-10-30 : initialize TIM2 and NVIC for interrupt operation; add TIM2_Handler
@; stm32f767xx_TIM2_demo02b.S wmh 2017-10-18 : some small fixes -- don't recall what they were
@; stm32f767xx_TIM2_demo02a.S wmh 2017-10-18 : simple TIM2 initialization demo adding debug timer freeze
@;   Changes from polling TIM2's UIF in TIM2_delay() to polling TIM2's CC1IE (TIM2 CH1 iterrupt flag) to test if TIM2_CH1 compare is working
@; stm32f767xx_TIM2_demo02.S wmh 2017-10-23 : TIM2 PWM demo
@; stm32f767xx_TIM2_demo01.S wmh 2017-10-18 : simple TIM2 initialization demo
@; --- characterize target syntax, processor
	.syntax unified				@; ARM Unified Assembler Language (UAL).
	.thumb						@; but here we'll use thumb instructions only

@; --- definitions pertinent to TIM2, extracted from 'stm32f767xx.h'
.equ 	PERIPH_BASE,		0x40000000U @; Base address of : AHB/ABP Peripherals
.equ	AHB1PERIPH_BASE,	(PERIPH_BASE + 0x00020000U)
.equ	RCC_BASE,           (AHB1PERIPH_BASE + 0x3800U)
.equ 	APB1RSTR,			0x20		@; RCC APB1 peripheral reset register, Address offset: 0x20
.equ	APB1ENR,			0x40		@; RCC APB1 peripheral clock enable register, Address offset: 0x40
.equ 	AHB1ENR,			0x30		@; RCC AHB1 peripheral clock register
.equ 	APB1PERIPH_BASE,	(PERIPH_BASE + 0)
.equ 	TIM2_BASE,			(APB1PERIPH_BASE + 0x0000U)	@; origin of TIM2 control register array

@; offsets to registers in TIMx configuration array
.equ	CR1,	0x00	@;	  __IO uint32_t CR1;              TIM control register 1,              Address offset: 0x00
.equ	CR2,	0x04	@;	  __IO uint32_t CR2;              TIM control register 2,              Address offset: 0x04
.equ	SMCR,	0x08	@;	  __IO uint32_t SMCR;             TIM slave mode control register,     Address offset: 0x08
.equ	DIER,	0x0C	@;	  __IO uint32_t DIER;             TIM DMA/interrupt enable register,   Address offset: 0x0C
.equ	SR,		0x10	@;	  __IO uint32_t SR;               TIM status register,                 Address offset: 0x10
.equ	EGR,	0x14	@;	  __IO uint32_t EGR;              TIM event generation register,       Address offset: 0x14
.equ	CCMR1,	0x18	@;	  __IO uint32_t CCMR1;            TIM capture/compare mode register 1, Address offset: 0x18
.equ	CCMR2,	0x1C	@;	  __IO uint32_t CCMR2;            TIM capture/compare mode register 2, Address offset: 0x1C
.equ	CCER,	0x20	@;	  __IO uint32_t CCER;             TIM capture/compare enable register, Address offset: 0x20
.equ	CNT,	0x24	@;	  __IO uint32_t CNT;              TIM counter register,                Address offset: 0x24
.equ	PSC,	0x28	@;	  __IO uint32_t PSC;              TIM prescaler,                       Address offset: 0x28
.equ	ARR,	0x2C	@;	  __IO uint32_t ARR;              TIM auto-reload register,            Address offset: 0x2C
.equ	RCR,	0x30	@;	  __IO uint32_t RCR;              TIM repetition counter register,     Address offset: 0x30
.equ	CCR1,	0x34	@;	  __IO uint32_t CCR1;             TIM capture/compare register 1,      Address offset: 0x34
.equ	CCR2,	0x38	@;	  __IO uint32_t CCR2;             TIM capture/compare register 2,      Address offset: 0x38
.equ	CCR3,	0x3C	@;	  __IO uint32_t CCR3;             TIM capture/compare register 3,      Address offset: 0x3C
.equ	CCR4,	0x40	@;	  __IO uint32_t CCR4;             TIM capture/compare register 4,      Address offset: 0x40
.equ	BDTR,	0x44	@;	  __IO uint32_t BDTR;             TIM break and dead-time register,    Address offset: 0x44
.equ	DCR,	0x48	@;	  __IO uint32_t DCR;              TIM DMA control register,            Address offset: 0x48
.equ	DMAR,	0x4C	@;	  __IO uint32_t DMAR;             TIM DMA address for full transfer,   Address offset: 0x4C
.equ	OR,		0x50	@;	  __IO uint32_t OR;               TIM option register,                 Address offset: 0x50
.equ	CCMR3,	0x54	@;	  __IO uint32_t CCMR3;            TIM capture/compare mode register 3,      Address offset: 0x54
.equ	CCR5,	0x58	@;	  __IO uint32_t CCR5;             TIM capture/compare mode register5,       Address offset: 0x58
.equ	CCR6,	0x5C	@;	  __IO uint32_t CCR6;             TIM capture/compare mode register6,       Address offset: 0x5C
.equ	AF1,	0x60	@;	  __IO uint32_t AF1;              TIM Alternate function option register 1, Address offset: 0x60
.equ	AF2,	0x64	@;	  __IO uint32_t AF2;              TIM Alternate function option register 2, Address offset: 0x64


	.text
	.align 2
	.global TIM2_init
	.thumb_func
TIM2_init:	@;TIM2 initialized for PWM output (manual section 26.3.9)
    push {r7,lr}
	push {r0}
	@;(re-)enable TIM2 and then reset it
	ldr r3,=RCC_BASE		@;enable TIM2
	ldr r2,[r3,#APB1ENR]	@; ..
	orr	r2,r2,0x01			@; ..  (see manual page 185)
	str r2,[r3,#APB1ENR]	@; ..
	ldr r2,[r3,#APB1RSTR]	@;reset TIM2
	orr r2,r2,0x01 			@; ..  (see manual page 174)
	str r2,[r3,#APB1RSTR]	@; ..
	bic	r2,r2,0x01			@; ..  manual: APB1RSTR bits are "set _and_ cleared by software"
	str r2,[r3,#APB1RSTR]	@; ..

@; here with TIM2 enabled and reset
    ldr r3,=TIM2_BASE       @;select TIM2 for register operations

	@;set TIM2 prescaler reload value
	movw r2,#0x5E08			@; prescale 168mHz system clock by 168 (see manual page 987)
	strh r2,[r3,#PSC]		@; ..

	@;set TIM2 counter reload value
	pop {r0}
	mov r2, r0
	//movw r2,r0			@; counter reloads at 999  (see manual page 987)
	//movt r2,#0				@; ..
	str r2,[r3,#ARR]		@; ..

	@;select PWM mode (note 1) and enable TIM2 CH4 preload register (note 2)
	ldr r2,[r3,#CCMR2]		@; TIM2_CCMR2 : OC4M[3:0]=
	bic r2,#(1<<15)			@; OC4M[3]=0, not be affected by ETRF input?
	orr r2,#(0x6<<12)			@; OC4M[2:0]=110, pwm mode 1
	orr r2,#(1<<11)			@; OC4PE=1
	str r2,[r3,#CCMR2]		@; ..

	@;enable CH4 output mode (note 4,5)
	mov r2,1<<(12)			@; TIM2_CCER : CC4P=0 (active high), CC4E= 1 (OC4 active high, enabled) --> pulse=1 until CCR4 value is reached
	str r2,[r3,#CCER]

	@;set CH4's compare value
	movw r2,#249
	movt r2,#0
	str r2,[r3,#CCR4]

	@;initialize the comparitor register with its value (note 3)
	mov r2,#(1<<4) @;CC4G = 1
	str r2,[r3,#EGR]
	@;!! here with UIF in SR=1 as a side effect of the above instruction

	@;enable TIM2 interrupt on CH4
	mov r2,#(1<<4)			@; set CC4IE: 1 Capture/Compare 4 interrupt enable
	str r2,[r3,DIER]

	@;enable TIM2 as up-counting(Dir = 0) edge-aligned (CMS=00) overflow-triggered (URS = 1) repeating counter OPM(1) (notes 6 and 7)
	movw r2,#0x91				@; ..
	strh r2,[r3,#CR1]		@; done last, as counter starts immediately (see manual page 937)
	@;!! here with all CCxIF flags in SR =1 as a side effect of the above instruction

	@;clear TIM2 interrupts at startup
	mov r2, 0x0000			@; .. reset value 0x0000
	strh r2,[r3,#SR]		@; all interrupt and overflow flags all 0

	@; here with TIM2 running
	pop {r7,pc}

	.global TIM2_disable
TIM2_disable:	@;TIM2 initialized for PWM output (manual section 26.3.9)
    push {r7,lr}
	@;(re-)enable TIM2 and then reset it
	ldr r3,=RCC_BASE		@;disable TIM2
	ldr r2,[r3,#APB1ENR]	@; ..
	bic	r2,r2,0x01			@; ..  (see manual page 185)
	str r2,[r3,#APB1ENR]	@; ..
	ldr r2,[r3,#APB1RSTR]	@;reset TIM2
	orr r2,r2,0x01 			@; ..  (see manual page 174)
	str r2,[r3,#APB1RSTR]	@; ..
	bic	r2,r2,0x01			@; ..  manual: APB1RSTR bits are "set _and_ cleared by software"
	str r2,[r3,#APB1RSTR]	@; ..
	pop {r7,pc}


	.global TIM2_check
	.thumb_func
TIM2_check:
	push {r7, lr}

	mov r0,0
	ldr r3, = TIM2_BASE
	ldr r2, [r3,#SR]
	ands r1, r2, #0x1
	cmp r1, #1
	ittt eq
	biceq r2, #(1)
	streq r2, [r3,#SR]
	moveq r0, 1

	pop {r7,pc}


	.global TIM2_poll
	.thumb_func
TIM2_poll:
	push {r7, lr}

	ldr r3, = TIM2_BASE
	ldr r2, [r3,#SR]
	ands r1, r2, #0x1
	cmp r1, #1
	ittt eq
	biceq r2, #(1)
	streq r2, [r3,#SR]
	bleq togglePG14

	pop {r7,pc}
