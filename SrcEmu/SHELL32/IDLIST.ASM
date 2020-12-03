
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

SHGetPathFromIDListA proc public pidl:ptr, pszPath:ptr BYTE

        mov eax, E_FAIL
		@strace <"SHGetPathFromIDListA(", pidl, ", ", pszPath, ")=", eax>                
		ret
SHGetPathFromIDListA endp

SHGetPathFromIDListW proc public pidl:ptr, pszPath:ptr WORD

        mov eax, E_FAIL
		@strace <"SHGetPathFromIDListA(", pidl, ", ", pszPath, ")=", eax>                
		ret
SHGetPathFromIDListW endp

		end
