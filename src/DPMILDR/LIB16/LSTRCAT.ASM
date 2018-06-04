
		.286

_TEXT	segment word public 'CODE'


LSTRCAT proc far pascal uses ds si di string1:dword, string2:dword

       cld
       xor     ax,ax
       or      cx,-1
       les     di,string2
       repne   scasb
       push    cx
       les     di,string1
       push    di
       repne   scasb
       lds     si,string2
       pop     ax
       pop     cx
       not     cx
       dec     di
       shr     cx,1
       rep     movsw
       adc     cx,cx
       rep     movsb
       mov     dx,es
       ret
LSTRCAT endp

_TEXT	ends

        end

