################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/mymain_F429v01.c 

S_UPPER_SRCS += \
../src/Blinky_LD3.S \
../src/myDataOps02.S \
../src/mySystemInit.S \
../src/startup_stm32f429xx_02.S 

OBJS += \
./src/Blinky_LD3.o \
./src/myDataOps02.o \
./src/mySystemInit.o \
./src/mymain_F429v01.o \
./src/startup_stm32f429xx_02.o 

S_UPPER_DEPS += \
./src/Blinky_LD3.d \
./src/myDataOps02.d \
./src/mySystemInit.d \
./src/startup_stm32f429xx_02.d 

C_DEPS += \
./src/mymain_F429v01.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.S
	@echo 'Building file: $<'
	@echo 'Invoking: MCU GCC Compiler'
	@echo $(PWD)
	arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -DSTM32F429ZITx -DSTM32F429I_DISC1 -DSTM32F4 -DSTM32 -DDEBUG -I"/Users/mateojarafabian/Desktop/enee440/03Blinky_STM32F429/inc" -O0 -g3 -Wall -fmessage-length=0 -ffunction-sections -c -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: MCU GCC Compiler'
	@echo $(PWD)
	arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -DSTM32F429ZITx -DSTM32F429I_DISC1 -DSTM32F4 -DSTM32 -DDEBUG -I"/Users/mateojarafabian/Desktop/enee440/03Blinky_STM32F429/inc" -O0 -g3 -Wall -fmessage-length=0 -ffunction-sections -c -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


