@;Msg_Handler03.S wmh 2019-04 10 : adding messaging functions for C tasks and commands
@;Msg_Handler01.S wmh 2018-11-06 : begin development

	.syntax unified				@; ARM Unified Assembler Language (UAL). 
	.thumb						@; use thumb instructions only

	@; system variable kept in register
	rTASKP 	.req r4			@;holds current place in task list; always valid on function entry
	
	@; offsets of standard variables in task's control structure
	.equ XEQ,0				@; offset in the device's task control structure to the device's coroutine resume-execution address
	.equ NEXT,4				@; offset in the device's task control structure to the next device in the Tasklist
	.equ PREV,8				@; offset in the device's task control structure to the next device in the Tasklist
	.equ MSGPTR,12			@;will hold pointer to this message's next character to print
	.equ MSGCOUNT,16		@;will hold count of remaining number of characters of message to print
	.equ MSGLINK,20			@;will hold pointer to data structure of next device with a message (if any)

	.macro MOV_imm32 reg, constant
		movw \reg, #:lower16:\constant
		movt \reg, #:upper16:\constant
	.endm

	@;-------- message posting 
	@; Messages are posted by invoking the macro MSG_post (below), which initializes some data then calls MSG_post_fn()
	@; User code must prevent a device from posting more than one message at
	@; a time. Doing so will break the message list by making it circular.
	@;
	.macro MSG_post mydata, msgtext, msglength	@;called by a command or task to put a message in the message queue
		push {r0-r3}			@;make safe as a macro
		
		MOV_imm32 r0,\mydata	@; record message's particulars in this device's data area
		MOV_imm32 r1,\msgtext	@; ..
		str	r1,[r0,#MSGPTR]		@; ..	
		MOV_imm32 r1,\msglength	@; ..
		str	r1,[r0,#MSGCOUNT]	@; ..
@;		mov r1,#0				@; zero the 'next message' link (messages are always appended at the end of the chain)
@;		str	r1,[r0,#MSGLINK]	@; (now done in MSG_post_fn() ) 
		bl MSG_post_fn			@; append this message to the message chain 
		
		pop {r0-r3}				@;restore and continue
	.endm

	.global post_Cdevicemsg
	.thumb_func
post_Cdevicemsg: @; uint32_t post_Cdevicemsg(taskCTL_t * pCTL, char * msgbody, uint32_t msglen); //send msglen bytes from msgbody; returns 0 if message has been placed in queue, returns >0 if previous message from same device is still in queue
	@;called by Cdevice commands or tasks
	push {r7,lr}
	ldr r3,[r0,#MSGCOUNT]	@;is another message from this device still in the message queue?
	cbz r3,1f				@;  no -- put the message on the queue
	mov r0,r3				@;  yes -- abort sending and return count of existing message still not sent
	pop {r7,pc}				@; 	..
1:	@;here to add message to the message queue
	str r1,[r0,#MSGPTR]		@;store control values 
	str r2,[r0,#MSGCOUNT]	@; ..
	MOV_imm32 r3,Msgs_list	@;get pointer to message currently at head of message list
	ldr r2,[r3,#HEAD_PTR]	@;  in r2
	cbz r2,2f				@;if list is empty then new message at r0 is both first and last			
	@;here when there's at least one device message on the list 
	ldr r2,[r3,#TAIL_PTR]	@;r2 now points to  message at the tail of the message list
	str	r0,[r2,#MSGLINK]	@;  that device's message now chains to our device's message 
	str	r0,[r3,#TAIL_PTR]	@; and we become the last message
	b 3f
2: 	@;here if message queue is empty	
	str r0,[r3,#HEAD_PTR]	@;make this message first on the list
	str r0,[r3,#TAIL_PTR]	@; and also last

3:	mov r1,#0				@; zero the new message's 'next message' link 
	str	r1,[r0,#MSGLINK]	@; .. 

	mov r0,#0				@; returning 0 signals "message is in queue" 

 	pop {r7,pc}				@;  back to C device
	
	
	
	
	
	@;----------------------------------------------------------------------
	.data
	
	.align 2		@;data is all word so should be on a word-boundary; 
	@; ---- system data. holds pointers to head and tail of message list
	.global Msgs_list, Msgs_head, Msgs_tail
Msgs_list: @;system data. holds pointers to head and tail of message list
Msgs_head:
	.skip 4
Msgs_tail:
	.skip 4
	
	@;offsets of elements of message control structure 'Msgs_list'
	.equ HEAD_PTR,0
	.equ TAIL_PTR,4

	
	@;------------------------------------------------------------------------	
	.text

	
	
	
	@; -------------- message posting macro-assist
	.global MSG_post_fn @; place a message in message queue
	.thumb_func
MSG_post_fn: @;void _MSG_post(device_data *) appends message to message list. 
@; low-level function designed to be called by Msg_post macro. 
	push {r7,lr}

	@;arrive here with r0 pointing to data of device with a message to be added
	MOV_imm32 r3,Msgs_list					@;get pointer to message at head of message list
	ldr r2,[r3,#HEAD_PTR]					@;  in r2
	cbz r2,1f								@;if list is empty then new message at r0 is both first and last			
	@;here when there's at least one device message on the list 
	ldr r2,[r3,#TAIL_PTR]					@;r2 now points to  message at the tail of the message list
	str	r0,[r2,#MSGLINK]					@;  that device's message now chains to our device's message 
	str	r0,[r3,#TAIL_PTR]					@; and we become the last message
	b 2f
1: 	@;here if message queue is empty	
	str r0,[r3,#HEAD_PTR]					@;make this message first on the list
	str r0,[r3,#TAIL_PTR]					@; and also last

2:	mov r1,#0								@; zero the new message's 'next message' link 
	str	r1,[r0,#MSGLINK]					@; .. 

 	pop {r7,pc}								@;  back to Msg_post macro

	
	@;------------ test message handler
	.global initMsg_Handler 	@;clear any messages waiting on the message list, reset list to empty
	.thumb_func
initMsg_Handler: @;void initMsg_Handler(void);
	MOV_imm32 r3,Msgs_list
	ldr r2,[r3,#HEAD_PTR]
	ldr	r3,[r3,#TAIL_PTR]		
	orr r0,r2,r3
	cbz r0,1f	@;list is already empty
	@;here when there's at least one device entry on the list
	mov r0,#0					@;clear message controls of message being deleted
2:	ldr r1,[r2,#MSGLINK]		@;link to next message (if any) in r1
	str r0,[r2,#MSGLINK]		@; clear device message controls	
	str r0,[r2,#MSGPTR]			@; ..
	str r0,[r2,#MSGCOUNT]		@; ..
	cbz r1,1f					@;done if message just deleted has no successors
	mov r2,r1					@; else move to the successor message
	b 2b						@;  for more cleanout
1:	str r0,[r3,#TAIL_PTR]		@;clear TAIL_PTR pointer !!a concern? if the linked list was somehow broken, then there might be orphans
	bx lr						@;back to caller 


	.global Msg_Handler @; coroutine executing round-robin with do_tasks()
	@; tries to send a character from the message string each time it runs;
	@; loads the next message string in MSGLINK when th current string is empty
	.thumb_func
Msg_Handler: @;message* Msg_Handler(void); //called in main()'s while(1)
	push {r7,lr}
	
	MOV_imm32 r3,Msgs_list
	ldr r2,[r3,#HEAD_PTR]					@;get link to data structure of current message
	@;-- here with r2=0 if no messages, else r2=address of device data structure containing the message control variables
	cbz r2,1f								@; list is empty, so leave
	
2:	@;(future) might loop here in the case where multiple characters of the message might be sent at once
	.global Msg_sender	@;global for debugger visibility
	.thumb_func							
Msg_sender:  @; here to send next character of message; removes message from list when they have been sent
	@;here with r2=address of device data structure containing the message control variables
	ldr r1,[r2,#MSGPTR]						@;pointer to next message character in r1
	ldrb r0,[r1],#1							@;  next message character in r0 
	@;attempt to send message character
	push {r2,r3}							@; nbUSART1_putchar takes/returns r0 and uses r2,r3
 	bl nbUSART1_putchar						@;non-blocking; returns +1 if char sent, -1 if fail to send
@;	bl bUSART1_putchar						@;!!debug using blocking; 
@;	mov r0,#1								@; fake nbUSART1_putchar() return 'success'
	pop {r2,r3}
	subs r0,#1								@;check if function's return in r0 =1 (character was sent)
	@;-- here with r2=address of device data structure containing the message control variables
	cbnz r0,1f								@;  send was blocked, so done for now -- leave (nothing is changed)
	@;here if the character was sent
	str r1,[r2,#MSGPTR]						@;update message pointer
	ldr r1,[r2,#MSGCOUNT]					@;update message count and test if =0
	subs r1,#1								@; (sets ZF if count reached 0)
	str r1,[r2,#MSGCOUNT]					@; .. 
@;	bne 2b	@; when burst-sending, attempts to send the nextcharacter of the message
	@; -- here with r2=address of device data structure containing the message control variables 
	bne 1f									@; message not done-- initially we'll only send one character at a time
	@;here if message count has reached 0 (message done)
	mov r1,#0								@;make MSGPTR=0 (MSGCOUNT=0 from above)
	str r1,[r2,#MSGPTR]						@; ..
	@;here to remove msg link of this message from list
	ldr r0,[r2,#MSGLINK]					@;get address (if exist) of next message in list in r0
	str r1,[r2,#MSGLINK]					@;  then clear (write NULL) to this device's link
	mov r2,r0								@; maintain consistent meaning for r2 as address of device data structure
	cbz r2,3f								@;if link was null then list is empty so reset the list pointers to NUL 
	@;here when another message follows this one on the list -- make it new first on list
	MOV_imm32 r3,Msgs_list					@; unnecessary/duplicative -- done 'just in case'
	str r2,[r3,#HEAD_PTR]					@;make this message's next message the new first message
	@; -- here with r2=address of next device data structure containing a message
	b 1f
@;	b 2b  @; when burst-sending, attempts to start the next message on the list

3:  @;here if no more messages on list ( r2=0 )
	MOV_imm32 r3,Msgs_list				@; unnecessary/duplicative -- done 'just in case'							@;unnecessary/duplicative -- done 'just in case'		
	str r2,[r3,#HEAD_PTR]					@;mark message list as empty
	str r2,[r3,#TAIL_PTR]					@; ..
	
1:	@;here with r2=0 if nothing more to send, o.w. = address of device control array
	mov r0,r2								@;function returns address of continuing or new message, else returns 0 
	pop {r7,pc}								@;							

	
	

	@;----------------------- test device message maker

	.data
	.align 2		@;data is all word so should be on word-boundary; 

	.global  phonyDEV_data	//empty phony device data for Msg_Handler test	
phonyDEV_data:	@;origin of  testDEV data structure
	.skip 24
	
	
	.text
	
	.global Msg_Handler_phony_post //toy post of message to test Msg_Handler
	.thumb_func
Msg_Handler_phony_post:
	push {r7,lr}
	@;phony message needs phony task
	@;initialize message control  for this 'task'
	MSG_post phonyDEV_data, phonyDEV_msg,(phonyDEV_msg_end - phonyDEV_msg)
	pop {r7,pc}

	@; DEV_initmsg is stored in FLASH (below)
	@; 
 phonyDEV_msg:
	.ascii "1234567890\n" 
 phonyDEV_msg_end:
	.align 1 @;!!important to do this ! 
	@;not doing this when putting text inline with code will randomly lead to 'Error: unaligned opcodes detected in executable segment'

