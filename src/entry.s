
[section .text]

[BITS 64]

extern extract
extern _print
extern _exit

global _start

_start:

    mov  rdi, rsp
    call extract

    call _exit

    ret
