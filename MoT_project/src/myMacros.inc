@;myMacros.inc wmh 2019-03-21 : recap of 2013's macros.inc

@;  - features
@;  - any register r0-r3 is valid as an argument 
@;	- no local pool 'out of range' (i.e. uses immediate values)
@;  - 

.equ R4R5PRESERVE,1		@; comment this out to save a push/pop in macros that use r4,r5 for scratch registers


.macro r4r5save
	.ifdef R4R5PRESERVE
	     push {r4,r5}
	.endif		 
.endm

.macro r4r5restore
	.ifdef R4R5PRESERVE
		pop {r4,r5}
	.endif
.endm

.macro MOV_imm32 reg constant		@;example of use: MOV_imm32 r0,0x12345678 !!note: don't use '#' on immediate value
	movw \reg, #:lower16:\constant
	movt \reg, #:upper16:\constant
.endm

.macro ORR_imm32 reg constant		@;'bit set' -- example of use: ORR_imm32 r0,0x12345678 !!note: don't use '#' on immediate value	
	r4r5save
	MOV_imm32 r4,\constant
	orr \reg,r4
	r4r5restore
.endm	

.macro BIC_imm32 reg constant		@;'bit clear' -- example of use: BIC_imm32 r0,0x12345678 !!note: don't use '#' on immediate value	
	r4r5save
	MOV_imm32 r4,\constant
	bic \reg,r4
	r4r5restore
.endm	

.macro SET_bit addr bitnum 		@;logical OR one bit at position 'bitnum' at 'addr' with 1 
	r4r5save
	MOV_imm32 r5,(\addr)
	ldr r4,[r5]
	orr r4,#(1<<\bitnum)
	str r4,[r5]	
	r4r5restore
.endm

.macro CLR_bit addr bitnum 		@;logical AND one bit at position 'bitnum' at 'addr' with 0 
	r4r5save
	MOV_imm32 r5,(\addr)
	ldr r4,[r5]
	bic r4,#(1<<\bitnum)
	str r4,[r5]	
	r4r5restore
.endm

.macro TST_bit addr bitnum 		@;logical AND one bit at position 'bitnum' at 'addr', update Z flag   
	r4r5save
	MOV_imm32 r5,(\addr)
	ldr r4,[r5]
	tst r4,#(1<<\bitnum)
	r4r5restore
.endm


.macro PORTBIT_read reg GPIOx_BASE bitnum	@;read 'bitnum' of port GPIOx, return bit value in bit0 of reg and 'Z' flag set/clear if bit=0/1
	r4r5save
	MOV_imm32 r5,(\GPIOx_BASE)
	ldr r4,[r5,#IDR]
	ands r4,#(1<<\bitnum)
	lsr r4,#\bitnum
	mov \reg,r4
	r4r5restore
.endm	

.macro PORTBIT_write GPIOx_BASE bitnum value	@;set 'bitnum' of port GPIOx to value {0,1}
	r4r5save
	MOV_imm32 r5,(\GPIOx_BASE)
	.ifeq \value	@;must write to upper 16 bits of BSSR to clear the bit
		mov r4,#( 1<<(16+\bitnum))
	.else			@;write to lower 16 bits of BSSR to set the bit
		mov r4,#( 1<<(\bitnum))
	.endif
	str r4,[r5,#BSRR]	
	r4r5restore
.endm

	
.equ STD_OUTPIN,0	@;port pin initialization code -- see macro 'PORTBIT_init'
.equ STD_INPIN,1	@; ""
.equ PULLUP_INPIN,2	@; ""

.macro PORTBIT_config bitnum, GPIOx_BASE, MODE, OTYPE, OSPEED, PUPD, AF
	r4r5save
	MOV_imm32 r5,(\GPIOx_BASE)

	ldr r4,[r5,#MODER]
	bic r4,(3 << (2*\bitnum))
	orr r4,(\MODE << (2*\bitnum)) 
	str r4,[r5,#MODER]

	ldr r4,[r5,#OTYPER]
	bic r4,(1 << \bitnum)
	orr r4,(\OTYPE << (1*\bitnum)) 
	str r4,[r5,#OTYPER]
	
	ldr r4,[r5,#OSPEEDR]
	bic r4,(3 << (2*\bitnum))
	orr r4,(\OSPEED << (2*\bitnum))
	str r4,[r5,#OSPEEDR]
                
	ldr r4,[r5,#PUPDR]
	bic r4,(3 << (2*\bitnum))
	orr r4,(\PUPD << (2*\bitnum))	
	str r4,[r5,#PUPDR]

	.iflt (\bitnum - 8) @;use AFRLR for configuration
		ldr r4,[r5,#AFRL]
		bic r4,(0xF << (4*\bitnum))
		orr r4,(\AF << (4*\bitnum))	
		str r4,[r5,#AFRL]

	.else @;use AFRH for configuration
		ldr r4,[r5,#AFRH]
		bic r4,(0xF << (4*(\bitnum-8)))
		orr r4,(\AF << (4*(\bitnum-8)))	
		str r4,[r5,#AFRH]
	.endif
	r4r5restore
.endm
