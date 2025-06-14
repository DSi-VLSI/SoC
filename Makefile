####################################################################################################
# VARIABLES
####################################################################################################

# Define the top module
TOP ?= soc_tb

# Get the root directory
ROOT_DIR = $(shell echo $(realpath .))

# Default goal is to help
.DEFAULT_GOAL := help

# Define XVLOG_DEFS
XVLOG_DEFS += -d SIMULATION

# Define a command to grep for WARNING and ERROR messages with color highlighting
GREP_EW := grep -E "WARNING:|ERROR:|" --color=auto

TEST?=default

TEST_REPO := tests

HARTID := $(shell shuf -i 0-3 -n 1)

####################################################################################################
# PACKAGE LISTS
####################################################################################################

PACKAGE_LIST += ${ROOT_DIR}/package/dm_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/riscv_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/ariane_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/axi_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/ariane_axi_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/std_cache_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/cf_math_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/config_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/fpnew_pkg.sv
PACKAGE_LIST += ${ROOT_DIR}/package/defs_div_sqrt_mvp.sv
PACKAGE_LIST += ${ROOT_DIR}/package/soc_pkg.sv

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
	@rm -f temp_ci_issues
	@echo -e "\033[3;35mCleaned build directory\033[0m"

.PHONY: clean_full
clean_full: clean
	@echo -e "\033[3;35mCleaning log directory...\033[0m"
	@rm -rf log
	@make -s log
	@echo -e "\033[3;35mCleaned log directory\033[0m"

.PHONY: build/build_$(TOP)
build/build_$(TOP):
	@if [ ! -f build/build_$(TOP) ]; then \
		make -s ENV_BUILD TOP=$(TOP); \
	else \
		make -s match_sha TOP=$(TOP); \
	fi

.PHONY: match_sha
match_sha:
	@sha256sum.exe $$(find include/ -type f) $$(find package/ -type f) $$(find source/ -type f) $$(find testbench/ -type f) > build/build_$(TOP)_new
	@diff build/build_$(TOP)_new build/build_$(TOP) || make -s ENV_BUILD TOP=$(TOP)

.PHONY: ENV_BUILD
ENV_BUILD:
	@make -s clean
	@echo -e "\033[3;35mCompiling...\033[0m"
	@echo "-i ${ROOT_DIR}/include" > build/flist
	@$(foreach file, $(PACKAGE_LIST), echo -e $(file) >> build/flist;)
	@find ${ROOT_DIR}/source -type f >> build/flist
	@find ${ROOT_DIR}/testbench -type f >> build/flist
	@cd build; xvlog -sv -f flist --nolog $(XVLOG_DEFS) | $(GREP_EW)
	@echo -e "\033[3;35mCompiled\033[0m"
	@echo -e "\033[3;35mElaborating $(TOP)...\033[0m"
	@cd build; xelab $(TOP) --O0 --incr --nolog --timescale 1ns/1ps --debug wave | $(GREP_EW)
	@echo -e "\033[3;35mElaborated $(TOP)\033[0m"
	@sha256sum.exe $$(find include/ -type f) $$(find package/ -type f) $$(find source/ -type f) $$(find testbench/ -type f) > build/build_$(TOP)

.PHONY: common_sim_checks
common_sim_checks: log
	@if [ "$(TOP)" = "ariane_tb" ]; then make -s test HARTID=${HARTID}; fi
	@echo "--testplusarg TEST=$(TEST)" > build/xsim_args
	@echo "--testplusarg HARTID=$(HARTID)" >> build/xsim_args

.PHONY: simulate
simulate: build/build_$(TOP) common_sim_checks
	@$(eval log_file_name := $(shell echo "$(TOP)_$(TEST).txt" | sed "s/\//___/g"))
	@cd build; xsim $(TOP) -f xsim_args -runall -log ../log/$(log_file_name)

.PHONY: simulate_gui
simulate_gui: build/build_$(TOP) common_sim_checks
	@cd build; xsim $(TOP) -f xsim_args -gui

.PHONY: print_logo
print_logo:
	@echo "                            ____   ___   ____                            ";
	@echo "                           / ___| / _ \ / ___|                           ";
	@echo "                           \___ \| |_| | |___                            ";
	@echo "                           |____/ \___/ \____|                           ";
	@echo "                                                                         ";

# Define the GCC command for RISC-V
RV64G_GCC := riscv64-unknown-elf-gcc -march=rv64g -nostdlib -nostartfiles

.PHONY: test
test: build
	@if [ -z ${TEST} ]; then echo -e "\033[1;31mTEST is not set\033[0m"; exit 1; fi
	@if [ ! -f ${TEST_REPO}/$(TEST) ]; then echo -e "\033[1;31m${TEST_REPO}/$(TEST) does not exist\033[0m"; exit 1; fi
	@$(eval TEST_TYPE := $(shell echo "$(TEST)" | sed "s/.*\.//g"))
	@echo -e "\033[1;33mLinker: core_${HARTID}.ld\033[0m"
	@$(RV64G_GCC) -o build/prog.elf ${TEST_REPO}/$(TEST) -T linkers/core_$(HARTID).ld
	@riscv64-unknown-elf-objcopy -O verilog build/prog.elf build/prog.hex
	@riscv64-unknown-elf-nm build/prog.elf > build/prog.sym
	@riscv64-unknown-elf-objdump -d build/prog.elf > build/prog.dump

