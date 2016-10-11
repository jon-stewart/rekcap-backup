GLOBAL extract_elf, load_elf, find_interp, read_interp, load_interp, update_auxv

EXTERN _mmap, _munmap, open, read, _fstat
EXTERN set_auxv_val

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
; Out:
;   rax-size of scratchpad
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

    mov     rax, rcx

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
;   [rbp-0x8] : elf base addr
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
    push    rbp
    mov     rbp, rsp
    sub     rsp, 8

    push    rdi
    push    rsi
    push    rbx
    push    rcx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     [rbp-0x8], rdi

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

    phdr_phys_info rsi, r14, r15

    add     r14, [rbp-0x8]          ; add base address to p_offset
    add     r13, 0xf6fb8            ; TODO this is a hack - mmap rounding down, memcpy blows up

    push    rsi
    push    rcx

    mmap    r12, r13

    mov     rdi, r12
    mov     rsi, r14
    mov     rcx, r15
    cld
    rep     movsb                   ; copy data into new segment

    pop     rcx
    pop     rsi

    jmp     .loop
.end:

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rcx
    pop     rbx
    pop     rsi
    pop     rdi
    mov     rsp, rbp
    pop     rbp
    ret

;------------------------------------------------------------------------------
; Name:
;   find_interp
;
; Description:
;   Access the original elf headers and return the addr/size of the PT_INTERP
;   segment.
;
; Stack:
;   rsi
;   rbx
;   rcx
;
; In:
;   rdi-elf base addr
;
; Out:
;   rax-address of interp string
;   rdx-length of interp string
;
; Modifies:
;   rax
;   rdx
;
find_interp:
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
    add     rsi, rbx
    dec     rcx

    test    rcx, rcx
    jz      .end
.begin:
    xor     rax, rax
    mov     eax, [rsi]              ; p_type
    cmp     eax, 3                  ; PT_INTERP
    jne     .loop
.end:

    phdr_phys_info rsi, rax, rdx

    add     rax, rdi                ; add elf base address to interp string offset

    pop     rcx
    pop     rbx
    pop     rsi
	ret

;------------------------------------------------------------------------------
; Name:
;   read_interp
;
; Description:
;   fstat interpreter file and get fsize.  Map region of memory and read in
;   file.
;
;   Return fsize so it can be cleaned up later.
;
; Stack:
;   [rbp-0x8]  : interp scratchpad addr
;   [rbp-0x10] : interp string addr
;   rcx
;
; In:
;   rdi-interp scratchpad addr
;   rsi-interp string addr
;
; Out:
;   rax-interpreter size
;
; Modifies:
;   rax
;
read_interp:
    push    rbp
    mov     rbp, rsp
    push    rdi
    push    rsi
    push    rcx

    mov     [rbp-8], rdi
    mov     [rbp-0x10], rsi

    fstat_filesz rsi

    mmap    [rbp-8], rcx

    mov     rdi, [rbp-0x10]
    call    open

    mov     rdi, rax            ; fd
    mov     rsi, [rbp-8]        ; buf addr
    mov     rdx, rcx            ; count
    call    read

    mov     rax, rcx            ; return interp size

    pop     rcx
    pop     rsi
    pop     rdi
    pop     rbp
    ret

;------------------------------------------------------------------------------
; Name:
;   load_interp
;
; Description:
;   Iterate through the interpreter elf headers and mmap the PT_LOAD segments.
;
; Stack:
;   [rbp-0x8]  : e_entry
;   [rbp-0x10] : elf base addr
;   rdi
;   rsi
;   rbx
;   rcx
;   r12
;   r13
;   r14
;   r15
;
; In:
;   rdi-interp elf base addr
;
; Out:
;   rax-interp e_entry
;
; Modifies:
;   rax
;
; TODO:  need rounding down/up of vaddr/length
;
load_interp:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 0x10
    push    rdi
    push    rsi
    push    rbx
    push    rcx
    push    r12
    push    r13
    push    r14
    push    r15

    nop                                 ; TODO i should merge load_elf/load_interp
    nop

    mov     [rbp-0x10], rdi

    mov     rax, [rdi + 0x18]         ; e_entry
    add     rax, 0x6000000              ; TODO hard coded for speed.  p_entry + base load address
    mov     [rbp-0x8], rax

    mov     rsi, [rdi + 0x20]         ; e_phoff
    lea     rsi, [rdi + rsi]          ; phdr addr

    xor     rbx, rbx
    mov     bl, [rdi + 0x36]         ; e_phent

    xor     rcx, rcx
    mov     cl, [rdi + 0x38]         ; e_phnum

    jmp     .begin
.loop:
    add     rsi, rbx
    dec     rcx

    test    rcx, rcx
    jz      .end
.begin:
    xor     rax, rax
    mov     eax, [rsi]              ; p_type
    cmp     eax, 1                  ; PT_LOAD
    jne     .loop

    phdr_virt_info rsi, r12, r13

                                    ; TODO if E_TYPE ET_DYN
    test    r12, r12                ; ld-linux is DYN of course! pick some random address
    jnz     .hop
    mov     r12, 0x6000000          ; TODO tidy hardcoded!
    jmp     .out
.hop:
    add     r13, 0xba0              ; TODO HACK : if vaddr round down..
.out:

    phdr_phys_info rsi, r14, r15

    add     r14, [rbp-0x10]         ; add base addr to p_offset

    push    rsi
    push    rcx

    mmap    r12, r13

    mov     rdi, r12
    mov     rsi, r14
    mov     rcx, r15
    cld
    rep     movsb                   ; copy data into segment

    pop     rcx
    pop     rsi

    jmp     .loop
.end:

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rcx
    pop     rbx
    pop     rsi
    pop     rdi
    add     rsp, 8
    pop     rax                     ; return e_entry
    pop     rbp
    ret

;------------------------------------------------------------------------------
; Name:
;   update_auxv
;
; Description:
;   Update values of AUXV to those of extracted elf.
;
; Stack:
;   rsi
;   rbx
;   rcx
;
; In:
;   rdi-base addr of auxv
;   rsi-base addr of extracted elf
;   rdx-interp e_entry
;
update_auxv:
    push    rsi
    push    rbx
    push    rcx

    mov     rbx, rsi                ; elf base addr
    mov     rcx, rdx                ; interp e_entry

    mov     rsi, 3                  ; AT_PHDR (3)
    mov     rdx, [rbx + 0x20]       ; e_phoff
    call    set_auxv_val

    mov     rsi, 4                  ; AT_PHENT
    xor     rdx, rdx
    mov     dl, [rbx + 0x36]        ; e_phent
    call    set_auxv_val

    mov     rsi, 5                  ; AT_PHNUM
    xor     rdx, rdx
    mov     dl, [rbx + 0x38]        ; e_phnum

    mov     rsi, 7                  ; AT_BASE
    mov     rdx, rcx                ; interp e_entry  TODO REALLY?

    mov     rsi, 9                  ; AT_ENTRY
    mov     rdx, [rbx + 0x18]       ; elf e_entry

    pop     rcx
    pop     rbx
    pop     rsi
    ret
