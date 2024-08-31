
		.286

        public  DOSFREESEG

DOSXXX  segment word public 'CODE'

DOSFREESEG:
        push    BP
        mov     BP,SP
        push    ES
        push    DX
        mov     AX,DS
        mov		DX,[BP+6]
        cmp     AX,DX		;dont free DS segment
        jz      done
        mov     ES,DX
        mov     AH,049h
        int     21h
        mov		AX,6
        jb      exit
done:
        xor     AX,AX
exit:
		pop     DX
        pop     ES
        pop     BP
        retf    2
DOSXXX  ends

end

