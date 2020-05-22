@; stm32f429xx@168MHz_USART3_115200N81.S -- USART3 initialization for 168MHZ clock !!note: this has been set back to 9600 baud for deugging
@; of note: 
@ USART1 is on APB2 bus (fast) while USART3 is on APB1 (slow) bus.  With SYSCLK set to 168 MHz these
@; buses are being driven at 84/42 MHz (fck=PCLK2/PCLK1)) respectively, therefore will have different 
@; baud rate (BRR) values, e.g. at the same baud rate, USART1's BRR value will be 2x USART3's BRR value.

@; TODO change all USART3 function names to start with USART3
@; stm32f429xx_USART3_115200N81_IT.S wmh 2019-03-04 : USART3 functions with interrupt for STM32F429 DISC1 board
@; stm32f429xx_USART3_115200N81.S wmh 2019-02-24 : USART3 functions for STM32F429 DISC1 board
@; stm32f429xx_USART1_9600N81.S wmh 2018-10-23 : USART1 functions for STM32F429 DISC1 board
/* 
	void initUSART3(void); 				//initialize USART3 for asynchronous 9600N81 communication
	int nbUSART3_getchar(void);			//success: return data>=0; failure: return -1
	int nbUSART3_putchar(char c);		//success: return +1; failure: return -1
	int bUSART3_getchar(void);			//blocks until new data, then return data
	void bUSART3_putchar(char c);		//block until character can be sent
	void USART3_writeDR(char c);			//debug: unconditional write to USART3 DR and return
*/


	@; --- characterize target syntax, processor
	.syntax unified				@; ARM Unified Assembler Language (UAL). 
	.thumb						@; Use thumb instructions only
	
@;*** USART3 -- required definitions ***

@; STM32F429xx register boundary addresses RM0090rev17_
.equ RCC_BASE, 0x40023800
.equ GPIOC_BASE, 0x40020800		@;for DISC1's PC10=USART3_TX, PC11=USART3_RX, 
.equ USART3_BASE,0x40004800		@;for USART3
  
@; offsets to USART registers extracted from USART_TypeDef in stm32f429xx.h 
.equ	SR,0x00         @; USART Status register,                   Address offset: 0x00 */
.equ	DR,0x04         @; USART Data register,                     Address offset: 0x04 */
.equ	BRR,0x08        @; USART Baud rate register,                Address offset: 0x08 */
.equ	CR1,0x0C        @; USART Control register 1,                Address offset: 0x0C */
.equ	CR2,0x10        @; USART Control register 2,                Address offset: 0x10 */
.equ	CR3,0x14        @; USART Control register 3,                Address offset: 0x14 */
.equ	GTPR,0x18       @; USART Guard time and prescaler register, Address offset: 0x18 */

@; offsets to RCC registers extracted from RCC_TypeDef in stm32429xx.h 
.equ	CR,			0x00	@; RCC clock control register
.equ	PLLCFGR,	0x04	@; RCC PLL configuration register
.equ	CFGR,		0x08	@; RCC clock configuration register
.equ	CIR,		0x0C	@; RCC clock interrupt register
.equ	AHB1RSTR,	0x10	@; RCC AHB1 peripheral reset register
.equ	AHB2RSTR,	0x14	@; RCC AHB2 peripheral reset register
.equ	AHB3RSTR,	0x18	@; RCC AHB3 peripheral reset register
 @;		RESERVED0			@; Reserved 0x1C
.equ	APB1RSTR,	0x20	@; RCC APB1 peripheral reset register
.equ	APB2RSTR,	0x24	@; RCC APB2 peripheral reset register
 @;	RESERVED1[2]			@; Reserved 0x28-0x2C
.equ	AHB1ENR,	0x30	@; RCC AHB1 peripheral clock register
.equ	AHB2ENR,	0x34	@; RCC AHB2 peripheral clock register
.equ	AHB3ENR,	0x38	@; RCC AHB3 peripheral clock register
 @;	RESERVED2,				@; Reserved 0x3C
.equ	APB1ENR,	0x40	@; RCC APB1 peripheral clock enable register
.equ	APB2ENR,	0x44	@; RCC APB2 peripheral clock enable register
 @;	RESERVED3[2],			@; Reserved 0x48-0x4C
.equ	AHB1LPENR,	0x50	@; RCC AHB1 peripheral clock enable in low power mode register
.equ	AHB2LPENR,	0x54	@; RCC AHB2 peripheral clock enable in low power mode register
.equ	AHB3LPENR,	0x58	@; RCC AHB3 peripheral clock enable in low power mode register
 @;	RESERVED4,				@; Reserved 0x5C
.equ	APB1LPENR,	0x60	@; RCC APB1 peripheral clock enable in low power mode register
.equ	APB2LPENR,	0x64	@; RCC APB2 peripheral clock enable in low power mode register
 @;	RESERVED5[2],			@; Reserved 0x68-0x6C
.equ	BDCR,		0x70	@; RCC Backup domain control register
.equ	CSR,		0x74	@; RCC clock control & status register
 @;	RESERVED6[2],			@; Reserved 0x78-0x7C
.equ	SSCGR,		0x80	@; RCC spread spectrum clock generation register
.equ	PLLI2SCFGR,	0x84	@; RCC PLLI2S configuration register
.equ	PLLSAICFGR,	0x88	@; RCC PLLSAI configuration register
.equ	DCKCFGR,	0x8C	@; RCC Dedicated Clocks configuration register1
@;stm32f7xx replaces stm32f4xx 'DCKCFGR' register above with the two registers DCKCFGR1, DCKCFGR2 below
@;.equ	DCKCFGR1,	0x8C	@; RCC Dedicated Clocks configuration register1
@;.equ	DCKCFGR2,	0x90	@; RCC Dedicated Clocks configuration register 2


@; offsets to GPIO registers extracted from GPIO_TypeDef in stm32f429xx.h 
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



@; --- begin code memory
	.text						@;start the code section
/*
	.global USART3_IRQHandler
	.thumb_func
USART3_IRQHandler: @; initial test for USART3_RXint_enab
	@;test if we are here for a legitimate reason (a character was received)
	push {r7,lr}	@;even though we're an interrupt, we're not a leaf function, so must do

	@;read flags to determine source of interrupt
	ldr r3,=USART3_BASE
	ldr r2,[r3,#SR]
	tst r2,#(0x0A)	@;test framing error and overrun error
	bne USART3_IRQHandler_error_trap
	teq r2,#(1<<5)	@;testing RXNE
	beq USART3_IRQHandler_nothing_to_do
	@;here if there is RX data
	ldr r0,[r3,#DR]
	bl nbUSART1_putchar
	@;return here with r0=-1 if it wasn't possible to send the data

	@;TODO put something here to fix the data-not-sent
	
USART3_IRQHandler_nothing_to_do:
	pop {r7,pc}
	
USART3_IRQHandler_error_trap:
	b .
	
	.global USART3_NVIC_init	@; NVIC end of USART3 interrupt enable and priority setting					
	.thumb_func
USART3_NVIC_init: 		@;NVIC configuration values for USART3 interrupt
	push {r7,lr}
	
	.equ position,39 		@;USART3 position in vector table from RM0090 Table 62. Vector table for STM32F42xxx and STM32F43xxx
	.equ byteoffset,4		@;# of bytes from origin to the bit at 'position', for any of the NVIC bit-registers
	.equ bitposition,7		@;position of enable/clear/active bit in byte at byteoffset, e.g. position=8*byteoffset+bitposition

	@;clear USART3 enable in NVIC before changing things
	ldr r3,=NVIC_ICER	
	ldrb r2,[r3,#byteoffset]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]

	@;clear pending USART3 in NVIC in case something got through previously
	ldr r3,=NVIC_ICPR	
	ldrb r2,[r3,#byteoffset]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]

	@;set USART3 interrupt priority high (1)
	ldr r3,=NVIC_IPR	
	mov r2,#0x10			@;priority is in upper nybble
	strb r2,[r3,#position]	

	
	@;enable USART3 in NVIC (should also enable in USART3 configuration
	ldr r3,=NVIC_ICER	
	ldrb r2,[r3,#byteoffset]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]

	pop {r7,pc}

	
	
    .global USART3_RXint_enab @;
    .thumb_func
USART3_RXint_enab: 
	push {r7,lr}
	
	.equ position,39 		@;USART3 position in vector table from RM0090 Table 62. Vector table for STM32F42xxx and STM32F43xxx
	.equ byteoffset,4		@;# of bytes from origin to the bit at 'position', for any of the NVIC bit-registers
	.equ bitposition,7		@;position of enable/clear/active bit in byte at byteoffset, e.g. position=8*byteoffset+bitposition

	@;clear USART3 enable in NVIC before changing things
	ldr r3,=NVIC_ICER	
	ldrb r2,[r3,#byteoffset]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]

	@;clear pending USART3 in NVIC in case something got through previously
	ldr r3,=NVIC_ICPR	
	ldrb r2,[r3,#byteoffset]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]
	
	@;start update of USART3 configuration
	ldr r3,=USART3_BASE
	@;turn off error-interrupt enables
	ldr r2,[r3,#CR3]
	bic r2,#(1<<0)	@;EIE (clear the miscellaneous error interrupt enable)
	str r2,[r3,#CR3]
	
	@;clear any error flags that might currently be on using the read SR, read DR sequence
	ldr r2,[r3,#SR]
	ldr r2,[r3,#DR]

	@;set USART3 interrupt priority high (1)
	ldr r3,=NVIC_IPR	
	mov r2,#0x10			@;priority is in upper nybble
	strb r2,[r3,#position]	

	@;enable USART3 in NVIC (should also enable in USART3 configuration
	ldr r3,=NVIC_ISER	
	ldrb r2,[r3,#byteoffset]
	orr r2,#(1<<bitposition)
	strb r2,[r3,#byteoffset]
	
	@;finish update of USART3
	ldr r3,=USART3_BASE
	@;(re)enable USART3 as receiver and enable USART3 RX interrupt
	ldr r2,[r3,#CR1]
	orr r2,#( (1<<5) | (1<<2) ) @; RXNEIE=bit5; RE=bit2
	str r2,[r3,#CR1]
	
	@;turn error-interrupt enable back on
	ldr r2,[r3,#CR3]
	orr r2,#(1<<0)	@;EIE (clear the miscellaneous error interrupt enable)
	str r2,[r3,#CR3]

	@;here with USART3 RX interrupt configured
	pop {r7,pc}
	
*/
	
    .global configure_GPIOC_for_USART3	@;set up GPIOA PC10,PC11 for USART3 operation
    .thumb_func
configure_GPIOC_for_USART3: 
   push {r7,lr}

	@;(re-)enable GPIOC 
	ldr r3,=RCC_BASE		@; select RCC AHB1 peripheral clock register
	ldr r2,[r3,#AHB1ENR]	@; ..
	orr	r2,r2,(1<<2)		@; set GPIOC_EN  (see manual page 181)
	str r2,[r3,#AHB1ENR]	@; ..

    @;configure GPIOC PC10, PC11 for alternate function USART3_TX, USART3_RX
    ldr r3,=GPIOC_BASE		@;select GPIOC for register operations

	@;begin configuration
	ldr r2,[r3,#(MODER)]
    bic r2,#(0x03<<(2*10))	@;clean mode bits
   	bic r2,#(0x03<<(2*11))	@; ..
	orr r2,#(0x02<<(2*10))	@;make PC10 alternate function
	orr r2,#(0x02<<(2*11))	@;make PC11 alternate function 	
	str r2,[r3,#(MODER)]

	@;configure PC10 output as push-pull  !!comment this and following out to check whether necessary
	ldr r2,[r3,#(OTYPER)]
    bic r2,#(0x01<<10)		@;clean type bit
	orr r2,#(0x00<<10)		@;output push-pull
	str r2,[r3,#(OTYPER)]
	
	@;configure PC10 as high-speed output
	ldr r2,[r3,#(OSPEEDR)]
    bic r2,#(0x03<<(2*10))	@;clear speed bits
	orr r2,#(0x02<<(2*10))	@;make high speed
	str r2,[r3,#(OSPEEDR)]

	@;no pullup/pulldown on PC10 
	ldr r2,[r3,#(PUPDR)]
    bic r2,#(0x03<<(2*10))	@;clear PUPD type bits  
    orr r2,#(0x00<<(2*10))	@;no pu/pd 	
	str r2,[r3,#(PUPDR)]
	
	@;connect PC10 as alternate function 7= USART3_TX
	ldr r2,[r3,#(AFRH)]
    bic r2,#(0x0F<<(4*(10-8)))	@;clear alternate function bits in AFRH (for pins 8-15) 
	orr r2,#(0x07<<(4*(10-8)))	@; set alternate function code
	str r2,[r3,#(AFRH)]

	@;configure PC11 output type: not done -- its an input

	@;configure PC11 output speed: not done -- its an input

	@; configure pullup on PC11 -- to make default input if not connected a 'mark' 
	ldr r2,[r3,#(PUPDR)]
    bic r2,#(0x03<<(2*11))	@;clear PUPD type bits
	orr r2,#(0x01<<(2*11))	@;configure as pullup
	str r2,[r3,#(PUPDR)]
	
	@;connect PC11 alternate function 7= USART3_RX
	ldr r2,[r3,#(AFRH)]
    bic r2,#(0x0F<<(4*(11-8)))	@;clear alternate function bits in AFRH (for pins 8-15) 
	orr r2,#(0x07<<(4*(11-8)))	@; set alternate function code
	str r2,[r3,#(AFRH)]

	@;here with GPIOC configured to connect USART3
	pop {r7,pc}


	.global initUSART3 	@;initialize USART3 for asynchronous 9600N81 communication
	.thumb_func
initUSART3: 
  	push {r7,lr}

	@; USART3EN: USART3 clock enable -- (re-)enable USART3 
	ldr r3,=RCC_BASE		@; select RCC APB1 peripheral clock register
	ldr r2,[r3,#APB1ENR]	@; ..
	orr	r2,#(1<<18)			@; set USART3_EN  (see manual page 184)
	str r2,[r3,#APB1ENR]	@; ..


	@; USART3RST: USART3 reset -- reset USART3 to start off clean
	ldr r3,=RCC_BASE			@; ..
	ldr r2,[r3,#APB1RSTR]		@; ..
	orr	r2,#(1<<18)				@; set USART3_RST 
	str r2,[r3,#APB1RSTR]		@; 
	nop							@; give it time to work (unnecessary?)
	nop							@; ..
	nop							@; ..
	nop							@; ..
	bic	r2,r2,#(1<<18)			@; clear USART3_RST to end reset
	str r2,[r3,#APB1RSTR]		@; 

@; --- configure USART3
/*
USART1 baudrate mystery -- what clock to use? Answer is spread around in RM0090 
    - Footnote 2 of USART baudrate tables: "USART1 and USART6 are clocked with PCLK2"
	- Remarked several places in manual: "APB2 clock domain (PCLK2)"
	- Remarked several places in manual: "AHB clock (HCLK)"
	- Description of RCC_CFGR bits: 
			"PPRE2: APB high-speed prescaler (APB2)"
			"SWS: System clock switch status"
	- Helpful visualization: 'Clock Tree' figure in manual showing derivations of clocks

	==> if RCC_CFGR is at reset defaults with PPRE2=0 and SWS=0 then 
	input to USART1 baud generator= PCLK2 (= APB2(= AHB(= HCLK(= HSI(= 16MHz))))). 
*/	
		
	@;step-by-step procedure from the manual for configuring the USART
	@;	1. Enable the USART by writing the UE bit in USART_CR1 register to 1.
	@;	2. Program the M bit in USART_CR1 to define the word length.
	@;	3. Program the number of stop bits in USART_CR2.
	@;	4. Select DMA enable (DMAT) in USART_CR3 if Multi buffer Communication is to take
	@;	place. Configure the DMA register as explained in multibuffer communication.
	@;	5. Select the desired baud rate using the USART_BRR register.
	@;	6. Set the TE bit in USART_CR1 to send an idle frame as first transmission.
	@;  6'. Set the RE bit USART_CR1 (this step is in a separate 'Character reception' procedure in the manual)
	
	ldr r3,=USART3_BASE

	@;step 1
	ldr r2,[r3,#CR1]
	orr r2,#(1<<13) @;UE=1 (USART enable)
	str r2,[r3,#CR1]

	@;step 2
	ldr r2,[r3,#CR1]
	bic r2,#(1<<12) @;M=0 (8 bit character)
	str r2,[r3,#CR1]
	
	@;step 3
	ldr r2,[r3,#CR2]
	bic r2,#(3<<12) @;STOP=00 (1 stop bit)
	str r2,[r3,#CR2]
	
	@;step 4
	ldr r2,[r3,#CR3]
	bic r2,#(1<<7) @;DMAT=0 (no DMA)
	str r2,[r3,#CR3]
	
	@;step 5 USARTDIV 546.875
	@using Table 142 in RM0090 rev17
@;	movw r2,#:lower16:1667	@;  target baud: 9600; fPCLK=16MHZ; OVER8=0 => USARTDIV= 1666.67 (or from table: 104.1875*16) 
@;	movw r2,#:lower16:139	@;  target baud: 115200; fCK=16MHZ => USARTDIV= 138.88 (or from table: 8.6875*16)
@;	movw r2,#:lower16:8750	@;  target baud: 9600; fPCLK=168MHZ; OVER8=0 => USARTDIV from table: 546.875*16 = 8750

@;	movw r2,#:lower16:729	@;  target baud: 115200; FCK=APB1= 42 MHz; OVER8=0 => USARTDIV from table: 22.8125*16 = 729
@;	movw r2,#:lower16:4380			@; 365	@;	729/2 in case we have a wrong bus clock input
	movw r2,#:lower16:365	@;	729/2 in case we have a wrong bus clock input
	strh r2,[r3,#BRR]		@; 


	@;step 6
	ldr r2,[r3,#CR1]
	orr r2,#(1<<3) @; TE=1 (transmitter enable , "sends a preamble (idle line)"? Sends 'MARK'?)
	str r2,[r3,#CR1]

	@;step 6'
	ldr r2,[r3,#CR1]
	orr r2,#(1<<2) @; RE=1 (receiver enable) 
	str r2,[r3,#CR1]
	
	@;GPIO settings
	bl configure_GPIOC_for_USART3

	pop {r7,pc}

	.global nbUSART3_getchar @;conditional USART3 getchar()
	.thumb_func
nbUSART3_getchar: @; char nbUSART3_getchar(void);	//success: return data>=0; failure: return -1
 	push {r7,lr}
	ldr r3,=USART3_BASE	

	@;initialize success/fail to 'fail'
	mov r0,#-1		
	@;check if new data is available
	ldr r2,[r3,#SR]			@;is receiver not empty (RXNE ==1)?
	tst r2,#(1<<5)				@; ..
	beq	1f						@;	no, receiver is empty -- return -1 (no data is available)
	ldrb r0,[r3,#DR]			@;	yes, receiver is not empty -- get new data (automatically clears RXNE)
@;	ands r0,#0xFF				@;	clean it up to 8 bits
@;	strb r0,[r3,#DR]			@;  echo it back for debug
1:	pop {r7,pc}					@; 	and return ( data>=0 =='success' )

	.global nbUSART3_putchar		@;conditional USART3 putchar()
	.thumb_func
nbUSART3_putchar: @;  int nbUSART3_putchar(char data);	//success: return +1; failure: return -1
 	push {r7,lr}
	ldr r3,=USART3_BASE	

	@;check if sending is ok
	ldr r2,[r3,#SR]			@;is transmitter empty (TXE ==1)?
	tst r2,#(1<<7)				@; .. 
	beq 1f						@;	no, transmitter not empty -- return -1 (sending is blocked)
	strb r0,[r3,#DR]			@;	yes -- send data (automatically clears TXE)
	mov r0,#1					@;		mark 'success'
	pop {r7,pc}					@; 		and return +1 (data was sent)
1:	mov r0,#-1					@;mark 'failure'
	pop {r7,pc}					@; 		and return -1 (sending is blocked)
	

	.global bUSART3_getchar		@; blocking USART3 getchar()
	.thumb_func
bUSART3_getchar: @;  int bUSART3_getchar(void);	//blocks until new data, then return data in r0
 	push {r7,lr}
	ldr r3,=USART3_BASE	

	@;check if new data is available
1:	ldr r2,[r3,#SR]			@;is receiver not empty (RXNE ==1)?
	tst r2,#(1<<5)				@; ..
	beq	1b						@;	no, receiver is empty -- keep testing
	ldrb r0,[r3,#DR]			@;	yes, receiver is not empty -- get new data (automatically clears RXNE)
@;	ands r0,#0xFF				@;	clean it up to 8 bits
	pop {r7,pc}					@; 	and return ( data>=0 =='success' )


	.global bUSART3_putchar		@;blocking USART3 putchar()
	.thumb_func
bUSART3_putchar: @;  void bUSART3_putchar(char data);	//block until character can be sent
 	push {r7,lr}
	ldr r3,=USART3_BASE	

	@;check if sending is ok
1:	ldr r2,[r3,#SR]			@;is transmitter empty (TXE ==1)?
	tst r2,#(1<<7)				@; .. 
	beq 1b						@;	no, transmitter not empty -- keep testing
	strb r0,[r3,#DR]			@;	yes -- send data (automatically clears TXE)
	pop {r7,pc}					@; 		and return

	
	
	.global USART3_writeDR
	.thumb_func
USART3_writeDR:			//debug: unconditional writes to USART3 DR and return
 	push {r7,lr}
	ldr r3,=USART3_BASE	
	strb r0,[r3,#DR]			@;	yes -- send data (automatically clears TXE)
	pop {r7,pc}					@; 		and return
