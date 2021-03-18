
;*** load a NE module

		.286
        
        externdef LOADLIBRARY:far

        public  DOSLOADMODULE

DOSXXX  segment word public 'CODE'

szDll:
        db ".DLL",0

DOSLOADMODULE   proc far

        push    bp
        mov     bp,sp
        push    BX
        push    CX
        push    DX
        push    DS
        push    SI
        push    ES
        push    DI
        mov     ES,[BP+0Ch]
        mov     DI,[BP+0Ah]
        mov     CX,050h		;name might be up to 80 bytes long
        cld
        xor     AX,AX
        repne scasb
        sub     CX,050h
        not     CX
        mov     BX,CX
        std
        mov     AL,'.'
        repne scasb
        cld
        jne     @F
        cmp     byte ptr es:[DI+1],0	;has ".dll" to be added?
        jne     nocopy
@@:
		mov     DX,BX
        add     DX,5
        test    DX,1
        je      @F
        inc     DX
@@:
		sub     SP,DX
        mov     DS,[BP+0Ch]
        mov     SI,[BP+0Ah]
        push    SS
        pop     ES
        mov     DI,SP
        push    DX
        push    ES
        push    DI
        mov     CX,BX
        rep     movsb
        mov     CX,seg szDll
        mov     DS,CX
        mov     SI,offset szDll
        mov     CX,5
        rep movsb
        jmp copied
nocopy:
		xor     DX,DX
        push    DX
        push    [BP+0Ch]
        push    [BP+0Ah]
copied:    
		call   LOADLIBRARY
        pop     BX
        add     SP,BX
        cmp     AX,01Fh		;must be above 1Fh to be successful
        ja      ok
        cmp     AX,0		;0 is not a valid error code
        jne     @F
        mov     AX,8
        jmp exit
@@:
		cmp     AX,3
        jne     @F
        mov     AX,0Bh
        jmp exit
@@:
		mov     AX,2
        jmp exit
ok:
		lds     SI,[BP+6]
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
        retf    0Eh

DOSLOADMODULE   endp

DOSXXX  ends

		end
        
