GLOBAL extract_elf, load_elf, cleanup_elf_scratchpad, userland_exec

EXTERN _mmap, _munmap, fstat_filesz

%include "src/elf.mac"
%include "src/syscall.mac"

;------------------------------------------------------------------------------
; Name:
;   extract_elf
;
; Description:
;   Accessing the stub elf header, get p_vaddr and p_memsz from the 2nd phdr
;   which represents the segment holding the original xor'd binary.
;
;   mmap the elf scratchpad and xor copy the data into it.
;
; Stack:
;   rdi
;   rsi
;   rbx
;   rcx
;
; In:
;   rdi-elf scratchpad addr
;   rsi-phdr addr
;   rdx-phdr entry size
;
; Modifies:
;   rax
;   rdx
;
extract_elf:
    push    rdi
    push    rsi
    push    rbx
    push    rcx

    lea     rax, [rsi + rdx]        ; 2nd phdr addr

    ; rbx-p_vaddr
    ; rcx-p_memsz
    phdr_virt_info rax, rbx, rcx

    mmap    rdi, rcx

    mov     rsi, rbx                ; src
    mov     rdx, rcx                ; count
    call    xor_copy

    pop     rcx
    pop     rbx
    pop     rsi
    pop     rdi
    ret

;------------------------------------------------------------------------------
; Name:
;   xor_copy
;
; Description:
;   for i bytes in count:
;       dst[i] = (src[i] ^ xor_val)
;
;   xor value must be <255
;
; Stack:
;   rdi
;   rsi
;   rcx
;
; In:
;   rdi-dst
;   rsi-src
;   rdx-len
;
; Modifies:
;   rax
;   rdx
;
xor_copy:
    push    rdi
    push    rsi
    push    rcx

    mov     rcx, rdx
    mov     dl, 0x90            ; xor value
    jmp     .begin
.loop:
    add     rsi, 1
    add     rdi, 1
.begin:
    mov     al, [rsi]
    xor     al, dl
    mov     [rdi], al
    dec     rcx
    test    rcx, rcx
    jnz     .loop

    pop     rcx
    pop     rsi
    pop     rdi
    ret

;------------------------------------------------------------------------------
; Name:
;   load_elf
;
; Description:
;   Iterate through extracted elf phdr and mmap the PT_LOAD segments.
;
; Stack:
;   rdi
;   rsi
;   rbx
;   rcx
;
; In:
;   rdi-elf base addr
;
; Modifies:
;   rax
;   rdx
;
load_elf:
    push    rdi
    push    rsi
    push    rbx
    push    rcx

    mov     rax, [rdi + 0x20]       ; e_phoff
    lea     rsi, [rdi + rax]        ; phdr addr

    xor     rbx, rbx
    mov     bl, [rdi + 0x36]        ; e_phent

    xor     rcx, rcx
    mov     cl, [rdi + 0x38]        ; e_phnum

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

    phdr_virt_info rsi, r12, r13

    mmap    r12, r13

    jmp     .loop
.end:

    pop     rcx
    pop     rbx
    pop     rsi
    pop     rdi
    ret

;------------------------------------------------------------------------------
; Name:
;   cleanup_elf_scratchpad
;
; Description:
;   Jump phdr pointer to 2nd entry.  Get p_memsz from phdr.
;
;   Unmap the elf scratch pad
;
; Stack:
;   rdi
;   rsi
;   rbx
;   rcx
;
; In:
;   rdi-elf scratchpad addr
;   rsi-phdr addr
;   rdx-phdr entry size
;
; Modifies:
;   rax
;   rdx
;
cleanup_elf_scratchpad:
    push    rdi
    push    rsi
    push    rbx
    push    rcx

    lea     rax, [rsi + rdx]        ; 2nd phdr addr

    ; rbx-p_vaddr
    ; rcx-p_memsz
    phdr_virt_info rax, rbx, rcx

    munmap  rdi, rcx

    pop     rcx
    pop     rbx
    pop     rsi
    pop     rdi
    ret

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
;   Return interpeter e_entry point.  Caller mus
;userland_exec:
;    push    rbp
;    mov     rbp, rsp
;    sub     rsp, 0x20
;
;    mov     [rbp-0x8], rdi
;
;    mov     rax, [rdi + 0x20]       ; e_phoff
;    lea     rbx, [rdi + rax]        ; phdr addr
;    mov     [rbp-0x8], rbx
;
;    xor     rax, rax
;    mov     al, [rdi + 0x36]        ; e_phent
;    mov     [rbp-0x10], rax
;
;    xor     rax, rax
;    mov     al, [rdi + 0x38]        ; e_phnum
;    mov     [rbp-0x18], rax
;
;
;    mov     rdi, [rbp-0x8]          ; phdr addr
;    mov     rsi, [rbp-0x10]         ; e_phent
;    mov     rdx, [rbp-0x18]         ; e_phnum
;    call    load_elf
;
;    mov     rdi, [rbp-0x8]          ; phdr addr
;    mov     rsi, [rbp-0x10]         ; e_phent
;    mov     rdx, [rbp-0x18]         ; e_phnum
;    mov     r8,  [rbp-0x20]
;    call    load_interp
;
;    mov     rsp, rbp
;    pop     rbp
;    ret
