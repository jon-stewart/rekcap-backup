;------------------------------------------------------------------------------
; Name:
;   extract
;
; Description:
;   Stub of code placed along side packed elf executable.
;
;   - Traverse stack to find program header info from AUXV
;   - mmap unpack location, size of packed elf
;   - xor segment into unpack location
;   - munmap segment
;   - userland exec
;
[section .text]

[BITS 64]

; elf.s
EXTERN find_auxv, get_auxv_val

; user_exec.s
EXTERN extract_elf, load_elf, find_interp, read_interp, load_interp, update_auxv

; syscalls.s
EXTERN _mmap, _munmap


%include "src/elf.mac"
%include "src/syscall.mac"

%define ELF_SCRATCHPAD      0x2000000
%define INTERP_SCRATCHPAD   0x4000000

; stack
; [rbp-0x8]  : base addr
; [rbp-0x10] : auxv addr
; [rbp-0x18] : elf scratchpad size
; [rbp-0x20] : interp scratchpad size
; [rbp-0x28] : interp e_entry TODO  needs be DYN address loaded to

global _start

_start:
    mov     rbp, rsp                ; rbp is NULL - nothing to push to stack
    sub     rsp, 0x28
    call    delta

delta:
    pop     rax
    sub     rax, delta
    mov     [rbp-8], rax

    print   [rbp-8], msg_start, msg_start_sz

    mov     rdi, rbp                ; beyond stack frame
    call    find_auxv

    mov     [rbp-0x10], rax         ; base addr of auxv

    mov     rdi, rax

    mov     rsi, 3                  ; AT_PHDR
    call    get_auxv_val
    mov     r10, rax

    mov     rsi, 4                  ; AT_PHENT
    call    get_auxv_val
    mov     r11, rax

    mov     rdi, ELF_SCRATCHPAD
    mov     rsi, r10                ; phdr addr
    mov     rdx, r11                ; phdr entry size
    call    extract_elf

    mov     [rbp-0x18], rax         ; elf scratchpad size

    call    load_elf

    call    find_interp

    mov     rdi, INTERP_SCRATCHPAD
    mov     rsi, rax                ; interp string addr
    call    read_interp

    mov     [rbp-0x20], rax         ; interp scratchpad size

    call    load_interp

    mov     [rbp-0x28], rax         ; interp e_entry

    mov     rdi, [rbp-0x10]         ; auxv addr
    mov     rsi, ELF_SCRATCHPAD
    mov     rdx, 0x6000000          ; interp .text dyn address TODO tidy
    call    update_auxv

    munmap  ELF_SCRATCHPAD, [rbp-0x18]

    munmap  INTERP_SCRATCHPAD, [rbp-0x20]

    print   [rbp-8], msg_end, msg_end_sz

fin:
    mov     rax, [rbp-0x28]
    mov     rsp, rbp
    jmp     rax                     ; fingers crossed

exit:

    mov     rax, 60                 ; sys_exit
                                    ; rdi:error code
    syscall

msg_start:      db "start",10,0
msg_start_sz:   equ $-msg_start

msg_end:        db "end",10,0
msg_end_sz:     equ $-msg_end
