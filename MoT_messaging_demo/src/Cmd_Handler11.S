@; Cmd_Handler11.S wmh 2019-04-10 : adds suspend_Ctask, LINK_Ctask, UNLINK_Ctask, REDIRECT_Ctask functions
@; Cmd_Handler10.S wmh 2018-11-04 : improved name for the same code 
@; CoMul_dispatcher09.S wmh 2018-11-04 : adds dispatcher for serial command inputs to the cooperative multitasker
@; CoMul_dispatcher08.S wmh 2018-10-27 : dispatcher for serial command inputs to the cooperative multitasker
@;  - linked list of active tasks for better fit to embedded system problem (=single 'user' with predefined fixed set of device 'tasks')  
@;  - stateful coroutine 'Cmd_Handler()' running in alternation with stateful coroutine 'do_tasks()' rather than called by do_tasks() (r4 = rTASKP, r5= rCMDP)
@;	- command dispatching by branch (instead of call) from Cmd_Handler() for return back to main() ==> do_tasks() runs after each command.
@;	- task dispatching by call (instead of branch) from do_tasks()
@;	- commands self-install (add to Tasklist) their tasks; tasks can self-deinstall. 
@;	- all task's data structures are preallocated and initialized at system startup
@;	- buffered comm -- Cmd_Handler() gets commands from a message buffer rather than directly from comm port. 
@;  - smart Tasklist :  doubly linked list (PREV, NEXT) with permanent LAST task element;  LAST executes return to main()
@;	- mandatory task data structure starts with three words -- TASKp (coroutine resume addr), NEXTp, PREVp (list links), followed by anything else. 
@;	- thought: task's data initializations could be 'automatic' if task's record was in .data . !! a startup Tasklist in .data could be done this way!  
@;  - TODO: get commands by serial interrupt; make command buffer a ring buffer; add a new coroutine for sending messages to PC


/* 	Each device 'owns' a static data structure at its 'mydata' address
	struct 'mydata' {	
							void (*this_device)(void);		//resume-execution address of the device
							void *next;						//address of the next device's 'mydata'
							void *prev						//address of the previous device's 'mydata'
							...								// everything else the device needs to store
						}
	The Tasklist is a linked list of currently active devices. Linking and unlinking tasks is slightly harder than storing the task resume address in an array
	but now we always only scan 'live' tasks and we will never outgrow the tasklist or queue because everything is pre-allocated and doesn't grow. 					
*/			
 
	.syntax unified				@; ARM Unified Assembler Language (UAL). 
	.thumb						@; use thumb instructions only

	
@; ============ handy definitions

	rTASKP 	.req r4		@;current place in task list; system variable must be preserved through function calls, interrupts
	rCMDP	.req r5		@;resume address of Cmd_Handler function;  "" ; runs Cmd_Handler state machine
	rMSGP	.req r6
	.equ EOF,-1
	.equ NULL,0


	@; offsets of standard variables in each task's control structure
	.equ XEQ,0				@; offset in the device's task control structure to the device's coroutine resume-execution address
	.equ NEXT,4				@; offset in the device's task control structure to the next device in the Tasklist
	.equ PREV,8				@; offset in the device's task control structure to the next device in the Tasklist
	.equ MSGPTR,12			@;will hold pointer to this message's next character to print
	.equ MSGCOUNT,16		@;will hold count of remaining number of characters of message to print
	.equ MSGLINK,20			@;will hold pointer to data structure of next device with a message (if any)
	.equ DATAPTR,24			@;will hold pointer to task's own data
	
	@;offsets of fields in the message control structure 'MSG_list'
	.equ FIRSTMSG,0
	.equ LASTMSG,4
	
	
	
	
	.macro MOV_imm32 reg, constant
		movw \reg, #:lower16:\constant
		movt \reg, #:upper16:\constant
	.endm

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

@	.macro QUEUE_msg
	

@;===================== startup task data
	.data
	.align 2
	
	
@;define and initialize empty task list
	.global Tasklist_root
Tasklist_root:	
	.word NULL					@;at offset XEQ: root has no execution behavior
	.word Tasklist_last			@;at offset NEXT: nothing between root and last when starting
	.word NULL					@;at offset PREV: no predecessor
	.word NULL					@;at offset START_SP; used to restore stack pointer after C tasks have run				
	
.equ START_SP,12	
	
@; !! to create a task which starts at system startup, place task's control structure here and link it into list
	
	.global Tasklist_last
Tasklist_last:	
	.word do_tasks_return		@;at offset XEQ: back to do_tasks caller
	.word NULL					@;at offset NEXT: nothing after last
	.word Tasklist_root			@;at offset PREV: nothing between last and root when starting 
	

@;define and initialize empty message list
	.global MSG_list, MSGS_begin, MSGS_end
MSG_list:
MSGS_begin:	.word NULL			@;pointer to data of device with message underway or pending at offset FIRSTMSG
MSGS_end: 	.word NULL			@;pointer to last message on list at offset LASTMSG

@;===================== runtime data
	.bss
	.align 2
	
@; Cmd_Handler data structure definitions
	.equ CMD_CTRL,12			@;allocation value to hold read and write offsets and count (below)
	.equ CMD_RDINDX,(-12)		@;address 'handle' for INBUF is between control variables and data buffer
	.equ CMD_WRINDX,(-8)		@; ..
	.equ CMD_CNT,(-4)			@; ..
	.equ CMD_SIZE,(1<<8)		@;set limit for maximum command length to a power of 2;  makes ring-buffer code simpler (not implemented)

	
	@;data area for communication with controller
	.global Cmd_buf
	.align 2
	.comm Cmd_buf,(CMD_CTRL + CMD_SIZE)	@;sets us up for Cmd_buf 'handle' trick (handle is pointer into middle of data structure with params before and data after)

	
	.text

	@;The 'Devicetable' contains addresses of the entry point of each task or command operation defined for the system. 
	@ Incoming commands start with an operation ID (opID). The opID*4 = offset into the table holding the operation's entry point
	@;Whether a opID arrives in a command from the controller (PC) or is part of a system initialization list, it is used to 
	@;	index into the task table and dispatch the code for that task or. command. 
	@;
	@; A 'Command' is an opID that is executed but doesn't leave a follow-on task in the Tasklist 
	@; A 'Task' is an opID  that leaves a residual task in the Tasklist
	@; When 'Cmd_Handler' decodes a command message and dispatches the associated operation, the operation starts with r0 pointing
	@; to the command's binary 'tail' containing any further information needed. Typically, the first entry in the command tail
	@; is a function number which directs what the command is supposd to do.  See 'GreenLED.S' for an example.  
	.global Devicetable	 		@;holds pointers to Device dispatch code; currently there are only two devices
Devicetable:	
	.word Reset_Handler			@; Executing Reset_Handler restarts the system :0000
	.word GreenLED				@; init= :0100FF fast= :0101FE slow= :0102FD stop= :0103FC
	.word RedLED				@; init= :0200FE fast= :0201FD slow= :0202FC stop= :0203FB
	.word hello_USART3			@; initial testing of USART3-8266 interface
	.word Voltage				@; init= :04000000300001000101C9, pause= :040100FB, resume= :040101FA
	.word RedVoltage			@; init= :0500010101F8
	.word GreenVoltage			@; init= :0600010101F7
	.word TimedVolt				@; init= :0700010C110C130C15009B init_inter= :07000000010000000001F7
	@; *** other device entry points to follow here when they are developed ***

	.global suspend_Ctask
	.thumb_func
suspend_Ctask:	@; void suspend_Ctask(taskCTL_t * pCTL); //called at the end of tasks written as C functions 
	ldr rTASKP,[r0,#NEXT]		@;update task pointer to point next task's taskCTL block (needed by assembly tasks)
	ldr pc,[rTASKP,#XEQ]		@;start the next task

	.global link_Ctask
	.thumb_func	
link_Ctask:		@; void link_Ctask(taskCTL_t * pCTL, void (*CtaskXEQ)(void));
	ldr r2,[r0,#XEQ]			@;is this task is already installed?
	cbnz r2,1f					@;  yes -- DO NOT REINSTALL !!TODO give some sort of warning
	@;here if the device is not currently on the task list
	str r1,[r0,#XEQ]			@;install task entry point in taskCTL
	MOV_imm32 r2,Tasklist_root	@;get start of tasklist taskCTL in r2
	ldr r1,[r2,#NEXT]			@;get taskCTL of old first entry in list in r1
	str r0,[r2,#NEXT]			@;install this device's taskCTL as new first on list
	str r1,[r0,#NEXT]			@;install old first as next of this device
	str r2,[r0,#PREV]			@;and Tasklist_root as previous of this device
	str r0,[r1,#PREV]			@;link this device as previous of the old first

1:	bx lr
	
	.global unlink_Ctask
	.thumb_func	
unlink_Ctask:		@; void unlink_Ctask(taskCTL_t * pCTL);
	ldr r1,[r0,#NEXT]			@;r1= follow-on task's taskCTL
	ldr r2,[r0,#PREV]			@;r2= previous task's taskCTL
	str r1,[r2,#NEXT]			@;follow-on task is now previous task's NEXT
	str r2,[r1,#PREV]			@;previous is now follow-on task's PREV
	mov r1,#0					@;reset the unlinked tasks taskCTL values
	str r1,[r0],#4				@;	XEQ = NULL
	str r1,[r0],#4				@;	NEXT = NULL
	str r1,[r0],#4				@;	PREV = NULL
	str r1,[r0],#4				@;	MSGPTR = NULL
	str r1,[r0],#4				@;	MSGCOUNT = 0
	str r1,[r0],#4				@;	MSGLINK = NULL
	bx lr
	
	.global relink_Ctask	
	.thumb_func	
relink_Ctask:	@; void relink_Ctask(taskCTL_t * pCTL, void (*CtaskXEQ)(void));
	str r1,[r0,#XEQ]			@; install task's resume execution address
	bx lr

	
	.global do_tasks			@;void do_tasks(void); //called from while(1) loop in main()
	.thumb_func					
do_tasks: @;called by main() to execute the task list
	push {r7,lr}	
	MOV_imm32 r3,Tasklist_root	@; point task pointer ('rTASKP'=r4) to 1st entry on task list
	str sp,[r3,#START_SP]		@; save starting sp (C tasks exit without cleaning up stack)
	ldr rTASKP,[r3,#NEXT]		@; after this executes, rTASKP points to the XEQ field of the 1st task on the task list
	ldr pc,[rTASKP]				@;  off we go to the first task on the task list
	@; we will not return here; return to our caller is handled by do_tasks_return() called by the last task on the tsk list (see below)

	.global do_tasks_return
	.thumb_func
do_tasks_return:				@;execution behavior of Tasklist_last
	MOV_imm32 r3,Tasklist_root	@; point task pointer ('rTASKP'=r4) to 1st entry on task list for next go-around
	ldr sp,[r3,#START_SP]		@; restore starting sp (C tasks will have messed it up)
	pop {r7,pc}

	.global initCmd_Handler 	@;initialize command buffer indexes, set entry point at Cmd_wait_for_startchar()
	.thumb_func
initCmd_Handler:
	@;Cmd_buf is where commands are received and interpreted. It is not (yet) written as a ring-buffer so new commands re-zero the buffer
	MOV_imm32 r3,Cmd_buf
	mov r0,#0					
	str r0,[r3],#4				@;CMD_RDINDX
	str r0,[r3],#4				@;CMD_WRINDX
	str r0,[r3]					@;CMD_COUNT	
	MOV_imm32 rCMDP,Cmd_wait_for_startchar @;set command parser initial state
	bx lr						@;back to caller 
	
	.global Cmd_Handler 		@;processes commands received from the controller
	.thumb_func
Cmd_Handler: 					@;void Cmd_Handler(void); //called in main()'s while(1)
	@;this is the common entry point for dispatching Cmd_Handler-states
	push {r7,lr}				@; registers saved here will be restored by the Cmd_Handler state
	bx rCMDP					@; dispatch to the current state of Cmd_Handler

	.thumb_func
Cmd_wait_for_startchar:
	bl nbUSART1_getchar			@;returns >= 0 if char, return <0 if no new value
	cmp r0,#(':')
	beq	Cmd_have_startchar
	@; here if start char was not received
	MOV_imm32 rCMDP,Cmd_wait_for_startchar @;retry on next cycle
	pop {r7,pc}
	@;
Cmd_have_startchar: @; here when start char wss received
	@; reinitialize command-buffer control values
	MOV_imm32 r3,(Cmd_buf + CMD_CTRL)	@;Cmd_buf 'handle' (e.g. midpoint) in r3
	mov r2,#0					@;initialize counters
	str r2,[r3,#CMD_RDINDX]		@;reaching 'back' from handle for INBUF control values
	str r2,[r3,#CMD_WRINDX]		@;
	str r2,[r3,#CMD_CNT]		@; 
	@; fall through to start command  acquisition task 
	@;
	.thumb_func
Cmd_get_msg_evenchar:			@;message bytes all consist of a pair (even:odd) of hex ASCII bytes
	bl nbUSART1_getchar			@; getchar() returns r0 > 0 : success; r0 = 0 or negative : failure
	cmp r0,#0
	bgt Cmd_have_evenchar		@;we've received a new character
	@; here if nothing was received
	MOV_imm32 rCMDP,Cmd_get_msg_evenchar @;try again later
	pop {r7,pc}
	@;
Cmd_have_evenchar:				@; here when there's a new character
	cmp r0,#0x0A				@;test for newline (= end-of-message) of various flavors
	beq	Cmd_have_endchar		@; ..
	cmp r0,#0x0D				@; ..
	beq	Cmd_have_endchar		@; ..
	@; here if character was not end-of-message
	MOV_imm32 r3,(Cmd_buf + CMD_CTRL)	@;get Cmd_buf 'handle' in r3
	ldr r2,[r3,#CMD_WRINDX]		@;get offset to current write-location in the command buffer
	@;convert message character to binary and save value 
	@;no error checking -- assumes all message characters are legal hex ASCII 0-9 A-F
	cmp r0,#('9')				@;check if hi nybble character is 9 or below
	ite LS						@;	..
	subLS r0,#('0')				@;	if yes -- adjust for numeric '0' - '9' 
	subHI r0,#('A'-10)			@;  else adjust for alpha 'A' - 'F'
	lsl r0,#4					@;	save binary hi nybble value
	strb r0,[r3,r2]				@;  ..	
	@; fall through to odd char acquisition task 
	@;
	.thumb_func
Cmd_get_msg_oddchar:			@;message bytes all consist of a pair (even:odd) of hex ASCII bytes
	bl nbUSART1_getchar			@; getchar() returns r0 > 0 : success; r0 = 0 or negative : failure
	cmp r0,#0
	bgt Cmd_have_oddchar
	@; here if nothing was received
	MOV_imm32 rCMDP,Cmd_get_msg_oddchar @;try again later
	pop {r7,pc}
	@;
Cmd_have_oddchar: @; here if something was received 
	cmp r0,#0x0A				@;test for newline of various flavors !!newline here would be an error
	beq	Cmd_error_exit			@; ..
	cmp r0,#0x0D				@; ..
	beq Cmd_error_exit			@; ..
	@; here if character was not end-of-message
	MOV_imm32 r3,(Cmd_buf + CMD_CTRL)				@;get Cmd_buf 'handle' in r3
	ldr r2,[r3,#CMD_WRINDX]						@;get offset to current write-location in the command buffer
	@;convert message character to binary (assumes all message characters are legal hex ASCII 0-9 A-F
	cmp r0,#('9')		
	ite LS						@;	check if lo nybble's value is 9 or below
	subLS r0,#('0')				@;	if yes -- adjust for numeric '0' - '9' 
	subHI r0,#('A'-10)			@;  else adjust for alpha 'A' - 'F'		
	ldr r1,[r3,r2]				@;get hi nybble value of this byte
	add r1,r0					@; add lo nybble to it
	strb r1,[r3,r2]				@; and save it back
	adds r2,#1					@;  then update buffer pointer
	str r2,[r3,#CMD_WRINDX]		@; ..
	ldr r2,[r3,#CMD_CNT]
	adds r2,#1
	str r2,[r3,#CMD_CNT]
	MOV_imm32 rCMDP, Cmd_get_msg_evenchar @;continue getting  message 
	pop {r7,pc}
	@;
Cmd_have_endchar: @;here from Cmd_build_msg_even_char when '\n' (x0D or 0x0A) of message was received 
	MOV_imm32 r3,(Cmd_buf + CMD_CTRL)	@;Cmd_buf 'handle' in r3
	ldr r2,[r3,#CMD_WRINDX]		@;r2 points to end+1 of message body
	cmp r2,#0
	beq Cmd_error_exit			@; message body is empty
	@;
	@; ok so far, now do the checksum. 
	ldr r2,[r3,#CMD_CNT]	
	mov r0,#0
Cmd_check_format:
	ldrb r1,[r3],#1
	adds r0,r1
	subs r2,#1
	bhi Cmd_check_format
	@;checksum in r0 must=0
	and r0,0xFF					@;checksum is low 8 bits only
	cmp r0,#0
	bne Cmd_error_exit
	@;
Cmd_dispatch_command:	@;!!TODO -- check dispatch code against the length of Devicetable
	@;here with a valid command in the buffer 
	MOV_imm32 r2,Devicetable@;pointer to Devicetable in r2
	MOV_imm32 r0,(Cmd_buf + CMD_CTRL)@;pointer to start of msg in r0 
	ldrb r1,[r0],#1				@;get deviceID in r1; r0 now points to task fn#
	ldr r2,[r2,r1,LSL #2]		@;lookup command in Devicetable -- command entry address in r2
	blx r2						@;dispatch device / device function ; r0 points to device's fn# in the command buffer
Cmd_complete_exit:
	@; return here on command completion (no tail recursion). Since we only have one command buffer, command must be finished before we start another 
	@; !! we could also add an optional ACK message back to the controller her with some return code
	MOV_imm32 rCMDP, Cmd_wait_for_startchar	@;prepare to start parsing next command 
	pop {r7,pc}

Cmd_error_exit:	@;here if the message was empty or invalid (not hex ASCII or checksum fails) 
	@;!! todo : send NACK to controller to indicate some problem with the message
	bl initCmd_Handler			@;initialize command buffer indexes, set entry point at Cmd_wait_for_startchar()
	pop {r7,pc}					@; back to main() while(1)


	
