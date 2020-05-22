@; mySystemInit.S wmh 2018-08-14 : updated for STM32F429ZI
@; mySystemInit.S wmh 2017-08-27 : disassembly of Blinky's SystemInit(), edited for reassembly


	  .syntax unified	@;			
	  .cpu cortex-m4	@;				
	  .fpu softvfp		@;	 			
	  .thumb			@;	 			
	.global mySystemInit							
	.thumb_func			@;	  	
	.align 2			@; start on word boundary	
	
						@;	08002a8c <SystemInit>:				
						@;	  *         SystemFrequency variable.				
						@;	  * @param  None				
						@;	  * @retval None			
						@;	  */	
mySystemInit:			@;	void SystemInit(void)				
						@;	{				
	push	{r7}		@;	 8002a8c:	b480      	push	{r7}	
	add	r7, sp, #0		@;	 8002a8e:	af00      	add	r7, sp, #0	
						@;	  #if (__FPU_PRESENT == 1) && (__FPU_USED == 1)				
						@;	    SCB->CPACR |= ((3UL << 10*2)|(3UL << 11*2));  /* set CP10 and CP11 Full Access */				
						@;	  #endif				
						@;	  /* Reset the RCC clock configuration to the default reset state ------------*/				
						@;	  /* Set HSION bit */				
						@;	  RCC->CR |= (uint32_t)0x00000001;				
	ldr	r2, [pc, #68]	@;	 8002a90:	4a11      	ldr	r2, [pc, #68]	; (8002ad8 <SystemInit+0x4c>)
	ldr	r3, [pc, #68]	@;	 8002a92:	4b11      	ldr	r3, [pc, #68]	; (8002ad8 <SystemInit+0x4c>)
	ldr	r3, [r3, #0]	@;	 8002a94:	681b      	ldr	r3, [r3, #0]	
	orr.w	r3, r3, #1	@;	 8002a96:	f043 0301 	orr.w	r3, r3, #1	
	str	r3, [r2, #0]	@;	 8002a9a:	6013      	str	r3, [r2, #0]	
						@;					
						@;	  /* Reset CFGR register */				
						@;	  RCC->CFGR = 0x00000000;				
	ldr	r3, [pc, #56]	@;	 8002a9c:	4b0e      	ldr	r3, [pc, #56]	; (8002ad8 <SystemInit+0x4c>)
	movs	r2, #0		@;	 8002a9e:	2200      	movs	r2, #0	
	str	r2, [r3, #8]	@;	 8002aa0:	609a      	str	r2, [r3, #8]	
						@;					
						@;	  /* Reset HSEON, CSSON and PLLON bits */				
						@;	  RCC->CR &= (uint32_t)0xFEF6FFFF;				
	ldr	r1, [pc, #52]	@;	 8002aa2:	490d      	ldr	r1, [pc, #52]	; (8002ad8 <SystemInit+0x4c>)
	ldr	r3, [pc, #48]	@;	 8002aa4:	4b0c      	ldr	r3, [pc, #48]	; (8002ad8 <SystemInit+0x4c>)
	ldr	r2, [r3, #0]	@;	 8002aa6:	681a      	ldr	r2, [r3, #0]	
	ldr	r3, [pc, #48]	@;	 8002aa8:	4b0c      	ldr	r3, [pc, #48]	; (8002adc <SystemInit+0x50>)
	ands	r3, r2		@;	 8002aaa:	4013      	ands	r3, r2	
	str	r3, [r1, #0]	@;	 8002aac:	600b      	str	r3, [r1, #0]	
						@;					
						@;	  /* Reset PLLCFGR register */				
						@;	  RCC->PLLCFGR = 0x24003010;				
	ldr	r3, [pc, #40]	@;	 8002aae:	4b0a      	ldr	r3, [pc, #40]	; (8002ad8 <SystemInit+0x4c>)
	ldr	r2, [pc, #44]	@;	 8002ab0:	4a0b      	ldr	r2, [pc, #44]	; (8002ae0 <SystemInit+0x54>)
	str	r2, [r3, #4]	@;	 8002ab2:	605a      	str	r2, [r3, #4]	
						@;					
						@;	  /* Reset HSEBYP bit */				
						@;	  RCC->CR &= (uint32_t)0xFFFBFFFF;				
	ldr	r2, [pc, #32]	@;	 8002ab4:	4a08      	ldr	r2, [pc, #32]	; (8002ad8 <SystemInit+0x4c>)
	ldr	r3, [pc, #32]	@;	 8002ab6:	4b08      	ldr	r3, [pc, #32]	; (8002ad8 <SystemInit+0x4c>)
	ldr	r3, [r3, #0]	@;	 8002ab8:	681b      	ldr	r3, [r3, #0]	
	bic.w	r3, r3, #262144	@;	 8002aba:	f423 2380 	bic.w	r3, r3, #262144	; 0x40000
	str	r3, [r2, #0]	@;	 8002abe:	6013      	str	r3, [r2, #0]	
						@;					
						@;	  /* Disable all interrupts */				
						@;	  RCC->CIR = 0x00000000;				
	ldr	r3, [pc, #20]	@;	 8002ac0:	4b05      	ldr	r3, [pc, #20]	; (8002ad8 <SystemInit+0x4c>)
	movs	r2, #0		@;	 8002ac2:	2200      	movs	r2, #0	
	str	r2, [r3, #12]	@;	 8002ac4:	60da      	str	r2, [r3, #12]	
						@;					
						@;	  /* Configure the Vector Table location add offset address ------------------*/				
						@;	#ifdef VECT_TAB_SRAM				
						@;	  SCB->VTOR = RAMDTCM_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal SRAM */				
						@;	#else				
						@;	  SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal FLASH */				
	ldr	r3, [pc, #28]	@;	 8002ac6:	4b07      	ldr	r3, [pc, #28]	; (8002ae4 <SystemInit+0x58>)
	mov.w	r2, #134217728	@;	 8002ac8:	f04f 6200 	mov.w	r2, #134217728	; 0x8000000
	str	r2, [r3, #8]	@;	 8002acc:	609a      	str	r2, [r3, #8]	
						@;	#endif				
						@;	}				
	nop					@;	 8002ace:	bf00      	nop		
	mov	sp, r7			@;	 8002ad0:	46bd      	mov	sp, r7	
	pop	{r7}			@;	 8002ad2:	bc80      	pop	{r7}	
	bx	lr				@;	 8002ad4:	4770      	bx	lr	
	nop					@;	 8002ad6:	bf00      	nop		
	.word	0x40023800	@;	 8002ad8:	40023800 	.word	0x40023800	
	.word	0xfef6ffff	@;	 8002adc:	fef6ffff 	.word	0xfef6ffff	
	.word	0x24003010	@;	 8002ae0:	24003010 	.word	0x24003010	
	.word	0xe000ed00	@;	 8002ae4:	e000ed00 	.word	0xe000ed00	
