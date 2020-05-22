@; stm32f429xx_USART1_9600N81.S wmh 2018-10-23 : USART1 functions for STM32F429 DISC1 board
/* 
	void initUSART1(void); 				//initialize USART1 for asynchronous 9600N81 communication
	int nbUSART1_getchar(void);			//success: return data>=0; failure: return -1
	int nbUSART1_putchar(char c);		//success: return +1; failure: return -1
	int bUSART1_getchar(void);			//blocks until new data, then return data
	void bUSART1_putchar(char c);		//block until character can be sent
	void USART1_writeDR(char c);			//debug: unconditional write to USART1 DR and return
*/


	@; --- characterize target syntax, processor
	.syntax unified				@; ARM Unified Assembler Language (UAL). 
	.thumb						@; Use thumb instructions only
	
@;*** USART1 -- required definitions ***

@; STM32F429xx register boundary addresses RM0090rev17_
.equ RCC_BASE, 0x40023800
.equ GPIOA_BASE, 0x40020000		@;for DISC1's PA9=USART1_TX, PA10=USART1_RX, 
.equ USART1_BASE,0x40011000		@;for USART1
  
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


@; --- begin code memory
	.text						@;start the code section

@;    .global configure_GPIOA_for_USART1	@;set up GPIOA A9,A10 for USART1 operation
    .thumb_func
configure_GPIOA_for_USART1: 
   push {r7,lr}

	@;(re-)enable GPIOA 
	ldr r3,=RCC_BASE		@; select RCC AHB1 peripheral clock register
	ldr r2,[r3,#AHB1ENR]	@; ..
	orr	r2,r2,(1<<0)		@; set GPIOA_EN  (see manual page 181)
	str r2,[r3,#AHB1ENR]	@; ..

    @;configure GPIOA PA9, PA10 for alternate function USART1_TX, USART1_RX
    ldr r3,=GPIOA_BASE		@;select GPIOA for register operations

	@;configure PA9, PA10 for alternate function
	ldr r2,[r3,#(MODER)]
    bic r2,#(0x03<<(2*9))	@;clear mode bits
   	bic r2,#(0x03<<(2*10))	@; ..
	orr r2,#(0x02<<(2*9))	@;make alternate function
	orr r2,#(0x02<<(2*10))	@; .. 	
	str r2,[r3,#(MODER)]

	@;configure PA9 output as push-pull  !!comment this and following out to check whether necessary
	ldr r2,[r3,#(OTYPER)]
    bic r2,#(0x01<<9)		@;clear type bit
	str r2,[r3,#(OTYPER)]

	@;configure PA9 as high-speed output
	ldr r2,[r3,#(OSPEEDR)]
    bic r2,#(0x03<<(2*9))	@;clear speed bits
	orr r2,#(0x02<<(2*9))	@;make high speed
	str r2,[r3,#(OSPEEDR)]

	@;no pullup/pulldown on PA9 
	ldr r2,[r3,#(PUPDR)]
    bic r2,#(0x03<<(2*9))	@;clear PUPD type bits (no pu/pd) 
	str r2,[r3,#(PUPDR)]
	
	@;connect PA9 alternate function 7= USART1_TX
	ldr r2,[r3,#(AFRH)]
    bic r2,#(0x0F<<(4*1))	@;clear alternate function bits
	orr r2,#(0x07<<(4*1))	@; set alternate function code
	str r2,[r3,#(AFRH)]

	@;configure PA10 output type -- skipped. Its an input

	@;configure PA10 output speed -- skipped. Its an input

	@; configure pullup on PA10 -- to make default input if not connected= 'mark' 
	ldr r2,[r3,#(PUPDR)]
    bic r2,#(0x03<<(2*10))	@;clear PUPD type bits
	orr r2,#(0x01<<(2*10))	@;configure as pullup
	str r2,[r3,#(PUPDR)]
	
	@;connect PA10 alternate function 7= USART1_RX
	ldr r2,[r3,#(AFRH)]
    bic r2,#(0x0F<<(4*2))	@;clear alternate function bits
	orr r2,#(0x07<<(4*2))	@; set alternate function code
	str r2,[r3,#(AFRH)]

	@;here with GPIOA configured to connect USART1
	pop {r7,pc}


	.global initUSART1 	@;initialize USART1 for asynchronous 9600N81 communication
	.thumb_func
initUSART1: 
  	push {r7,lr}

	@; USART1EN: USART1 clock enable -- (re-)enable USART1 
	ldr r3,=RCC_BASE		@; select RCC APB1 peripheral clock register
	ldr r2,[r3,#APB2ENR]	@; ..
	orr	r2,#(1<<4)			@; set USART1_EN  (see manual page 184)
	str r2,[r3,#APB2ENR]	@; ..


	@; USART1RST: USART1 reset -- reset USART1 to start off clean
	ldr r3,=RCC_BASE			@; ..
	ldr r2,[r3,#APB2RSTR]		@; ..
	orr	r2,#(1<<4)				@; set USART1_RST 
	str r2,[r3,#APB2RSTR]		@; 
	nop							@; give it time to work (unnecessary?)
	nop							@; ..
	nop							@; ..
	nop							@; ..
	bic	r2,r2,#(1<<4)			@; clear USART1_RST to end reset
	str r2,[r3,#APB2RSTR]		@; 

@; --- configure USART1
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
	
	ldr r3,=USART1_BASE

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
	
	@;step 5
@;	movw r2,#:lower16:1667	@;  target baud: 9600; fPCLK=16MHZ; OVER8=0 => USARTDIV= 1666.67 (or from RM0090 Table 136: 104.1875*16) 
	movw r2,#:lower16:8752	@;  target baud: 9600; fPCLK=84MHZ; OVER8=0 => USARTDIV= 1666.67 * (84/16) = 8762 (or from RM0090 Table 142: 546.875*16) 
@;	movw r2,#:lower16:139	@;  target baud: 115200; fCK=16MHZ => USARTDIV= 138.88 (or from table: 8.6875*16)
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
	bl configure_GPIOA_for_USART1

	pop {r7,pc}

	.global nbUSART1_getchar @;conditional USART1 getchar()
	.thumb_func
nbUSART1_getchar: @; char nbUSART1_getchar(void);	//success: return data>=0; failure: return -1
 	push {r7,lr}
	ldr r3,=USART1_BASE	

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

	.global nbUSART1_putchar		@;conditional USART1 putchar()
	.thumb_func
nbUSART1_putchar: @;  int nbUSART1_putchar(char data);	//success: return +1; failure: return -1
 	push {r7,lr}
	ldr r3,=USART1_BASE	

	@;check if sending is ok
	ldr r2,[r3,#SR]			@;is transmitter empty (TXE ==1)?
	tst r2,#(1<<7)				@; .. 
	beq 1f						@;	no, transmitter not empty -- return -1 (sending is blocked)
	strb r0,[r3,#DR]			@;	yes -- send data (automatically clears TXE)
	mov r0,#1					@;		mark 'success'
	pop {r7,pc}					@; 		and return +1 (data was sent)
1:	mov r0,#-1					@;mark 'failure'
	pop {r7,pc}					@; 		and return -1 (sending is blocked)
	

	.global bUSART1_getchar		@; blocking USART1 getchar()
	.thumb_func
bUSART1_getchar: @;  int bUSART1_getchar(void);	//blocks until new data, then return data in r0
 	push {r7,lr}
	ldr r3,=USART1_BASE	

	@;check if new data is available
1:	ldr r2,[r3,#SR]			@;is receiver not empty (RXNE ==1)?
	tst r2,#(1<<5)				@; ..
	beq	1b						@;	no, receiver is empty -- keep testing
	ldrb r0,[r3,#DR]			@;	yes, receiver is not empty -- get new data (automatically clears RXNE)
@;	ands r0,#0xFF				@;	clean it up to 8 bits
	pop {r7,pc}					@; 	and return ( data>=0 =='success' )


	.global bUSART1_putchar		@;blocking USART1 putchar()
	.thumb_func
bUSART1_putchar: @;  void bUSART1_putchar(char data);	//block until character can be sent
 	push {r7,lr}
	ldr r3,=USART1_BASE	

	@;check if sending is ok
1:	ldr r2,[r3,#SR]			@;is transmitter empty (TXE ==1)?
	tst r2,#(1<<7)				@; .. 
	beq 1b						@;	no, transmitter not empty -- keep testing
	strb r0,[r3,#DR]			@;	yes -- send data (automatically clears TXE)
	pop {r7,pc}					@; 		and return

	
	
	.global USART1_writeDR
	.thumb_func
USART1_writeDR:			//debug: unconditional writes to USART1 DR and return
 	push {r7,lr}
	ldr r3,=USART1_BASE	
	strb r0,[r3,#DR]			@;	yes -- send data (automatically clears TXE)
	pop {r7,pc}					@; 		and return
