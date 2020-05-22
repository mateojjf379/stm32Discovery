
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

uint32_t SysTick_secs;
uint16_t SysTick_msecs;

// ------------------------------------- begin device-specific definitions

// ------ RedLED data : data is private to the this task;
// persistent data must be global but should be declared 'static' (private to this device's code)


static struct {		// local data used by Timedvolt tasks
	uint8_t runflag;
	uint8_t mode; 	//0 interval, 1 scheduled
	int interval;
	int initial;
	int second;
	int third;
} Timedcontrol;

// ------ Red_LED messages
char timed_install_msg[]= "Installing Timed Voltage reader\n\rInstallation completed\n\rRunning\n\r";
//char update_msg[]="updating RedLED on/off times\n\r";
char timedpause_msg[]="timed voltage paused\n\r";
char timedresume_msg[]="timed voltage resuming\n\r";
char timedremove_msg[]="Removing timed-scheduled device\n\r";
char timed_badrequest_msg[]="Bad request -- timed volt command not recognized\n\r";

//char ON_msg[]="RedLED on\n\r";
//char OFF_msg[]="RedLED off\n\r";

//char voltage[]="Voltage is ";
//char volts[8];

// ------ RedLED tasks : installed by commands here and dispatched by do_tasks() in main()

void timed_reading(void);
void timed_remove();
int ADC_check();
int first_done = 0;
int day = 0;

void concatenate_string_1(char *original, char *add)
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

int time_hex2sec(uint8_t hr, uint8_t min){
	if(hr >= 24){
		hr = 0;
	}
	if(min >= 60){
		min = 0;
	}
	return (hr*60*60+min*60);
}

void timed_reading(void) //checks 'on' duration, may switch task to RedLED_off
{

	setRedLED();	//turn on LED TODO where?
	char voltage[30]="Voltage is ";
	char volts[2];
	int check = ADC_check();
	if(Timedcontrol.mode == 0){
		if(SysTick_secs >= Timedcontrol.interval){
			if(check == -1){
				;
			}
			else{
				check = (check*3)/4093;
				itoa(check,volts,10);
				concatenate_string_1(voltage,volts);
				post_Cdevicemsg(&myCTL,voltage,CHARCOUNT(voltage));
				relink_Ctask(&myCTL,timed_reading);

			}
			if(SysTick_msecs >= 25){
				SysTick_secs = 0;
			}
		}

	}
	else{
		if(SysTick_secs >= 86400){
			SysTick_secs = 0;
			day = 0;
		}
		if(!day && !first_done && SysTick_secs >= Timedcontrol.second){
			if(check == -1){
				;
			}
			else{
				check = (check*3)/4093;
				itoa(check,volts,10);
				concatenate_string_1(voltage,volts);
				post_Cdevicemsg(&myCTL,voltage,CHARCOUNT(voltage));
				relink_Ctask(&myCTL,timed_reading);
			}
			if(SysTick_msecs >= 25){
				first_done = 1;
			}

		}
		if(!day && first_done && SysTick_secs >= Timedcontrol.third){
			if(check == -1){
				;
			}
			else{
				check = (check*3)/4093;
				itoa(check,volts,10);
				concatenate_string_1(voltage,volts);
				post_Cdevicemsg(&myCTL,voltage,CHARCOUNT(voltage));
				relink_Ctask(&myCTL,timed_reading);
			}
			if(SysTick_msecs >= 25){
				first_done = 0;
				day = 1;
			}
		}

	}
	suspend_Ctask(&myCTL);	//exit to next task
}


// ------ RedLED commands

void timed_install(void * Cmdtail) //initial installation
{	//usually hardware is initialized first, but was already initialized by call in main() to initPG13PG14()
	//initialize blinking rate-control values
	//Cmdtail will contain uint8_t Device, uint8_t Cmd, uint32_t ontime, uint32_t offtime in a hex ASCII string
	Timedcontrol.mode = *((uint8_t *)(Cmdtail+0));
	uint8_t interval_h; //if mode 0, interval of when it will measure
	uint8_t interval_m;
	uint8_t initial_h;
	uint8_t initial_m;
	uint8_t second_h;
	uint8_t second_m;
	uint8_t third_h;
	uint8_t third_m;

	if(Timedcontrol.mode == 0){
		interval_h = *((uint8_t *)(Cmdtail+1));
		interval_m = *((uint8_t *)(Cmdtail+2));
		Timedcontrol.interval = time_hex2sec(interval_h, interval_m);
		SysTick_secs = 0;
	}
	else{
		initial_h = *((uint8_t *)(Cmdtail+1));
		initial_m = *((uint8_t *)(Cmdtail+2));
		second_h = *((uint8_t *)(Cmdtail+3));
		second_m = *((uint8_t *)(Cmdtail+4));
		third_h = *((uint8_t *)(Cmdtail+5));
		third_m = *((uint8_t *)(Cmdtail+6));
		Timedcontrol.initial = time_hex2sec(initial_h, initial_m);
		Timedcontrol.second = time_hex2sec(second_h, second_m);
		Timedcontrol.third = time_hex2sec(third_h, third_m);
		SysTick_secs = Timedcontrol.initial;
	}
	Timedcontrol.runflag = *((uint8_t *)(Cmdtail+7));

	TIM2_init(999);
	PC3_enable();
	myADC3_TIM2_PC3();
	link_Ctask(&myCTL, timed_reading);
	//send info message to PC
	post_Cdevicemsg(&myCTL,timed_install_msg,CHARCOUNT(timed_install_msg));
	return;	// to Cmd_Handler()
}

void timed_pauseresume(void *Cmdtail)	// set/reset runflag
{	//Cmdtail will contain uint8_t Device, uint8_t Cmd, uint8_t Control in a hex ASCII string
	Timedcontrol.runflag= *((uint8_t *)Cmdtail);
	if(Timedcontrol.runflag==0)
		post_Cdevicemsg(&myCTL,timedpause_msg,CHARCOUNT(timedpause_msg));
	else
		post_Cdevicemsg(&myCTL,timedresume_msg,CHARCOUNT(timedresume_msg));
	return;	// to Cmd_Handler()

}


void timed_remove()	//turn off RedLED, remove RedLED task
{	//
	TIM2_disable();
	resetRedLED();
	unlink_Ctask(&myCTL);
	post_Cdevicemsg(&myCTL,timedremove_msg,CHARCOUNT(timedremove_msg)); //done AFTER task is unlinked ??TODO figure out why
}

//------ RedLED command dispatcher

void TimedVolt(void *Cmdtail)	//dispatched from Devicetable by Cmd_handler(). Enter with r0 pointing to the byte following the device code
{
	switch(*((uint8_t *)Cmdtail)) {
		case 0:	timed_install(Cmdtail+1); break; 		// hardware initialization and install blink task
		//case 1:	RedLED_update(Cmdtail+1); break; 		// new RedLED ontime/offtime
		case 1:	timed_pauseresume(Cmdtail+1);break;	// pause or resume blinking
		case 2:	timed_remove(); break; 		// remove RedLED from the task list
		default: post_Cdevicemsg(&myCTL,timed_badrequest_msg,CHARCOUNT(timed_badrequest_msg));
	}
}
