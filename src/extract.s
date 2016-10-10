GLOBAL xor_copy

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
    jnz     .loop

    ret
