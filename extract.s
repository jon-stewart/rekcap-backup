;------------------------------------------------------------------------------
; Name:
;   extract
;
; Description:
;   Stub of code placed along side packed elf executable.
;
;   Elf hdr e_entry should point to this code, it will then unpack original
;   executable into memory.
;
[section .text]

[BITS 64]

; stack
; [rbp-0x8] : base address

global _start

_start:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 8
    call    delta

delta:
    pop     rax
    sub     rax, delta
    mov     [rbp-8], rax

    mov     rax, 1              ; sys_write
    mov     rdi, 1              ; stdout
    mov     rdx, [rbp-8]
    lea     rsi, [rdx + str]    ; buf
    mov     rdx, str_sz         ; count
    syscall

exit:
    mov     rsp, rbp
    pop     rbp

    mov     rax, 60             ; sys_exit
    xor     rdi, rdi            ; err
    syscall

str:     db "Hello world",10,0
str_sz:  equ $-str
