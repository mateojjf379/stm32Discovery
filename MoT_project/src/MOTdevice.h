//MOTdevice.h wmh 2019-04-12 : taskCTL data structure and Ctask functions used by MoT

#include <stdint-gcc.h>	//for uint8_t, uint16_t, uint32_t  etc. 
#include <stddef.h>		//for NULL

#define CHARCOUNT(string) (sizeof(string) -1)  //not including strings '\0'

typedef struct taskCTL {	//task control structure
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
uint32_t post_Cdevicemsg(taskCTL_t * pCTL, char * msgbody, uint32_t msglen); //send msglen bytes from msgbody; returns 0 if message has been placed in queue, returns >0 if previous message from same device is still in queue
