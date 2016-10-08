;------------------------------------------------------------------------------
; Name:
;   print
;
; Description:
;   Write string to stdout
;
; In:
;   1-base address
;   2-string offset
;   3-string length
;
%macro print 3
    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    mov     rdx, %1
    lea     rsi, [rdx + %2] ; buf
    mov     rdx, %3         ; count
    syscall
%endmacro

;------------------------------------------------------------------------------
; Name:
;   extract
;
; Description:
;   Stub of code placed along side packed elf executable.
;
;   - Traverse stack to find program header info from AUXV
;   - mmap 0x400000 size of packed elf
;   - xor 0x90 .data segment into 0x400000
;   - userland exec
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

    print [rbp-8], str, str_sz

exit:
    mov     rsp, rbp
    pop     rbp

    mov     rax, 60             ; sys_exit
    xor     rdi, rdi            ; err
    syscall

str:     db "start",10,0
str_sz:  equ $-str
