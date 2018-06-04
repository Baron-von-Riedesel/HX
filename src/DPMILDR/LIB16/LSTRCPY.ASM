
		.286

_TEXT	segment word public 'CODE'

LSTRCPY proc far pascal uses ds si di string1:dword, string2:dword

        cld
        les     di,string2
        or      cx,-1
        xor     ax,ax
        repne   scasb
        lds     si,string2
        les     di,string1
        mov     ax,di
        mov     dx,es
        not     cx
        shr     cx,1
        rep     movsw
        adc     cx,cx
        rep     movsb
        ret
LSTRCPY endp

_TEXT	ends

        end

