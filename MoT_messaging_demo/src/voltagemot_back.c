//RedLED04.c wmh 2019-04-19 : adding Cmdtail arguments
//RedLED03.c wmh 2019-04-10 : adding messaging
//RedLED02.c wmh 2019-04-10 : converting inline task utilities to function calls
//RedLED01.c wmh 2019-04-07 : red LED MoT task in C

//------------------------------------ begin common definitions, usually in a header file shared by devices but expanded here for tutorial purposes
/*
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
	//uint8_t freq_divider;
	uint8_t store;
	uint8_t units;
	uint32_t samples;
} Voltcontrol;

// ------ Red_LED messages
char volt_install_msg[]= "Installing Voltage reader\n\r";
//char update_msg[]="updating RedLED on/off times\n\r";
char voltagepause_msg[]="voltage paused\n\r";
char voltageresume_msg[]="voltage resuming\n\r";
//char remove_msg[]="Removing RedLED\n\r";
char volt_badrequest_msg[]="Bad request -- volt command not recognized\n\r";

//char ON_msg[]="RedLED on\n\r";
//char OFF_msg[]="RedLED off\n\r";

//char voltage[]="Voltage is ";
//char volts[8];

// ------ RedLED tasks : installed by commands here and dispatched by do_tasks() in main()

void Voltage_reading(void);
int ADC_check();

void concatenate_string(char *original, char *add)
{
   while(*original)
      original++;

   while(*add)
   {
      *original = *add;
      add++;
      original++;
   }
   *original = '\n';
   original++;
   *original = '\r';
   original++;
   *original = '\0';
}

void Voltage_reading(void) //checks 'on' duration, may switch task to RedLED_off
{
	int counter;
	setRedLED();	//turn on LED TODO where?
	int check = ADC_check();
	char voltage[30]="Voltage is ";
	char volts[10];
	if( check == -1 ) { //we are not blinking so exit
		; //TODO
	}
	else { //we'll blink
		if(Voltcontrol.runflag == 0){
			;
		}
		else{
			if(Voltcontrol.units == 1){
				check = (check*3)/4093;
				itoa(check,volts,10);
			}
			if(Voltcontrol.units == 2){
				itoa(check,volts,10);
			}
			if(Voltcontrol.units == 0){
				itoa(check,volts,16);
			}
			concatenate_string(voltage,volts);

			if(Voltcontrol.show_screen == 1){
				post_Cdevicemsg(&myCTL,voltage,CHARCOUNT(voltage));
			}
					//post_Cdevicemsg(&myCTL,volts,CHARCOUNT(volts));
			relink_Ctask(&myCTL,Voltage_reading);
		}


	}
	suspend_Ctask(&myCTL);	//exit to next task
}


// ------ RedLED commands

void Voltage_install(void * Cmdtail) //initial installation
{	//usually hardware is initialized first, but was already initialized by call in main() to initPG13PG14()
	//initialize blinking rate-control values
	//Cmdtail will contain uint8_t Device, uint8_t Cmd, uint32_t ontime, uint32_t offtime in a hex ASCII string
	Voltcontrol.samples = *((uint32_t *)(Cmdtail+0));
	Voltcontrol.show_screen = *((uint8_t *)(Cmdtail+4));
	Voltcontrol.store = *((uint8_t *)(Cmdtail+5));
	Voltcontrol.units = *((uint8_t *)(Cmdtail+6));
	Voltcontrol.runflag = *((uint8_t *)(Cmdtail+7));

	TIM2_init(999);
	PC3_enable();
	myADC3_TIM2_PC3();
	link_Ctask(&myCTL, Voltage_reading);
	//send info message to PC
	post_Cdevicemsg(&myCTL,volt_install_msg,CHARCOUNT(volt_install_msg));
	return;	// to Cmd_Handler()
}

void voltage_pauseresume(void *Cmdtail)	// set/reset runflag
{	//Cmdtail will contain uint8_t Device, uint8_t Cmd, uint8_t Control in a hex ASCII string
	Voltcontrol.runflag= *((uint8_t *)Cmdtail);
	if(Voltcontrol.runflag==0)
		post_Cdevicemsg(&myCTL,voltagepause_msg,CHARCOUNT(voltagepause_msg));
	else
		post_Cdevicemsg(&myCTL,voltageresume_msg,CHARCOUNT(voltageresume_msg));
	return;	// to Cmd_Handler()

}


//------ RedLED command dispatcher

void Voltage(void *Cmdtail)	//dispatched from Devicetable by Cmd_handler(). Enter with r0 pointing to the byte following the device code
{
	switch(*((uint8_t *)Cmdtail)) {
		case 0:	Voltage_install(Cmdtail+1); break; 		// hardware initialization and install blink task
		//case 1:	RedLED_update(Cmdtail+1); break; 		// new RedLED ontime/offtime
		case 1:	voltage_pauseresume(Cmdtail+1);break;	// pause or resume blinking
		//case 3:	RedLED_remove(Cmdtail+1); break; 		// remove RedLED from the task list
		default: post_Cdevicemsg(&myCTL,volt_badrequest_msg,CHARCOUNT(volt_badrequest_msg));
	}
}

*/
