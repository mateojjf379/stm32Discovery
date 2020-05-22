//RedLED04.c wmh 2019-04-19 : adding Cmdtail arguments
//RedLED03.c wmh 2019-04-10 : adding messaging
//RedLED02.c wmh 2019-04-10 : converting inline task utilities to function calls
//RedLED01.c wmh 2019-04-07 : red LED MoT task in C

//------------------------------------ begin common definitions, usually in a header file shared by devices but expanded here for tutorial purposes

#include <stdint-gcc.h>	//for uint8_t, uint16_t, uint32_t  etc.
#include <stddef.h>		//for NULL

#define CHARCOUNT(string) (sizeof(string) -1)  //not including the string's '\0'

typedef struct taskCTL {	//task control structure common to all tasks
	void (*xeq)(void);		//,0		@; offset in the device's task control structure to the device's coroutine resume-execution address
	struct taskCTL * next;	//,4		@; offset in the device's task control structure to the next device in the tasklist
	struct taskCTL * prev;	//,8		@; offset in the device's task control structure to the next device in the tasklist
	char * msgptr;			//,12		@;will hold pointer to this message's next character to print
	uint32_t msgcount;		//,16		@;will hold count of remaining number of characters of message to print
	struct taskCTL * msglink;	//,20	@;will hold pointer to data structure of next device with a message (if any)
	void * dataptr;			//,24	@;untyped; used as pointer to a custom struct for this task
} taskCTL_t;


static taskCTL_t myCTL;					//'static' makes private, may also initialize all to 0 (CHECK THIS!)
										//question: how is myCTL related to rTASKP (r4) of assembly tasks?

extern taskCTL_t Tasklist_root;			//system variable holds pointer to first on task list
void suspend_Ctask(taskCTL_t * pCTL);	//task exit procedure
void link_Ctask(taskCTL_t * pCTL, void (*CtaskXEQ)(void));
void unlink_Ctask(taskCTL_t * pCTL);
void relink_Ctask(taskCTL_t * pCTL, void (*CtaskXEQ)(void));
uint32_t post_Cdevicemsg(taskCTL_t * pCTL, char * msgbody, uint32_t msglen); //send msglen bytes from msgbody;
//returns 0 if message has been placed in queue, returns >0 if previous message from same device is still in queue


// ------------------------------------- begin device-specific definitions

// ------ RedLED data : data is private to the this task;
// persistent data must be global but should be declared 'static' (private to this device's code)

void TIM2_init();
int TIM2_check();

static struct {		// local data used by RedLED tasks
	uint8_t runflag;

} RedLEDcontrol;

// ------ external hardware interface functions
void setRedLED();	//in Blinky_LD3_LD4.S
void resetRedLED();	//""
void TIM2_disable();

// ------ Red_LED messages
char install_msg[]= "Installing Voltage reader\n\r";
char update_msg[]="updating RedLED on/off times\n\r";
char pause_msg[]="RedLED paused\n\r";
char resume_msg[]="RedLED resuming\n\r";
char remove_msg[]="Removing RedLED\n\r";
char badrequest_msg[]="Bad request -- RedLED command not recognized\n\r";

char ON_msg[]="RedLED on\n\r";
char OFF_msg[]="RedLED off\n\r";

char voltage[]="Voltage is ";


// ------ RedLED tasks : installed by commands here and dispatched by do_tasks() in main()

void Voltage_reading(void);
void RedLED_off(void);
int ADC_check();

void Voltage_reading(void) //checks 'on' duration, may switch task to RedLED_off
{
	setRedLED();	//turn on LED TODO where?
	int check = ADC_check();

	if( check == -1 ) { //we are not blinking so exit
		; //TODO
	}
	else { //we'll blink
		//check = TIM2_check();
		/*while(check==0){
			check = TIM2_check();
		}
		post_Cdevicemsg(&myCTL,OFF_msg,CHARCOUNT(OFF_msg));
		relink_Ctask(&myCTL,RedLED_off);*/

			//RedLEDcontrol.count = RedLEDcontrol.offcount;
			post_Cdevicemsg(&myCTL,voltage,CHARCOUNT(voltage));
			relink_Ctask(&myCTL,Voltage_reading);

	}
	suspend_Ctask(&myCTL);	//exit to next task
}


// ------ RedLED commands

void Voltage_install(void * Cmdtail) //initial installation
{	//usually hardware is initialized first, but was already initialized by call in main() to initPG13PG14()
	//initialize blinking rate-control values
	//Cmdtail will contain uint8_t Device, uint8_t Cmd, uint32_t ontime, uint32_t offtime in a hex ASCII string
	TIM2_init(999);
	//NVIC_set_ADC3_priority();
	//NVIC_ADC3_IRQ_enable();
	PC3_enable();
	myADC3_TIM2_PC3();
	//RedLEDcontrol.oncount= *((uint32_t *)(Cmdtail+0));
	//RedLEDcontrol.offcount= *((uint32_t *)(Cmdtail+4));
	//start blinking (or not) with RedLED_on task
	//RedLEDcontrol.runflag= *((uint8_t *)(Cmdtail+8));
	//RedLEDcontrol.count= RedLEDcontrol.oncount;
	link_Ctask(&myCTL, Voltage_reading);
	//send info message to PC
	post_Cdevicemsg(&myCTL,install_msg,CHARCOUNT(install_msg));
	return;	// to Cmd_Handler()
}


//------ RedLED command dispatcher

void Voltage(void *Cmdtail)	//dispatched from Devicetable by Cmd_handler(). Enter with r0 pointing to the byte following the device code
{
	switch(*((uint8_t *)Cmdtail)) {
		case 0:	Voltage_install(Cmdtail+1); break; 		// hardware initialization and install blink task
		//case 1:	RedLED_update(Cmdtail+1); break; 		// new RedLED ontime/offtime
		//case 2:	RedLED_pauseresume(Cmdtail+1);break;	// pause or resume blinking
		//case 3:	RedLED_remove(Cmdtail+1); break; 		// remove RedLED from the task list
		default: post_Cdevicemsg(&myCTL,badrequest_msg,CHARCOUNT(badrequest_msg));
	}
}



