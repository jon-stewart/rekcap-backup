#!/usr/bin/python3

import struct

# Elf64_Half : unsigned short     (H)
# Elf64_Word : unsigned int       (I)
# Elf64_Addr : unsigned long long (Q)
# Elf64_Off  : unsigned long long (Q)

class Ehdr():
    '''
    '''
    e_fmt       = "4sBBBBB7sHHIQQQIHHHHHH"
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
    e_entry     = 0
    e_phoff     = 64
    e_shoff     = 0
    e_flags     = 0
    e_ehsize    = 64
    e_phentsize = 56
    e_phnum     = 0
    e_shentsize = 0
    e_shnum     = 0
    e_shstrndx  = 0

    def pack(self):
        return (struct.pack(self.e_fmt,
                self.ei_mag,
                self.ei_class,
                self.ei_data,
                self.ei_ver,
                self.ei_osabi,
                self.ei_abiver,
                self.ei_pad,
                self.e_type,
                self.e_machine,
                self.e_version,
                self.e_entry,
                self.e_phoff,
                self.e_shoff,
                self.e_flags,
                self.e_ehsize,
                self.e_phentsize,
                self.e_phnum,
                self.e_shentsize,
                self.e_shnum,
                self.e_shstrndx))


class Phdr():
    '''
    '''
    p_fmt    = "IIQQQQQQ"
    p_type   = 1
    p_offset = 0
    p_vaddr  = 0
    p_paddr  = 0
    p_filesz = 0
    p_memsz  = 0
    p_flags  = 0
    p_align  = 0x200000

    def pack(self):
        return (struct.pack(self.p_fmt,
                self.p_type,
                self.p_flags,
                self.p_offset,
                self.p_vaddr,
                self.p_paddr,
                self.p_filesz,
                self.p_memsz,
                self.p_align))



class Elf():
    '''
    '''

    def __init__(self):
        self.ehdr     = None
        self.seg_list = []
        self.pad      = "".encode("UTF-8")
        self.raw      = None


    def create_ehdr(self):
        '''
        '''
        self.ehdr = Ehdr()


    def create_phdr(self, offset, va, sz, segment):
        '''
        p_type  : PT_LOAD (1)
        p_flags : (exec (1) | write (2) | read (4))

        First PT_LOAD segment must contain ehdr and phdrs (offset=0)
        '''
        if (len(self.seg_list) == 0) and (offset != 0):
            print("[!] First segment must have zero offset.")
            return

        phdr = Phdr()

        phdr.p_offset = offset
        phdr.p_vaddr  = va
        phdr.p_paddr  = va
        phdr.p_filesz = sz
        phdr.p_memsz  = sz
        phdr.p_flags  = 0x5

        self.seg_list.append((phdr, segment))

        self.ehdr.e_phnum += 1


    def padding(self, sz):
        '''
        '''
        self.pad = struct.pack("{0}s".format(sz), "".encode("UTF-8"))


    def set_entry_point(self):
        '''
        First PT_LOAD segment must contain ehdr and phdrs.

        For now program entry point is within same segment, set value to address beyond ehdr and phdrs.
        '''
        (phdr, _) = self.seg_list[0]

        self.ehdr.e_entry = (phdr.p_vaddr + self.ehdr.e_ehsize + (self.ehdr.e_phnum * self.ehdr.e_phentsize))


    def create_binary(self):
        '''
        '''
        self.set_entry_point()

        self.raw = self.ehdr.pack()

        for (phdr, _) in self.seg_list:
            self.raw += phdr.pack()

        # TODO any way to ensure correct offset?
        for (_, segment) in self.seg_list:
            self.raw += segment

        self.raw += self.pad


    def dump_binary(self, fname):
        if (self.raw):
            with open(fname, "wb") as fp:
                fp.write(self.raw)
        else:
            print("[!] No raw binary to write out")
