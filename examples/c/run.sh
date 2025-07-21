#!/bin/bash

mkdir -p logs .linker_scripts

BIN_OUTPUT="logs/bin_stdout_logs.txt"
DMESG_LOG="logs/dmesg_logs.txt"

if [ ! -f .loader_output/$1 ]; then
	echo "No loader at .loader_output/$1"
	exit 1
fi

echo "Starting dmesg capture"

dmesg -W > $DMESG_LOG &
DMESG_PID=$!

./.loader_output/$1 &>$BIN_OUTPUT &
BIN_PID=$!

echo "Starting program $1 with PID=$BIN_PID"

while ! grep -q "BPF_INFO: type=attaching pid=$BIN_PID" $DMESG_LOG;
do
	sleep 1
done

echo "Message captured at $DMESG_LOG!!"
echo "Running linker script generation..."

python3 scripts/process_map_addr.py $1 $BIN_PID $DMESG_LOG 

echo "Linker script saved at .linker_scripts/$1.ld"

kill $DMESG_PID

echo "Making BPF native code"
# Compiling the native code
rm -rf .bpf_output/$1.bpf .header_override scripts/bpf_id_func_mapping.txt
make .bpf_output/$1.bpf

kill $BIN_PID # for now

echo "Stopping"
