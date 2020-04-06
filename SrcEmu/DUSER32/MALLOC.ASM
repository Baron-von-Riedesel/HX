
        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif

		option casemap:none
        option proc:private

		include winbase.inc        
		include winuser.inc        
        include duser32.inc
        include macros.inc

        .CODE

malloc	proc stdcall public dwBytes:DWORD

		invoke LocalAlloc, LMEM_FIXED, dwBytes
		ret
        align 4
malloc  endp

malloc2 proc stdcall public dwBytes:DWORD

		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, dwBytes
		ret
        align 4
malloc2 endp

;--- LocalFree() returns NULL on success!

free	proc stdcall public handle:DWORD

		invoke LocalFree, handle
        and eax, eax
        setz al
        movzx eax,al
		ret
        align 4
free	endp

        END

