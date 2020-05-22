@; myESP8266_USART3_interrupt01.S wmh 2019-03-31 : revised stm32f429xx_USART3_interrupt02.S for use with runAtcmd functions in myESP8266_runAtCmd01.c
@; USART3_IRQHandler(), USART3_IRQinit(), USART3_TXint_enab(), USART3_TXint_inhibit(), USART3_RXint_enab(), USART3_RXint_inhibit()
@; adds features to update timeout deadline; 
@; TODO: compare received data in this interrupt rather than in runAtcmd_status(), which is part of a task, e.g. runs too often so very time consuming.
@;
@; stm32f429xx_USART3_interrupt02.S wmh 2019-03-24 : adaptation of stm32f429xx_USART1_interrupt02.S  for USART3
@; see '^^' markers at paremeters requiring modification to reflect different USART
@; stm32f429xx_USART1_interrupt02.S wmh 2019-03-1? : sets up hardware, initializes and connects to ringbuffer
@; stm32f429xx_USART1_interrupt01.S wmh 2019-03-10 : connecting to ringbuffer -- changing ringbuffer pointer initialization in USART1_IRQinit
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

.macro MOV_imm32 reg constant		@;example of use: MOV_imm32 r0,0x12345678 !!note: don't use '#' on immediate value
	movw \reg, #:lower16:\constant
	movt \reg, #:upper16:\constant
.endm


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
.equ USART3_BASE,0x40004800		@;^^ change for different USART
  
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

@; --- USART3 offsets in NVIC	
.equ USART3_NVICposition,39 	@;^^ change for different USART -- USART3's 'position' in vector table from RM0090 Table 62. Vector table for STM32F42xxx and STM32F43xx
.equ USART3_NVICwordoffset,1	@;^^ change for different USART -- USART word-offset from origin to word holding bit 'position', for any of the NVIC bit-registers
.equ USART3_NVICbyteoffset,4	@;^^ change for different USART -- byte-offset from origin to byte holding priority for any of the NVIC priority registes

@; --- USART3 data
	.equ ESP8266_BUFFER_SIZE,1500
	.equ ESP8266_BUFFER_IDX,-4	@; offset from buffer origin to location of idx
	
	.equ TOKENEND,3				@;!!FIXME phony value used just to get this to assemble
	
@; --- global data memory
	.data
	.align 2
	.global USART3_txdata,USART3_txcount @;makes visible in debugger?
/*
USART3_txdata: 		.word 0		 	@;for basic testing
USART3_txcount:		.word 0			@; ""
USART3_RxBuffer:	.word 0			@;will hold address of RxBuffer 
*/
@; --- begin code memory
	.text								@;start the code section

	.global USART3_IRQHandler			@;using label from interrupt table
	.thumb_func
USART3_IRQHandler: @; 
	push {r7,lr} 
	@; get structure pointers
	ldr r3,=USART3_BASE					@; USART3 register structure
	@;read flags to determine source of interrupt		
	ldrh r1,[r3,#SR]					@;USART status in r1
	tst r1,#(0x0A)						@;framing or overrun error?
	bne USART3_IRQHandler_error_trap	@;	yes -- 
	tst r1,#(1<<5)	@;testing RXNE		@;new RX data?
	beq USART3_IRQHandler_notRX 		@;	no --
	@;here if a new character has been received
	@;update the timeout limit
	ldr r2,=SysTick_msecs				@;get the current time
	ldr r2,[r2]							@;  in r2
	ldr r1,=runAtCmd_Timeoutdelay		@;get the timeout increment
	ldr r0,[r1]							@;	in r0
	add r0,r0,r2						@;the new timeout value is in r0
	ldr r1,=runAtCmd_Timeoutlimit		@;update the timeout limit
	str r0,[r1]							@; ..
	@;check for buffer overflow
	ldr r2,=ESP8266_RxBuffer			@;get buffer handle	
	ldr r1,[r2,#-4]						@;get buffer index 
	MOV_imm32 r0,ESP8266_BUFFER_SIZE	@; and max index value
	cmp r0,r1							@;buffer full?
	beq USART3_IRQHandler_rx_overflow	@;  yes -- abort saving the character and return to caller
	@;save the new character to the buffer
	ldrh r0,[r3,#DR]					@;read new RX data value
	strb r0,[r2,r1]						@;save new value in buffer
	adds r1,#1							@;update index
	str r1,[r2,#-4]						@; ..
	@;here with r2=&buffer; r1= index; r0,r3 available: check if buffer contains token
	@;is index >= sizeof(token)?
@;	MOV_imm32 r3,runAtcmd_ctl			@;
@;	ldr r0,[r3,#TOKENEND]				@;r0 points to '\0' at end of token string
	pop {r7,pc}							@;  and return from interrupt

USART3_IRQHandler_notRX:	 @;here for TX or error interrupt
	@;structure pointer in r3 and status in r1 are still valid
	tst r1,#(1<<7)	@;testing TXE
	beq USART3_IRQHandler_unknown_trap	@;'good' interrupts have been eliminated
	@; here when TXE flag is set and interrupt is not due to a received character
	ldr r2,=runAtCmd_cmdptr;			@;get command pointer
	ldr r1,[r2]							@;  in r1
	ldrb r0,[r1]						@read the next byte of cmd string
	cmp r0,#0							@;are we at then end of the command string?
	strb r0,[r3,#DR]					@; send the '\0'
	beq	USART3_IRQHandler_TX_done		@;	and then go turn things off
	@;here afer sending the next character of the command (but not finishd)
	adds r1,#1							@; update cmd ptr
	str r1,[r2]							@;  save it back
	pop {r7,pc}							@;    and return from interrupt

USART3_IRQHandler_TX_done:	@;here when the cmd string '\0' terminator was reached
	ldrh r1,[r3,#CR1]					@; disable transmit interrupt
	bic r1,#( (1<<7) ) @; TXEIE=bit7	@; ..
	strh r1,[r3,#CR1]					@; .. 
	pop {r7,pc}							@;    and return from interrupt

USART3_IRQHandler_rx_overflow:			@;skips reading or storing received character
	pop {r7,pc}							@;   overflow condition will be detected in runAtcmd_status()
	
USART3_IRQHandler_error_trap:			@;trap overrun, etc for now; !!TODO put branch to recovery procedure here
	b .

	USART3_IRQHandler_unknown_trap:
	pop {r7,pc}							@;!!TODO fix this kludge-for-debugging why we got an interrupt without any flags set. !!?? maybe because the NVIC pending flag is set?
	b .
	
 @ --- USART3 interrupt initialization functions

	.global USART3_IRQinit 	@;void USART3_IRQinit(); //sets up USART3 interrupt
    .thumb_func
USART3_IRQinit: @; initialize interrupt hardware in USART3 and NVIC but don't turn interrupts on

	push {r7,lr}
	
	@;turn off all interrupts
	CPSID i	
	
//	@;save handle, initialize ring buffer
//	ldr r3,=USART1_bufHANDLE
//	str r0,[r3]
//	bl ringbuf_init

//	@;save handle, initialize ring buffer
//	add r0,#16					//adjustment gives address of buffer 'handle' in r0
//	sub r1,#16					//adjustment gives buffer's MAXDATA data size out the remaining allocation
//	ldr r3,=USART3_rxbufHANDLE	//save handle against future need
//	str r0,[r3]					// ..
//	bl ringbuf_init				//initialize ringbuffer control and status: ringbuf_init(void *bufHANDLE, uint8_t buffersize);
	
	@;NVIC: make sure USART3 interrupt enable is off in NVIC before changing things
	ldr r3,=(NVIC_ICER+4*USART3_NVICwordoffset)	
	mov r2,#(1<<(USART3_NVICposition-32*USART3_NVICwordoffset))
	str r2,[r3]

	@;USART: begin update of USART3 configuration
	ldr r3,=USART3_BASE

	@;USART: turn off USART3 error-interrupt enables
	ldrh r2,[r3,#CR3]
	bic r2,#(1<<0)	@;clearing EIE (enables fault-interrupts if DMAR is also on -- see RM0090 Figure 320. USART interrupt mapping diagram)
	strh r2,[r3,#CR3]

	@;USART: clear any error flags that might currently be on using the magic sequence (see RM0090 Status register (USART_SR) description) 
	ldrh r2,[r3,#SR]
	ldrh r2,[r3,#DR]	@;will also clear RXNE if its set

	@;NVIC: set USART3 interrupt priority to high
	ldr r3,=NVIC_IPR	
	mov r2,#0x20						@;priority is in upper nybble of byte
	strb r2,[r3,#USART3_NVICposition]	@; byte access is allowed for priority	

	@;NVIC: clear USART3 pending interrupt in NVIC in case something got through previously
	ldr r3,=(NVIC_ICPR+4*USART3_NVICwordoffset)	
	mov r2,#(1<<(USART3_NVICposition-32*USART3_NVICwordoffset)) //!!check this
	str r2,[r3]	//was observed storing 0x20 at 0xe000e284; 

	@;NVIC: enable USART3 interrupt
	ldr r3,=(NVIC_ISER+4*USART3_NVICwordoffset)	
	mov r2,#(1<<(USART3_NVICposition-32*USART3_NVICwordoffset))
	str r2,[r3] //observed storing 0x20 at 0xe000e104

//	@;USART: resume update of USART3 configuration
//	ldr r3,=USART3_BASE
	
//	@;USART: enable USART3 RX interrupt
//	ldrh r2,[r3,#CR1]
//	orr r2,#( (1<<5) ) @; RXNEIE=bit5
//	strh r2,[r3,#CR1]

	@;turn interrupts back on
	CPSIE i

	@;here with USART3 interrupt configured and RX interrupt enabled
	pop {r7,pc}

	
    .global USART3_TXint_enab 	@;enables TX interrupt assuming USART3_IRQinit() previously called
    .thumb_func
USART3_TXint_enab: 
	ldr r3,=USART3_BASE
	@; enable TX interrupt 
	ldrh r2,[r3,#CR1]
	orr r2,#( (1<<7) ) @; TXEIE
	strh r2,[r3,#CR1]
	bx lr

    .global USART3_TXint_inhib 	@; USART3_TXint_inhib(); inhibits TX interrupt assuming USART3_IRQinit() previous called
    .thumb_func
USART3_TXint_inhib: 
	ldr r3,=USART3_BASE
	@; inhibit TX interrupt 
	ldrh r2,[r3,#CR1]
	bic r2,#( (1<<7) ) @; TXEIE
	strh r2,[r3,#CR1]
	@;TODO? check that TC flag is off
	bx lr

    .global USART3_RXint_enab 	@;enables RX interrupt assuming USART3_IRQinit() previous called
    .thumb_func
USART3_RXint_enab: 
	ldr r3,=USART3_BASE
	@; enable RX interrupt 
	ldrh r2,[r3,#CR1]
	orr r2,#( (1<<5) ) @; RXNEIE
	strh r2,[r3,#CR1]
	bx lr

    .global USART3_RXint_inhib 	@;inhibits RX interrupt assuming USART3_IRQinit() previous called
    .thumb_func
USART3_RXint_inhib: 
	ldr r3,=USART3_BASE
	@; inhibit RX interrupt 
	ldrh r2,[r3,#CR1]
	bic r2,#( (1<<5) ) @; RXNEIE
	strh r2,[r3,#CR1]
	bx lr


