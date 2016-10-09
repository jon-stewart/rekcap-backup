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
; [rbp-0x8]  : base address
; [rbp-0x10] : phdr vaddr
; [rbp-0x18] : phdr size
; [rbp-0x20] : phdr number

global _start

_start:
; rbp is NULL - nothing to push to stack
    mov     rbp, rsp
    sub     rsp, 0x20
    call    delta

delta:
    pop     rax
    sub     rax, delta
    mov     [rbp-8], rax

    print   [rbp-8], msg_start, msg_start_sz

    mov     rdi, rsp
    add     rdi, 0x20           ; need to move past stack frame
    call    find_auxv

    ; found auxv

    ; AT_PHDR  (3)
    mov     rax, [rsi + 0x48]
    cmp     rax, 3
    jne     exit                ; verify
    mov     rax, [rsi + 0x50]
    mov     [rbp-0x10], rax

    ; AT_PHENT (4)
    mov     rax, [rsi + 0x58]
    cmp     rax, 4              ; verify
    jne     exit
    mov     rax, [rsi + 0x60]
    mov     [rbp-0x18], rax

    ; AT_PHNUM (5)
    mov     rax, [rsi + 0x68]
    cmp     rax, 5              ; verify
    jne     exit
    mov     rax, [rsi + 0x70]
    mov     [rbp-0x20], rax

    print   [rbp-8], msg_end, msg_end_sz

exit:
    mov     rsp, rbp
    pop     rbp

    mov     rax, 60             ; sys_exit
    xor     rdi, rdi            ; err
    syscall

msg_start:      db "start",10,0
msg_start_sz:   equ $-msg_start

msg_end:        db "end",10,0
msg_end_sz:     equ $-msg_end


;------------------------------------------------------------------------------
; Name:
;   find_auxv
;
; Description:
;   Jump rsi to beyond argc, argv and NULL to the start of environ vars.
;
;   Traverse stack with rsi until hit NULL, this is end of environ var.
;
;   Inc rsi 8byte to the start of auxv and return in rax.
;
; Stack:
;   No need to store/adjust
;
; In:
;   rdi-start address of stack
;
; Out:
;   rax-start address of auxv
;
; Reg:
;   rax
;   rsi
;
find_auxv:
    mov     rsi, rdi
    add     rsi, 0x18
loop:
    add     rsi, 8
    mov     rax, [rsi]
    test    rax, rax
    jne     loop

    add     rsi, 8
    mov     rax, rsi
    ret
