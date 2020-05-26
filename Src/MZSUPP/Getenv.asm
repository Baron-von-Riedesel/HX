
;*** read environment into a buffer ***

if ?FLAT eq  0

        .386
;        .MODEL SMALL, stdcall

		include jmppm32.inc

_TEXT32	segment dword public 'CODE'

;*** returns size of environment ***

_getenvironment proc stdcall uses esi edi ebx pStr:dword, maxsize:dword


        push    es
        mov     es, [__psp]
        mov     es,es:[002Ch]
        mov     ebx,es
        xor     edi,edi
        mov     ecx,edi
        dec     ecx
        mov     al,00
@@:
        repnz   scasb
        scasb
        jnz     @B          ;edi-> 01
        inc     edi         ;edi-> 00
        inc     edi         ;edi-> first char of pgmname
        repnz   scasb
                            ;edi = size environment
        pop     es

        push    ds
        mov     ds,ebx
        mov     ecx,edi
        mov     eax,edi
        cmp     ecx,maxsize
        jb      @F
        mov     ecx,maxsize
@@:
        xor     esi,esi
        mov     edi,pStr
        rep     movsb
        pop     ds
        ret
_getenvironment endp

_TEXT32	ends

endif

        end

