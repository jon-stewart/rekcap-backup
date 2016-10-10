GLOBAL _mmap, _munmap, fstat_filesz

;------------------------------------------------------------------------------
; Name:
;   _mmap
;
; Description:
;   Setup and make sys_mmap call
;
; Stack:
;   rdx
;   r8
;   r9
;   r10
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
_mmap:
    push    rdx
    push    r8
    push    r9
    push    r10

    mov     rax, 9                  ; sys_mmap
    mov     rdx, 7                  ; prot  (RWE)
    mov     r10, 0x22               ; flags (MAP_ANONYMOUS | MAP_PRIVATE)
    xor     r8, r8                  ; fd    (ignored)
    xor     r9, r9                  ; off   (ignored)
    syscall

    pop     r10
    pop     r9
    pop     r8
    pop     rdx
    ret

;------------------------------------------------------------------------------
; Name:
;   _munmap
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
_munmap:
    mov     rax, 0xb                ; sys_munmap
    syscall

    ret

;------------------------------------------------------------------------------
; Name:
;   fstat_filesz
;
; Description:
;   Setup and make sys_fstat call, return st_size from struct stat buf.
;
; Stack:
;   struct stat buf
;
; In:
;   rdi-fd
;
; Out:
;   rax-file size
;
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
