#!/bin/bash

log() {
	echo "-- run.sh: $@"
}

mkdir -p logs .linker_scripts

BIN_OUTPUT="logs/bin_stdout_logs.txt"
DMESG_LOG="logs/dmesg_logs.txt"

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

tail -n 0 -f $DMESG_LOG | grep -q -m 1 "EBPF_INFO: type=load_end .* pid=$BIN_PID" 

log "Message captured at $DMESG_LOG!!"
log "Running linker script generation..."

PROG_TYPE=$(python3 scripts/process_map_addr.py $1 $BIN_PID $DMESG_LOG)

log "Linker script saved at .linker_scripts/$1.ld"

kill $DMESG_PID

log "Generating header for helper func override for prog type $PROG_TYPE..."

mkdir -p .header_override .header_override/$PROG_TYPE .header_override/$PROG_TYPE/bpf
cp .output/bpf/bpf_helpers.h .header_override/$PROG_TYPE/bpf/bpf_helpers.h
cp bpf_core_read.h .header_override/$PROG_TYPE/bpf/bpf_core_read.h

python3 scripts/fn_name_to_hex.py
python3 scripts/modify_header.py .output/bpf/bpf_helper_defs.h .header_override/$PROG_TYPE/bpf/bpf_helper_defs.h $PROG_TYPE scripts/prog_helper_addr.csv

log "Making BPF native code"
# Compiling the native code
rm -rf .bpf_output/$1.bpf
make .bpf_output/$1.bpf PROG_TYPE=$PROG_TYPE

kill $BIN_PID # for now

log "Stopping"
