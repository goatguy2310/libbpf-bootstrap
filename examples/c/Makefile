# SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
PROG_TYPE ?=

HEADER_OVERRIDE := .header_override
OUTPUT := .output
BPF_OUTPUT := .bpf_output
LOADER_OUTPUT := .loader_output
CLANG ?= clang
LIBBPF_SRC := $(abspath ../../libbpf/src)
BPFTOOL_SRC := $(abspath ../../bpftool/src)
LIBBPF_OBJ := $(abspath $(OUTPUT)/libbpf.a)
BPFTOOL_OUTPUT ?= $(abspath $(OUTPUT)/bpftool)
BPFTOOL ?= $(BPFTOOL_OUTPUT)/bootstrap/bpftool
ARCH ?= $(shell uname -m | sed 's/x86_64/x86/' \
			 | sed 's/arm.*/arm/' \
			 | sed 's/aarch64/arm64/' \
			 | sed 's/ppc64le/powerpc/' \
			 | sed 's/mips.*/mips/' \
			 | sed 's/riscv64/riscv/' \
			 | sed 's/loongarch64/loongarch/')
VMLINUX := ../../vmlinux.h/include/$(ARCH)/vmlinux.h
# Use our own libbpf API headers and Linux UAPI headers distributed with
# libbpf to avoid dependency on system-wide headers, which could be missing or
# outdated
INCLUDES := -I$(OUTPUT) -I../../libbpf/include/uapi -I$(dir $(VMLINUX))
CFLAGS := -g -Wall

CFLAGS_BPF := -Wno-unknown-attributes -mcmodel=large -fno-pie -nopie -nostartfiles

LINKER_SCRIPTS := .linker_scripts
LINKING_COMMAND := -Wl,-T,

APPS = minimal bootstrap kprobe
# minimal minimal_legacy minimal_ns bootstrap uprobe kprobe fentry \
       usdt sockfilter tc ksyscall task_iter lsm

# Get Clang's default includes on this system. We'll explicitly add these dirs
# to the includes list when compiling with `-target bpf` because otherwise some
# architecture-specific dirs will be "missing" on some architectures/distros -
# headers such as asm/types.h, asm/byteorder.h, asm/socket.h, asm/sockios.h,
# sys/cdefs.h etc. might be missing.
#
# Use '-idirafter': Don't interfere with include mechanics except where the
# build would have failed anyways.
CLANG_BPF_SYS_INCLUDES ?= $(shell $(CLANG) -v -E - </dev/null 2>&1 \
	| sed -n '/<...> search starts here:/,/End of search list./{ s| \(/.*\)|-idirafter \1|p }')

ifeq ($(V),1)
	Q =
	msg =
else
	Q = @
	msg = @printf '  %-10s %s%s\n'					\
		      "$(1)"						\
		      "$(patsubst $(abspath $(OUTPUT))/%,%,$(2))"	\
		      "$(if $(3), $(3))";
	MAKEFLAGS += --no-print-directory
endif

define allow-override
  $(if $(or $(findstring environment,$(origin $(1))),\
            $(findstring command line,$(origin $(1)))),,\
    $(eval $(1) = $(2)))
endef

$(call allow-override,CC,$(CROSS_COMPILE)cc)
$(call allow-override,LD,$(CROSS_COMPILE)ld)

.PHONY: all loader tidy clean
all: $(foreach app, $(APPS), $(LOADER_OUTPUT)/$(app) $(BPF_OUTPUT)/$(app).bpf)

loader: $(foreach app, $(APPS), $(LOADER_OUTPUT)/$(app))

tidy:
	$(call msg,TIDY)
	$(Q)rm -rf $(LOADER_OUTPUT) $(BPF_OUTPUT) $(HEADER_OVERRIDE) scripts/bpf_id_func_mapping.txt

clean: tidy
	$(call msg,CLEAN)
	$(Q)rm -rf $(OUTPUT)

$(OUTPUT) $(OUTPUT)/libbpf $(BPFTOOL_OUTPUT) $(LOADER_OUTPUT) $(BPF_OUTPUT):
	$(call msg,MKDIR,$@)
	$(Q)mkdir -p $@

# Build libbpf
$(LIBBPF_OBJ): $(wildcard $(LIBBPF_SRC)/*.[ch] $(LIBBPF_SRC)/Makefile) | $(OUTPUT)/libbpf
	$(call msg,LIB,$@)
	$(Q)$(MAKE) -C $(LIBBPF_SRC) BUILD_STATIC_ONLY=1		      \
		    OBJDIR=$(dir $@)/libbpf DESTDIR=$(dir $@)		      \
		    INCLUDEDIR= LIBDIR= UAPIDIR=			      \
		    install

# Build bpftool
$(BPFTOOL): | $(BPFTOOL_OUTPUT)
	$(call msg,BPFTOOL,$@)
	$(Q)$(MAKE) ARCH= CROSS_COMPILE= OUTPUT=$(BPFTOOL_OUTPUT)/ -C $(BPFTOOL_SRC) bootstrap

# $(HEADER_OVERRIDE): bpf_core_read.h $(LIBBPF_OBJ) $(BPFTOOL)
# 	$(call msg,MKDIR,$@)
# 	$(Q)mkdir -p $@ $@/bpf
#	$(call msg,GENHEADER,$@)
#	$(Q)cp $(abspath $(OUTPUT))/bpf/bpf_helpers.h $(abspath $(HEADER_OVERRIDE))/bpf/bpf_helpers.h
#	$(Q/)cp bpf_core_read.h $(abspath $(HEADER_OVERRIDE))/bpf/bpf_core_read.h
#	$(Q)python3 scripts/map_bpf_helper.py scripts/bpf_id_func_mapping.txt
#	$(Q)python3 scripts/modify_header.py $(abspath $(OUTPUT))/bpf/bpf_helper_defs.h $(abspath $(HEADER_OVERRIDE))/bpf/bpf_helper_defs.h scripts/bpf_id_func_mapping.txt

# Build BPF code to native code (First task)
$(BPF_OUTPUT)/%.bpf: %.bpf.c $(LIBBPF_OBJ) $(wildcard %.h) $(VMLINUX) | $(OUTPUT) $(BPF_OUTPUT) $(BPFTOOL)
	$(call msg,BPF,$@)
	$(if $(wildcard $(HEADER_OVERRIDE)/$(PROG_TYPE)/),$(call msg,HEADER,$(HEADER_OVERRIDE)/$(PROG_TYPE)/)) 
	$(if $(wildcard $(LINKER_SCRIPTS)/$*.ld),$(call msg,LINKSCRIPT,$(LINKER_SCRIPTS)/$*.ld)) 
	$(Q)$(CLANG) -O3 -D__TARGET_ARCH_$(ARCH) $(CFLAGS_BPF)                                      \
		$(if $(wildcard $(HEADER_OVERRIDE)/$(PROG_TYPE)/),-I$(HEADER_OVERRIDE)/$(PROG_TYPE)/)    \
		$(INCLUDES) $(CLANG_BPF_SYS_INCLUDES)		                                    \
		$(if $(wildcard $(LINKER_SCRIPTS)/$*.ld),$(LINKING_COMMAND)$(LINKER_SCRIPTS)/$*.ld) \
		$< -o $@

# --------------------------------------------------
# Build BPF code to BPF bytecode (Second task)
$(OUTPUT)/%.bpf.o: %.bpf.c $(LIBBPF_OBJ) $(wildcard %.h) $(VMLINUX) | $(OUTPUT) $(BPFTOOL)
	$(call msg,BPF,$@)
	$(Q)$(CLANG) -g -O2 -target bpf -D__TARGET_ARCH_$(ARCH)		      \
		     $(INCLUDES) $(CLANG_BPF_SYS_INCLUDES)		      \
		     -c $(filter %.c,$^) -o $(patsubst %.bpf.o,%.tmp.bpf.o,$@)
	$(Q)$(BPFTOOL) gen object $@ $(patsubst %.bpf.o,%.tmp.bpf.o,$@)

# Generate BPF skeletons
$(OUTPUT)/%.skel.h: $(OUTPUT)/%.bpf.o | $(OUTPUT) $(BPFTOOL)
	$(call msg,GEN-SKEL,$@)
	$(Q)$(BPFTOOL) gen skeleton $< > $@

# Build user-space code
$(patsubst %,$(OUTPUT)/%.o,$(APPS)): %.o: %.skel.h

$(OUTPUT)/%.o: %.c $(wildcard %.h) | $(OUTPUT)
	$(call msg,CC,$@)
	$(Q)$(CC) $(CFLAGS) $(INCLUDES) -c $(filter %.c,$^) -o $@

# Build application binary
$(LOADER_OUTPUT)/%: $(OUTPUT)/%.o $(LIBBPF_OBJ) | $(OUTPUT) $(LOADER_OUTPUT)
	$(call msg,BINARY,$@)
	$(Q)$(CC) $(CFLAGS) $^ $(ALL_LDFLAGS) -lelf -lz -o $@


# delete failed targets
.DELETE_ON_ERROR:

# keep intermediate (.skel.h, .bpf.o, etc) targets
.SECONDARY:
