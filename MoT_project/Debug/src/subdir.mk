################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/MoT_demo_main01.c \
../src/VoltageMoT.c \
../src/deviceESP8266_01.c \
../src/deviceRedLED04.c \
../src/myESP8266_runAtCmd01.c 

S_UPPER_SRCS += \
../src/ADC.S \
../src/Blinky_LD3_LD4.S \
../src/Cmd_Handler11.S \
../src/Msg_Handler03.S \
../src/deviceGreenLED03.S \
../src/myESP8266_USART3_interrupt01.S \
../src/mySetSysClk03.S \
../src/mySysTick_Handler_168MHz.S \
../src/mySystemInit.S \
../src/startup_stm32f429xx_02.S \
../src/stm32f429xx_168MHz_USART1_9600N81.S \
../src/stm32f429xx_168MHz_USART3_115200N81.S \
../src/tim2.S 

OBJS += \
./src/ADC.o \
./src/Blinky_LD3_LD4.o \
./src/Cmd_Handler11.o \
./src/MoT_demo_main01.o \
./src/Msg_Handler03.o \
./src/VoltageMoT.o \
./src/deviceESP8266_01.o \
./src/deviceGreenLED03.o \
./src/deviceRedLED04.o \
./src/myESP8266_USART3_interrupt01.o \
./src/myESP8266_runAtCmd01.o \
./src/mySetSysClk03.o \
./src/mySysTick_Handler_168MHz.o \
./src/mySystemInit.o \
./src/startup_stm32f429xx_02.o \
./src/stm32f429xx_168MHz_USART1_9600N81.o \
./src/stm32f429xx_168MHz_USART3_115200N81.o \
./src/tim2.o 

S_UPPER_DEPS += \
./src/ADC.d \
./src/Blinky_LD3_LD4.d \
./src/Cmd_Handler11.d \
./src/Msg_Handler03.d \
./src/deviceGreenLED03.d \
./src/myESP8266_USART3_interrupt01.d \
./src/mySetSysClk03.d \
./src/mySysTick_Handler_168MHz.d \
./src/mySystemInit.d \
./src/startup_stm32f429xx_02.d \
./src/stm32f429xx_168MHz_USART1_9600N81.d \
./src/stm32f429xx_168MHz_USART3_115200N81.d \
./src/tim2.d 

C_DEPS += \
./src/MoT_demo_main01.d \
./src/VoltageMoT.d \
./src/deviceESP8266_01.d \
./src/deviceRedLED04.d \
./src/myESP8266_runAtCmd01.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.S
	@echo 'Building file: $<'
	@echo 'Invoking: MCU GCC Compiler'
	@echo $(PWD)
	arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -DSTM32F429ZITx -DSTM32F429I_DISC1 -DSTM32F4 -DSTM32 -DDEBUG -I"/Users/mateojarafabian/Desktop/enee440/MoT_project/inc" -I"/Users/mateojarafabian/Desktop/enee440/MoT_project/src" -O0 -g3 -Wall -fmessage-length=0 -ffunction-sections -c -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: MCU GCC Compiler'
	@echo $(PWD)
	arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -DSTM32F429ZITx -DSTM32F429I_DISC1 -DSTM32F4 -DSTM32 -DDEBUG -I"/Users/mateojarafabian/Desktop/enee440/MoT_project/inc" -I"/Users/mateojarafabian/Desktop/enee440/MoT_project/src" -O0 -g3 -Wall -fmessage-length=0 -ffunction-sections -c -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


