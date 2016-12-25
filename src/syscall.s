
global _print, _open, _mmap, _exit


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
;
; Out:
;   rax - retval
;
; Modifies:
;   rdx
;   r10
;   r8
;   r9
;
_mmap:
	mov		rax, 9			; sys_mmap
	mov     rdx, 7          ; prot  (RWE)
    mov     r10, 34         ; flags (MAP_ANONYMOUS | MAP_PRIVATE)
    xor     r8, r8          ; fd    (ignore)
    xor     r9, r9          ; off   (ignore)
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
    syscall
