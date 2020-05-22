//mymainF429v01.c wmh 2018-08-13a : 'Blinky' adaptation for STM32F429I-DISC1 board
// - changes green LED location to PG13
//mymain05.c wmh 2017-09-04 : demo use of 'extern'; demo difference between C and asm view of variable 'Dword'
//mymain04.c wmh 2017-09-04 : makes calls to functions in myDataOps.S to demo
//mymain03.c wmh 2017-08-27 : 
// - cleanup and recomment
//mymain02.c wmh 2017-08-27 : 
// - eliminate 'HAL' and 'CMSIS' I/O functions -- configure and control PORTB directly
//mymain01.c wmh 2017-08-27 : 
// - skips the too-complex calls to SystemClock_Config(), CPU_CACHE_Enable(), etc
// - uses default CPU startup values
// - replaces delay function with software delay but use PORTB functions from original example

// Includes ------------------------------------------------------------------
#include <stdint.h>	//for uint8_t, uint16_t, uint32_t  etc. 
#include "myIncludes03.h"	//hardware register addresses

void initPG13();
void togglePG13();

void software_delay(uint32_t count)	//time-waster to slow down blink-rate
{
	while(count--){};
	return;
}

//prototypes of demo function in myDataOps.S
uint32_t loadCONSTANT_01(void);
uint32_t loadVARIABLE_00(void);
void storeVARIABLE_00(void);
uint32_t loadDword(void);
extern uint32_t Dword;

int main(void) // toggles GPIOB-GPIO_PIN_0 IO in an infinite loop. 
{
	uint32_t x=0x89ABCDEE;
	//x=Dword;
	//x=loadDword();
 

	//problem 1
	//for references, read comments in myDataOps02.s
	loadCONSTANT_01();
	loadCONSTANT_02();
	loadCONSTANT_03();
	loadCONSTANT_04();
	loadCONSTANT_05();
	loadCONSTANT_06();
	loadCONSTANT_07();
	loadCONSTANT_08();

	//problem 2
	//for references, read comments in myDataOps02.s
	loadVARIABLE_01();
	loadVARIABLE_02();
	loadVARIABLE_03();
	loadVARIABLE_04();
	loadVARIABLE_05();
	loadVARIABLE_06();
	loadVARIABLE_07();
	loadVARIABLE_08();

	//problem 3
	//for references, read comments in myDataOps02.s
	storeVARIABLE_01();
	storeVARIABLE_02();
	storeVARIABLE_03();
	storeVARIABLE_04();
	storeVARIABLE_05();
	storeVARIABLE_06();
	storeVARIABLE_07();
	storeVARIABLE_08();
	storeVARIABLE_09();
	initPG13();

	while (1)
	{
		togglePG13();
		software_delay(0x54321);				//go away for a while
	}


	#define myRCC	((myRCC_TypeDef *) RCC_BASE) 	//from myIncludes.h (originally in stm32F767xx.h) -- see DM00224583.pdf
	#define myGPIOB	((myGPIO_TypeDef *) GPIOB_BASE)	// --"--
	
	initPG13();

  // -1- Enable GPIOB's Clock (to be able to program the configuration registers) 
	myRCC->AHB1ENR |= 1<<1;	//DM00224583.pdf Section 5.3.10 RCC AHB1 peripheral clock register (RCC_AHB1ENR)  

  // -2- Configure IO in output push-pull mode to drive external LEDs 
  //!!wmh -- the code below is not general purpose -- assumes initialization occurs immediately after reset so 'OR's occur over initial 0s
	myGPIOB->MODER |= 01<<0;    	// DM00224583.pdf Section 6.4.1 GPIO port mode register (GPIOx_MODER) (x =A..K)
	myGPIOB->OTYPER |= 0<<0;   	// DM00224583.pdf Section 6.4.2 GPIO port output type register (GPIOx_OTYPER) (x = A..K)
	myGPIOB->OSPEEDR |=2<<0;  	// DM00224583.pdf Section 6.4.3 GPIO port output speed register (GPIOx_OSPEEDR)
	myGPIOB->PUPDR |= 0<<0;    	// DM00224583.pdf Section 6.4.4 GPIO port pull-up/pull-down register (GPIOx_PUPDR)

  // -3- Toggle IO in an infinite loop 
  while (1)
  {
	// DM00224583.pdf Section  6.4.5 GPIO port input data register (GPIOx_IDR)
	// DM00224583.pdf Section  6.4.6 GPIO port output data register (GPIOx_ODR) 
	// __IO uint32_t IDR = GPIO port input data register,  address offset: 0x10 
	// __IO uint32_t ODR = GPIO port output data register, address offset: 0x14    
	
	myGPIOB->ODR = myGPIOB->IDR ^ (1<<0);	//flip output state of PORTB bit 0
	software_delay(0x54321);				//go away for a while 
  }
}

