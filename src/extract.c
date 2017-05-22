
#include <sys/auxv.h>
#include <elf.h>


/*
 * definitions
 */

#define ELF_SCRATCHPAD  (0xffff400000)
#define LD_SCRATCHPAD   (0xffffd00000)

typedef unsigned long long u64;


/*
 * extern
 */

extern int _mmap(void *, unsigned long, unsigned long);

extern void _munmap(void *, unsigned long);

extern int _open(char *);

extern int _fstat_size(int);

extern int _read(int, void *, int);


/*
 * static function def
 */

static Elf64_Ehdr *extract_elf(Elf64_Phdr *);

static void load_interp(Elf64_Ehdr *ehdr);

static void copy(char *, char *, int, char);

static void pt_load(Elf64_Ehdr *);

static void *auxv_base_addr(void *);

static u64 auxv_read(void *, int);




void
extract(void *stack)
{
    Elf64_Ehdr *elf_hdr;
    Elf64_Phdr *phdr;
    void       *auxv;

    auxv = auxv_base_addr(stack);

    phdr = (Elf64_Phdr *) auxv_read(auxv, AT_PHDR);

    /* 2nd phdr represents payload segment */
    ++phdr;

    elf_hdr = extract_elf(phdr);

    pt_load(elf_hdr);

    load_interp(elf_hdr);

    /* Cleanup elf */
    _munmap((void *) ELF_SCRATCHPAD, phdr->p_memsz);

}

/*
 * - get interp section from elf
 * - read interp into scratchpad
 * - dynamic pt_load
 */
static void
load_interp(Elf64_Ehdr *ehdr)
{
    Elf64_Phdr     *phdr, *interp = 0;
    Elf64_Half      phnum;
    Elf64_Off       phoff;
    u64             string;
    int             i, fd, size;

    phoff = ehdr->e_phoff;
    phnum = ehdr->e_phnum;

    phdr  = (Elf64_Phdr *) ((char *) ehdr + phoff);

    for (i = 0; i < phnum; ++i, ++phdr) {
        if (phdr->p_type == PT_INTERP) {
            interp = phdr;
            break;
        }
    }

    if (interp) {
        string = ((u64) ehdr) + interp->p_offset;

        if ((fd = _open((char *) string)) < 0) {
            // XXX return err
            return;
        }

        size = _fstat_size(fd);

        _mmap((void *) LD_SCRATCHPAD, size, 0);

        if (_read(fd, (char *) LD_SCRATCHPAD, size) != size) {
            // XXX handle err
            return;
        }
    }
}


/*
 * mmap scratchpad to copy payload into.  Decode.
 */
static Elf64_Ehdr *
extract_elf(Elf64_Phdr *phdr)
{
    _mmap((void *) ELF_SCRATCHPAD, phdr->p_memsz, 0);

    copy((char *) ELF_SCRATCHPAD, (char *) phdr->p_vaddr, phdr->p_memsz, 0x90);

    return ((Elf64_Ehdr *) ELF_SCRATCHPAD);
}

static void
copy(char *dst, char *src, int len, char xor)
{
    int i;

    for (i = 0; i < len; ++i) {
        dst[i] = (src[i] ^ xor);
    }
}

/*
 * XXX doesn't properly handle DYN
 */
static void
pt_load(Elf64_Ehdr *ehdr)
{
    Elf64_Phdr     *phdr;
    Elf64_Off       phoff;
    Elf64_Half      phnum;
    unsigned long   addr;
    unsigned long   size;
    unsigned long   off;
    int             i;

    phoff = ehdr->e_phoff;
    phnum = ehdr->e_phnum;

    phdr  = (Elf64_Phdr *) ((char *) ehdr + phoff);

    for (i = 0; i < phnum; ++i, ++phdr) {
        if (phdr->p_type != PT_LOAD) {
            continue;
        }

        /* ELF_PAGESTART(p_vaddr) : page boundary */
        addr = phdr->p_vaddr & ~(4096 - 1);

        /* p_filesz + ELF_PAGEOFFSET(p_vaddr) : add what was chopped from addr to size */
        size = phdr->p_filesz + (phdr->p_vaddr & (4096 - 1));

        /* ELF_PAGEALIGN(size) : round up to page boundary */
        size = (size + (4096 - 1) & ~(4096 - 1));

        /* p_offset - ELF_PAGEOFFSET(p_vaddr) : offset from mmap region (expect 0) (?) */
        off = phdr->p_offset - (phdr->p_vaddr & (4096 - 1));

        _mmap((void *) addr, size, off);

        copy((char *) phdr->p_vaddr, ((char *) ehdr + phdr->p_offset), phdr->p_filesz, 0);
    }
}

/*
 * Skip the arguments and environmental variables reach base address of auxv
 */
static void *
auxv_base_addr(void *addr)
{
    u64 *p = addr;

    while (*p++);
    
    while (*p++);

    return (p);
}

/*
 * Iterate through aux comparing keys, return associated value
 */
static u64
auxv_read(void *auxv, int key)
{
    u64 *p = auxv;

    while (*p != key) {
        ++p;
        ++p;
    }

    ++p;

    return (*p); 
}
