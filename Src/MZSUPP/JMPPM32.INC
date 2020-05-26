
?WIN32         = 0		;support Win32 emulation

externdef stdcall __STACKSIZE:abs
externdef stdcall __HEAPSIZE:abs

externdef stdcall __baseadd:dword
externdef stdcall __dossize:dword
externdef stdcall __psp:dword
externdef stdcall __ressize:dword

main proto near c
mainCRTStartup proto near c



ifdef ?TRACE

_TEXT32	segment

_trace32	proc private
		pushad
        mov ebp,esp
        pushfd
        mov esi, [ebp+32]
        .while (1)
	        db 2Eh
        	lodsb
            .break .if (!al)
            mov dl,al
            mov ah,2
            int 21h
        .endw
        mov [ebp+32],esi
        popfd
        popad
        ret
_trace32 endp

_TEXT32	ends

@trace macro string
local	xxx
		invoke _trace32
xxx		db string,0        
        endm
else

@trace	macro string
		endm

endif
