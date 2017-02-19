GLOBAL find_auxv, get_auxv_val, set_auxv_val

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
;   rcx
;
; In:
;   rdi-start address of stack
;
; Out:
;   rax-start address of auxv
;
; Modifies:
;   rax
;
find_auxv:
    push    rcx

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

    pop     rcx
    ret

;------------------------------------------------------------------------------
; Name:
;   get_auxv_val
;
; Description:
;   Iterate through keys in auxv and return the associated value the of
;   matching key (rsi).
;
; Stack:
;   rcx
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
;
get_auxv_val:
    push    rcx

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

    pop     rcx
    ret

;------------------------------------------------------------------------------
; Name:
;   set_auxv_val
;
; Description:
;   Iterate through keys in auxv and set associated value of the matching key.
;
; Stack:
;   rcx
;
; In:
;   rdi-base address of auxv
;   rsi-auxv key
;   rdx-auxv value
;
; Modifies:
;   rax
;
set_auxv_val:
    push    rcx

    xor     rcx, rcx
    jmp     .begin
.loop:
    add     rcx, 0x10               ; move to next key
.begin:
    mov     rax, [rdi + rcx]
    cmp     rax, rsi
    jne     .loop

    add     rcx, 8                  ; move to value
    mov     [rdi + rcx], rdx        ; store new value

    pop     rcx
    ret
