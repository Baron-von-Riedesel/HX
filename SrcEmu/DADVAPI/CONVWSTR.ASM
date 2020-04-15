
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option proc:private
        option casemap:none

        include winbase.inc
		include macros.inc

		.code
	
;--- this function converts a wide asciiz string in EAX to an ascii string.
;--- the converted string is stored onto the stack and returned in EAX.
;--- if the calling function use the "uses" phrase, ESP has to be
;--- saved/restored on proc entry/exit

ConvertWStr proc public
		push eax
		invoke lstrlenW, eax
        add eax,3+1
        and al,0FCh
        pop ecx
        pop edx
        sub esp,eax
        mov eax,esp
        push edx
        push esi
        push edi
        mov edi, eax
        mov edx, eax
        mov esi, ecx
@@:        
        lodsw
        stosb
        and ax,ax
		jnz @B
        mov eax, edx
        pop edi
        pop esi
		ret
        align 4
ConvertWStr endp

;-- function to convert an AString back to a WString
;-- the destination pointer may be NULL!
;-- max size in cchMax

ConvertAStrN proc public uses esi edi eax pszAStr:ptr byte, pszWStr:ptr word, cchMax:dword
		mov esi, pszAStr
		mov edi, pszWStr
        and edi, edi
        jz  exit
        mov ecx, cchMax
        jecxz exit
        xor eax,eax
@@:        
        lodsb
        add edi,2
        and al,al
        loopnz @B
        sub ecx, cchMax
        neg ecx
        dec esi
        sub edi,2
        std
nextchar:
       	lodsb
        stosw
        loopnz nextchar
        cld
exit:        
		ret
        align 4
ConvertAStrN endp

;--- convert a asciiz string to a wide string (same buffer)
;--- usually this is used to convert a returned string to a wide string
;--- size is in EAX, without terminating 0
;--- all registers preserved!

ConvertAStr proc public pBuffer:ptr
       	pushad
        mov ecx, eax
        mov ah,0
        inc ecx			;copy the term 0 as well
        mov edi, pBuffer
        mov esi, edi
        .while (ecx)
            dec ecx
         	mov al,[esi+ecx]
            mov [edi+ecx*2],ax
        .endw
		popad
        ret
        align 4
ConvertAStr endp            

		end
        
