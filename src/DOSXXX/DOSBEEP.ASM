
        public  DOSBEEP

		.286

DOSXXX  segment word public 'CODE'

DOSBEEP proc far pascal uses cx dx frequency:word, duration:word

        mov     cx,frequency
        mov     dx,duration
        in      AL,061h
        push    AX
outerloop:
		and     AL,0FCh
        out     061h,AL
        push    CX
        shr     cx,4
innerloop1:
		in      al,61h
        and     al,10h
        cmp     al,ah
        mov     ah,al
        jz      innerloop1
        loop    innerloop1
        pop     CX
        or      AL,2
        out     061h,AL
        push    CX
        shr     cx,4
innerloop2:    
		in      al,61h
        and     al,10h
        cmp     al,ah
        mov     ah,al
        jz      innerloop2
        loop    innerloop2
        pop     CX
        dec     DX
        jne     outerloop
        pop     AX
        out     061h,AL
        xor		ax,ax
        ret
DOSBEEP endp

DOSXXX  ends

end

