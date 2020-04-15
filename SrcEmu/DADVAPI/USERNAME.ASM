
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include macros.inc

        .CODE

GetUserNameA proc public uses esi edi lpNameBuffer:ptr BYTE, nSize:ptr DWORD

		mov ecx, nSize
        mov esi, [ecx]
        mov edi, lpNameBuffer
        invoke GetEnvironmentVariable, CStr("USERNAME"), edi, esi
        .if (!eax)
	        mov edx, CStr("DOS")
            mov ecx, esi
    	    .while (ecx)
        		mov al,[edx]
	            stosb
    	        .break .if (!al)
        	    inc edx
	            dec ecx
    	    .endw
	        sub edi, lpNameBuffer
        .else
        	mov edi, eax
            inc edi			;include terminating 0
        .endif
        mov ecx, nSize
        mov [ecx], edi
        xor eax, eax
        cmp esi, edi
        setnb al
		@strace <"GetUserNameA(", lpNameBuffer, ", ", nSize, ")=", eax>
        ret
        align 4
GetUserNameA endp

GetUserNameW proc public uses edi esi lpNameBuffer:ptr BYTE, nSize:ptr DWORD

		invoke GetUserNameA, lpNameBuffer, nSize
        .if (eax)
        	mov edi, lpNameBuffer
            mov esi, edi
            mov ecx, nSize
            mov ecx, [ecx]
            push eax
            mov ah,0
            .while (ecx)
            	mov al, [esi+ecx]
                mov [edi+ecx*2],ax
                dec ecx
			.endw
			pop eax        	
        .endif
		@strace <"GetUserNameW(", lpNameBuffer, ", ", nSize, ")=", eax>
		ret
        align 4
GetUserNameW endp

		end
