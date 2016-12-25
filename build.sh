#!/bin/bash

nasm -f elf64 -o obj/entry.o   src/entry.s
nasm -f elf64 -o obj/syscall.o src/syscall.s

gcc -c -o obj/extract.o src/extract.c

#ld -Ttext=0 -o stub.elf obj/main.o obj/user_exec.o obj/elf.o obj/syscall.o
ld -o stub.elf obj/entry.o obj/syscall.o obj/extract.o

objcopy stub.elf /dev/null --dump-section .text=stub.bin

#rm stub.elf
