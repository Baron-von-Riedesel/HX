
;*** copy command line from psp into variable ***

if ?FLAT eq  0

        .386
;        .MODEL SMALL, stdcall


		include jmppm32.inc

_TEXT32	segment dword public 'CODE'

_getcmdline proc stdcall uses esi edi pStr:dword


        push    ds
        mov     ds,[__psp]
        mov     edi,pStr
        mov     esi,80h
        lodsb
        movzx   eax,al
        mov     ecx,eax
        jecxz   l1
        push    eax
@@:
        lodsb
        cmp     al,' '
        loopz   @B
        stosb
        pop     eax
        rep     movsb
l1:
        mov     es:[edi],cl
        pop     ds
        ret
_getcmdline endp

_TEXT32	ends

endif

        end

