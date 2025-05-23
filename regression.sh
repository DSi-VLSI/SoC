#!/bin/bash

################################################################################
# FUNCTIONS
################################################################################

ci_simulate () {
  start_time=$(date +%s)
  echo -n -e " $(date +%x\ %H:%M:%S) - \033[1;33mSIMULATING $1 $2... \033[0m"
  make simulate TOP=$1 TEST=$2 > /dev/null 2>&1
  end_time=$(date +%s)
  time_diff=$((end_time - start_time))
  echo -e "\033[1;32mDone!\033[0m ($time_diff seconds)"
}

################################################################################
# CLEANUP
################################################################################

start_time=$(date +%s)
clear
make -s print_logo
echo -n -e " $(date +%x\ %H:%M:%S) - \033[1;33mCLEANING UP TEMPORATY FILES... \033[0m"
make -s clean_full > /dev/null 2>&1
end_time=$(date +%s)
time_diff=$((end_time - start_time))
echo -e "\033[1;32mDone!\033[0m ($time_diff seconds)"

################################################################################
# SIMULATE
################################################################################

ci_simulate ariane_tb add.s
ci_simulate ariane_tb addi.s
ci_simulate ariane_tb and.s
ci_simulate ariane_tb andi.s
ci_simulate ariane_tb auipc.s
ci_simulate ariane_tb beq.s
ci_simulate ariane_tb bge.s
ci_simulate ariane_tb bgeu.s
ci_simulate ariane_tb blt.s
ci_simulate ariane_tb bltu.s
ci_simulate ariane_tb bne.s
ci_simulate ariane_tb ebreak.s
ci_simulate ariane_tb ecall.s
ci_simulate ariane_tb fence.s
ci_simulate ariane_tb illegal_instr.s
ci_simulate ariane_tb intr_handler.s
ci_simulate ariane_tb jal.s
ci_simulate ariane_tb jalr.s
ci_simulate ariane_tb lb.s
ci_simulate ariane_tb lbu.s
ci_simulate ariane_tb lh.s
ci_simulate ariane_tb lhu.s
ci_simulate ariane_tb lui.s
ci_simulate ariane_tb lw.s
ci_simulate ariane_tb or.s
ci_simulate ariane_tb ori.s
ci_simulate ariane_tb sb.s
ci_simulate ariane_tb sh.s
ci_simulate ariane_tb sll.s
ci_simulate ariane_tb slli.s
ci_simulate ariane_tb slt.s
ci_simulate ariane_tb slti.s
ci_simulate ariane_tb sltiu.s
ci_simulate ariane_tb sltu.s
ci_simulate ariane_tb sra.s
ci_simulate ariane_tb srai.s
ci_simulate ariane_tb srl.s
ci_simulate ariane_tb srli.s
ci_simulate ariane_tb sub.s
ci_simulate ariane_tb sw.s
ci_simulate ariane_tb xor.s
ci_simulate ariane_tb xori.s
ci_simulate ariane_tb array.c
ci_simulate ariane_tb array_of_pointers.c
ci_simulate ariane_tb bitwise.c
ci_simulate ariane_tb conditional.c
ci_simulate ariane_tb const.c
ci_simulate ariane_tb dynamic_memory.c
ci_simulate ariane_tb enum.c
ci_simulate ariane_tb file_io.c
ci_simulate ariane_tb float.c
ci_simulate ariane_tb function_pointer.c
ci_simulate ariane_tb function_returning_pointer.c
ci_simulate ariane_tb loop.c
ci_simulate ariane_tb macro.c
ci_simulate ariane_tb math.c
ci_simulate ariane_tb pointer.c
ci_simulate ariane_tb pointer_arithmetic.c
ci_simulate ariane_tb printf.c
ci_simulate ariane_tb recursion.c
ci_simulate ariane_tb scanf.c
ci_simulate ariane_tb string.c
ci_simulate ariane_tb struct.c
ci_simulate ariane_tb typedef.c
ci_simulate ariane_tb union.c
ci_simulate ariane_tb volatile.c

ci_simulate soc default # REMOVE LATER

################################################################################
# COLLECT & PRINT
################################################################################

rm -rf temp_ci_issues
touch temp_ci_issues

grep -s -r "TEST FAILED" ./log | sed "s/.*\.log://g" >> temp_ci_issues
grep -s -r "ERROR:" ./log | sed "s/.*\.log://g" >> temp_ci_issues

echo -e ""
echo -e "\033[1;36m___________________________ CI REPORT ___________________________\033[0m"
grep -s -r "TEST PASSED" ./log | sed "s/.*\.log://g"
grep -s -r "TEST FAILED" ./log | sed "s/.*\.log://g"
grep -s -r "WARNING:" ./log | sed "s/.*\.log://g"
grep -s -r "ERROR:" ./log | sed "s/.*\.log://g"

echo -e "\n"
echo -e "\033[1;36m____________________________ SUMMARY ____________________________\033[0m"
echo -n "PASS    : "
grep -s -r "TEST PASSED" ./log | sed "s/.*\.log://g" | wc -l
echo -n "FAIL    : "
grep -s -r "TEST FAILED" ./log | sed "s/.*\.log://g" | wc -l
echo -n "WARNING : "
grep -s -r "WARNING:" ./log | sed "s/.*\.log://g" | wc -l
echo -n "ERROR   : "
grep -s -r "ERROR:" ./log | sed "s/.*\.log://g" | wc -l
echo -e ""
