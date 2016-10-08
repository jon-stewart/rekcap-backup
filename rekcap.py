#!/usr/bin/python3

from elf import Elf
import struct


def read_file(fname):
    data = None

    with open(fname, "rb") as fp:
        data = fp.read()

    return (data)


def write_file(fname, data):
    with open(fname, "wb") as fp:
        fp.write(data)


def xor_data(fdata):
    if (type(fdata) is not bytes):
        print("[!] Expecting bytes object")
        exit(-1)

    data = struct.unpack("%dB" % len(fdata), fdata)

    out = []
    for c in data:
        out.append(c ^ 0x90)

    return (struct.pack("%dB" % len(out), *out))


extract_stub = read_file("extract")

binary = xor_data(read_file("example"))

elf = Elf()

elf.create_ehdr()

elf.create_phdr(0x800000, 5, extract_stub)

elf.create_phdr(0x400000, 6, binary)

elf.padding(200)

elf.create_binary()

elf.dump_binary("poc.elf")
