@; GreenLED03.S wmh 2018-11-12 : partial cleanup, some renaming
@; GreenLED02.S wmh 2018-11-12 : --works. handles messaging overwrites. 
@; The order of coroutines in main() helps: Cmd_Handler -> Msg_Handler -> do_task (which sometime we will rename Task_Handler)
@; Doing it this way lets commands override ongoing task messages (e.g. the 1-0-1-0.. of the demo) while letting us prevent
@; task messages from superceding command messages 
@; GreenLED01.S wmh 2018-11-10 : developing messaging
@; todo : .macro to build device data structure
@; GreenLED.S wmh 2018-10-29 : example task definition 
@	-- question : why aren't we using rTASKP for most for data access functions in GreenLED_init()?



@------------------ constant and macro definitions

@;------ system variable kept in register
	rTASKP 	.req r4			@;holds current place in task list; always valid on task entry


@;------ offsets of standard variables in task's control structure
	.equ XEQ,0				@; offset in the device's task control structure to the device's coroutine resume-execution address
	.equ NEXT,4				@; offset in the device's task control structure to the next device in the Tasklist
	.equ PREV,8				@; offset in the device's task control structure to the next device in the Tasklist
	.equ MSGPTR,12			@;will hold pointer to this message's next character to print
	.equ MSGCOUNT,16		@;will hold count of remaining number of characters of message to print
	.equ MSGLINK,20			@;will hold pointer to data structure of next device with a message (if any)

@;------ offsets of elements of message control structure 'Msgs_list'
	.equ HEAD_PTR,0
	.equ TAIL_PTR,4

@;------ hardware constants
	@; from constants defined in stm32f4xx.h 
	.equ	PERIPH_BASE,	0x40000000  @; Base address of : AHB/ABP Peripherals  
	.equ	AHB1PERIPH_BASE,(PERIPH_BASE + 0x00020000)

	.equ	RCC_BASE,(AHB1PERIPH_BASE + 0x3800)
	.equ 	RCC_AHB1ENR,0x30	@;RCC AHB1 peripheral clock enable register, Address offset: 0x30 

	.equ	GPIOG_BASE,(AHB1PERIPH_BASE + 0x1800)
	.equ	MODER,	0x00	@;  GPIO port mode register,	Address offset:	0x00	      
	.equ	OTYPER,	0x04	@;  GPIO port output type register,	Address offset:	0x04	      
	.equ	OSPEEDR,0x08	@;  GPIO port output speed register,	Address offset:	0x08	      
	.equ	OPUPDR,	0x0C	@;  GPIO port pull-up/pull-down register,	Address offset:	0x0C
	.equ	IDR,	0x10	@;  GPIO port input data register,	Address offset:	0x10	      
	.equ	ODR,	0x14	@;  GPIO port output data register,	Address offset:	0x14	      
	.equ	BSRR,	0x18	@;  GPIO port bit set/reset register,	Address offset:	0x18	      
	.equ	LCKR,	0x1C	@;  GPIO port configuration lock register,	Address offset:	0x1C	      
	.equ	AFRL,	0x20	@;  GPIO alternate function register low,	Address offset:	0x20
	.equ	AFRH,	0x24	@;  GPIO alternate function register high,	Address offset:	0x24 

@;------ utility macro
	.macro MOV_imm32 reg, constant
		movw \reg, #:lower16:\constant
		movt \reg, #:upper16:\constant
	.endm
	
@;------ macro used in MonT commands
	.macro LINK_me	mydata, myXEQ 	@; installs a device in the Tasklist
	@; this macro is placed at the exit of commands called from Cmd_Handler which install a device task on the task list
	@; 'mydata' is the address the task's data structure; task data structures are preallocated and optionally initialized at system startup
	@; 'myXEQ' is the device's execution-resume address.
	@; note: this macro is placed only at Cmd_Handler()'s exit point so we are free to use r0-r3 without consequences
	@; 
	MOV_imm32 r3,\mydata		@;pointer to this (new) device's task control structure in r3
	ldr r2,[r3,#XEQ]			@;check -- is this device already installed (
	cbnz r2,1f					@;  yes -- stop installation right now !!fix this if you can think of something better			
	MOV_imm32 r2,Tasklist_root	@;pointer to the Tasklist origin in r2
	ldr r1,[r2,#NEXT]			@;pointer to current first list element in r1
	MOV_imm32 r0,\myXEQ			@;pointer to the new device's entry point in r0
	str r0,[r3,#XEQ]			@; ..
	str r3,[r2,#NEXT]			@;link this device as new first on list
	str r3,[r1,#PREV]			@;link new first as previous of the old first
	str r1,[r3,#NEXT]			@;link old first as next of this device
	str r2,[r3,#PREV]			@;link list root as previous of this device
1:	@;installation skipped by jumping here from cbnz abovd
	.endm

@;------ macros used in MonT tasks
	.macro UNLINK_me mydata  	@; remove a device from the Tasklist
	@; this macro is placed at the exit of tasks which are removing themselves from the Tasklist
	@; removing a task from the Tasklist does not destroy the task's data so it could be part of a scheme to suspend rather than kill tasks
	@; because this is placed at the exit point back to main (via pop {r7,pc} ) we are free to use r0-r3
	@; 
	MOV_imm32 r3,\mydata		@;get address of (this device's) list element to be unlinked
	ldr r2,[r3,#PREV]			@;get element's predecessor in r2
	ldr r1,[r3,#NEXT]			@;get element's successor in r1
	str r1,[r2,#NEXT]			@;link old predecessor to old successor
	str r2,[r1,#PREV]			@;link old successor to old predecessor
	mov r0,#0					@; clear obsolete links
	str r0,[r3,#XEQ]			@; ..
	str r0,[r3,#NEXT]			@; ..
	str r0,[r3,#PREV]			@; ..
	.endm
		
	.macro RELINK_me newXEQ	@; redirect to another section of this device's routines
	@; this macro automates replacing the device task's resume address; 
	@; rTASKP points to the task's data element because we are in the task 
	MOV_imm32 r2,\newXEQ		@;get coroutine's entry address
	str r2,[rTASKP,#XEQ]		@; set up for next dispatch
	.endm
	
@;------ macro used in MonT messaging
	@; Messages are posted by invoking the macro MSG_post (below), which initializes some data then calls MSG_post_fn()
	@; User code must prevent a device from posting more than one message at
	@; a time. Doing so will break the message list by making it circular.
	@;
	.macro MSG_post mydata, msgtext, msglength	@;called by commands and tasks to put a message in the message queue
		push {r0-r3}			@;make safe as a macro
		
		MOV_imm32 r0,\mydata	@; record message's particulars in this device's data area
		MOV_imm32 r1,\msgtext	@; ..
		str	r1,[r0,#MSGPTR]		@; ..	
		MOV_imm32 r1,\msglength	@; ..
		str	r1,[r0,#MSGCOUNT]	@; ..
		bl MSG_post_fn			@; append this message to the message chain 
		
		pop {r0-r3}				@;restore and continue
	.endm

	
	
	
@;-------------------------- data and code	

	.syntax unified				@; ARM Unified Assembler Language (UAL) is allowed 
	.thumb						@; here we're use thumb instructions only

	.bss						@;all zeroed by startup
	.align 2					@;data is all word so should be on word-boundary; 
	.global GreenLED_data 		@;for visibility in debug
	
GreenLED_data:	@;origin of GreenLED data structure 
@;------ system variables: the required part of every device's data structure. Accessed by offsets .equ'd at top
	.global GreenLED_XEQ, GreenLED_NEXT, GreenLED_PREV 	@;unnecessary global labelsso as to be visible in debugger
	.global GreenLED_MSGPTR, GreenLED_MSGCOUNT, GreenLED_MSGLINK	
	@; using '.skip' to guarantee placement
	GreenLED_XEQ: 		.skip 4		@; offset XEQ holds task-resume address (standard for all tasks)
	GreenLED_NEXT:		.skip 4		@; offset NEXT holds link-address of next element in Tasklist (standard for all tasks)
	GreenLED_PREV:		.skip 4		@; offset PREV holds link-address of previous element in Tasklist (standard for all tasks)		
	GreenLED_MSGPTR:	.skip 4		@;pointer to this message's next character to print
	GreenLED_MSGCOUNT:	.skip 4		@;count of remaining number of characters of message to print	
	GreenLED_MSGLINK:	.skip 4		@;pointer to data structure of next device with a message (if any)
		
@;------ device variables: optional part of device data structure for  GreenLED device. Accessed by offsets .equ'd at top
	.global GreenLED_reload, GreenLED_count,GreenLED_flags  @; global for visibility in debug
	GreenLED_reload: 	.skip 4	 	@;value used to reload count after timerout (special for this task)						
	GreenLED_count:	 	.skip 4		@;current value of  downcount used to determine blink rate (special for this task)						
	GreenLED_flags:	 	.skip 4		@;used to prevent green LED 'ON' and 'OFF' tasks from sending multiple status messages
							
	@;definitions to make code more understandable (use calculated in case data structure is changed)
	.equ GLED_RELOAD,(GreenLED_reload - GreenLED_data)	@;calculated offset in GreenLED_data to reload value
	.equ GLED_COUNT,(GreenLED_count - GreenLED_data)	@;calculated offset in GreenLED_data to count value
	.equ GLED_FLAGS,(GreenLED_flags - GreenLED_data)	@; not used

	.text
@;------ Green_LED messages
	Green_LED_init_msg:
	.ascii "Install GreenBlinky\n\r"
	.equ Green_LED_init_msglen,( . - Green_LED_init_msg)
	
	Green_LED_fast_msg:
	.ascii "Fast GreenBlinky blink\n\r"
	.equ Green_LED_fast_msglen,( . - Green_LED_fast_msg)

	Green_LED_slow_msg:
	.ascii "Slow GreenBlinky blink\n\r"
	.equ Green_LED_slow_msglen,( . - Green_LED_slow_msg)

	Green_LED_remove_msg:
	.ascii "Remove GreenBlinky\n\r"
	.equ Green_LED_remove_msglen,( . - Green_LED_remove_msg)

	Green_LED_ON_msg:
	.ascii "1\n\r"
	.equ Green_LED_ON_msglen,( . - Green_LED_ON_msg)

	Green_LED_OFF_msg:
	.ascii "0\n\r"
	.equ Green_LED_OFF_msglen,( . - Green_LED_OFF_msg)
	
	.align 1 @;!!important to do this wherever we have inline messages ! 
	@;not doing this when putting text inline with code will randomly lead to 'Error: unaligned opcodes detected in executable segment'
	
@;------ Green_LED dispatcher
	.global GreenLED	
	.thumb_func					
GreenLED: @;Cmd_handler() branches here after identifying a valid command with device ID = 'GreenLED'
	push {r7,lr}		@;this 'push' is balanced with a 'pop' at exit of each of the routines of the dispatch table below
	
	ldrb r1,[r0],#1		@;read function code from the command buffer and advance r0 to point to the command's argument list (if any) 
	and r1,0x03			@;limit range of functions codes 0-3 for safety (error-checking would be nice but isn't done here)
	@; GreenLED function byte meanings
	@;	0: install - initalize GreenLED hardware and data and place GreenLED ON and OFF tasks on the task list
	@;	1: change blinking schedule to 'fast'
	@;	2: change blinking schedule to 'slow'
	@;  3: remove - remove GreenLED ON and OFF from the task list
	tbb [pc,r1]
GreenLED_cmd_table:
	.byte (GreenLED_init - GreenLED_cmd_table)/2	  	@;hardware initialization and install blink task
	.byte (GreenLED_fast - GreenLED_cmd_table)/2	  	@;change blink rste to fast standard
	.byte (GreenLED_slow - GreenLED_cmd_table)/2	  	@;change blink rste to slow standard 
	.byte (GreenLED_stop - GreenLED_cmd_table)/2		@;remove GreenLED from the task list
	.align 1 @;!!important to do this where odd-byte aligement is possbile 

@;------ GreenLED commands 
	@; commands below are dispatched by Cmd_Handler() in main() using the tbb (above) on the command's function number
	@; commands on entry have r0 pointing to the 'argument' (if any) of the command

	.global GreenLED_init	@;taskID=1, function number=0		
	.thumb_func
GreenLED_init: @; arrive here from Cmd_Handler with r0 pointing to function argument (not used by this device) 
	@;initialize blinking rate-control values
	mov r1,#0								
	MOV_imm32 r3,GreenLED_data 				
	str r1,[r3,#GLED_RELOAD]				
	str r1,[r3,#GLED_COUNT]	
	str r1,[r3,#GLED_FLAGS]

	@;put 'init' message on message list !!TODO - make 'CMD_add_message' a macro
	ldr r1,[r3,#MSGCOUNT]				@;is there a GreenLED message already on the message list?
	cbz r1,1f								@ no -- put it there
	@;here when some GreenLED message is on the message list currently
	MOV_imm32 r1,Green_LED_init_msg 		@; replace current Green_LED message in list with init message
	str r1,[r3,#MSGPTR]						@; ..
	MOV_imm32 r1,Green_LED_init_msglen 		@; ..
	str r1,[r3,#MSGCOUNT]					@; ..
	b 2f									@; skip new posting, start task
	
1:	@; post new GreenLED message on list	
	MSG_post GreenLED_data, Green_LED_init_msg, Green_LED_init_msglen

2:	@; add GreenLED_on task to task list
	LINK_me	GreenLED_data,GreenLED_on		@;insert task 'GreenLED_on' on Tasklist

	
	@; configure PG13 to drive LD3 (green LED)
	@; make sure GPIOG is enabled
	ldr r3,=RCC_BASE
	ldr r2,[r3,#RCC_AHB1ENR]
	orr r2,#(1<<6)		@; set enable bit
	str r2,[r3,#RCC_AHB1ENR]
	
	@; configuring PG13
	ldr r3,=GPIOG_BASE
	
	@; configure PG13 as an output
	ldr r2,[r3,#MODER]
	bic r2,#(3<<(2*13))						@;clear current value if any of PG13 mode
	orr	r2,#(1<<(2*13))						@;set new value of PG13 mode to general purpose  output
	str r2,[r3,#MODER]						@; ..
	
	@; configure output on PG13 as push/pull
	ldr r2,[r3,#OTYPER]
	bic r2,#(1<<(1*13))						@;clear control bit 
	str r2,[r3,#OTYPER]						@; ..

	@; configure output on PG13 as high speed 
	ldr r2,[r3,#OSPEEDR]
	bic r2,#(3<<(2*13))						@;clear current value if any of control bits
	orr	r2,#(2<<(2*13))						@;set new value of PG13 mode high speed
	str r2,[r3,#OSPEEDR]					@; ..

	@; configure output on PG13 as no pullup, pulldown
	ldr r2,[r3,#OPUPDR]
	bic r2,#(3<<(2*13))						@;clear current value if any of control bits
	str r2,[r3,#OPUPDR]						@; ..
		
	pop {r7,pc}								@;this 'pop' is balances the 'push' done at entry label GreenLED above; returns to Cmd_Handler

	.global GreenLED_slow @;taskID=1, function number=1		
	.thumb_func
GreenLED_slow: @; arrive here from Cmd_Handler with r0 pointing to function argument if any (not used for GreenLED commands)
/*
	@; First, append 'slow' message to message list if possible.  Message will probably be lost if GreenLED 'on' or 'off' task 
	@;	is already running. This is because ON and OFF tasks send a message each time they start, so this device's 
	@;  opportunity to send messages is probably completely used up by the continuous message stream generated by ON and OFF 
	MSG_post GreenLED_data, Green_LED_slow_msg, Green_LED_slow_msglen
	@;If message wasn't sent it is probably lost because we won't be retrying this.
	@; !!idea -- put call to Msg_Handler() ahead of call to do_tasks() in main(), to give command messages priority.  
	mov r1,#0								@;suppress task message until command has reported 
	str r1,[r3,#GLED_FLAGS]					@; ..
	MOV_imm32 r1,0x12345					@;set a new reload value for GreenLED blink delay						
	MOV_imm32 r3,GreenLED_data 				@; ..				
	str r1,[r3,#GLED_RELOAD]				@; ..	
	@; append 'slow' message to message list if possible (message will not be added if another message is still being sent
	MSG_post GreenLED_data, Green_LED_slow_msg, Green_LED_slow_msglen
	@;return value is lost so if message wasn't sent it is lost
	pop {r7,pc}								@;  then back to Cmd_Handler 
*/
	@;put 'slow' message on message list
	ldr r1,[r3,#MSGCOUNT]					@;is there a GreenLED message already on the message list?
	cbz r1,1f								@ no -- put it there
	@;here when some GreenLED message is on the message list currently
	MOV_imm32 r1,Green_LED_slow_msg 		@; replace current Green_LED message in list  
	str r1,[r3,#MSGPTR]						@; ..
	MOV_imm32 r1,Green_LED_slow_msglen 		@; ..
	str r1,[r3,#MSGCOUNT]					@; ..
	b 2f									@; skip new posting, start task
	
1:	@; post new GreenLED message on list	
	MSG_post GreenLED_data, Green_LED_slow_msg, Green_LED_slow_msglen

2:	@; change GreenLED delay count
	MOV_imm32 r1,0x12345					@;set a new values for GreenLED blink delay						
	MOV_imm32 r3,GreenLED_data 				@; ..				
	str r1,[r3,#GLED_RELOAD]				@; ..	
	str r1,[r3,#GLED_COUNT]					@; ..

	pop {r7,pc}								@;this 'pop' is balances the 'push' done at entry label GreenLED above; returns to Cmd_Handler

						
	.global GreenLED_fast @;taskID=1, function number=2		
	.thumb_func
GreenLED_fast: @; arrive here from Cmd_Handler with r0 pointing to function argument if any (not used for GreenLED_xxx commands) 
	@;put 'fast' message on message list
	ldr r1,[r3,#MSGCOUNT]				@;is there a GreenLED message already on the message list?
	cbz r1,1f								@ no -- put it there
	@;here when some GreenLED message is on the message list currently
	MOV_imm32 r1,Green_LED_fast_msg 		@; replace current Green_LED message in list  
	str r1,[r3,#MSGPTR]						@; ..
	MOV_imm32 r1,Green_LED_fast_msglen 		@; ..
	str r1,[r3,#MSGCOUNT]					@; ..
	b 2f									@; skip new posting, start task
1:	@; post new GreenLED message on list	
	MSG_post GreenLED_data, Green_LED_fast_msg, Green_LED_fast_msglen
2:	@; change GreenLED delay count
	MOV_imm32 r1,0x1234					@;set a new values for GreenLED blink delay						
	MOV_imm32 r3,GreenLED_data 				@; ..				
	str r1,[r3,#GLED_RELOAD]				@; ..	
	str r1,[r3,#GLED_COUNT]					@; ..

	pop {r7,pc}								@;  then back to Cmd_Handler 

	.global GreenLED_stop @;taskID=1, function number=3		
	.thumb_func
GreenLED_stop: @; !!not fixed yet arrive here from Cmd_Handler with r0 pointing to function argument if any (not used for GreenLED_xxx commands)
/*	@; turn off the Green LED
	ldr r3,=GPIOG_BASE						@;get current GPIOG port values
	ldr r2,[r3,#IDR]						@; ..
	bic r2,r2,#(1<<(1*13))					@;turn off green LED
	str r2,[r3,#ODR]						@;update GPIOG port values
	UNLINK_me GreenLED_data
	@; append 'stop' message to message list if possible (message will not be added if another message is still being sent
 	MSG_post GreenLED_data, Green_LED_remove_msg, Green_LED_remove_msglen
	@;return value is lost so if message wasn't sent it is lost	!!??fix this?
*/
	@;put 'remove' message on message list
	ldr r1,[r3,#MSGCOUNT]					@;is there a GreenLED message already on the message list?
	cbz r1,1f								@ no -- put this one there
	@;here when some GreenLED message is on the message list currently
	MOV_imm32 r1, Green_LED_remove_msg		@; replace current Green_LED message in list  
	str r1,[r3,#MSGPTR]						@; ..
	MOV_imm32 r1,Green_LED_remove_msglen	@; ..
	str r1,[r3,#MSGCOUNT]					@; ..
	b 2f									@; skip new message posting, go remove task
	
1:	@; post new GreenLED message on list	
 	MSG_post GreenLED_data, Green_LED_remove_msg, Green_LED_remove_msglen

2:	@; turn off the Green LED
	ldr r3,=GPIOG_BASE						@;get current GPIOG port values
	ldr r2,[r3,#IDR]						@; ..
	bic r2,r2,#(1<<(1*13))					@;turn off green LED
	str r2,[r3,#ODR]						@;update GPIOG port values
	UNLINK_me GreenLED_data					@;remove me from the task list
	
	pop {r7,pc}								@;this 'pop' is balances the 'push' done at entry label GreenLED above; returns to Cmd_Handler	

	
@;------ GreenLED tasks 
	@; 'tasks' are dispatched by do_tasks() in main() !! TODO - make 'TASK_add_message' a macro

	.global GreenLED_on @;task which counts down, blinks and restarts timer
	.thumb_func
GreenLED_on: @;arrive here with rTASKP = GreenLED_data
	ldr r2,[rTASKP,#GLED_RELOAD]			@; reload value = 0 says no blinking 
	cbz r2,1f								@;  not blinking so skip to exit
	@; here if blinking  
	ldr r2,[rTASKP,#MSGCOUNT]				@; check if message is busy
	cbnz r2,3f								@;  message is busy -- can't post new message and tasks can't overwrite existing messages
	@; here if message is not busy -- append 'ON' message to message list
	MSG_post GreenLED_data, Green_LED_ON_msg, Green_LED_ON_msglen 
	@;here with Green_LED_ON_msg posted
	
	@;update task resume point -- will skip the above tests while this branch of this task continues to run
	RELINK_me GreenLED_on_msg_posted		
	.global GreenLED_on_msg_posted
	.thumb_func
GreenLED_on_msg_posted:	
3:	ldr r2,[rTASKP,#GLED_RELOAD]			@; get counter reload value
	cbz r2,1f								@; skip remaining operation of task if its 0 (=initial value and halted value)
	ldr r1,[rTASKP,#GLED_COUNT]				@; otherwise get the current count
	cbz r1,2f								@; prepare for next countdown if its 0
	subs r1,#1								@;  otherwise decrement it 
	str r1,[rTASKP,#GLED_COUNT]				@;  and store it back
	@; turn on the Green LED
	ldr r3,=GPIOG_BASE						@;get current GPIOG port values
	ldr r2,[r3,#IDR]						@; ..
	orr r2,r2,#(1<<(1*13))					@;turn on bit 13 
	str r2,[r3,#ODR]						@;update GPIOG port values
	b	1f									@; go to exit to the next task
2:	@; here when repeat count reaches 0	
	ldr r2,[rTASKP,#GLED_RELOAD]			@; restart count for GreenLED_off_msg phase of this task
	str r2,[rTASKP,#GLED_COUNT]				@;  ..
	RELINK_me GreenLED_off					@; update task resume point as GreenLED_off_msg
1:	@; task for this device is done for now -- proceed to next device/task on list
	ldr	rTASKP,[rTASKP,#NEXT]				@; rTASKP points to next task 
	ldr pc,[rTASKP,#XEQ]					@; dispatch next task on list   ..

	
	.global GreenLED_off @; counts down, blinks and restarts timer
	.thumb_func
GreenLED_off: @;arrive here with rTASKP = GreenLED_data
	ldr r2,[rTASKP,#GLED_RELOAD]			@; reload value = 0 says no blinking 
	cbz r2,1f								@;  no blinking so skip to exit
/*
	@; here if blinking  
	ldr r2,[rTASKP,#GLED_FLAGS]				@; check if 'OFF' message has been sent 
	cbz r2,3f								@;   if yes then don't resend it
	@; else append 'OFF' message to message list
	MSG_post GreenLED_data, Green_LED_OFF_msg, Green_LED_OFF_msglen
	@;here with r0=0 if message post was successful
	cbnz r0,3f								@;message post was _not_ successful; will keep trying
	@;here when Green_LED_OFF_msg has been posted
@;	str r0,[rTASKP,#GLED_FLAGS]				@;   mark that 'OFF' message has been sent (!!bad style/cheap reuse of '0 in r0
	mov r2,#0								@;   mark that 'OFF' message has been sent
	str r2,[rTASKP,#GLED_FLAGS]				@;    ..
*/
	@; here if blinking  
	ldr r2,[rTASKP,#MSGCOUNT]				@; check if message is busy
	cbnz r2,3f								@;  message is busy -- can't post and tasks can't overwrite running messages
	@; here if message is not busy -- append 'OFF' message to message list
	MSG_post GreenLED_data, Green_LED_OFF_msg, Green_LED_OFF_msglen 
	@;here with Green_LED_OFF_msg posted

	@;update task resume point -- will skip the above tests while this task continues to run
	RELINK_me GreenLED_off_msg_posted		
	.global GreenLED_off_msg_posted
	.thumb_func
GreenLED_off_msg_posted:		
3:	ldr r2,[rTASKP,#GLED_RELOAD]			@; get counter reload value
	cbz r2,1f								@; exit if its 0 (=initial value and halted value)
	ldr r1,[rTASKP,#GLED_COUNT]				@; otherwise get the current count
	cbz r1,2f								@; prepare for next countdown if its 0
	subs r1,#1								@;  otherwise decrement it 
	str r1,[rTASKP,#GLED_COUNT]				@;  and store it back
	@; turn off the Green LED
	ldr r3,=GPIOG_BASE						@;get current GPIOG port values
	ldr r2,[r3,#IDR]						@; ..
	bic r2,r2,#(1<<(1*13))					@;turn off bit 13 
	str r2,[r3,#ODR]						@;update GPIOG port values
	b	1f									@; go to exit to the next task
2:	@; here when counter reaches 0	
	ldr r2,[rTASKP,#GLED_RELOAD]			@; restart count
	str r2,[rTASKP,#GLED_COUNT]				@;  ..
	mov r2,#1								@; reset flag to allow 'ON' message to be sent
	str r2,[rTASKP,#GLED_FLAGS]				@;  ..
	RELINK_me GreenLED_on					@; update task resume point
1:	@;this task is done -- proceed to next task on the list
	ldr	rTASKP,[rTASKP,#NEXT]				@; rTASKP points to next task
	ldr pc,[rTASKP,#XEQ]					@; dispatch next task on list   ..
 







