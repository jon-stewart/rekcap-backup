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
    mov     rax, 1                  ; sys_write
    mov     rdi, 1                  ; stdout
    mov     rdx, %1
    lea     rsi, [rdx + %2]         ; buf
    mov     rdx, %3                 ; count
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
; [rbp-0x28] : p_vaddr (xor'd elf address)
; [rbp-0x30] : p_memsz (xor'd elf size)

%define UNPACK_ADDR 0x400000

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
    mov     rdi, [rbp-0x10]
    mov     rsi, [rbp-0x18]
    call    get_phdr_info
    mov     [rbp-0x28], rax         ; p_vaddr
    mov     [rbp-0x30], rbx         ; p_memsz

    ; mmap
    mov     rdi, UNPACK_ADDR        ; addr
    mov     rsi, [rbp-0x30]         ; len
    call    mmap

    ; copy and xor original elf into mapped region
    mov     rdi, UNPACK_ADDR        ; dst
    mov     rsi, [rbp-0x28]         ; src
    mov     rdx, [rbp-0x30]         ; count
    mov     r8, 0x90                ; xor value
    call    xor_copy

    ; munmap
    mov     rdi, UNPACK_ADDR        ; addr
    mov     rsi, [rbp-0x30]         ; len
    call    munmap

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
;   find_auxv
;
; Description:
;   Jump 3 qword (argc, argv and NULL) to the start of environ vars.
;
;   Traverse stack until hit NULL, this is end of environ var.
;
;   Jump 1 qword to the start of auxv and return effective address in rax.
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
; Modifies:
;   rax
;   rcx
;
find_auxv:
    mov     rcx, 0x18
    jmp     .begin
.loop:
    add     rcx, 8
.begin:
    mov     rax, [rdi + rcx]
    test    rax, rax
    jne     .loop

    add     rcx, 8
    lea     rax, [rdi + rcx]
    ret

;------------------------------------------------------------------------------
; Name:
;   get_auxv_val
;
; Description:
;   Iterate through keys in auxv and return value (rax) of matching key (rsi).
;
; Stack:
;   No need to store/adjust
;
; In:
;   rdi-base address of auxv
;   rsi-auxv key
;
; Out:
;   rax-auxv value
;
; Modifies:
;   rax
;   rcx
;
get_auxv_val:
    xor     rcx, rcx
    jmp     .begin
.loop:
    add     rcx, 0x10               ; move to next key
.begin:
    mov     rax, [rdi + rcx]
    cmp     rax, rsi
    jne     .loop

    add     rcx, 8                  ; move to value
    mov     rax, [rdi + rcx]
    ret

;------------------------------------------------------------------------------
; Name:
;   get_phdr_info
;
; Description:
;   Load address of 2nd phdr and return p_vaddr and p_memsz.
;
; Stack:
;   Nothing
;
; In:
;   rdi-phdr start address
;   rsi-size of phdr entry
;
; Out:
;   rax-p_vaddr
;   rbx-p_memsz
;
; Modifies:
;   rax
;   rbx
;   r8
get_phdr_info:
	lea     r8,  [rdi + rsi]
	mov		rax, [r8 + 0x10]
	mov		rbx, [r8 + 0x28]

    ret

;------------------------------------------------------------------------------
; Name:
;   mmap
;
; Description:
;   Setup and make sys_mmap call
;
; Stack:
;   Nothing
;
; In:
;   rdi-address
;   rsi-length
;
; Out:
;   rax-error
;
; Modifies:
;   rax
;   rdx
;   r10
;   r8
;   r9
;
mmap:
    mov     rax, 9                  ; sys_mmap
    mov     rdx, 7                  ; prot  (RWE)
    mov     r10, 0x22               ; flags (MAP_ANONYMOUS | MAP_PRIVATE)
    xor     r8, r8                  ; fd    (ignored)
    xor     r9, r9                  ; off   (ignored)
    syscall

    ret

;------------------------------------------------------------------------------
; Name:
;   munmap
;
; Description:
;   Setup and make sys_munmap call
;
; Stack:
;   Nothing
;
; In:
;   rdi-address
;   rsi-length
;
; Out:
;   rax-error
;
; Modifies:
;   rax
;
munmap:
    mov     rax, 0xb                ; sys_munmap
    syscall

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
;   Nothing
;
; In:
;   rdi-dst
;   rsi-src
;   rdx-len
;   r8 -xor value
;
; Out:
;   -
;
; Modifies:
;   rax
;   rcx
;
xor_copy:
    mov     rcx, rdx
    mov     rdx, r8
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
    jne     .loop

    ret
