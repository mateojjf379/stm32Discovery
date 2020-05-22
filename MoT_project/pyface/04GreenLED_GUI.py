#04GreenLED_GUI.py wmh 2018-11-10 -- step 1: receive text from serial, print to console
#03GreenLED_GUI.py wmh 2018-11-04 -- stopping development until we add a messaging task list to DoT  
#GreenLED_GUI_standalone02v3.py wmh 2018-11-04 -- update for STM32F429-Disc1 and DonT 'GreenLED.S' working on both Python 2.7 and 3.7
#GreenLED_GUI_standalone01.py wmh 2018-04-09 -- trial of creating separate GUIs for each device then merging them together
# We see in 3grid_test--gridded_frames!.py that we can create separate gridded frames and then place them in a larger frame.
# If it is possible to make frame GUIs for devices separately and then combine them our system development will be easier


import tkinter as tk
import serial
import Cmd_hexlify
root = tk.Tk()
ser = serial.Serial('COM27') #!!??does this go in each GUI?  see http://pyserial.readthedocs.io/en/latest/pyserial_api.html --

############### GreenLED functions 
GreenLED_txtmsg = tk.StringVar()

def GreenLED_txtmsg_save():
	global txline
	txline = GreenLED_txtmsg.get()

def send_GreenLED_init():
	print ("GreenLED_init -- sending :0100FF")
	#!!IMPORTANT: ser.write() message MUST HAVE newline or ser.readline() will block
	ser.flushInput()
	cmdstring=":0100FF\n"
	ser.write(cmdstring.encode('utf-8'))		#works
#various other approaches to writing the string
#	ser.write(cmdstring.encode())				#also works (encode() defaults to utf-8)
#	ser.write(':0100FF\n'.encode('utf-8'))		#also works
#	ser.write(":0100FF\n".encode('utf-8'))		#also works
#	ser.write(":0100FF\n".encode())				#also works
#	ser.write(':0100FF\n'.encode())				#also works

	rxline = ser.readline()
	GreenLED_txtmsg.set(rxline)
	# print "received:",
	print (rxline),

def send_GreenLED_fast():
	print ("GreenLED_fast -- sending :0101FE")
	ser.write(":0101FE\n".encode('utf-8'))
	rxline = ser.readline()
	GreenLED_txtmsg.set(rxline)
	#print "received:",						
	print (rxline)							

def send_GreenLED_slow():
	print ("GreenLED_slow -- sending :0102FD")
	ser.write(":0102FD\n".encode('utf-8'))
	rxline = ser.readline()
	GreenLED_txtmsg.set(rxline)
	# print "received:",
	print (rxline),

def send_GreenLED_stop():
	print ("GreenLED_stop -- sending :0103FC (removes GreenLED task)")
	ser.write(":0103FC\n".encode('utf-8'))
	rxline = ser.readline()
	GreenLED_txtmsg.set(rxline)
	# print "received:",
	print (rxline),



# def send_GreenLED_userstring():
	# GreenLED_txtmsg_save()
	# ser.write(txline)
	# ser.write("\n")
	# rxline = ser.readline()
	# print "received:",
	# print (rxline),

def send_System_reset():
	print ("System_reset() -- sending :0000\n")
	ser.write(":0000\n".encode('utf-8'))
#	rxline = ser.readline()	-- nothing returned after reset, so don't wait
	GreenLED_txtmsg.set("<reset>")

def msg_Handler():	#called periodically from tkinter mainloop
	global msg_buf			#where initialized?
	global msg_char
	global msg_len
	waitnum = ser.in_waiting
	while (waitnum>0):
		msg_char = ser.read(1).decode('ascii')
		waitnum -= 1
		if (msg_char != '\n'):
			msg_buf += msg_char
			msg_len += 1
		if (msg_char == '\n'): #message is read for interpretation
			#here to validate message and dispatch response
			# ...
			print(msg_buf)	#for debug
			#
			# ... do whatever the message is supposed to do
			#     (see esp. http://effbot.org/tkinterbook/button.htm and "config(**options)" )
			msg_buf = ''	#clear the message buf
			msg_len = 0		# ..
	#exit to caller when nothing more to read	
	
############ GreenLED GUI 
GreenLED_frame = tk.Frame(root, highlightbackground="green", highlightcolor="green", highlightthickness=1, width=50, height=100, bd= 0)
GreenLED_frame.grid(row=0,column=0)	#placement 0,0 in the higher level frame

#Label(GreenLED_frame, text="PULSE INTERVAL")		#.grid(row=0)
#Label(GreenLED_frame, text="PULSE WIDTH")			#.grid(row=1)



#row 1 
GreenLED_INITbutton = tk.Button(GreenLED_frame, text="INIT", command=send_GreenLED_init)
GreenLED_INITbutton.grid(row=1,column=0)

GreenLED_msgbox = tk.Entry(GreenLED_frame,width=10,textvariable=GreenLED_txtmsg)
GreenLED_msgbox.grid(row=1,column=1)

# GreenLED_FREQbox = tk.Entry(GreenLED_frame,width=50,textvariable=GreenLED_FREQtext)
# GreenLED_FREQbox.grid(row=1,column=1)

# GreenLED_WIDTHbox = tk.Entry(GreenLED_frame,width=50,textvariable=GreenLED_WIDTHtext)
# GreenLED_WIDTHbox.grid(row=1,column=2)

#row 2
#GreenLED_UPDATEbutton = tk.Button(GreenLED_frame, text="INIT", command=send_GreenLED_init)
#GreenLED_UPDATEbutton.grid(row=2,column=0)

GreenLED_FASTbutton = tk.Button(GreenLED_frame, text="FAST", command=send_GreenLED_fast)
GreenLED_FASTbutton.grid(row=2,column=0)

GreenLED_SLOWbutton = tk.Button(GreenLED_frame, text="SLOW", command=send_GreenLED_slow)
GreenLED_SLOWbutton.grid(row=2,column=1)

GreenLED_STOPbutton = tk.Button(GreenLED_frame, text="STOP", command=send_GreenLED_stop)
GreenLED_STOPbutton.grid(row=2,column=2)


#row 3
GreenLED_RESETbutton = tk.Button(GreenLED_frame,  text="RESET", fg="red", command=send_System_reset)
GreenLED_RESETbutton.grid(row=3,column=0)

GreenLED_QUITbutton = tk.Button(GreenLED_frame,  text="QUIT", fg="red", command=quit)
GreenLED_QUITbutton.grid(row=3,column=2)

#msg_Handler()



root.mainloop()
