@;myDataOps02.S wmh 2017-09-09 : demo pseudo-op  'ldr r0,=Dword' 
@;myDataOps01.S wmh 2017-09-04 : ARM data instruction examples

@; --- characterize target syntax, processor
	.syntax unified				@; ARM Unified Assembler Language (UAL). 
								@; Code written using UAL can be assembled 
								@; for ARM, Thumb-2, or pre-Thumb-2 Thumb
	.thumb						@; but here we'll use thumb instructions only

@; --- constant definitions (locally symbol macros -- these do not use storage)
	.equ silly,0x12345678
	
@; --- _initialized_ RAM data					
	.data						@; keyword '.data' starts the _initialized_ RAM data section
	.align 2					@; .align's argument is power of 2, so this pads memory to start on 4-byte (e.g. word) boundary
	.global Dword				@; this makes variable 'Dint' visible everywhere in the program (C and asm sources) 
Dword: 	.word  0xAAAA5555   	@; Dword is 32-bits
Static: .word 0x00000000

 @; --- _uninitialized_ RAM data	
	.bss						@; keyword 'bss' starts the _uninitialized_ RAM data section				 
	.align	2					@; pad to word-boundary
global_bss_begin:				@; marker for start of  global .bss variables
	.comm	Garray,256			@; 256 bytes of static storage starting at global label 'Garray'
	.comm	Gword,4				@; 4 bytes of static storage starting at global label 'Gword'
	.comm	Ghalf,2				@; 2 bytes of static storage starting at global label 'Ghalf'
	.comm	Gbyte,1				@; 1 byte of static storage starting at global label 'Gbyte'
	
	.align	2					@; pad to word-boundary
local_bss_begin:				@; marker for start of  local .bss variables
	.lcomm	Larray,256			@; 256 bytes of static storage starting at local label 'Larray'
	.lcomm	Lword,4				@; 4 bytes of static storage starting at local label 'L
	.lcomm	Lhalf,2				@; 2 bytes of static storage starting at local label 'L
	.lcomm	Lbyte,1				@; 1 byte of static storage starting at local label 'L
	

@; --- program memory and constant data
	.text						@;keyword '.text' starts the code section (in ROM)
	
@; --- strncpy function -----------------
	.global strncpy
	.thumb_func
strncpy:
	mov r4, #0					@; initialize r4 and r5 to 0
	mov r5, #0
	push {r0}
loop_strncpy:
	ldrb r3, [r1], #1			@; loads char by char into r3
	cmp r3, #0					@; checks if we have reached the end if the string
	beq check_n
	cmp r4,r2					@; checks if the counter has reached "n"
	bhs end_strncpy				@; if "n" characters reached, leave the loop
	strb r3, [r0], #1			@; stores char into new string
	adds r4, r4, #1				@; updates counter
	b loop_strncpy
check_n:
	cmp r4,r2					@; if the end of string has been reached, then pad with zeros
	bhs end_strncpy
	strb r5, [r0], #1			@; put as many zeros as needed to reach "n" chars copied
	adds r4, r4, #1
	b check_n
end_strncpy:
	pop {r0}					@; return to initial r0
	bx lr

@; --- strncat function -----------------
	.global strncat
	.thumb_func
strncat:
	mov r4, #0						@; initialize r4,r5 to 0
	mov r5, #0
	push {r0}						@; pushes initial address
check_before:
	ldrb r3, [r0], #1				@; we need to go to the last char of the string, so
	cmp r3, #0						@; we move until we find the char = 0, and then we start
	beq start_concat
	b check_before
start_concat:
	ldrb r3, [r0], #-1				@; we start at the position after the last char of string
loop_concat:
	ldrb r3, [r1], #1				@; load chars from second string into r3
	cmp r3, #0						@; compares if we have reached the end of second string
	beq end_concat
	strb r3, [r0], #1				@; stores char by char until we have store n (r2) chars
	adds r4, r4, #1
	cmp r4, r2
	bhs end_concat
	b loop_concat
end_concat:
	strb r5, [r0]					@; ends storing a 0 at the end of new string
	pop {r0}						@; return the old r0 pointer
	bx lr


@; --- strncmp function -----------------
	.global strncmp
	.thumb_func
strncmp:
	mov r3, #0 						@; initialize counter to 0
loop_strncmp:
	ldrb r4, [r0], #1				@; load char by char to be compared
	ldrb r5, [r1], #1
	cmp r3, r2						@; check if we have reached the limit of comparitions (n)
	itt eq
	moveq r0, #0					@; if we have reached the limit, then put zero to r0
	beq end_strncmp					@; and return that value
	cmp r4, r5						@; if we have not reached the limit yet, then compare both chars
	itt eq
	addeq r3, #1					@; if both are equal then add one to counter
	beq loop_strncmp				@; and start the loop again with next set of chars
	b leave_strncmploop				@; else leave the loop and get the positive or negative number
leave_strncmploop:
	subs r0, r4, r5					@; store the negative or positive number into r0
end_strncmp:
	bx lr							@; return 0, positive, or negative accordingly



@; --- strrchr function -----------------
	.global strrchr
	.thumb_func
strrchr:
	mov r3, #0						@; initialize r3,r4,r5 to zero
	mov r4, #0
	mov r5, #0
loop_strrchr:
	ldrb r2, [r0], #1				@; loads char by char to r2.
	cmp r2, r3						@; first compares if it is zero to verify when the string ends
	beq end_strrchr					@; if zero then leave loop
	cmp r2, r1						@; second compares the char against args[1]
	beq get_addr					@; if equal then we need the address of that occurrence
	b loop_strrchr					@; else start the loop again with next char
get_addr:
	subs r5, r0, #1					@; stores the address in r5
	adds r4, r4, #1					@; updates the counter
	b loop_strrchr					@; goes back to the loop, to check possible next occurrence
end_strrchr:
	cmp r4, #0						@; if counter not equal to zero (greater)
	ite ne
	addne r0, r5, #0				@; then store r5 (address of last occurrence) in r0
	addeq r0, r3, #0				@; else store NULL in r0
	bx lr							@; return address


@; --- strnspn function -----------------
	.global strspn
	.thumb_func
strspn:
	mov r4, #0						@; counter = 0
loop_strspn:
	ldrb r2, [r0], #1				@; compares characters from args[0] and args[1] in order
	ldrb r3, [r1], #1
	cmp r2, r3
	ite eq							@; if equal then add 1 to counter
	addeq r4, r4, #1
	bne end_strspn					@; else leave the loop
	b loop_strspn					@; continue to next char
end_strspn:
	adds r0, r4, #0					@; returns the counter = length
	bx lr


@; --- strcspn function -----------------
	.global strcspn
	.thumb_func
strcspn:
	mov r4, #0						@; counter = 0
	adds r5, r1, #0					@; stores a copy of args[1] into r5
loop_strcspn:
	adds r4, r4, #1					@; add 1 to counter
	ldrb r2, [r0], #1				@; get char at address position from args[0]
	adds r1, r5, #0					@; stores in r1 the copy of old r1, previously stored in r5
inner_loop:
	ldrb r3, [r1], #1				@; loads every single char from args[1]
	cmp r3, #0						@; if current char equal to zero, then leave inner loop
	beq loop_strcspn
	cmp r3, r2						@; if current args[0] char equal to any args[1] char
	beq end_strcspn					@; then go to end
	b inner_loop					@; otherwise check args[0] char against next args[1] char
end_strcspn:
	adds r0, r4, #0					@; return counter or length
	bx lr


@; --- strtok function -----------------
	.global strtok
	.thumb_func
strtok:
	movw r5,#:lower16:Static		@; get _address_ of Static in r5
	movt r5,#:upper16:Static
	cmp r0, #0						@; if args[0] is NULL then work with the Static address
	it eq
	ldreq r0, [r5]					@; then, load in r0 the address saved in static var Static
	mov r4, #0						@; r4 = 0
	push {r0}						@; push initial address of the string
loop_strtok:
	ldrb r2, [r0], #1				@; compare char by char, first against 0 to identify where
	cmp r2, #0						@; the string finished, and then against the delimiter
	beq full_end
	cmp r2, r1						@; when char is equal to the delimiter, leave loop
	beq end_strtok
	b loop_strtok
end_strtok:
	subs r0, r0, #1					@; stores 0 instead of the delimiter in string.
	strb r4, [r0], #1
	str r0, [r5]					@; stores the new address into address in r5 (Static)
full_end:
	pop {r0}						@; pops r0 to return intial address
	bx lr

@; --- some constant data we're putting in ROM which you might access with some of your instructions

	.global	ROMdata				@; global label of test target data area
	.align 2					@; pad memory if necessary to align on word boundary for word storage 
ROMdata:						@; start of test data area	
	.byte 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F	@;16 bytes with contents = offset from start
	.byte 0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F	@;""
	.byte 0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F	@;""
	.byte 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F	@;""
	.byte 0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F	@;""
	.byte 0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5A,0x5B,0x5C,0x5D,0x5E,0x5F	@;""
	.byte 0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x6E,0x6F	@;""
	.byte 0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7A,0x7B,0x7C,0x7D,0x7E,0x7F	@;""
	.byte 0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8A,0x8B,0x8C,0x8D,0x8E,0x8F	@;""
	.byte 0x90,0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9A,0x9B,0x9C,0x9D,0x9E,0x9F	@;""
	.byte 0xA0,0xA1,0xA2,0xA3,0xA4,0xA5,0xA6,0xA7,0xA8,0xA9,0xAA,0xAB,0xAC,0xAD,0xAE,0xAF	@;""
	.byte 0xB0,0xB1,0xB2,0xB3,0xB4,0xB5,0xB6,0xB7,0xB8,0xB9,0xBA,0xBB,0xBC,0xBD,0xBE,0xBF	@;""
	.byte 0xC0,0xC1,0xC2,0xC3,0xC4,0xC5,0xC6,0xC7,0xC8,0xC9,0xCA,0xCB,0xCC,0xCD,0xCE,0xCF	@;""
	.byte 0xD0,0xD1,0xD2,0xD3,0xD4,0xD5,0xD6,0xD7,0xD8,0xD9,0xDA,0xDB,0xDC,0xDD,0xDE,0xDF	@;""
	.byte 0xE0,0xE1,0xE2,0xE3,0xE4,0xE5,0xE6,0xE7,0xE8,0xE9,0xEA,0xEB,0xEC,0xED,0xEE,0xEF	@;""
	.byte 0xF0,0xF1,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0xF8,0xF9,0xFA,0xFB,0xFC,0xFD,0xFE,0xFF	@;"" , 256 bytes total
	 
