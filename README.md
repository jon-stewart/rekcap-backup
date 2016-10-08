# rekcap
rekcap:packer

 * Create elf header
 * Add single program header which will load whole binary into memory
 * Shove in some compiled position independent assembly and set p_entry

Next:
 ~~* Load elf into some other address~~
 ~~* Provide a random elf and XOR it into a new .data segment~~
 * Have stub traverse stack to AUXV and find the elf program headers
 * mmap(exec|write) to 0x400000
 * XOR original elf from .data segment into 0x400000
 * Userland exec
