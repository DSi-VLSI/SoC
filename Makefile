####################################################################################################
# VARIABLES
####################################################################################################

# Define the top module
TOP ?= soc

# Get the root directory
ROOT_DIR = $(shell echo $(realpath .))

# Default goal is to help
.DEFAULT_GOAL := help

# Define XVLOG_DEFS
XVLOG_DEFS += -d SIMULATION

# Define a command to grep for WARNING and ERROR messages with color highlighting
GREP_EW := grep -E "WARNING:|ERROR:|" --color=auto

TEST?=default

####################################################################################################
# FILE LISTS
####################################################################################################

# package
FLIST += ${ROOT_DIR}/package/dm_pkg.sv
FLIST += ${ROOT_DIR}/package/riscv_pkg.sv
FLIST += ${ROOT_DIR}/package/ariane_pkg.sv
FLIST += ${ROOT_DIR}/package/axi_pkg.sv
FLIST += ${ROOT_DIR}/package/ariane_axi_pkg.sv
FLIST += ${ROOT_DIR}/package/std_cache_pkg.sv
FLIST += ${ROOT_DIR}/package/cf_math_pkg.sv
FLIST += ${ROOT_DIR}/package/soc_pkg.sv

FLIST += $(shell find ${ROOT_DIR}/source/ -type f -name "*.sv")

####################################################################################################
# TARGETS
####################################################################################################

# Help target: displays help message
.PHONY: help
help:
	@echo -e "\033[1;36mAvailable targets:\033[0m"
	@echo -e "\033[1;33m  clean          \033[0m- Removes build directory and rebuilds it"
	@echo -e "\033[1;33m  clean_full     \033[0m- Cleans both build and log directories"
	@echo -e "\033[1;33m  simulate       \033[0m- Compiles and simulates the design"
	@echo -e "\033[1;33m  simulate_gui   \033[0m- Compiles and simulates the design with GUI"
	@echo -e "\033[1;33m  test           \033[0m- Compiles and prepares a test program for simulation"
	@echo -e "\033[1;36mVariables:\033[0m"
	@echo -e "\033[1;33m  TOP            \033[0m- Specifies the top module to be used (default: soc)"
	@echo -e "\033[1;33m  TEST           \033[0m- Specifies the test program to compile (required for 'test' target)"

# Build target: creates build directory and adds it to gitignore
build:
	@mkdir -p build
	@echo "*" > build/.gitignore
	@git add build > /dev/null 2>&1

# Log target: creates log directory and adds it to gitignore
log:
	@mkdir -p log
	@echo "*" > log/.gitignore
	@git add log > /dev/null 2>&1

# Clean target: removes build directory and rebuilds it
.PHONY: clean
clean:
	@echo -e "\033[3;35mCleaning build directory...\033[0m"
	@rm -rf build
	@make -s build
	@echo -e "\033[3;35mCleaned build directory\033[0m"

.PHONY: clean_full
clean_full: clean
	@echo -e "\033[3;35mCleaning log directory...\033[0m"
	@rm -rf log
	@make -s log
	@echo -e "\033[3;35mCleaned log directory\033[0m"

# Define compile function: compiles the source files in chunks
define compile
  $(eval SUB_LIB := $(shell echo "$(wordlist 1, 25,$(COMPILE_LIB))"))
  cd build; xvlog -i ${ROOT_DIR}/include -sv $(SUB_LIB) --nolog $(XVLOG_DEFS) | $(GREP_EW)
  $(eval COMPILE_LIB := $(wordlist 26, $(words $(COMPILE_LIB)), $(COMPILE_LIB)))
  $(if $(COMPILE_LIB), $(call compile))
endef

build/build_$(TOP): source/$(TOP).sv build
ifeq ($(wildcard build/build_$(TOP)),)
	@make -s clean
	@echo -e "\033[3;35mCompiling...\033[0m"
	@$(eval COMPILE_LIB := $(FLIST))
	@$(call compile)
	@echo -e "\033[3;35mCompiled\033[0m"
	@echo -e "\033[3;35mElaborating $(TOP)...\033[0m"
	@cd build; xelab $(TOP) --O0 --incr --nolog --timescale 1ns/1ps --debug wave | $(GREP_EW)
	@echo -e "\033[3;35mElaborated $(TOP)\033[0m"
	@echo "" > build/build_$(TOP)
else
	@echo -e "\033[3;35m$(TOP) build already exists. Skipping build.\033[0m"
endif

.PHONY: simulate
simulate: build/build_$(TOP)
	@if [ "$(TOP)" = "ariane_tb" ]; then make -s test; fi
	@echo "--testplusarg TEST=$(TEST)" > build/xsim_args
	@cd build; xsim $(TOP) -f xsim_args -runall -log ../log/$(TOP)_$(TEST).txt

.PHONY: simulate_gui
simulate_gui: build/build_$(TOP)
	@if [ "$(TOP)" = "ariane_tb" ]; then make -s test; fi
	@echo "--testplusarg TEST=$(TEST)" > build/xsim_args
	@cd build; xsim $(TOP) -f xsim_args -gui

.PHONY: print_logo
print_logo:
	@echo ""

# Define the GCC command for RISC-V
RV64G_GCC := riscv64-unknown-elf-gcc -march=rv64g -nostdlib -nostartfiles

.PHONY: test
test: build
	@if [ -z ${TEST} ]; then echo -e "\033[1;31mTEST is not set\033[0m"; exit 1; fi
	@if [ ! -f tests/$(TEST) ]; then echo -e "\033[1;31mtests/$(TEST) does not exist\033[0m"; exit 1; fi
	@$(eval TEST_TYPE := $(shell echo "$(TEST)" | sed "s/.*\.//g"))
	@if [ "$(TEST_TYPE)" = "c" ]; then TEST_ARGS="library/startup.s"; else TEST_ARGS=""; fi; \
		$(RV64G_GCC) -o build/prog.elf tests/$(TEST) $$TEST_ARGS -Ilibrary
#		$(RV64G_GCC) -o build/prog.elf tests/$(TEST) $$TEST_ARGS -Ilibrary -Tlibrary/ariane_tb.ld
	@riscv64-unknown-elf-objcopy -O verilog build/prog.elf build/prog.hex
	@riscv64-unknown-elf-nm build/prog.elf > build/prog.sym
	@riscv64-unknown-elf-objdump -d build/prog.elf > build/prog.dump

