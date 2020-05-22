@;myDataOps02.S wmh 2017-09-09 : demo pseudo-op  'ldr r0,=Dword' 
@;myDataOps01.S wmh 2017-09-04 : ARM data instruction examples

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

@; initial addresses
	.equ RCC_base, 0x40023800
	.equ FLASH_ACR, 0x40023c00
@; --- ofsets of registers for RCC
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

	.text
	.global SetSysClk
	.thumb_func
SetSysClk:
	push {r7,lr}

	MOV_imm32 r3,RCC_base			@;r3 will remain as RCC register array base throughout the following
	@;resets CR, PLLCFGR, and CFGR
	MOV_imm32 r0,CR_reset
	str r0, [r3, #RCC_CR]
	MOV_imm32 r0, PLLCFGR_reset
	str r0, [r3, #RCC_PLLCFGR]
	MOV_imm32 r0,CFGR_reset
	str r0, [r3, #RCC_CFGR]
	@;ready for a fresh start

	SET_bit r3, #RCC_CR, 16 @; starts HSE oscilator
	//CHECK_bit r3, #RCC_CR, 17
	//cbz r0, HSE_no_start	@;clock initialization has failed

2:	@;here if HSE oscillator has started --

	SET_bit r3, #RCC_PLLCFGR, 22 	@; sets source of PLL as HSE
	ldr r0,[r3,#RCC_PLLCFGR]
	bic r0, r0, #(0x7F00)			@; cleans certain bits
	bic r0, r0, #(0xFF)
	@;PLLP is set to 00, no need to set it
	orr r0, r0, #(0x150<<6)			@;PLLN configuration
	orr r0, r0, #(0x1A)				@;PLLM configuration
	str r0,[r3,#RCC_PLLCFGR]		@;updating PLL bits

	ldr r0,[r3,#RCC_CFGR]
	bic r0, r0, #(0xFC00)
	orr r0, r0, #(4<<13)			@;setting APB2
	orr r0, r0, #(5<<10)			@;setting APB1
	str r0,[r3,#RCC_CFGR]			@;updating CFGR

	@;prefetch enable, instruction cache enable,  data cache enable; wait states = 5
	MOV_imm32 r1,0x00000705
	MOV_imm32 r2,FLASH_ACR
	ldr r0,[r2]
	orr r0,r1
	str r0,[r2]

	SET_bit r3, #RCC_CR, 24			@;setting PLL on
	//ldr r0,[r3,#RCC_CR]
	//ands r1, r0, #(0x1<<25)
	//cbz r1, PLL_no_start			@;checking if PLL is ready

	ldr r0,[r3,#RCC_CFGR]			@;setting PLL as system clock (10 in SW)
	orr r0, #0x02
	str r0,[r3,#RCC_CFGR]

1:	ldr r0,[r3,#RCC_CFGR]			@;checking if SW and SWS are the same
	ands r1, r0, #(0x03)
	ands r2, r0, #(0x03<<2)
	cmp r1, r2,LSR #2
	beq SetSysClock_Done
	b 1b
	@;here when timeout occurred before clocks good
PLL_no_start:
	b .

HSE_no_start: @;trap here if HSE does not start
	b .
	
SetSysClock_Done:
pop {r7,pc}						@;keyword '.text' starts the code section (in ROM)
