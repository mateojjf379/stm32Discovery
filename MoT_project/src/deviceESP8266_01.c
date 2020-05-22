//deviceESP8266_01.c wmh 2019-04-12 : interface to esp8266 wifi modem chip on USART3

#include <stdint-gcc.h>	//for uint8_t, uint16_t, uint32_t  etc. 
#include <stddef.h>		//for NULL

#include "MOTdevice.h"



// ------------------------------------- begin device-specific 
// ------ MOTdevice definitions
#define ESP8266_RUNATCMD_TX_RUNNING	0
#define ESP8266_RUNATCMD_RX_TIMEOUT 1
#define ESP8266_RUNATCMD_RX_OVERFLOW 2
#define ESP8266_RUNATCMD_RX_ERROR 3
#define ESP8266_RUNATCMD_COMPLETE 4
#define ESP8266_RUNATCMD_UNKNOWN 5

// ------ MOTdevice data : data is private to the this task; persistent data must be global but should be declared 'static' (private)
extern char * runAtCmd_cmdptr;

// ------ external functions
uint32_t runAtcmd_status(void);	//in myESP8266_runAtCmd01.c 		 -- returns current status of 'runATcmd' operation
void USART3_TXint_enab(); 		//in myESP8266_USART3_interrupt01.S  -- enables TX interrupt assuming USART3_IRQinit() previously called
USART3_TXint_inhib();			// ""

// ------ MOTdevice messages
char device8266_init_msg[]= "Install ESP8266 interface\n\r";

// ------ MOTdevice tasks (dispatched by do_tasks()) 

//operating test
char USART3_TXdone_msg[]= "USART3 transmit is complete\n\r";
void monitor_USART3_TX(void)		//start of debugging the interface. Monitors USART3, reports to PC when transmit is complete 
{
	if( *runAtCmd_cmdptr == '\0') { //string sending is complete
//		USART3_TXint_inhib();	//shouldn't it already be turned off by the transmit routine?
		unlink_Ctask(&myCTL);
		post_Cdevicemsg(&myCTL,USART3_TXdone_msg,CHARCOUNT(USART3_TXdone_msg)); //done AFTER task is unlinked
	}
	else
		suspend_Ctask(&myCTL);	
}


// ------ MOTdevice commands (dispatched by Cmd_Handler())

char USART3_TXhello_msg[]= "USART3 says 'Hello, world!'\n\r";
void hello_USART3(void) //testing: send a text string on USART3, dispatch monitor_USART3 task. Assumes USART3 already initialized
{
			
	link_Ctask(&myCTL,monitor_USART3_TX);	//start the USART3 transmit task to wait for message completion
	runAtCmd_cmdptr = USART3_TXhello_msg;	//point runAtCmd_cmdptr to the text string which will be sent
	USART3_TXint_enab(); 					//turn on the transmit interrupt
	//do we need to send a character to get the TX started?
}
	
	
	








