#
# tensorForth root Makefile
#
-include ${HOME}/makefile.init

RM := rm

APP_NAME  := ten4
#APP_EXT   := .exe
APP_HOME  := ${HOME}/devel/forth/$(APP_NAME)
CUDA_LIB  := ${CUDA_HOME}/targets/x86_64-linux/lib
CUDA_ARCH := compute_75
CUDA_CODE := sm_75

# All of the sources participating in the build are defined here
SRCS :=
OBJS :=

# Every subdirectory with source files must be described here
SUBDIRS := src

# Add inputs and outputs from these tool invocations to the build variables
-include src/Makefile
-include tests/Makefile

# Cutlass library in ${CUTLASS_HOME}/build/tools/library
CL_LIB := cutlass

# Extra pre-compiled object and libraries
USER_OBJS :=
USER_LIBS :=

OPTIONAL_TOOL_DEPS := \
	$(wildcard ${HOME}/makefile.defs) \
	$(wildcard ${HOME}/makefile.init) \
	$(wildcard ${HOME}/makefile.targets)

APP_TARGET:= ./tests/$(APP_NAME)$(APP_EXT)
NVLINK_FLAGS:=-ccbin g++ --cudart=static -Xnvlink --suppress-stack-size-warning

.PHONY: all tests main-build clean

# All Target
all: main-build

tests: test

# Main-build Target
main-build: $(APP_NAME)

# Tool invocations
$(APP_NAME): $(OBJS) $(USER_OBJS) $(OPTIONAL_TOOL_DEPS)
	@echo 'Building target: $@'
	@echo 'Invoking: NVCC linker'
	${CUDA_HOME}/bin/nvcc \
        ${NVLINK_FLAGS} \
		-L$(CUDA_LIB) \
		-L${CUTLASS_HOME}/build/tools/library \
		-l$(CL_LIB) \
		-gencode arch=${CUDA_ARCH},code=${CUDA_CODE} \
        -o "$(APP_TARGET)" \
		$^
	@echo 'Finished building target: $@'
	@echo ' '

# Other Targets
clean:
	-$(RM) $(APP_TARGET)
	-@echo ' '

-include ../makefile.targets
