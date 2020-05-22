@;mySetSysClk03.asm wmh 2019-03-21 : changing PLLP, PLLM, PPRE1 parameter values
@;mySetSysClk02.asm wmh 2019-03-21 : changing initialization sequence to turn PLLON last
@; Simple system clock initialization "Sysclk-code_from_web.c" does the above and claims to work
@;mySetSysClk01.asm wmh 2019-03-21 :  doesn't work -- when we write new value to PLLCFGR in debgger, it reverts to a previous value
@; initializes system clock at 168 MHz with highspeed external oscillator (HSE) with 8MHz crystal
	.syntax unified				@; ARM Unified Assembler Language (UAL). 
	.thumb						@; use thumb instructions only

	.include "myMacros.inc"

	@;registers affected
	.equ RCC_base,				0x40023800	
	.equ RCC_CR, 				0x40023800
	.equ RCC_CR_offset,			8
	.equ RCC_PLLCFGR, 			0x40023804
	.equ RCC_PLLCFGR_offset, 	4
	.equ RCC_CFGR,				0x40023808
	.equ RCC_CFGR_offset,		8
	.equ RCC_CIR,				0x40023808
	.equ RCC_CIR_offset,		8	
	.equ FLASH_ACR,				0x40023C00

	@;RCC_PLLCFGR settings to generate HCLK (CPU clock)= 168 MHz with HSE (external crystal)= 8 MHz  
	.equ PLLM_val, 		(8<<0)		@;HSE divider: makes PLL input 1 MHz
	.equ PLLN_val,		(336<<6)	@;PLL multiplier: gives PLL output 336 MHz 
	.equ PLLQ_val,		(7<<24)		@;PLL divider: 336/7 provides 48 MHz clock input to USB OTG, SDIO, and RNG
	.equ PLLP_val,		(0<<16)		@;PLL divider: 336/2 provides 168 MHz clock input to APB1, APB2 bus clock prescalers

	@;RCC_PLLCFGR value field masks
	.equ PLLM_mask, 	(0x3F<<0)	@;clear HSE divider
	.equ PLLN_mask,		(0x1FF<<6)	@;clear PLL multiplier
	.equ PLLQ_mask,		(0xF<<24)	@;clear PLL divider
	.equ PLLP_mask,		(0x3<<16)	@;PLL divider


	@;RCC_CR control bit position
	.equ HSION_bitpos,0				@;highspeed internal oscillator (HSI) enable
	.equ HSEON_bitpos,16			@;highspeed external oscillator (HSE) enable
	.equ CSSON_bitpos,19			@;Clock security system enable
	.equ PLLON_bitpos,24			@;phase lock loop (PLL) clock generator enable
	.equ HSEBYP_bitpos,18			@;HSE bypass enable. 0: HSE oscillator not bypassed
	.equ HSERDY_bitpos,17			@;HSE clock ready flag 1: HSE clock is running
	
	@;RCC_CR control bit masks
	.equ HSION_bitmask,(1<<0)		@;highspeed internal oscillator (HSI) enable
	.equ HSEON_bitmask,(1<<16)		@;highspeed external oscillator (HSE) enable
	.equ CSSON_bitmask,(1<<19)		@;Clock security system enable
	.equ PLLON_bitmask,(1<<24)		@;phase lock loop (PLL) clock generator enable
	.equ HSEBYP_bitmask,(1<<18)		@;HSE bypass enable. 0: HSE oscillator not bypassed
	.equ HSERDY_bitmask,(1<<17)		@;HSE clock ready flag 1: HSE clock is running
	
	@;RCC_PLLCFGR control bit position
	.equ PLLSRC_bitpos,22			@;PLL sources: 1: HSE oscillator clock selected as PLL and PLLI2S clock entry

	@;RCC_PLLCFGR control bit mask
	.equ PLLSRC_bitmask,(1<<22)		@;PLL sources: 1: HSE oscillator clock selected as PLL and PLLI2S clock entry

	@;RCC_CFGR settings for AHB, APB1, APB2 clocks 
	.equ SW_val,		(2<<0)		@;PLL selected as system clock SYSCLK
	.equ HPRE_val,		(0<<4)		@;AHB prescaler does not reduce system clock frequency: SYSCLK = PLL/1 (no reduction)
	.equ PPRE1_val,		(5<<10) 	@;APB1 prescaler divides SYSCLK by 4 in order to get below 42 MHz limit
	.equ PPRE2_val,		(4<<13) 	@;ABP2 prescaler divides SYSCLK by 2 in order to get below 84 MHz limit

	@;RCC_CFGR value field masks
	.equ SW_mask,		(0x3<<0x3)	@;clear SW[1:0]
	.equ HPRE_mask,		(0xF<<4)	@;clear HPRE[3:0]
	.equ PPRE1_mask,	(0x7<<10) 	@;clear PPRE1[2:0]
	.equ PPRE2_mask,	(0x7<<13) 	@;clear PPRE2[2:0]
	
	@;maximum number of empty program loops HSE oscillator or PLL will wait before aborting clock setup
	.equ HSE_StartLimit,1000000	
	.equ PLL_StartLimit,1000000
	
	
	.data 
	

	.align 2
	.comm HSE_StartCount,4 	@;number of empty loops before RCC_CR.HSERDY reports HSE is running
	.comm PLL_StartCount,4	@;number of empty loops before RCC_CR.PLLRDY reports PLL is running

	.text
	
	.global SetSysClk
	.thumb_func
SetSysClk:	
	push {r7,lr}
	
	@; step-by-step, starting with SystemInit(void) from system_clock.c, which puts everything back to reset state
	@; followed by SetSysClock_PLL_HSE(), which writes new values to various location.
	
	@; === from SystemInit()
    /* Reset the RCC clock configuration to the default reset state ------------*/
	@;operations on RCC
	MOV_imm32 r3,RCC_base			@;r3 will remain as RCC register array base throughout the following			
	
    /* Set HSION bit */	
    @;	RCC->CR |= (uint32_t)0x00000001;
@;	ldr r0,[r3,#RCC_CR_offset]
	SET_bit RCC_CR,HSION_bitpos		@;to make sure there's a clock for the rest of our activities here
@;	str r0,[r3,#RCC_CR_offset]
	
    /* Reset CFGR register */
    @;	RCC->CFGR = 0x00000000;
	mov r0,#0
	str r0,[r3,#RCC_CFGR_offset]
	
    /* Reset HSEON, CSSON and PLLON bits */
	@;	RCC->CR &= (uint32_t)0xFEF6FFFF;
	ldr r0,[r3,#RCC_CR_offset]
	BIC_imm32 r0,(HSEON_bitmask | CSSON_bitmask | PLLON_bitmask) 
	str r0,[r3,#RCC_CR_offset]

    /* Reset PLLCFGR register */
@;??    MOV_imm32 r0,0x24003010;			@;"default starting value" why are we doing this? 
@;??	str r0,[r3,#RCC_PLLCFGR_offset]
	
    /* Reset HSEBYP bit */
    @;	RCC->CR &= (uint32_t)0xFFFBFFFF;	@;why do this separately from above?
@;	ldr r0,[r3,#RCC_CR_offset]
	CLR_bit RCC_CR,HSEBYP_bitpos
@;	str r0,[r3,#RCC_CR_offset]	

    /* Disable all interrupts */
    @;	RCC->CIR = 0x00000000;
	mov r0,#0
	str r0,[r3,#RCC_CIR_offset]

	@; === from SetSysClock_PLL_HSE(bypass=0) 
	    // Enable HSE oscillator and activate PLL with HSE as source
	@; RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;

    @; RCC_OscInitStruct.HSEState = RCC_HSE_ON; //using external 8 MHz xtal on OSC_IN/OSC_OUT
@;	ldr r0,[r3,#RCC_CR_offset]
	SET_bit	RCC_CR,HSEON_bitpos
@;	str r0,[r3,#RCC_CR_offset]
	
	@; Wait for HSE oscillator to start
	MOV_imm32 r1,HSE_StartCount
	MOV_imm32 r2,HSE_StartLimit
	mov r0,#0	
	@;loop until HSERDY is true or until start count = start limit
1:	str r0,[r1]	
	TST_bit RCC_CR,HSEON_bitpos		@;HSE started?
	bne 2f							@;  yes -- continue with clock initialization  
	@;here while HSEON is 0 
	add r0,#1						@;increment  count
	cmp r0,r2						@; timed out?
	blo 1b							@;	no -- keep testing 
	@;here if timeout occurred befor HSE started
	b HSE_no_start	@;clock initialization has failed 	
2:	@;here if HSE oscillator has started -- 


	@;continue with initializaiton

/* mySetSysClk02.asm moves the below PLL turnon to end )
	@;
	@; RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
@;	ldr r0,[r3,#RCC_CR_offset]
	SET_bit	RCC_CR,PLLON_bitpos
@;	str r0,[r3,#RCC_CR_offset]
*/
	@; RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
@;	ldr r0,[r3,#RCC_PLLCFGR_offset]
	SET_bit	RCC_PLLCFGR,PLLSRC_bitpos
@;	str r0,[r3,#RCC_PLLCFGR_offset]

	@;set PLL multiplers and dividers for 168 Mhz output 
	@; RCC_OscInitStruct.PLL.PLLM = 4;
	@; RCC_OscInitStruct.PLL.PLLN = 336;
	@; RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2 = 2;
	@; RCC_OscInitStruct.PLL.PLLQ = 7;
@;using RCC_PLLCFGR values defined at top and repeated below
@;.equ PLLM_val, 	(4<<0)			@;HSE divider: input to PLL = 2 MHz
@;.equ PLLN_val,	(336<<6)		@;PLL multiplier: gives PLL output 336 MHz 
@;.equ PLLQ_val,	(7<<24)			@;PLL divider: provides 48 MHz clock input to USB OTG, SDIO, and RNG
@;.equ PLLP_val,	(2<<16)			@;PLL divider: provides 84 MHz clock input to APB1, APB2 bus clock prescalers
	ldr r0,[r3,#RCC_PLLCFGR_offset]
	BIC_imm32 r0,( PLLM_mask | PLLN_mask | PLLP_mask | PLLQ_mask ) 	@;clear fields to be updated	
	ORR_imm32 r0,( PLLM_val | PLLN_val | PLLP_val | PLLQ_val ) 		@; update field values
	str r0,[r3,#RCC_PLLCFGR_offset]

	
@;??    if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK) { return 0; // FAIL }

@;??    // Activate the OverDrive to reach the 180 MHz Frequency
@;??    if (HAL_PWREx_EnableOverDrive() != HAL_OK) {  return 0; // FAIL }

@;??	@; RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_SYSCLK | RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;

	@; RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
	@; RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1; // 180 or 168 MHz
	@; RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;  //  45 or  42 MHz
	@; RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;  //  90 or  84 MHz
@;	RCC_CFGR settings for AHB, APB1, APB2 clocks values defined at top and repeated below
@;	.equ SW_val,(2<<0)				@;PLL selected as system clock SYSCLK
@;	.equ HPRE_val,(0<<4)			@;AHB prescaler does not reduce system clock frequency: SYSCLK = PLL/1 (no reduction)
@;	.equ PPRE1_val,(5<<10) 			@;APB1 prescaler divides 168 MHz SYSCLK by 4 in order to stay below 45 MHz limit
@;	.equ PPRE2_val,(4<<13) 			@;ABP2 prescaler divides 168 MHz SYSCLK by 2 in order to stay below 90 MHz limit
	@;update everything
	ldr r0,[r3,#RCC_CFGR_offset]
	BIC_imm32 r0,( SW_mask | HPRE_mask | PPRE1_mask | PPRE2_mask )	@;clear RCC_CFGR files to be updated
	ORR_imm32 r0,( SW_val | HPRE_val | PPRE1_val | PPRE2_val )		@;update with new values 
	str r0,[r3,#RCC_CFGR_offset]

	@;here with SYSCLK, AHB, APB1, and APB2 clocks configured. Some others (USB, I2S, ..) will need further configuration	

@;??	if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_5) != HAL_OK) {  return 0; // FAIL }

	@;prefetch eable, instruction cache enable,  data cache enable; wait states = 5
	MOV_imm32 r1,0x00000705
	MOV_imm32 r2,FLASH_ACR
	ldr r0,[r2]
	orr r0,r1
	str r0,[r2]


@; mySetSysClk02.asm has moved the PLL turnon here at end 
	@;
	@; RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
@;	ldr r0,[r3,#RCC_CR_offset]
	SET_bit	RCC_CR,PLLON_bitpos
@;	str r0,[r3,#RCC_CR_offset]

	
	@; Wait for PLL oscillator to start
	MOV_imm32 r1,PLL_StartCount
	mov r0,#0	
	str r0,[r1]
	@;loop until RCC_CFGR SWS value matches SW value or timeout 
1:	ldr r0,[r3,#RCC_CFGR_offset]
	ror r1,r0,#2
	eor r0,r0,r1
	movw r1,0x03
	ands r0,r1
	beq SetSysClock_Done			@;SW and SWS match! clocks are good
	@;here while clocks are still not good
	MOV_imm32 r1,PLL_StartCount
	MOV_imm32 r2,PLL_StartLimit
	ldr r0,[r1]
	cmp r0,r2
	blo 1b
	@;here when timeout occurred before clocks good
PLL_no_start:
	b .
	
HSE_no_start: @;trap here if HSE does not start
	b .
	
SetSysClock_Done:
	pop {r7,pc}
	
	
	
