
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

SHGetMalloc proc public pMalloc:ptr DWORD

		mov ecx, pMalloc
        mov dword ptr [ecx],0
		mov eax, E_FAIL
		@strace <"SHGetMalloc(", ")=", eax>                
		ret
        align 4
SHGetMalloc endp

		end
