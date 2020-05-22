//MoT_demo01.c wmh 2018-10-28 : foreground program of 'Micro on Tether (DonT) demo 


// Includes ------------------------------------------------------------------
#include <stdint-gcc.h>	//for uint8_t, uint16_t, uint32_t  etc. 

int32_t serchar;
#define BUFF_SIZE 256
void initPG13PG14();
void togglePG13();
void togglePG14();
void initSysTick();
void initUSART1(void);
int32_t nbUSART1_getchar(void); //non-blocking; returns received char >= 0 or -1 if fail/no char
int32_t nbUSART1_putchar(char);	//non-blocking; returns +1 if char sent, -1 if fail to send
int32_t bUSART1_getchar(void);	//blocking; does not return until character is received
void bUSART1_putchar(char);		//blocking; does not return until character is sent
void USART1_writeDR(char);		//for serial debug: unconditional write to USART1 DR
void initCmd_Handler(void); 	//initialize command buffer indexes, sets entry point at Cmd_wait_for_startchar()
void Cmd_Handler(void);			//parses serial input and dispatches tasks
void do_tasks(void);			//starts a traverse of the task-list, returns when tasks have run once
void initMsg_Handler(void);		//clear messages waiting on the message list, reset list to empty
int *Msg_Handler(void);			//returns 0 if no more messages, else address of current message's device data
void Msg_Handler_phony_post(void);	//'posts' a message on Msg_list to test Msg_Handler
//extern uint32_t SysTick_msecs;	//global value defined in mySysTick_Handler.S , zero'd at startup, updated in mySysTick_Handler.S
//extern uint32_t SysTick_secs;	//  ""

//from C:\_umd\_2019-01-01\ENEE440_S19\_work\0407_RunAtCmd\RunAtCmd_01\STM32F429_esp8266_ws\STM32F429_esp8266\src
void SetSysClk();				//in mySetSysClk03.S; increase SYSCLK to 168 MHz
void initSysTick();				//in mySysTick_Handler_168MHz.S msec timer to operate at 168Hz 
void initUSART1();				//in stm32f429xx_168MHz_USART1_9600N81.S; 168MHz version of USART1 into to 9600N81 over ST-LINK
// not used?	USART1_IRQinit(USART1_Ringbuf,USART1_BUFSIZE);	// USART1_IRQinit(USART1_RBhandle,USART1_BUFSIZE);	//
void initUSART3();				//in stm32f429xx_168MHz_USART3_115200N81.S; initialize USART3 to talk at 115200N81 
void USART3_IRQinit();			//in myESP8266_USART3_interrupt01.S
char buffer[BUFF_SIZE + 1];


int *pdev_data;					// points to current device control block
int xeq;						// device resume-execution address
int next;						// next device in the tasklist
int prev;						// previousdevice in the tasklist
int msgptr; 					// pointer next character to print
int msgcount; 					// count of remaining number of characters of message 
int msglink; 					// pointer to data structure of next device with a message (if any)

uint32_t SysTick_msecs = 0; 	//defined here for visibility but updated in 'mySysTick_Handler_168MHz.S'
uint32_t SysTick_absmsecs = 0; 	// ""
uint32_t SysTick_secs = 0;		// ""	





int main(void) // 
{
	uint32_t shadowSysTick_secs;

	SetSysClk();					
	initPG13PG14();
	initSysTick();
	initUSART1();
	initUSART3();
	USART3_IRQinit();	
	initCmd_Handler();
	initMsg_Handler();
/* test
	while(serchar!='x'){	//initial test of communication
		serchar= bUSART1_getchar();
		togglePG14();
		USART1_writeDR('!');
		bUSART1_putchar(serchar+1);		
	}
*/
/* test
	Msg_Handler_phony_post(); <<== !!breaks real system by screwing up rTASKP -- only good for checking basic Msg_Handler function
	
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
	Msg_Handler();
*/	
	//RedLED_install(0x0202FC);
	Voltage_install();
	while (1)
	{
		shadowSysTick_secs= SysTick_secs;
		
		Cmd_Handler();
		pdev_data=Msg_Handler(); 					//invoke Msg_Handler, peek at device control block for debuf
		if (pdev_data != 0) {
			xeq=pdev_data[0];						// device resume-execution address
			next=pdev_data[1];						// next device in the tasklist
			prev=pdev_data[2];						// previousdevice in the tasklist
			msgptr=pdev_data[3]; 					// pointer next character to print
			msgcount=pdev_data[4]; 					// count of remaining number of characters of message 
			msglink=pdev_data[5];					// pointer to data structure of next device with a message (if any)
		}
		do_tasks();
	}
}
