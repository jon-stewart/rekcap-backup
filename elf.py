#!/usr/bin/python3

import struct

#    Elf64_Half : unsigned short     (H)
#    Elf64_Word : unsigned int       (I)
#    Elf64_Addr : unsigned long long (Q)
#    Elf64_Off  : unsigned long long (Q)

def elf_hdr(entry):
    '''
    '''
    fmt   = "4sBBBBB7sHHIQQQIHHHHHH"

    ei_mag      = "\x7fELF".encode("UTF-8")
    ei_class    = 2
    ei_data     = 1
    ei_ver      = 1
    ei_osabi    = 0
    ei_abiver   = 0
    ei_pad      = "".encode("UTF-8")
    e_type      = 2
    e_machine   = 0x3e
    e_version   = 1
    e_entry     = entry
    e_phoff     = 64
    e_shoff     = 0
    e_flags     = 0
    e_ehsize    = 64
    e_phentsize = 56
    e_phnum     = 1
    e_shentsize = 0
    e_shnum     = 0
    e_shstrndx  = 0

    hdr = struct.pack(fmt,
            ei_mag,
            ei_class,
            ei_data,
            ei_ver,
            ei_osabi,
            ei_abiver,
            ei_pad,
            e_type,
            e_machine,
            e_version,
            e_entry,
            e_phoff,
            e_shoff,
            e_flags,
            e_ehsize,
            e_phentsize,
            e_phnum,
            e_shentsize,
            e_shnum,
            e_shstrndx)

    return (hdr)


def elf_phdr(offset, va, size):
    '''
    p_type  : PT_LOAD (1)
    p_flags : (exec (1) | write (2) | read (4))
    '''
    fmt = "IIQQQQQQ"

    p_type   = 1
    p_offset = offset
    p_vaddr  = va
    p_paddr  = va
    p_filesz = size
    p_memsz  = size
    p_flags  = 0x5
    p_align  = 0x200000

    phdr = struct.pack(fmt,
            p_type,
            p_flags,
            p_offset,
            p_vaddr,
            p_paddr,
            p_filesz,
            p_memsz,
            p_align)

    return (phdr)


def stub():
    '''
    '''

    data = None

    with open("extract", "rb") as fp:
        data = fp.read()

    return (data)


padding = struct.pack("200s", "".encode("UTF-8"))

data = elf_hdr(0x400000 + 64 + 56)

data += elf_phdr(0, 0x400000, 0xf0)

data += stub()

data += padding

with open("lol", "wb") as fp:
    fp.write(data)
