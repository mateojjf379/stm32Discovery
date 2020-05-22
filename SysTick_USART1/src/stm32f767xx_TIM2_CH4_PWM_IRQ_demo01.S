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


@; --- definitions for alternate function assignment of TIM2 to PA3
.equ 	GPIOA_BASE,	    (AHB1PERIPH_BASE + 0x0000U)	        @; origin of GPIOA control register array
@; offsets to registers in GPIO control array
.equ	MODER,	0x00	@;  GPIO port mode register,	Address offset:	0x00	      
.equ	OTYPER,	0x04	@;  GPIO port output type register,	Address offset:	0x04	      
.equ	OSPEEDR,0x08	@;  GPIO port output speed register,	Address offset:	0x08	      
.equ	PUPDR,	0x0C	@;  GPIO port pull-up/pull-down register,	Address offset:	0x0C	      
.equ	IDR,	0x10	@;  GPIO port input data register,	Address offset:	0x10	      
.equ	ODR,	0x14	@;  GPIO port output data register,	Address offset:	0x14	      
.equ	BSRR,	0x18	@;  GPIO port bit set/reset register,	Address offset:	0x18	      
.equ	LCKR,	0x1C	@;  GPIO port configuration lock register,	Address offset:	0x1C	      
.equ	AFRL,	0x20	@;  GPIO alternate function register low,	Address offset:	0x20
.equ	AFRH,	0x24	@;  GPIO alternate function register high,	Address offset:	0x24 

@; --- NVIC register array base addresses
.equ	NVIC_ISER,	0xE000E100	@; Interrupt Set-Enable Registers, NVIC_ISER0-NVIC_ISER15
.equ	NVIC_ICER,	0xE000E180	@; Interrupt Clear-Enable Registers, NVIC_ICER0-NVIC_ICER15
.equ	NVIC_ISPR,	0xE000E200	@; Interrupt Set-Pending Registers, NVIC_ISPR0-NVIC_ISPR15
.equ	NVIC_ICPR,	0xE000E280	@; Interrupt CLR-Pending Registers, NVIC_ICPR0-NVIC_ICPR15
.equ 	NVIC_IABR,	0xE000E300	@; Interrupt Active Bit Registers, NVIC_IABR0-NVIC_IABR15
.equ 	NVIC_IPR,	0xE000E400	@; Interrupt Priority Registers, NVIC_IPR0-NVIC_IPR123

.equ position,28		@;TIM2 location in table -- from manual Table 46 "STM32F76xxx and STM32F77xxx vector table"
.equ byteoffset,4		@;# of bytes from origin to the bit at 'position', for any of the NVIC bit-registers
.equ bitposition,5		@;position of enable/clear/active bit in byte at byteoffset, e.g. position=8*byteoffset+bitposition

@; --- TIM2 demo code
	.text						
	.align 2

	.global NVIC_set_TIM2_priority	@; general interrupt enable and priority setting					
	.thumb_func
NVIC_set_TIM2_priority:	@; 	called first, configures NVIC for all active interrupts
	push {r7,lr}
	
	@;set TIM2 interrupt priority mid-level (8)
	ldr r3,=NVIC_IPR	
	mov r2,#0x80			@;priority is in upper nybble
	strb r2,[r3,#position]	

	pop {r7,pc}

	.global NVIC_TIM2_IRQ_enable
	.thumb_func
NVIC_TIM2_IRQ_enable:		@;called _after_ clearing TIM2 interrupts set by configuration
	push {r7,lr}
	
	@;enable TIM2 in NVIC (will also need to be enable in TIM configuration)
	ldr r3,=NVIC_ISER	
	ldrb r2,[r3,#byteoffset]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]

	pop {r7,pc}

	.global NVIC_TIM2_IRQ_disable
	.thumb_func
NVIC_TIM2_IRQ_disable:
	push {r7,lr}
	
	@;enable TIM2 in NVIC (will also need to be enable in TIM configuration)
	ldr r3,=NVIC_ISER	
	ldrb r2,[r3,#byteoffset]
	bic r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]

	pop {r7,pc}
	
	

    @; functions to freeze/unfreeze TIM2; derived from macros in stm32f7xx_hal.h 
@; --- definitions for DBGMCU control of TIM2 (from STM32F767xx.h)
.equ    DBGMCU_BASE,    0xE0042000  @; Debug MCU registers base address 
.equ	APB1FZ,	0x08	@;	   __IO uint32_t APB1FZ;  /*!< Debug MCU APB1 freeze register,   Address offset: 0x08 */
.equ    DBGMCU_APB1_FZ_DBG_TIM2_STOP_Pos,  0x0   @;position of bit in APB1FZ; setting this bit will cause TIM2 to 'freeze' when CPU stops at breakpoints

	.global DBGMCU_FREEZE_TIM2
	.thumb_func
DBGMCU_FREEZE_TIM2:	@;freeze TIM2 when stopped in debug mode
	ldr r3,=DBGMCU_BASE @; ..
	ldr r2,[r3,#APB1FZ]	@; ..
    orr r2,#(1<<DBGMCU_APB1_FZ_DBG_TIM2_STOP_Pos) @; ..
	str r2,[r3,#APB1FZ]	@; ..    
    bx lr

	.global DBGMCU_UNFREEZE_TIM2
	.thumb_func
DBGMCU_UNFREEZE_TIM2:	@;unfreeze TIM2 in debug mode
	ldr r3,=DBGMCU_BASE @; ..
	ldr r2,[r3,#APB1FZ]	@; ..
    bic r2,#(1<<DBGMCU_APB1_FZ_DBG_TIM2_STOP_Pos) @; ..
	str r2,[r3,#APB1FZ]	@; ..    
    bx lr



    .global connect_TIM2_CH4_to_PA3
    .thumb_func
connect_TIM2_CH4_to_PA3: 
   push {r7,lr}

	@;(re-)enable GPIOA 
	ldr r3,=RCC_BASE		@;enable GPIOA
	ldr r2,[r3,#AHB1ENR]	@; ..
	orr	r2,r2,0x01			@; ..  (see manual page 181)
	str r2,[r3,#AHB1ENR]	@; ..

    @;configure PA3 for alternate function TIM2 CH4
    ldr r3,=GPIOA_BASE       @;select GPIOA for register operations

	@;put PA3 in alternate function mode
	ldr r2,[r3,#(MODER)]
    bic r2,#(3<<(2*3))	@;clear mode bits
	orr r2,#(2<<(2*3))	@;make alternate function
	str r2,[r3,#(MODER)]

	@;set PA3 output as push-pull
	ldr r2,[r3,#(OTYPER)]
    bic r2,#(1<<(1*3))		@;clear type bit
	str r2,[r3,#(OTYPER)]

	@;set PA3 as high-speed output
	ldr r2,[r3,#(OSPEEDR)]
    bic r2,#(3<<(2*3))		@;clear speed bits
	orr r2,#(2<<(2*3))		@;make high speed
	str r2,[r3,#(OSPEEDR)]

	@;no pullup/pulldown on PA3 
	ldr r2,[r3,#(PUPDR)]
    bic r2,#(3<<(2*3))		@;clear PUPD type bits
	str r2,[r3,#(PUPDR)]
	
	@;connect PA3 alternate function 1 (AFR1) -- TIM2 CH1
	ldr r2,[r3,#(AFRL)]
    bic r2,#(15<<(1*4))	@;clear alternate function bits
	orr r2,#(1<<(1*4))	@;make alternate function 1
	str r2,[r3,#(AFRL)]

	@;here with TIM2 CH4 output on PA3
	pop {r7,pc}



	.global TIM2_init
	.thumb_func
TIM2_init:	@;TIM2 initialized for PWM output (manual section 26.3.9)
    push {r7,lr}

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
	movw r2,#167			@; prescale 168mHz system clock by 168 (see manual page 987)	
	strh r2,[r3,#PSC]		@; ..

	@;set TIM2 counter reload value
	movw r2,#999			@; counter reloads at 999  (see manual page 987)	
	movt r2,#0				@; ..
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
	movw r2,#0x83				@; ..
	strh r2,[r3,#CR1]		@; done last, as counter starts immediately (see manual page 937)
	@;!! here with all CCxIF flags in SR =1 as a side effect of the above instruction

	@;clear TIM2 interrupts at startup
	mov r2, 0x0000			@; .. reset value 0x0000
	strh r2,[r3,#SR]		@; all interrupt and overflow flags all 0

	@; here with TIM2 running
	pop {r7,pc}

	.global TIM2_IRQHandler
	.thumb_func
TIM2_IRQHandler:
	push {r7,lr}			@;write as AAPCS so can be called as function for testing

	@;clear CC4 interrupt flag CC4IF
	ldr r3,=TIM2_BASE 		@; ..		
@;	ldr r3,=0x30000000
	ldr r2,[r3,#SR]			@; ..		
	bic r2,r2,#(1<<4)		@; ..
	str r2,[r3,#SR]			@; ..

	@;increment tick count
	ldr r3,=ticks500
	ldr r2,[r3]
	add r2,r2,#1
	str r2,[r3]	
	cmp r2,#500				@;is tick limit reached
	blo	1f					@;  no -- exit

	@;here when 500 interrupts have occurred
	mov r2,#0				@; restart tick counter
	str r2,[r3]				@; ..
	//bl toggle_PB0			@; blink the LED
	
1:	@;interrupt is done
	pop {r7,pc}
