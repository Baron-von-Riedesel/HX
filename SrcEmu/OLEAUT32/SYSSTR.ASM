
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include windef.inc
        include winbase.inc
        include macros.inc

?OWNHEAP	equ 0	;1 for debugging purposes

if ?OWNHEAP
		.DATA
        
hHeap	dd 0        
        
endif
        .CODE

SysAllocStringLen proc public psz:ptr WORD, cch:DWORD

		mov eax, cch
        add eax, eax		;source is a wide string               	
        add eax, 4+2		;extra space for length(4) + term 0 (2)
if ?OWNHEAP
		cmp hHeap, 0
        jnz @F
        push eax
        invoke HeapCreate, 0, 100000, 0
        mov hHeap, eax
        pop eax
@@:        
		invoke HeapAlloc, hHeap, 0, eax
else
        invoke LocalAlloc, LMEM_FIXED, eax
endif        
        .if (eax)
        	mov ecx, cch
            add ecx, ecx
            mov [eax],ecx			;size is in bytes! without term 0!
        	add eax, 4
            mov word ptr [eax+ecx],0
	        .if (psz)
            	push eax
            	invoke RtlMoveMemory, eax, psz, ecx
                pop eax
            .endif
        .endif
		@strace <"SysAllocStringLen(", psz, ", ", cch, ")=", eax>
		ret
        align 4
        
SysAllocStringLen endp

SysAllocString proc public psz:ptr WORD

		invoke lstrlenW, psz
        invoke SysAllocStringLen, psz, eax
		@strace <"SysAllocString(", psz, ")=", eax>
		ret
        align 4
        
SysAllocString endp

SysAllocStringByteLen proc public psz:ptr WORD, cch:DWORD

		mov eax, cch
        add eax, 4+1
if ?OWNHEAP
		cmp hHeap, 0
        jnz @F
        push eax
        invoke HeapCreate, 0, 8000h, 0
        mov hHeap, eax
        pop eax
@@:        
		invoke HeapAlloc, hHeap, 0, eax
else
        invoke LocalAlloc, LMEM_FIXED, eax
endif        
        .if (eax)
        	mov ecx, cch
            mov [eax],ecx
        	add eax, 4
            mov byte ptr [eax+ecx],0
	        .if (psz)
            	push eax
    	    	invoke RtlMoveMemory, eax, psz, ecx
                pop eax
            .endif
        .endif
		@strace <"SysAllocStringByteLen(", psz, ", ", cch, ")=", eax>
		ret
        align 4
        
SysAllocStringByteLen endp

SysStringLen proc public psz:ptr WORD

		mov eax, psz
        .if (eax)
        	mov eax,[eax-4]
            shr eax, 1
        .endif
		@strace <"SysStringLen(", psz, ")=", eax>
		ret
        align 4
        
SysStringLen endp

SysStringByteLen proc public psz:ptr WORD

		mov eax, psz
        .if (eax)
        	mov eax,[eax-4]
        .endif
		@strace <"SysStringByteLen(", psz, ")=", eax>
		ret
        align 4
        
SysStringByteLen endp

;--- SysFreeString has no return value

SysFreeString proc public bstr:ptr WORD

		mov eax, bstr
        .if (eax)
	        sub eax, 4
if ?OWNHEAP
			invoke HeapFree, hHeap, 0, eax
else
			invoke LocalFree, eax
endif            
        .endif
		@strace <"SysFreeString(", bstr, ")=", eax>
        ret
        align 4

SysFreeString endp

SysReAllocStringLen proc public pbstr:ptr ptr WORD, psz:ptr WORD, cch:DWORD

		invoke SysAllocStringLen, psz, cch
        .if (eax)
        	mov ecx, pbstr
            xchg eax, [ecx]
            invoke SysFreeString, eax
            @mov eax, TRUE
        .endif
		@strace <"SysReAllocStringLen(", pbstr, ", ", psz, ", ", cch, ")=", eax>
		ret
        align 4
        
SysReAllocStringLen endp

		end
