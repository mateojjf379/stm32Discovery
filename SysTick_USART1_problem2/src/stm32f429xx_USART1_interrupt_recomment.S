@; stm32f429xx_USART1_interrupt.S wmh 2019-03-05 : interrupt added to USART1 functions
@; stm32f429xx_USART1_9600N81.S wmh 2018-10-23 : USART1 functions for STM32F429 DISC1 board
/* from libUSART1_AC6gcc_nodebug.a
	void initUSART1(void); 				//initialize USART1 for asynchronous 9600N81 communication
	int nbUSART1_getchar(void);			//success: return data>=0; failure: return -1
	int nbUSART1_putchar(char c);		//success: return +1; failure: return -1
	int bUSART1_getchar(void);			//blocks until new data, then return data
	void bUSART1_putchar(char c);		//block until character can be sent
	void USART1_writeDR(char c);		//debug: unconditional write to USART3 DR and return
   from below
	void USART1_IRQinit(void);			//sets up USART1 interrupt and enables receive interrupt

*/

/* from DU0553A: !!
Ensure software uses correctly aligned register accesses. The processor does not support
unaligned accesses to NVIC registers. See the individual register descriptions for the supported
access sizes.
Interrupt priority registers are stated to be byte-accessible, and nothing is mentioned about the others, 
so assume they must be accessed on word boundaries. 
*/

	@; --- characterize target syntax, processor
	.syntax unified				@; ARM Unified Assembler Language (UAL). 
	.thumb						@; Use thumb instructions only

@; STM32F429xx register boundary addresses RM0090rev17_
.equ USART1_BASE,0x40011000		@; 0x40011000-0x400113FF is boundary address for USART1
.equ BUFF_SIZE, 20
.equ read,0x00
.equ write,0x01
.equ start_write,0x02
.equ data,0x03

@; offsets to USART registers extracted from USART_TypeDef in stm32f429xx.h 
.equ	SR,0x00         @; USART Status register,                   Address offset: 0x00 */
.equ	DR,0x04         @; USART Data register,                     Address offset: 0x04 */
.equ	BRR,0x08        @; USART Baud rate register,                Address offset: 0x08 */
.equ	CR1,0x0C        @; USART Control register 1,                Address offset: 0x0C */
.equ	CR2,0x10        @; USART Control register 2,                Address offset: 0x10 */
.equ	CR3,0x14        @; USART Control register 3,                Address offset: 0x14 */
.equ	GTPR,0x18       @; USART Guard time and prescaler register, Address offset: 0x18 */

@; --- NVIC register array base addresses
.equ	NVIC_ISER,	0xE000E100	@; Interrupt Set-Enable Registers, NVIC_ISER0-NVIC_ISER15
.equ	NVIC_ICER,	0xE000E180	@; Interrupt Clear-Enable Registers, NVIC_ICER0-NVIC_ICER15
.equ	NVIC_ISPR,	0xE000E200	@; Interrupt Set-Pending Registers, NVIC_ISPR0-NVIC_ISPR15
.equ	NVIC_ICPR,	0xE000E280	@; Interrupt CLR-Pending Registers, NVIC_ICPR0-NVIC_ICPR15
.equ 	NVIC_IABR,	0xE000E300	@; Interrupt Active Bit Registers, NVIC_IABR0-NVIC_IABR15
.equ 	NVIC_IPR,	0xE000E400	@; Interrupt Priority Registers, NVIC_IPR0-NVIC_IPR123

@; --- global data memory
	.data
	.align 2
	.global USART1_txdata,USART1_txcount @;make visible in debugger?
USART1_txdata: .word 0					@;for basic testing
USART1_txcount:.word 0

@; --- begin code memory
	.text								@;start the code section

	.global USART1_IRQHandler			@;using label from interrupt table
	.thumb_func
USART1_IRQHandler: @; initial test for USART1_interrupt_enab
	push {r7,lr}	@;even though we're an interrupt, we're not a leaf function, so must do this
	@;read flags to determine source of interrupt
	ldr r3,=USART1_BASE
	ldrh r2,[r3,#SR]
	tst r2,#(0x0A)						@;check if Overrunn error (ORE) set and Framing error(FE) set
	bne USART1_IRQHandler_error_trap	@;if ORE or FE are present, then go to the error_trap
	tst r2,#(1<<5)	@;testing RXNE		@;test if received data is ready to be read
	beq end_hand		@;if data is not ready to be read, then go to noRXdata

	@; puts data from data reg into txtdata. And sets counter to five
	ldrh r0,[r3,#DR]					@;loads the USART1 data register into r0
	ldr r1,=buffer						@;loads address of buffer into r1
	@;checks if char is return key. If it is, then set the start_write bit and leave	```
	cmp r0, 0xd
	ittt eq
	moveq r2, #1
	strbeq r2, [r1,#start_write]
	beq end_hand

	mov r2, #(BUFF_SIZE-1)
	ldrb r3, [r1,#read]
	ldrb r4, [r1,#write]

	add r5, r1, #3
	add r5, r5, r3
	strb r0, [r5]				@;stores char into array at read location
	cmp r3, r2					@;adds one to read pointer. goes back to zero if its on max position
	ite	eq
	moveq r3, #0
	addne r3, r3, #1
	strb r3, [r1, #read]

	cmp r4, r3
	it eq
	addeq r4, #1
	cmp r4, r2
	it gt
	movgt r4, #0
	strb r4, [r1, #write]

end_hand:
	@;bl USART1_TXint_enab				@;call TXint_enab
	pop {r7,pc}

USART1_IRQHandler_noRXdata:  @;here with image of SR in r2 and source of interrupt is still unknown
	tst r2,#(1<<7)						@;checks if TXE bit is 1, (transmit data register empty)
	beq USART1_IRQHandler_unknown_trap	@;if TXE is not set, go to unknow_trap
	
	@; here because TXE flag is set
	ldr r1,=USART1_txcount
	ldr r0,[r1]							@;loads whatever is in USART1_txcount, if r0 is not zero go to USART1_IRQHandler_moreTXdata
	cbnz r0,USART1_IRQHandler_moreTXdata

	@; here with no more data to send
	bl USART1_TXint_inhib				@;if r0 = 0, or count = 0, then set TXE to 0

	@;here with nothing more to do in this interrupt
	pop {r7,pc}	
	
USART1_IRQHandler_moreTXdata: @; here with data still left to send 
	@;update remaining count (r0,r1 still valid after branch from 'cbnz r0,USART1_IRQHandler_moreTXdata' sbove
	subs r0,#1
	str r0,[r1]
	
	@;send another copy of the data
	ldr r1,=USART1_txdata
	ldr r0,[r1]
	bl nbUSART1_putchar
	
	@;check for return value = -1 (character wasn't sent)
	adds r0,#1
	cbz r0, USART1_IRQHandler_putchar_failure_trap
	
	@;here with another copy of the USART1_txdata character sent
	pop {r7,pc}	
	
USART1_IRQHandler_error_trap:
	b .
USART1_IRQHandler_unknown_trap:
	b .
USART1_IRQHandler_putchar_failure_trap:
	b .
	
	
 @ --- USART1 interrupt initialization and control functions
	
	.equ USART1_NVICposition,37 	@;USART1's 'position' in vector table from RM0090 Table 62. Vector table for STM32F42xxx and STM32F43xx
	.equ USART1_NVICwordoffset,1	@;# of words from origin to word holding bit 'position', for any of the NVIC bit-registers
	.equ USART1_NVICbyteoffset,4	@;# of bytes from origin to byte holding priority for any of the NVIC priority registes

	.global USART1_IRQinit 	@;sets up USART1 interrupt and enables RX interrupt
    .thumb_func
USART1_IRQinit: 
	push {r7,lr}
	
	CPSID i	
	
	@;NVIC: make sure USART1 interrupt enable is off in NVIC before changing things
	ldr r3,=(NVIC_ICER+4*USART1_NVICwordoffset)	
	mov r2,#(1<<(USART1_NVICposition-32*USART1_NVICwordoffset))
	str r2,[r3]

	@;USART: begin update of USART1 configuration
	ldr r3,=USART1_BASE

	@;USART: turn off USART1 error-interrupt enables
	ldrh r2,[r3,#CR3]
	bic r2,#(1<<0)						@;disables EIE (error interrupt enable)
	strh r2,[r3,#CR3]

	@;USART: clear any error flags that might currently be on using the magic sequence (see RM0090 Status register (USART_SR) description) 
	ldrh r2,[r3,#SR]
	ldrh r2,[r3,#DR]	@;will also clear RXNE if its set

	@;NVIC: set USART1 interrupt priority to next-to-highest (=1)
	ldr r3,=NVIC_IPR	
	mov r2,#0x10						@;sets bit 5 to 1 in register 2
	strb r2,[r3,#USART1_NVICposition]	@;sets the position 37 to the contents of r2, this way sets USART1 interrupt priority

	@;NVIC: clear USART1 pending interrupt in NVIC in case something got through previously
	ldr r3,=(NVIC_ICPR+4*USART1_NVICwordoffset)	
	mov r2,#(1<<(USART1_NVICposition-32*USART1_NVICwordoffset))
	str r2,[r3]

	@;NVIC: enable USART1 interrupt
	ldr r3,=(NVIC_ISER+4*USART1_NVICwordoffset)	
	mov r2,#(1<<(USART1_NVICposition-32*USART1_NVICwordoffset))
	str r2,[r3]

	@;USART: resume update of USART1 configuration
	ldr r3,=USART1_BASE
	
	@;USART: enable USART1 RX interrupt
	ldrh r2,[r3,#CR1]
	orr r2,#( (1<<5) ) 					@; enables bit 5 in CR1 which is RXNEIE
	strh r2,[r3,#CR1]

	CPSIE i								@; change procesor state, interrupt enable

	@;here with USART1 interrupt configured and RX interrupt enabled
	pop {r7,pc}

	
    .global USART1_TXint_enab 	@;enables TX interrupt assuming USART1_IRQinit() previous called
    .thumb_func
USART1_TXint_enab: 
	ldrh r2,[r3,#CR1]
	orr r2,#( (1<<7) ) 					@;manually enables TXE interrupt enable, then TXE will be enabled too
	strh r2,[r3,#CR1]
	bx lr

    .global USART1_TXint_inhib 	@;inhibits TX interrupt assuming USART1_IRQinit() previous called
    .thumb_func
USART1_TXint_inhib: 
	ldrh r2,[r3,#CR1]
	bic r2,#( (1<<7) ) 					@;disables TXEIE from CR1, so TXE will be disabled too.
	strh r2,[r3,#CR1]
	bx lr

