//myESP8266_runAtCmd01.c wmh 2019-04-07 : fundamental C-level interface with esp8266.
// We will attempt to write this as something that could also be called in a MoT task
// The idea being that the serial interrupts will be moving the data to/from the buffers
//  while the MoT 'C' task will monitor their progress. 
// The point of attack for integrating MoT with C will be LINK_me, RELINK_me, UNLINK_me
// macros. The runAtcmd's state variables have to be accessed through the MoT _data structure
// 
// First line of attack for adapting ESP8266 operations to MoT requirements is 'runAtcmd_status()'. 
// This will interrogate the interrupt function for AtCmd status so C-level tasks can determine
// next moves. 
// 
// Initial issues: no string.h library for strlen() and strstr() ==> write them 


/* adapted from 
  ******************************************************************************
  * @file    WiFi/ESP8266_IAP_Client/Src/esp8266.c
  * @author  MCD Application Team
  * @brief   This file provides a set of functions needed to manage the ESP8266
  *          WiFi devices.
*/


#include <stdint.h>		//for uint8_t, uint16_t, uint32_t  etc. 

#include <string.h>

#include "esp8266.h"	//lots of stuff (ESP8266 AT commands, error response codes, etc)


/*
  * @brief  Run the AT command
  * @param  cmd the buffer to fill will the received data.
  * @param  Length the maximum data size to receive.
  * @param  Token the expected output if command runs successfully
  * @retval Returns ESP8266_OK on success and ESP8266_ERROR otherwise.
  */

 //Lowlevel transmit interrupt design requirements for RunAtcmd():
 // global transmitted character count: absolute number of character transmitted since epoch. Polled by foreground programs to monitor number transmitted.
 // global transmitted character time: time in msecs since epoch of most recent character sent. Polled by foreground programs for timeout information.  
 // ring buffer compatibilty -- if data is to be sent on a rolling basis then a ringbuffer data structure (use Maxdata != 0 to indicate ringbuffer?) 
 
 //Lowlevel receive interrupt enhancements required for 'RunAtcmd():
 //	global received character count: absolute number of character received since epoch. Polled by foreground programs to monitor number received.
 // global received character time: time in msecs since epoch of most recent character received. Polled by foreground programs for timeout information.  
 
 
  
 //The new functions runAtcmd_start(), runAtcmd_status(), runAtcmd_reset() use globals to hold task state.
 //They are non-blocking functions which are to be called conditionally in main() based on state values.
 //Design 'should' be compatible with MoT

 //!!TODO put the following inside a struct for convenient access in the USART3 IRQ
 //struct {
	uint32_t runAtcmd_State;
	uint8_t * runAtCmd_cmdptr;			//null terminated string
	uint8_t * runAtCmd_Tokenbegin;		//makes processing without strstr() easier
	uint8_t * runAtCmd_Tokenend;		// ""
	uint32_t runAtCmd_Tokenlength;
	uint32_t ESP8266_RxBuffer_idx;
	uint8_t * ESP8266_RxBuffer;			//
	uint32_t runAtCmd_Lengthexpected;
	uint32_t runAtCmd_Timeoutdelay;
	uint32_t runAtCmd_Timeoutlimit;
 //} runAtcmd_status;
 
	uint8_t RxBuffer[1500];
	uint8_t * Token;
 
	//!!TODO -- move these data definitions to .S so order is guaranteed
	#define ESP8266_RXBUFFER_SIZE 1500
//	uint8_t ESP8266_RxBuffer = (uint8_t *)malloc(ESP8266_RXBUFFER_SIZE); !!hiding 'malloc()'
/* !!hide temporarily
ESP8266_StatusTypeDef runAtcmd_start(uint8_t* cmd, uint32_t Length, const uint8_t* Token, uint32_t Timeoutdelay)
{
	if(runAtcmd_State != ESP8266_READY) return runAtcmd_State;	//foreground program's responsibility to return state to ESP8266_READY after processing previous command
	else { 
		//initialize state
		runAtCmd_cmdptr = cmd;
		runAtCmd_Lengthexpected = Length;
		runAtCmd_Tokenbegin = Token;
		runAtCmd_Tokenend = Token + strlen(Token);
		runAtCmd_Timeoutdelay = Timeoutdelay;
		
		//TODO
		// - initialize transmit and receive interrupt parameters
		// - turn on the the transmit and receive interrupts
		return runAtcmd_State = ESP8266_STARTED;				//started ok
	}
}
*/

	extern uint32_t SysTick_msecs;
	uint32_t runAtCmd_Timeout;
	extern uint32_t RxBuffer_idx;

	//!!we'll put the #defines below in a header file to be included here and in the interrupt routine
	#define ESP8266_RUNATCMD_TX_RUNNING	0
	#define ESP8266_RUNATCMD_RX_TIMEOUT 1
	#define ESP8266_RUNATCMD_RX_OVERFLOW 2
	#define ESP8266_RUNATCMD_RX_ERROR 3
	#define ESP8266_RUNATCMD_COMPLETE 4
	#define ESP8266_RUNATCMD_UNKNOWN 5
	
uint32_t runAtcmd_status(void) //uses state variables updated by USART interrupt routines to measure progress through AtCmd sequence 
//returns tokens equivalent to those of 'ESP8266_StatusTypeDef '
// We are going to eliminate repetitive use of general purpose string functions like strstr and strlen because the strings 
// we are testing for in the interrupt are the EXP8266's AT command responses, which seem always to end with OK, ERROR, or FAIL,
// and possibly a newline -- see '4A-ESP8266_AT_Instruction_Set__EN.pdf' for examples.

{
	if( runAtCmd_cmdptr != '\0' ) //tx interrupt stops at end of command string
		return runAtcmd_State = ESP8266_RUNATCMD_TX_RUNNING;			
	else { //we are receiving 
		if( SysTick_msecs > runAtCmd_Timeout ) { //every rx interrupt occurrence updates timeout value
			return runAtcmd_State =  ESP8266_RUNATCMD_RX_TIMEOUT; //so this signals timeout if  excessive delay between characters
		} else { //still not TIMEOUT
			if( RxBuffer_idx == ESP8266_RXBUFFER_SIZE ) {  //rx interrupt stops when RXBUFFER_SIZE is reached
				return runAtcmd_State = ESP8266_RUNATCMD_RX_OVERFLOW;
			} else { 
				if( (RxBuffer_idx > sizeof(Token)) && (strstr((char *)RxBuffer, (char *)Token) != NULL) ) {   //'Token' was received
					return runAtcmd_State = ESP8266_RUNATCMD_COMPLETE;  //not sure what else to do? 
				} else { //'Error_string' was received
					if ( (RxBuffer_idx > sizeof(AT_ERROR_STRING)) && (strstr((char *)RxBuffer, AT_ERROR_STRING) != NULL) ) { 
						return runAtcmd_State = ESP8266_RUNATCMD_RX_ERROR; //not sure what else to do?
					}
				}
			}
		}
	}
	//something is wrong if we've made it to here
	return ESP8266_RUNATCMD_UNKNOWN;	
}
/* hide					
ESP8266_StatusTypeDef runAtcmd_reset(void)	
{
	//probably most important is to disable the USART interrupts and the timer. 
}				
*/		

		
/* original version, for reference 
  static ESP8266_StatusTypeDef old_runAtCmd(uint8_t* cmd, uint32_t Length, const uint8_t* Token)
{
  uint32_t idx = 0;
  uint8_t RxChar;
  
  //~ Reset the Rx buffer to make sure no previous data exist ~/
  memset(RxBuffer, '\0', MAX_BUFFER_SIZE);
  
  
  //~ Send the command ~/
  if (ESP8266_IO_Send(cmd, Length) < 0)
  {
    return ESP8266_ERROR;
  }

  //~ Wait for reception ~/
  while (1)
  {	
	//~ Wait to recieve data ~/
    if (ESP8266_IO_Receive(&RxChar, 1) != 0)
    {
      RxBuffer[idx++] = RxChar; 
    }
    else
    {
      break;
    }
    
	//~ Check that max buffer size has not been reached ~/
    if (idx == MAX_BUFFER_SIZE)
    {
      break;
    }

	//~ Extract the Token ~/
    if (strstr((char *)RxBuffer, (char *)Token) != NULL)
    {
      return ESP8266_OK;
    }
    
	//~ Check if the message contains error code ~/
    if (strstr((char *)RxBuffer, AT_ERROR_STRING) != NULL)
    {
      return ESP8266_ERROR;
    }
  }

  return ESP8266_ERROR;
}

*/
