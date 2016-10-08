#!/usr/bin/python3

from elf import Elf

with open("extract", "rb") as fp:
    stub_data = fp.read()

elf = Elf()

elf.create_ehdr()

elf.create_phdr(0, 0x800000, 0xf0, stub_data)

elf.padding(200)

elf.create_binary()

elf.dump_binary("poc.elf")
