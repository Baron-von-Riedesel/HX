
;*** get a NE module handle

        extern   GETMODULEHANDLE:far

        public  DOSGETMODHANDLE

DOSXXX  segment word public 'CODE'

szDll:
        db ".DLL",0

;int DosGetModHandle(szModuleName, lpHandle);

DOSGETMODHANDLE proc far
        push    BP
        mov     BP,SP
        push    BX
        push    CX
        push    DX
        push    DS
        push    SI
        push    ES
        push    DI
        les     DI,[BP+0Ah]
        mov     CX,050h		;max path length
        cld
        xor     AX,AX
        repne   scasb
        sub     CX,050h
        not     CX
        mov     BX,CX
        std
        mov     AL,'.'
        repne   scasb
        cld
        jne     @F
        cmp     byte ptr es:[DI+1],0
        jne     nocopy
@@:    
		mov     DX,BX		;make a copy of module name on stack
        add     DX,5
        test    DX,1
        je      @F
        inc     DX
@@:    
		sub     SP,DX
        lds     SI,[BP+0Ah]
        push    SS
        pop     ES
        mov     DI,SP
        push    DX
        push    ES
        push    DI
        mov     CX,BX
        rep     movsb
        mov     CX,CS
        mov     DS,CX
        mov     SI,offset szDll
        mov     CX,5
        rep     movsb
        jmp     fullname
nocopy:
		xor     DX,DX		;no copy required
        push    DX
        push    [BP+0Ch]
        push    [BP+0Ah]
fullname:
		call    GETMODULEHANDLE
        pop     BX
        add     SP,BX
        cmp     AX,0
        jne     @F
        mov     AX,07Eh
        jmp     exit
@@:
		lds     SI,[BP+6]	;store handle
        mov     [SI],AX
        xor     AX,AX
exit:
		pop     DI
        pop     ES
        pop     SI
        pop     DS
        pop     DX
        pop     CX
        pop     BX
        pop     BP
        retf    8
DOSGETMODHANDLE endp

DOSXXX  ends

        end

