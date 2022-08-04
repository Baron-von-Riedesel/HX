
;--- 16bit DPMI application

initpm proc
    mov ax, 1687h   ;DPMI host installed?
    int 2Fh
    and ax, ax
    jnz nohost
    push es         ;save DPMI entry address
    push di
    and si, si      ;requires host client-specific DOS memory?
    jz nomemneeded
    mov bx, si
    mov ah, 48h     ;alloc DOS memory
    int 21h
    jc nomem
    mov es, ax
nomemneeded:
    mov bp, sp
    mov ax, 0000    ;start a 16-bit client
    call far ptr [bp]
    jc initfailed
    add sp, 4
    ret

nohost:
    call error
    db "no DPMI host installed",13,'$'
nomem:
    call error
    db "not enough DOS memory for initialisation",13,10,'$'
initfailed:
    call error
    db "DPMI initialisation failed",13,10,'$'
error:
    push cs
    pop ds
    pop dx
    mov ah, 9
    int 21h
    mov ax, 4C00h
    int 21h

initpm endp
