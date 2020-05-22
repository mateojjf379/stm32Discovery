# Cmd_hexlify.py wmh 2018-04-07 : functions to generate hex Cmd strings sent to Cmd_Handler() in CoMul system
#  makeCmd(dev,fn), makeCmd_32(dev,fn,arg), makeCmd_32_32(dev,fn,arg1, arg2) take numeric arguments <255 for dev, fn and <2**32 for arg1, arg2
#  and covert them into the format required by Cmd_Handler() for sending over the serial link to the Nucleo board. 
# 4test_hexlify.py wmh 2018-04-07 : 'makeCmd_32(dev,fn,arg)', 'makeCmd_32_32(dev,fn,arg1, arg2)' -- make commands with one and two arguments
# 3test_hexlify.py wmh 2018-04-07 : 'makeCmd(dev,fn)' -- convert device-number and function-number strings into a CoMul command string --works
# 2test_hexlify.py wmh 2018-04-06 : working out how to generate CoMul messages (dev+fn+params+checksum)
#  working so far: convert numeric string to little-endian hex, then break hex into bytes, then convert bytes into numeric
import struct
import binascii

def i2hex(n):
#	print binascii.hexlify(struct.pack('>i',n))
	return binascii.hexlify(struct.pack('<i',n)).upper()

# def print_i2hex(n): #test-demo of various conversion methods
	# n=i2hex(n)	# converts decimal number to little-endian hex string
# #	print '%(#)02X' %{"#":binascii.unhexlify(n[0:2])}
	# print n
	# print n[0:2]	# print  2-digit hex number component of little-endian string
	# print n[2:4]
	# print n[4:6]
	# print n[6:8]

	# print binascii.unhexlify(n[0:2])		# convert 2-digit hex number string to a single 8-bit character
	# print binascii.unhexlify(n[2:4])
	# print binascii.unhexlify(n[4:6])
	# print binascii.unhexlify(n[6:8])

	# print ord(binascii.unhexlify(n[0:2]))	# convert 2-digit number to 8 bit numeric value
	# print ord(binascii.unhexlify(n[2:4]))
	# print ord(binascii.unhexlify(n[4:6]))
	# print ord(binascii.unhexlify(n[6:8]))

def makeCmd( dev, fn ):	#convert device-number and function-number strings into a CoMul command string
	hexdev= i2hex(dev)[0:2]
	hexfn= i2hex(fn)[0:2]
	intdev= ord(binascii.unhexlify(hexdev)) 
	intfn= ord(binascii.unhexlify(hexfn)) 
	intchk= intdev + intfn
	hexchk= i2hex(-intchk)[0:2]
	# print hexdev 
	# print intdev
	# print hexfn 
	# print intfn
	# print hexchk
	# print intchk
	return ':'+hexdev+hexfn+hexchk+'\n'

def makeCmd_32( dev, fn, arg32 ):	#convert device-number and function-number strings into a CoMul command string
	hexdev= i2hex(dev)[0:2]
	hexfn= i2hex(fn)[0:2]
	hexarg32= i2hex(arg32) 
	hexarg32_0= hexarg32[0:2]
	hexarg32_1= hexarg32[2:4]
	hexarg32_2= hexarg32[4:6]
	hexarg32_3= hexarg32[6:8]
	intdev= ord(binascii.unhexlify(hexdev)) 
	intfn= ord(binascii.unhexlify(hexfn))
	intarg32_0= ord(binascii.unhexlify(hexarg32_0))
	intarg32_1= ord(binascii.unhexlify(hexarg32_1))
	intarg32_2= ord(binascii.unhexlify(hexarg32_2))
	intarg32_3= ord(binascii.unhexlify(hexarg32_3))
	intchk= intdev + intfn + intarg32_0 + intarg32_1 + intarg32_2 + intarg32_3
	hexchk= i2hex(-intchk)[0:2]
	# print hexdev 
	# print intdev
	# print hexfn 
	# print intfn
	# print hexarg32
	# print hexchk
	# print intchk
	return ':'+hexdev+hexfn+hexarg32_0+hexarg32_1+hexarg32_2+hexarg32_3+hexchk+'\n'
	

def makeCmd_32_32( dev, fn, arg1_32, arg2_32  ):#convert device-number and function-number strings into a CoMul command string
	hexdev= i2hex(dev)[0:2]
	hexfn= i2hex(fn)[0:2]
	hexarg1_32= i2hex(arg1_32)
	hexarg1_32_0= hexarg1_32[0:2]
	hexarg1_32_1= hexarg1_32[2:4]
	hexarg1_32_2= hexarg1_32[4:6]
	hexarg1_32_3= hexarg1_32[6:8]
	hexarg2_32= i2hex(arg2_32)
	hexarg2_32_0= hexarg2_32[0:2]
	hexarg2_32_1= hexarg2_32[2:4]
	hexarg2_32_2= hexarg2_32[4:6]
	hexarg2_32_3= hexarg2_32[6:8]
	intdev= ord(binascii.unhexlify(hexdev)) 
	intfn= ord(binascii.unhexlify(hexfn))
	intarg1_32_0= ord(binascii.unhexlify(hexarg1_32_0))
	intarg1_32_1= ord(binascii.unhexlify(hexarg1_32_1))
	intarg1_32_2= ord(binascii.unhexlify(hexarg1_32_2))
	intarg1_32_3= ord(binascii.unhexlify(hexarg1_32_3))
	intarg2_32_0= ord(binascii.unhexlify(hexarg2_32_0))
	intarg2_32_1= ord(binascii.unhexlify(hexarg2_32_1))
	intarg2_32_2= ord(binascii.unhexlify(hexarg2_32_2))
	intarg2_32_3= ord(binascii.unhexlify(hexarg2_32_3))
	intchk= intdev +intfn +intarg1_32_0 +intarg1_32_1 +intarg1_32_2 +intarg1_32_3 +intarg2_32_0 +intarg2_32_1 +intarg2_32_2 +intarg2_32_3
	hexchk= i2hex(-intchk)[0:2]
	return ':'+hexdev+hexfn+hexarg1_32_0+hexarg1_32_1+hexarg1_32_2+hexarg1_32_3+hexarg2_32_0+hexarg2_32_1+hexarg2_32_2+hexarg2_32_3+hexchk+'\n'
	
# if __name__ == "__main__":
    # import sys
# # print_i2hex(int(sys.argv[1]))	#giving it 305419896 = 0x12345678 
# msg= makeCmd_32(1,2,196608)
# print msg
# msg= makeCmd_32_32(1,2,196608,262144)
# print msg
