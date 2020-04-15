
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc

?SUPP1101	equ 0	; 1101h is used by OpenGL32
					; to get infos about the vendor (=driver) dll
                    ; first 2 dwords are version
                    ; then 256? WORDS path

        .CODE

Escape proc public hdc:DWORD, nEscape:dword, cbInput:dword, lpvInData:ptr, lpvOutData:dword

		xor eax, eax
		@strace <"Escape(", hdc, ", ", nEscape, ", ", cbInput, ", ", lpvInData, ", ", lpvOutData, ")=", eax, " *** unsupp">
        ret
        align 4
Escape endp

;--- nEscape: magic number
;--- cbInput: size input buffer
;--- cbOutput: size output buffer

ExtEscape proc public hdc:DWORD, nEscape:dword, cbInput:dword, lpszInData:ptr, cbOutput:dword, lpszOutData:ptr

        xor eax, eax
		mov edx, lpszInData
        .if (nEscape == QUERYESCSUPPORT)
        	mov ecx, [edx]
if ?SUPP1101            
			.if (ecx == 1101h)
            	inc eax
            .endif
endif            
			@strace <"ExtEscape(", hdc, ", QUERYESCSUPPORT, ", cbInput, ", ", lpszInData, "[", ecx, "], ", cbOutput, ", ", lpszOutData, ")=", eax, " *** unsupp">
        .else
           	mov ecx, lpszOutData
if ?SUPP1101
        	.if (nEscape == 1101h)
            	mov dword ptr [ecx+0*4],2
            	mov dword ptr [ecx+1*4],12345h
                inc eax
            .endif
endif            
			@strace <"ExtEscape(", hdc, ", ", nEscape, ", ", cbInput, ", ", lpszInData, ", ", cbOutput, ", ", lpszOutData, ")=", eax, " *** unsupp">
        .endif
        ret
        align 4

ExtEscape endp

		end
