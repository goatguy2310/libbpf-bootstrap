// SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
/* Copyright (c) 2020 Facebook */
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>
#include "bootstrap.h"

char LICENSE[] SEC("license") = "Dual BSD/GPL";

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, 8192);
	__type(key, pid_t);
	__type(value, u64);
} exec_start SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_RINGBUF);
	__uint(max_entries, 256 * 1024);
} rb SEC(".maps");

const volatile char faker[100];
const volatile unsigned long long min_duration_ns = 0;

SEC("tp/sched/sched_process_exit")
int handle_exit(struct trace_event_raw_sched_process_template *ctx)
{
	struct task_struct *task;
	struct event *e;
	pid_t pid, tid;
	u64 id, ts, *start_ts, duration_ns = 0;

	/* get PID and TID of exiting thread/process */
	id = bpf_get_current_pid_tgid();
	pid = id >> 32;
	tid = (u32)id;

	/* ignore thread exits */
	if (pid != tid)
		return 0;

	/* if we recorded start of the process, calculate lifetime duration */
	u64 start_lookup = bpf_ktime_get_ns();
	start_ts = bpf_map_lookup_elem(&exec_start, &pid);
	bpf_printk("Hash lookup time: %llu", bpf_ktime_get_ns() - start_lookup);
	if (start_ts)
		duration_ns = bpf_ktime_get_ns() - *start_ts;
	else if (min_duration_ns)
		return 0;
	bpf_map_delete_elem(&exec_start, &pid);

	/* if process didn't live long enough, return early */
	if (min_duration_ns && duration_ns < min_duration_ns)
		return 0;

	/* reserve sample from BPF ringbuf */
	e = bpf_ringbuf_reserve(&rb, sizeof(*e), 0);
	if (!e)
		return 0;

	/* fill out the sample with data */
	task = (struct task_struct *)bpf_get_current_task();

	e->exit_event = true;
	e->duration_ns = duration_ns;
	e->pid = pid;
	e->ppid = BPF_CORE_READ(task, real_parent, tgid);
	e->exit_code = (BPF_CORE_READ(task, exit_code) >> 8) & 0xff;
	bpf_get_current_comm(&e->comm, sizeof(e->comm));

	/* send data to user-space for post-processing */
	bpf_ringbuf_submit(e, 0);

	// bonjour(0, 2);
	// bpf_loop(1, bonjour, (void *) 0, 0);
	return 0;
}

struct {
	__uint(type, BPF_MAP_TYPE_PROG_ARRAY);
	__uint(key_size, sizeof(u32));
	__uint(max_entries, 1);
	__array(values, u32 (void *));
} progs SEC(".maps") = {
	.values = {
		[0] = (void *)&handle_exit
	},
};

struct flow_key {
  union {
    __be32 src;
    __be32 srcv6[4];
  };
  union {
    __be32 dst;
    __be32 dstv6[4];
  };
  union {
    __u32 ports;
    __u16 port16[2];
  };
  __u8 proto;
};

struct packet_description {
  struct flow_key flow;
  __u32 real_index;
  __u8 flags;
  // dscp / ToS value in client's packet
  __u8 tos;
};

// __attribute__((__always_inline__)) static inline int
__attribute__((__always_inline__)) static inline int test2(int pid, struct trace_event_raw_sched_process_template *ctx, int idx) {
	char c = faker[idx] + 100;	
	bpf_printk("woah2 %d%c\n", pid, c);
	bpf_tail_call(ctx, &progs, 0);
	return 0;
}
__attribute__((__always_inline__)) static inline int test(int pid, struct trace_event_raw_sched_process_template *ctx) {
	char c = faker[2] + 60;
	struct packet_description something = {};
	bpf_printk("woah %d%c\n", pid, c);
	if (pid < 100) {
		return test2(pid, ctx, 2);
	} else if (pid < 200) {
		return 0;
	}
	something.real_index = something.flow.src = 1;
	return test2(pid, ctx, 0);
}

SEC("tp/sched/sched_process_exit")
int handle_exit2(struct trace_event_raw_sched_process_template *ctx)
{
	int pid = bpf_get_current_pid_tgid() >> 32;	
	// bpf_tail_call(ctx, &progs, 0);

	// int (*tail)(void *) = (int (*)(void *)) 123;
	// return tail(ctx);
	if (pid % 2 == 0) return test(pid, ctx);
	bpf_printk("kkk\n");
	
	return test2(pid - 1, ctx, 1);
}

SEC("tp/sched/sched_process_exec")
int handle_exec(struct trace_event_raw_sched_process_exec *ctx)
{
	struct task_struct *task;
	unsigned fname_off;
	struct event *e;
	pid_t pid;
	u64 ts;

	/* remember time exec() was executed for this PID */
	pid = bpf_get_current_pid_tgid() >> 32;
	ts = bpf_ktime_get_ns();
	bpf_map_update_elem(&exec_start, &pid, &ts, BPF_ANY);

	/* don't emit exec events when minimum duration is specified */
	if (min_duration_ns)
		return 0;

	/* reserve sample from BPF ringbuf */
	e = bpf_ringbuf_reserve(&rb, sizeof(*e), 0);
	if (!e)
		return 0;

	/* fill out the sample with data */
	task = (struct task_struct *)bpf_get_current_task();

	e->exit_event = false;
	e->pid = pid;
	e->ppid = BPF_CORE_READ(task, real_parent, tgid);
	bpf_get_current_comm(&e->comm, sizeof(e->comm));

	fname_off = ctx->__data_loc_filename & 0xFFFF;
	bpf_probe_read_str(&e->filename, sizeof(e->filename), (void *)ctx + fname_off);

	/* successfully submit it to user-space for post-processing */
	bpf_ringbuf_submit(e, 0);

	// bonjour(0, 1);
	// bpf_loop(1, bonjour, (void *) 0, 0);
	// bpf_tail_call(ctx, &progs, 0);
	return 0;
}
