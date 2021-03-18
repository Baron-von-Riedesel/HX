
;*** get an export from a NE module

		.286

        externdef GETPROCADDRESS:far

        public  DOSGETPROCADDR
        
DOSXXX  segment word public 'CODE'

DOSGETPROCADDR:
        push    BP
        mov     BP,SP
        push    BX
        push    CX
        push    DX
        push	ds
        push    ES
        push    [BP+0Eh]
        push    [BP+0Ch]
        push    [BP+0Ah]
        call    GETPROCADDRESS
        mov		cx,ax
        or		cx,dx
        jnz		ok
;       mov		ax,6	;invalid handle
        mov		ax,127	;proc not found
        jmp		exit
ok:        
        lds     BX,[BP+6]
        mov     [BX+0],AX
        mov     [BX+2],DX
        xor     AX,AX
exit:        
        pop     ES
        pop		ds
        pop     DX
        pop     CX
        pop     BX
        pop     BP
        retf    0Ah
DOSXXX  ends

		end
        
