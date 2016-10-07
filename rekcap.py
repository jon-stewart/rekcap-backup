#!/usr/bin/python3

from elf import Elf

elf = Elf()

data = elf.ehdr(0x600000 + 64 + 56)

data += elf.phdr(0, 0x600000, 0xf0)

with open("extract", "rb") as fp:
    stub_data = fp.read()

data += stub_data

data += elf.padding(200)

with open("poc.elf", "wb") as fp:
    fp.write(data)
