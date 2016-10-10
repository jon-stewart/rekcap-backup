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

EXTERN find_auxv, get_auxv_val, set_auxv_val
EXTERN xor_copy
EXTERN _mmap, _munmap

%include "src/elf.mac"
%include "src/syscall.mac"

; Address to unpack the original elf file
%define ELF_SCRATCHPAD      0x2000000

; Address to read in interpreter
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


    ; find vaddr and size of .data segment
    mov     rax, [rbp-0x10]         ; phdr address
    mov     rbx, [rbp-0x18]         ; phdr entry size
    lea     rdi, [rax + rbx]        ; 2nd phdr
    get_phdr_virt_info rdi, rax, rbx
    mov     [rbp-0x28], rax
    mov     [rbp-0x30], rbx

    mmap ELF_SCRATCHPAD, [rbp-30]

    ; copy and xor original elf into mapped region
    mov     rdi, ELF_SCRATCHPAD     ; dst
    mov     rsi, [rbp-0x28]         ; src
    mov     rdx, [rbp-0x30]         ; count
    mov     r8, 0x90                ; xor value
    call    xor_copy

    mov     rdi, ELF_SCRATCHPAD
    call    userland_exec

    ; munmap the scratch pad
    munmap ELF_SCRATCHPAD, [rbp-0x30]


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
; Name:
;   userland_exec
;
; Description:
;   Traverse elf headers and find the PT_INTERP and PT_LOAD phdrs.
;
;   For each PT_LOAD: mmap.
;
;   Read in interpreter to the interp scratch pad.  For each PT_LOAD: mmap.
;
;   Munmap the interp scratch pad.
;
;   Change values of the AUXV on stack to reflect new elf.
;
;   Return interpeter e_entry point.  Caller must cleanup stack frame and
;   scratchpads and jump to this address.
;
; Stack:
;   [rbp-0x8]  : phdr addr
;   [rbp-0x10] : phdr size
;   [rbp-0x18] : number of phdr
;   [rbp-0x20] : base of elf TODO tidy
;
; In:
;   rdi-base address of elf scratch pad
;
; Out:
;   rax-interpreter e_entry point
;
; Modifies:
;
userland_exec:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 0x20

    mov     [rbp-0x20], rdi

    mov     rax, [rdi + 0x20]       ; e_phoff
    lea     rbx, [rdi + rax]        ; phdr addr
    mov     [rbp-0x8], rbx

    xor     rax, rax
    mov     al, [rdi + 0x36]        ; e_phent
    mov     [rbp-0x10], rax

    xor     rax, rax
    mov     al, [rdi + 0x38]        ; e_phnum
    mov     [rbp-0x18], rax


    mov     rdi, [rbp-0x8]          ; phdr addr
    mov     rsi, [rbp-0x10]         ; e_phent
    mov     rdx, [rbp-0x18]         ; e_phnum
    call    load_elf

    mov     rdi, [rbp-0x8]          ; phdr addr
    mov     rsi, [rbp-0x10]         ; e_phent
    mov     rdx, [rbp-0x18]         ; e_phnum
    mov     r8,  [rbp-0x20]
    call    load_interp

    mov     rsp, rbp
    pop     rbp
    ret

;------------------------------------------------------------------------------
; Name:
;   load_elf
;
; Description:
;   Iterate through phdr and mmap in PT_LOAD segments
;
; Stack:
;   Nothing
;
; In:
;   rdi-phdr addr
;   rsi-phdr size
;   rdx-number of phdr
;
; Modifies:
;   rax
;   rbx
;   rcx
;   rdx
;   rdi
;   rsi
;
; Calls:
;   mmap
;
load_elf:
    mov     rbx, rsi
    mov     rsi, rdi
    mov     rcx, rdx

    ; foreach phdr - if PT_LOAD : mmap
    jmp     .begin
.loop:
    add     rsi, rbx                ; move to next phdr
    dec     rcx

    test    rcx, rcx
    jz      .end

.begin:
    xor     rax, rax
    mov     eax, [rsi]              ; p_type
    cmp     eax, 1                  ; PT_LOAD
    jne     .loop

    push    rbx

    mov     rdi, rsi                ; phdr addr
    get_phdr_virt_info rdi, rax, rdx

    push    rsi
    push    rcx

    mmap rax, rdx

    pop     rcx
    pop     rsi
    pop     rbx

    jmp     .loop

.end:
    ret

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

    get_phdr_phys_info rsi, rdi, rsi

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
    call    fstat_filesz

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
    get_phdr_virt_info rdi, rax, rdx

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

;------------------------------------------------------------------------------
; Name:
;   fstat_filesz
;
; In:
;   rdi-fd
;
; Out:
;   rax-file size
fstat_filesz:
    push    rbp
    mov     rbp, rsp

    sub     rsp, 144                ; sizeof struct stat

    mov     rax, 5                  ; sys_fstat
    mov     rsi, rsp                ; statbuf
    syscall

    mov     rax, [rsp + 48]         ; st_size

    mov     rsp, rbp
    pop     rbp
    ret
