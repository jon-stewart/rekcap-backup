#!/bin/bash

nasm -f elf64 -o obj/main.o     src/main.s
nasm -f elf64 -o obj/extract.o  src/extract.s
nasm -f elf64 -o obj/elf.o      src/elf.s
nasm -f elf64 -o obj/syscall.o  src/syscall.s

ld -Ttext=0 -o stub.elf obj/main.o obj/extract.o obj/elf.o obj/syscall.o

objcopy stub.elf /dev/null --dump-section .text=stub.bin

rm stub.elf
