
#include <sys/auxv.h>
#include <elf.h>


/*
 * definitions
 */

#define ELF_SCRATCHPAD  (0xffff400000)

typedef unsigned long long u64;

/*
 * extern
 */

extern int _mmap(void *, unsigned long, unsigned long);

/*
 * static function def
 */

static void extract_elf(Elf64_Phdr *);

static void
copy(char *, char *, int, char);

static void pt_load(Elf64_Ehdr *);

static void *auxv_base_addr(void *);

static u64 auxv_read(void *, int);




void
extract(void *stack)
{
    void       *auxv;
    Elf64_Phdr *phdr;

    auxv = auxv_base_addr(stack);

    phdr = (Elf64_Phdr *) auxv_read(auxv, AT_PHDR);

    /* 2nd phdr represents payload segment */
    ++phdr;

    extract_elf(phdr);

    pt_load((Elf64_Ehdr *) ELF_SCRATCHPAD);
}


/*
 * mmap scratchpad to copy payload into.  Decode.
 */
static void
extract_elf(Elf64_Phdr *phdr)
{
    _mmap((void *) ELF_SCRATCHPAD, phdr->p_memsz, 0);

    copy((char *) ELF_SCRATCHPAD, (char *) phdr->p_vaddr, phdr->p_memsz, 0x90);
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
