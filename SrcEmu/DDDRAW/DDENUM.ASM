
        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
        option casemap:none
        option proc:private
        
        include ddraw.inc
        include dddraw.inc
        include macros.inc

        .CODE

driverdesc label byte
drivername db "hx ddraw emulator",0
guid	dd 1, 2, 3, 4

DirectDrawEnumerateA proc public lpCallback:dword, lpContext:dword

		push	lpContext
        push	offset drivername
        push	offset driverdesc
        push	offset guid
		call	lpCallback
        mov     eax,DD_OK
		@strace <"DirectDrawEnumerateA(", lpCallback, ", ", lpContext, ")=", eax> 
        ret
        align 4
DirectDrawEnumerateA endp

DirectDrawEnumerateExA proc public lpCallback:dword, lpContext:dword, dwFlags:dword

		push	0
		push	lpContext
        push	offset drivername
        push	offset driverdesc
        push	offset guid
		call	lpCallback
        mov     eax,DD_OK
		@strace <"DirectDrawEnumerateExA(", lpCallback, ", ", lpContext, ", ", dwFlags, ")=", eax> 
        ret
        align 4
DirectDrawEnumerateExA endp

        END

