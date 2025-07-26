savedcmd_replace.ko := ld -r -m elf_x86_64 -z noexecstack --no-warn-rwx-segments --build-id=sha1  -T /mnt/kernel_src/scripts/module.lds -o replace.ko replace.o replace.mod.o .module-common.o
