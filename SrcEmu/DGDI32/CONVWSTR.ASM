
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option proc:private
        option casemap:none

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
		include macros.inc

		.code
	
;--- this function converts a wide string in EAX, size ECX to an ascii string.
;--- the converted string is stored onto the stack and returned in EAX.
;--- if the calling function use the "uses" phrase, ESP has to be
;--- saved/restored on proc entry/exit

ConvertWStr proc public
		.if (ecx == -1)
			push eax
			invoke lstrlenW, eax
            mov ecx, eax
            pop eax
        .endif
        pop edx			;pop return address

        sub esp,ecx
        sub esp, 4
        and esp, not 4
        
        push edx		;push return address
        push esi
        push edi
        lea edi, [esp+3*4]	;destination
        mov edx, edi
        mov esi, eax	;source
        jecxz done
@@:        
        lodsw
        stosb
        dec ecx
        jnz @B
done:
		mov eax, edx
        pop edi
        pop esi
		ret
        align 4
ConvertWStr endp

		end
        
