
// Includes ------------------------------------------------------------------
#include <stdint.h>	//for uint8_t, uint16_t, uint32_t  etc. 
#include "myIncludes03.h"	//hardware register addresses

//miscellaneous functions used here -- see .S files for definitions
void initPG13();	// in '05Blinky_LD3.S'
void initPG14();

void SetSysClk();
void TIM2_init(uint32_t delay);
void TIM2_poll();
void setPG13();		// ""
void resetPG13();	// ""
void initSysTick();	// in 'mySysTick_Handler.S'



uint16_t SysTick_msecs = 0; 	//defined here but updated in 'mySysTick_Handler.S'
uint32_t SysTick_secs = 0;		// ""	


int main(void) // does some data access demos then blinks the green LED forever 
{
	SetSysClk();
	TIM2_init(333);
	initPG13();
	initPG14(); 		//initialize the PG13 port pin which drives the green LED (LD3)
	initSysTick();	//turn on the msec timer


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

