#!/bin/bash

log() {
	echo "-- run.sh: $@"
}

mkdir -p logs .linker_scripts

BIN_OUTPUT="logs/bin_stdout_logs.txt"
DMESG_LOG="logs/dmesg_logs.txt"
PROGS_INFO="scripts/progs_info.csv"
MODULE_NAME="replace_multiple"

log "Building loader (if not existed)"

make loader

if [ ! -f .loader_output/$1 ]; then
	log "No loader at .loader_output/$1"
	exit 1
fi

log "Starting dmesg capture"

dmesg -W > $DMESG_LOG &
DMESG_PID=$!

./.loader_output/$1 &>$BIN_OUTPUT &
BIN_PID=$!

log "Starting program $1 with PID=$BIN_PID"

# while ! grep -q "EBPF_INFO: type=load_end pid=$BIN_PID" $DMESG_LOG;
# do
# 	sleep 1
# done

tail -n 0 -f $DMESG_LOG | grep -q -m 2 "EBPF_INFO: type=load_end .* pid=$BIN_PID" 

log "Message captured at $DMESG_LOG!!"
log "Processing logs and running linker script generation..."

TYPES=$(python3 scripts/process_dmesg.py $1 $BIN_PID $DMESG_LOG)

log "Linker script saved at .linker_scripts/$1.ld"

kill $DMESG_PID

if [ ! -f lkm/$MODULE_NAME.ko ]; then
	(cd lkm && make)
	log "Compiling kernel module..."
fi

log "Starting kernel module..."
insmod lkm/$MODULE_NAME.ko

rm -rf .header_override
mkdir .header_override

python3 scripts/fn_name_to_hex.py

log "Looping through all progs..."
while IFS= read -r PROG_TYPE; do
	if [ -d ".header_override/$PROG_TYPE" ]; then
		log "(TYPE=$PROG_TYPE) Helper func override for $PROG_TYPE already exists!"
	else
		log "(TYPE=$PROG_TYPE) Generating header for helper func override..."

		# preparing header files to override
		mkdir .header_override/$PROG_TYPE .header_override/$PROG_TYPE/bpf
		cp .output/bpf/bpf_helpers.h .header_override/$PROG_TYPE/bpf/bpf_helpers.h
		cp bpf_core_read.h .header_override/$PROG_TYPE/bpf/bpf_core_read.h

		# generating new helper defs
		python3 scripts/modify_header.py bpf_helper_defs.h .header_override/$PROG_TYPE/bpf/bpf_helper_defs.h $PROG_TYPE scripts/prog_helper_addr.csv
	fi

	log "(TYPE=$PROG_TYPE) Making BPF native code..."
	make .bpf_output/$1.bpf PROG_TYPE=$PROG_TYPE

	log "(TYPE=$PROG_TYPE) Extracting functions from $1 and writing to kernel module..."
	python3 scripts/extract_funcs_from_bin_type.py .bpf_output/$1.bpf $PROG_TYPE -o scripts/func.out
	cat scripts/func.out > /sys/kernel/debug/bpf_replace/prog_to_replace

	log "(TYPE=$PROG_TYPE) Replacing PROG_TYPE=$PROG_TYPE success!"
done <<< "$TYPES"

log "Replace process finished! Press any key to restore and end."
read -n 1 -s -r

log "Removing module..."
rmmod $MODULE_NAME # for now
sleep 1
kill $BIN_PID # for now

log "Stopping"
