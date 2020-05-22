
@; --- characterize target syntax, processor
	.syntax unified				@; ARM Unified Assembler Language (UAL). 
								@; Code written using UAL can be assembled 
								@; for ARM, Thumb-2, or pre-Thumb-2 Thumb
	.thumb						@; but here we'll use thumb instructions only


	.macro MOV_imm32 reg, constant
		movw \reg, #:lower16:\constant
		movt \reg, #:upper16:\constant
	.endm
	.macro SET_bit reg_addr, offset, bit_num
		push {r0-r1}			@;preserve registers for unwary macro users
		ldr r1, [\reg_addr, \offset]
		orr r1, r1, #(0x01<<\bit_num)
		str r1, [\reg_addr, \offset]
		pop {r0-r1}				@;restore registers
	.endm
	.macro CHECK_bit reg_addr, offset, bit_num
		push {r1}
		ldr r1, [\reg_addr, \offset]
		ands r1, r1, #(0x01<<\bit_num)
		cmp r1, #(0x01<<\bit_num)
		ite eq
		moveq r0, #1
		movne r0, #0
		pop {r1}
	.endm

	.equ BUFF_SIZE, 256
	.equ read,0x00

@; initial addresses
	.equ RCC_base, 0x40023800
	.equ FLASH_ACR, 0x40023c00
	.equ ADC, 0x40012000
	.equ ADC3_offset, 0x200
	.equ ADC3, (ADC + ADC3_offset)
	.equ DAC_base, 0x40007400
	.equ GPIOC_base, 0x40020800
	.equ GPIOA_base, 0x40020000

@; DAC registers
	.equ DAC_CR, 0x00
	.equ DAC_SWTRIGR, 0x04

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

@; offsets if registers for ADC
	.equ ADC_CCR, (ADC + 0x304)
	.equ ADC_SR, 0x00
	.equ ADC_CR1, 0x04
	.equ ADC_CR2, 0x08
	.equ ADC_SMPR1, 0x0c
	.equ ADC_SMPR2, 0x10
	.equ ADC_SQR1, 0x2c
	.equ ADC_SQR2, 0x30
	.equ ADC_SQR3, 0x34
	.equ ADC_DR, 0x4c
@; --- offsets of registers for RCC
	.equ RCC_CR, 0x00
	.equ RCC_PLLCFGR, 0x04
	.equ RCC_CFGR, 0x08
	.equ RCC_CIR, 0x0C
	.equ RCC_AHB1RSTR, 0x10
	.equ RCC_AHB2RSTR, 0x14
	.equ RCC_AHB3RSTR, 0x18
	.equ RCC_APB1RSTR, 0x20
	.equ RCC_APB2RSTR, 0x24
	.equ RCC_AHB1ENR, 0x30
	.equ RCC_AHB2ENR, 0x34
	.equ RCC_AHB3ENR, 0x38
	.equ RCC_APB1ENR, 0x40
	.equ RCC_APB2ENR, 0x44
	.equ RCC_AHB1LPENR, 0x50
	.equ RCC_AHB2LPENR, 0x54
	.equ RCC_AHB3LPENR, 0x58
	.equ RCC_APB1LPENR, 0x60
	.equ RCC_APB2LPENR, 0x64
	.equ RCC_BDCR, 0x70
	.equ RCC_CSR, 0x74
	.equ RCC_SSCGER, 0x80
	.equ RCC_PLLI2SCFGR, 0x84
@; reset values
	.equ CR_reset, 0x00000083
	.equ PLLCFGR_reset, 0x24003010
	.equ CFGR_reset, 0x00000000
@; --- NVIC register array base addresses
	.equ	NVIC_ISER,	0xE000E100	@; Interrupt Set-Enable Registers, NVIC_ISER0-NVIC_ISER15
	.equ	NVIC_ICER,	0xE000E180	@; Interrupt Clear-Enable Registers, NVIC_ICER0-NVIC_ICER15
	.equ	NVIC_ISPR,	0xE000E200	@; Interrupt Set-Pending Registers, NVIC_ISPR0-NVIC_ISPR15
	.equ	NVIC_ICPR,	0xE000E280	@; Interrupt CLR-Pending Registers, NVIC_ICPR0-NVIC_ICPR15
	.equ 	NVIC_IABR,	0xE000E300	@; Interrupt Active Bit Registers, NVIC_IABR0-NVIC_IABR15
	.equ 	NVIC_IPR,	0xE000E400	@; Interrupt Priority Registers, NVIC_IPR0-NVIC_IPR123

	.equ position,18		@;ADC3 location in table -- from manual Table 46 "STM32F76xxx and STM32F77xxx vector table"
	.equ byteoffset,0x2		@;# of bytes from origin to the bit at 'position', for any of the NVIC bit-registers
	.equ bitposition,2		@;position of enable/clear/active bit in byte at byteoffset, e.g. position=8*byteoffset+bitposition


	.text
	.align 2

	.global NVIC_set_ADC3_priority	@; general interrupt enable and priority setting
	.thumb_func
NVIC_set_ADC3_priority:	@; 	called first, configures NVIC for all active interrupts
	push {r7,lr}

	@;set ADC3 interrupt priority mid-level (8)
	ldr r3,=NVIC_IPR
	mov r2,#0x80			@;priority is in upper nybble
	strb r2,[r3,#(0x04*4+2)]
	ldr r2,[r3,#(0x04*4)]
	pop {r7,pc}

	.global NVIC_ADC3_IRQ_enable
	.thumb_func
NVIC_ADC3_IRQ_enable:		@;called _after_ clearing adc3 interrupts set by configuration
	push {r7,lr}

	@;enable ADC3 in NVIC (will also need to be enable in ADC configuration)
	ldr r3,=NVIC_ISER
	ldrb r2,[r3,#(byteoffset)]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#(byteoffset)]
	ldr r2,[r3]

	pop {r7,pc}

	.global NVIC_ADC3_IRQ_disable
	.thumb_func
NVIC_ADC3_IRQ_disable:
	push {r7,lr}

	@;enable TIM2 in NVIC (will also need to be enable in TIM configuration)
	ldr r3,=NVIC_ISER
	ldrb r2,[r3,#(byteoffset)]
	bic r2,#(1<<bitposition)
	strb r2,[r3,#(byteoffset)]

	pop {r7,pc}

	.global PC3_enable
	.thumb_func
PC3_enable:
	push {r7,lr}

	@;(re-)enable GPIOC
	ldr r3,=RCC_base			@;enable GPIOC
	ldr r2,[r3,#RCC_AHB1ENR]	@; ..
	orr	r2,r2,0x04				@; ..
	str r2,[r3,#RCC_AHB1ENR]	@; ..

	@;configure PC3
    ldr r3,=GPIOC_base       @;select GPIOC for register operations

	@;put PC3 in analog mode
	ldr r2,[r3,#(MODER)]
    bic r2,#(3<<(2*3))		@;clear mode bits
	orr r2,#(3<<(2*3))		@;make analog function
	str r2,[r3,#(MODER)]

	@;set PC3 as high-speed output
	ldr r2,[r3,#(OSPEEDR)]
    bic r2,#(3<<(2*3))		@;clear speed bits
	orr r2,#(2<<(2*3))		@;make high speed
	str r2,[r3,#(OSPEEDR)]

	@;here PC3 enabled
	pop {r7,pc}

	.global PA5_enable
	.thumb_func
PA5_enable:
	push {r7,lr}

	@;(re-)enable GPIOA
	ldr r3,=RCC_base		@;enable GPIOA
	ldr r2,[r3,#RCC_AHB1ENR]	@; ..
	orr	r2,r2,0x01			@; ..
	str r2,[r3,#RCC_AHB1ENR]	@; ..

	@;configure PA5
    ldr r3,=GPIOA_base       @;select GPIOC for register operations

	@;put PA5 in analog mode
	ldr r2,[r3,#(MODER)]
    bic r2,#(3<<(2*5))		@;clear mode bits
	orr r2,#(3<<(2*5))		@;make analog function
	str r2,[r3,#(MODER)]

	@;set PA5 as high-speed output
	ldr r2,[r3,#(OSPEEDR)]
    bic r2,#(3<<(2*5))		@;clear speed bits
	orr r2,#(2<<(2*5))		@;make high speed
	str r2,[r3,#(OSPEEDR)]

	@;here PA5 enabled
	pop {r7,pc}

	.global DAC_enable
	.thumb_func
DAC_enable:
	push {r7,lr}

	@;setting MAMP2, WAVE2, TSEL2, TEN2
	ldr r3,=DAC_base
	ldrh r2,[r3,#(DAC_CR+0x2)]
	orr r2,#(1<<8)			@;MAMP2
	orr r2,#(0xB<<6)		@;WAVE2
	orr r2,#(7<<3)			@;TSEL2
	strh r2,[r3,#(DAC_CR+0x2)]

	@;enable DAC2
	ldr r2,[r3,#(DAC_CR)]
	orr r2,#(1<<16)
	str r2,[r3,#(DAC_CR)]

	@;starting the wave generation
	ldr r2,[r3,#(DAC_SWTRIGR)]
	orr r2,#1
	str r2,[r3,#(DAC_SWTRIGR)]

	@;DAC2 shoould be generating triagular waveform to PA5
	pop {r7,pc}

	.text
	.global myADC3_TIM2_PC3
	.thumb_func
myADC3_TIM2_PC3:
	push {r7,lr}
	
	@;enable ADC3 clock
	ldr r3,=RCC_base
	ldr r2,[r3,#(RCC_APB2ENR)]
	orr r2,#(1<<10)
	str r2,[r3,#(RCC_APB2ENR)]

	@;set ADC prescaler
	ldr r3,=ADC_CCR
	ldrh r2,[r3,#0x02]
	orr r2,#(3)
	strh r2,[r3,#0x02]

	@;enable ADC with ADON
	ldr r3,=ADC3
	ldr r2,[r3,#(ADC_CR2)]
	orr r2,#(1)
	str r2,[r3,#(ADC_CR2)]

	@;enable interrupt (for EOC)
	ldr r3,=ADC3
	ldr r2,[r3,#(ADC_CR1)]
	orr r2,#(1<<5)
	str r2,[r3,#(ADC_CR1)]

	@;enable PC3 as channel to read from
	ldr r2,[r3,#(ADC_SQR3)]
	orr r2,#(0xD)
	str r2,[r3,#(ADC_SQR3)]

	@;start conversion
	ldr r3,=ADC3
	ldr r2,[r3,#(ADC_CR2)]
	orr r2,#(0x15<<24)
	str r2,[r3,#(ADC_CR2)]


myADC3_TIM2_PC3_Done:
	pop {r7,pc}						@;keyword '.text' starts the code section (in ROM)


	.global ADC_check
	.thumb_func
ADC_check:
	push {r7,lr}

	mov r0,#(-1)
	ldr r3,=ADC3
	ldr r2,[r3,#(ADC_SR)]
	cmp r2,#0
	it eq
	beq end_ADC_check
	bic r2,r2,#(1<<1)
	str r2,[r3,#(ADC_SR)]

	ldr r2,[r3,#(ADC_DR)]
	mov r0,r2

end_ADC_check:
	pop {r7,pc}

	.global ADC_IRQHandler
	.thumb_func
ADC_IRQHandler:
	push {r7,lr}			@;write as AAPCS so can be called as function for testing

	@;clear EOC interrupt flag
	ldr r3,=ADC3			@; ..
	ldr r2,[r3,#(ADC_SR)]		@; ..
	bic r2,r2,#(1<<1)		@; ..
	str r2,[r3,#(ADC_SR)]		@; ..

	ldr r2,[r3,#(ADC_DR)]

	@;write to buffer
	ldr r1, =buffer
	ldrb r3, [r1,#read]
	adds r5, r1, #1
	adds r5, r5, r3
	strh r2, [r5]				@;stores half word into array at read location
	mov r2, #(BUFF_SIZE-1)
	cmp r3, r2					@;adds one to read pointer. goes back to zero if its on max position
	ite	eq
	moveq r3, #0
	addne r3, r3, #2
	strb r3, [r1, #read]

1:	@;interrupt is done
	pop {r7,pc}
