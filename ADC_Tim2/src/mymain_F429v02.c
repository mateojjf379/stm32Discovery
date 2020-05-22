
// Includes ------------------------------------------------------------------
#include <stdint.h>	//for uint8_t, uint16_t, uint32_t  etc. 
#include "myIncludes03.h"	//hardware register addresses

#define BUFF_SIZE 256

//miscellaneous functions used here -- see .S files for definitions
void initPG13();	// in '05Blinky_LD3.S'
void initPG14();

void SetSysClk();
void TIM2_init(uint32_t delay);
void TIM2_poll();
void setPG13();		// ""
void resetPG13();	// ""
void initSysTick();	// in 'mySysTick_Handler.S'
void NVIC_set_TIM2_priority();
void NVIC_TIM2_IRQ_enable();
void NVIC_set_ADC3_priority();
void NVIC_ADC3_IRQ_enable();
void PA5_enable();
void DAC_enable();
void PC3_enable();
void myADC3_TIM2_PC3();
char buffer[BUFF_SIZE + 1];

uint16_t SysTick_msecs = 0; 	//defined here but updated in 'mySysTick_Handler.S'
uint32_t SysTick_secs = 0;		// ""	


int main(void) // does some data access demos then blinks the green LED forever 
{
	//int i = 0;
	NVIC_set_TIM2_priority();
	NVIC_TIM2_IRQ_enable();
	SetSysClk();
	TIM2_init(999);
	NVIC_set_ADC3_priority();
	NVIC_ADC3_IRQ_enable();
	PA5_enable();
	DAC_enable();
	PC3_enable();
	myADC3_TIM2_PC3();
	initPG13();
	initPG14(); 		//initialize the PG13 port pin which drives the green LED (LD3)
	initSysTick();	//turn on the msec timer

	/*while(i < 1000000){
		//nothing
		i++;
	}*/

	while(1){
		TIM2_poll();
		if( SysTick_msecs <5 ) { //short 'on'
			setPG13();
		}
		if( SysTick_msecs >=5 ) { //long 'off'
			resetPG13();
		}
	}

}

