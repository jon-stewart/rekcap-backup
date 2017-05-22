
global _print, _open, _fstat_size, _read, _mmap, _munmap, _exit


;------------------------------------------------------------------------------
; Name:
;   _print
;
; Description:
;   sys_write syscall buffer to stdout
;
; In:
;   rdi - buffer
;   rsi - len
;
; Out:
;   rax - retval
;
; Modifies:
;   rdi
;   rsi
;
_print:
    push    rbp
    mov     rbp, rsp

	push	rdx
    push    rsi
    push    rdi

    mov     rax, 1          ; sys_write
    mov     rdi, 1          ; stdout
    pop     rsi             ; buffer
    pop     rdx             ; len
    syscall

	pop		rdx

    mov     rsp, rbp
    pop     rbp
    ret

;------------------------------------------------------------------------------
; Name:
;   _fstat_size
;
; Description:
;   Setup and pass local struct stat to fstat syscall.
;
;   Return the st_size.
;
; In:
;   rdi - fd
;
; Out:
;   rax - retval
;
_fstat_size:
    push    rbp
    mov     rbp, rsp

    sub     rsp, 144        ; sizeof (struct stat)

    mov     rax, 5          ; sys_fstat
    mov     rsi, rsp        ; struct stat
    syscall

    mov     rax, [rsp + 48] ; st_size

    mov     rsp, rbp
    pop     rbp
    ret

;------------------------------------------------------------------------------
; Name:
;   _open
;
; Description:
;   setup and make sys_open call
;
; In:
;   rdi - filename
;
; Out:
;   rax - retval
;
_open:
	push	rbp
	mov		rbp, rsp

	push	rsi
	push	rdx

    mov     rax, 2          ; sys_open
    xor     rsi, rsi        ; flags
    xor     rdx, rdx        ; mode
    syscall

	pop		rdx
	pop		rsi

	mov		rsp, rbp
	pop		rbp
    ret


;------------------------------------------------------------------------------
; Name:
;   _read
;
; Description:
;   setup and make sys_read call.
;
; In:
;   rdi - fd
;   rsi - buf
;   rdx - count
;
; Out:
;   rax - retval
;
_read:
    mov     rax, 0          ; sys_read
    syscall
    ret


;------------------------------------------------------------------------------
; Name:
;   _mmap
;
; Description:
;   setup and make sys_mmap call
;
;   mmap doesn't restore register values (?)
;
; In:
;   rdi - address
;   rsi - length
;   rdx - offset
;
; Out:
;   rax - retval
;
; Modifies:
;   r10
;   r8
;   r9
;
_mmap:
	mov		rax, 9			; sys_mmap
    mov     r9,  rdx        ; off
	mov     rdx, 7          ; prot  (RWE)
    mov     r10, 34         ; flags (MAP_ANONYMOUS | MAP_PRIVATE)
    xor     r8,  r8         ; fd    (ignore)
    syscall

    ret

;------------------------------------------------------------------------------
; Name:
;   _munmap
;
; Description:
;   unmap region of memory
;
; In:
;   rdi - address
;   rsi - length
;
_munmap:
    mov     rax, 11         ; sys_munmap
    syscall
    ret

;------------------------------------------------------------------------------
; Name:
;   _exit
;
; Description:
;   clean program exit
;
_exit:
    mov     rax, 60         ; sys_exit
    xor     rdi, rdi        ; error_code
    syscall
