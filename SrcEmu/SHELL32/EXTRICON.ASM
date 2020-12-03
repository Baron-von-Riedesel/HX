
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

ExtractIconA proc public hInst:DWORD, lpszExeFileName:ptr BYTE, nIconIndex:dword

		xor eax, eax
		@strace <"ExtractIconA(", hInst, ", ", lpszExeFileName, ", ", nIconIndex, ")=", eax, " *** unsupp ***">                
		ret
        align 4
ExtractIconA endp

ExtractIconExA proc public lpszExeFileName:ptr BYTE, nIconIndex:dword, phIconLarge:ptr DWORD, phIconSmall:ptr DWORD, nIcons:DWORD

		xor eax, eax
		@strace <"ExtractIconExA(", lpszExeFileName, ", ", nIconIndex, ", ", phIconLarge, ", ", phIconSmall, ", ", nIcons, ")=", eax, " *** unsupp ***">                
		ret
        align 4
ExtractIconExA endp

		end
