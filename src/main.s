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
EXTERN find_auxv, get_auxv_val, set_auxv_val

; extract.s
EXTERN extract_elf, load_elf, cleanup_elf_scratchpad

; syscalls.s
EXTERN _mmap, _munmap


%include "src/elf.mac"
%include "src/syscall.mac"

%define ELF_SCRATCHPAD      0x2000000
%define INTERP_SCRATCHPAD   0x4000000

; stack
; [rbp-0x8]  : base address
; [rbp-0x10] : phdr vaddr
; [rbp-0x18] : phdr size
; [rbp-0x20] : phdr number
; [rbp-0x28] : p_vaddr (xor'd elf address)
; [rbp-0x30] : p_memsz (xor'd elf size)

global _start

_start:
    mov     rbp, rsp                ; rbp is NULL - nothing to push to stack
    sub     rsp, 0x30
    call    delta

delta:
    pop     rax
    sub     rax, delta
    mov     [rbp-8], rax

    print   [rbp-8], msg_start, msg_start_sz

    mov     rdi, rbp                ; beyond stack frame
    call    find_auxv

    mov     rdi, rax                ; base address of auxv

    mov     rsi, 3                  ; AT_PHDR
    call    get_auxv_val
    mov     [rbp-0x10], rax

    mov     rsi, 4                  ; AT_PHENT
    call    get_auxv_val
    mov     [rbp-0x18], rax

    mov     rsi, 5                  ; AT_PHNUM
    call    get_auxv_val
    mov     [rbp-0x20], rax

    mov     rdi, ELF_SCRATCHPAD
    mov     rsi, [rbp-0x10]         ; phdr addr
    mov     rdx, [rbp-0x18]         ; phdr entry size
    call    extract_elf

    call    load_elf

    call    find_interp

    mov     rdi, INTERP_SCRATCHPAD
    mov     rsi, rax                ; interp string addr
    call    load_interp

    mov     rdi, ELF_SCRATCHPAD
    mov     rsi, [rbp-0x10]         ; phdr addr
    mov     rdx, [rbp-0x18]         ; phdr entry size
    call    cleanup_elf_scratchpad

    print   [rbp-8], msg_end, msg_end_sz

exit:
    mov     rsp, rbp
    pop     rbp

    mov     rax, 60                 ; sys_exit
                                    ; rdi:error code
    syscall

msg_start:      db "start",10,0
msg_start_sz:   equ $-msg_start

msg_end:        db "end",10,0
msg_end_sz:     equ $-msg_end


;------------------------------------------------------------------------------
; TODO Assuming there always PT_INTERP for now
;
; In:
;   rdi-phdr addr
;   rsi-phdr size
;   rdx-number of phdr
;   r8 -base addr.. TODO tidy
;
; Modifies:
;   r12
;
load_interp:
    push    rbp
    mov     rbp, rsp
    push    r12


    mov     rbx, rsi
    mov     r12, rdi
    mov     rcx, rdx

    jmp     .begin
.loop:
    add     r12, rbx
    dec     rcx

    test    rcx, rcx
    jz      .end
.begin:
    xor     rax, rax
    mov     eax, [r12]              ; p_type
    cmp     eax, 3                  ; PT_INTERP
    jne     .loop
.end:

    phdr_phys_info rsi, rdi, rsi

    sub     rsp, rdx                ; create space on stack

    ; zero out
    xor     rax, rax
    mov     rdi, rsp
    mov     rcx, rbx
    rep     stosb

    ; copy string into stack
    mov     rdi, rsp
    mov     rsi, r8
    add     rsi, rdx
    mov     rcx, rbx
    rep     movsb


    mov     rax, 2                  ; sys_open
    mov     rdi, rsp                ; filename
    xor     rsi, rsi                ; flags
    xor     rdx, rdx                ; mode
    syscall

    push    rax                     ; fd

    mov     rdi, rax
    ; call    fstat_filesz

    push    rax                     ; fsize

    mmap INTERP_SCRATCHPAD, rax

    mov     rax, 0                  ; sys_read
    pop     rdx                     ; count
    pop     rdi                     ; fd
    mov     rsi, INTERP_SCRATCHPAD  ; buf
    syscall


    ; get e_entry
    mov     rsi, INTERP_SCRATCHPAD
    mov     r13, [rsi + 0x18]       ; e_entry

    ; mmap each PT_LOAD
    mov     rbx, [rsi + 0x20]       ; e_phoff

    xor     rdx, rdx
    mov     dl,  [rsi + 0x36]       ; e_phent

    xor     rcx, rcx
    mov     cl,  [rsi + 0x38]       ; e_phnum

    lea     rsi, [rsi + rbx]        ; phdr addr

    jmp     .begin1
.loop1:
    add     rsi, rdx
    dec     rcx

    test    rcx, rcx
    jz      .end1
.begin1:
    xor     rax, rax
    mov     eax, [rsi]              ; p_type
    cmp     eax, 1                  ; PT_LOAD
    jne     .loop1


    push    rdx

    mov     rdi, rsi                ; phdr addr
    phdr_virt_info rdi, rax, rdx

    push    rsi
    push    rcx

    mmap rax, rdx

    pop     rcx
    pop     rsi
    pop     rdx

    jmp     .loop1


.end1:

    pop     r12
    mov     rsp, rbp
    pop     rbp
    ret
