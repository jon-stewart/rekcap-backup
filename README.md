# rekcap
rekcap:packer


Packing:

    * Create elf header
    * Add single program header which will load whole binary into memory
    * Shove in some compiled position independent assembly and set p_entry
    * Provide random elf and XOR it into RW segment
    * Correctly set offsets and sizes (must be 0x200000 between PT_LOAD segments)


Unpacking:

    * Traverse stack to AUXV
    * Extract elf program header info from AUXV
    * mmap(exec|write) to original elf base address (0x400000)
    * XOR original elf from segment into newly mapped memory
    * Userland exec


Auxillary Vector Keys:

    AT_PHDR  : 3
    AT_PHENT : 4
    AT_PHNUM : 5
    AT_ENTRY : 9


Userland Exec Paper:

    https://grugq.github.io/docs/ul_exec.txt
