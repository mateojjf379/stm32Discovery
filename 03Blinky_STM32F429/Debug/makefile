################################################################################
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.init

RM := rm -rf

# All of the sources participating in the build are defined here
-include sources.mk
-include src/subdir.mk
-include subdir.mk
-include objects.mk

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(S_UPPER_DEPS)),)
-include $(S_UPPER_DEPS)
endif
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
endif

-include ../makefile.defs

# Add inputs and outputs from these tool invocations to the build variables 

# All Target
all: 03Blinky_STM32F429.elf

# Tool invocations
03Blinky_STM32F429.elf: $(OBJS) $(USER_OBJS) /Users/mateojarafabian/Desktop/enee440/03Blinky_STM32F429/STM32F429ZITx_FLASH.ld
	@echo 'Building target: $@'
	@echo 'Invoking: MCU GCC Linker'
	arm-none-eabi-gcc -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -nostartfiles -nodefaultlibs -nostdlib -static -T"/Users/mateojarafabian/Desktop/enee440/03Blinky_STM32F429/STM32F429ZITx_FLASH.ld" -Wl,-Map=output.map -Wl,--gc-sections -o "03Blinky_STM32F429.elf" @"objects.list" $(USER_OBJS) $(LIBS) -lm
	@echo 'Finished building target: $@'
	@echo ' '
	$(MAKE) --no-print-directory post-build

# Other Targets
clean:
	-$(RM) *
	-@echo ' '

post-build:
	-@echo 'hex lst bin and size'
	arm-none-eabi-objcopy -O ihex "03Blinky_STM32F429.elf" "03Blinky_STM32F429.hex"
	arm-none-eabi-objdump -D "03Blinky_STM32F429.elf" > "03Blinky_STM32F429.lst"
	arm-none-eabi-objcopy -O binary "03Blinky_STM32F429.elf" "03Blinky_STM32F429.bin"
	arm-none-eabi-size "03Blinky_STM32F429.elf"
	-@echo ' '

.PHONY: all clean dependents
.SECONDARY: post-build

-include ../makefile.targets
