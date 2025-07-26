savedcmd_replace.mod := printf '%s\n'   replace.o | awk '!x[$$0]++ { print("./"$$0) }' > replace.mod
