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


static struct {		// local data used by RedLED tasks
	uint8_t show_screen;
	uint8_t runflag;
	int threshold;
} RedVcontrol;

// ------ Red_LED messages
char redv_install_msg[]= "Installing Redv reader\n\r";
//char update_msg[]="updating RedLED on/off times\n\r";
char redvpause_msg[]="voltage paused\n\r";
char redvresume_msg[]="voltage resuming\n\r";
char redvremove_msg[]="Removing high voltage alert\n\r";
char redv_badrequest_msg[]="Bad request -- volt command not recognized\n\r";

char redv_ON_msg[]="RedLED on\n\r";
char redv_OFF_msg[]="RedLED off\n\r";

//char voltage[]="Voltage is ";
//char volts[8];

// ------ RedLED tasks : installed by commands here and dispatched by do_tasks() in main()


int ADC_check();
void redv_ON(void);
void redv_OFF(void);
void setRedLED();
void resetRedLED();
void redv_remove();

void redv_ON(void) //checks 'on' duration, may switch task to RedLED_off
{
	setRedLED();	//turn on LED TODO where?
	int check = 0;

	if( RedVcontrol.runflag == 0 ) { //we are not blinking so exit
		; //TODO
	}
	else { //we'll blink
		check = ADC_check();
		/*while(check==0){
			check = TIM2_check();
		}
		post_Cdevicemsg(&myCTL,OFF_msg,CHARCOUNT(OFF_msg));
		relink_Ctask(&myCTL,RedLED_off);*/
		if( check >= RedVcontrol.threshold ) { //its not time to blink so exit
			; //TODO
		}
		else { //its time to blink
			//RedLEDcontrol.count = RedLEDcontrol.offcount;
			post_Cdevicemsg(&myCTL,redv_OFF_msg,CHARCOUNT(redv_OFF_msg));
			relink_Ctask(&myCTL,redv_OFF);
		}
	}
	suspend_Ctask(&myCTL);	//exit to next task
}

void redv_OFF(void) //checks 'off' duration, may switch task to RedLED_on
{
	resetRedLED();	//turn off LED
	int check = 0;

	if( RedVcontrol.runflag == 0 ) { //we are not blinking so exit
		; //TODO
	}
	else { //we'll blink
		check = ADC_check();
		/*while(check==0){
			check = TIM2_check();
		}
		post_Cdevicemsg(&myCTL,ON_msg,CHARCOUNT(ON_msg));
		relink_Ctask(&myCTL,RedLED_on);*/
		if( check < RedVcontrol.threshold ) { //its not time to blink so exit
			; //TODO
		}
		else { //its time to blink
			//RedLEDcontrol.count = RedLEDcontrol.oncount;
			post_Cdevicemsg(&myCTL,redv_ON_msg,CHARCOUNT(redv_ON_msg));
			relink_Ctask(&myCTL,redv_ON);
		}
	}
	suspend_Ctask(&myCTL);	//exit to next task
}


// ------ RedLED commands

void Redv_install(void * Cmdtail) //initial installation
{	//usually hardware is initialized first, but was already initialized by call in main() to initPG13PG14()
	//initialize blinking rate-control values
	//Cmdtail will contain uint8_t Device, uint8_t Cmd, uint32_t ontime, uint32_t offtime in a hex ASCII string
	RedVcontrol.show_screen = *((uint8_t *)(Cmdtail+0));
	RedVcontrol.runflag = *((uint8_t *)(Cmdtail+1));
	uint8_t tmp = *((uint8_t *)(Cmdtail+2));
	if(tmp == 0){
		RedVcontrol.threshold = 0;
	}
	else if(tmp == 1){
		RedVcontrol.threshold = 1363;
	}
	else if(tmp == 2){
		RedVcontrol.threshold = 2045;
	}
	else{
		RedVcontrol.threshold = 4000;
	}

	TIM2_init(999);
	PC3_enable();
	myADC3_TIM2_PC3();
	link_Ctask(&myCTL, redv_OFF);
	//send info message to PC
	post_Cdevicemsg(&myCTL,redv_install_msg,CHARCOUNT(redv_install_msg));
	return;	// to Cmd_Handler()
}

void Redv_pauseresume(void *Cmdtail)	// set/reset runflag
{	//Cmdtail will contain uint8_t Device, uint8_t Cmd, uint8_t Control in a hex ASCII string
	RedVcontrol.runflag= *((uint8_t *)(Cmdtail+1));
	if(RedVcontrol.runflag==0)
		post_Cdevicemsg(&myCTL,redvpause_msg,CHARCOUNT(redvpause_msg));
	else
		post_Cdevicemsg(&myCTL,redvresume_msg,CHARCOUNT(redvresume_msg));
	return;	// to Cmd_Handler()

}

void redv_remove()	//turn off RedLED, remove RedLED task
{	//
	TIM2_disable();
	resetRedLED();
	unlink_Ctask(&myCTL);
	post_Cdevicemsg(&myCTL,redvremove_msg,CHARCOUNT(redvremove_msg)); //done AFTER task is unlinked ??TODO figure out why
}

//------ RedLED command dispatcher

void RedVoltage(void *Cmdtail)	//dispatched from Devicetable by Cmd_handler(). Enter with r0 pointing to the byte following the device code
{
	switch(*((uint8_t *)Cmdtail)) {
		case 0:	Redv_install(Cmdtail+1); break; 		// hardware initialization and install blink task
		//case 1:	RedLED_update(Cmdtail+1); break; 		// new RedLED ontime/offtime
		case 1:	Redv_pauseresume(Cmdtail+1);break;	// pause or resume blinking
		case 2:	redv_remove(); break; 		// remove RedLED from the task list
		default: post_Cdevicemsg(&myCTL,redv_badrequest_msg,CHARCOUNT(redv_badrequest_msg));
	}
}

