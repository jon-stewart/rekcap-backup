GLOBAL _mmap, _munmap, open, read, _fstat

;------------------------------------------------------------------------------
; Name:
;   _mmap
;
; Description:
;   Call via macro.
;
;   Setup and make sys_mmap call.
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
;   Call via macro.
;
;   Setup and make sys_munmap call.
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
;   open
;
; Description:
;   Setup and make sys_open call
;
; Stack:
;   Nothing
;
; In:
;   rdi-filename
;
; Out:
;   rax-error
;
; Modifies:
;   rax
;   rdx
;
open:
    push    rsi

    mov     rax, 2                  ; sys_open
    xor     rsi, rsi                ; flags
    xor     rdx, rdx                ; mode
    syscall

    pop     rsi
    ret

;------------------------------------------------------------------------------
; Name:
;   read
;
; Description:
;   Setup and make sys_read call.
;
; Stack:
;   Nothing
;
; In:
;   rdi-fd
;   rsi-buf
;   rdx-count
;
; Out:
;   rax-error
;
; Modifies:
;   rax
;
read:
    mov     rax, 0                  ; sys_read
    syscall

    ret

;------------------------------------------------------------------------------
; Name:
;   _fstat
;
; Description:
;   Call via macro.
;
;   Setup and make sys_fstat call.
;
; Stack:
;   struct stat buf
;
; In:
;   rdi-struct stat buf
;
; Out:
;   rax-error
;
_fstat:
    mov     rax, 5                  ; sys_fstat
    syscall

    ret
