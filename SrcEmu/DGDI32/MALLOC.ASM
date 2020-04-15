
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

        .DATA

g_hHeap 	dd 0
g_bIsShared db 0

        .CODE

checkheap proc

		cmp g_hHeap,0
        jz @F
        ret
@@:
if 1
		invoke HeapCreate, 0, 10000h, 0
        .if (!eax)
        	invoke GetProcessHeap
            mov g_bIsShared, 1
        .endif
else
		invoke GetProcessHeap
        mov g_bIsShared, 1
endif
        mov g_hHeap, eax
		ret
        align 4
checkheap endp

_GDImalloc	proc stdcall public dwBytes:DWORD

		call checkheap
		invoke HeapAlloc, g_hHeap, 0, dwBytes
		@strace <"GDImalloc(", dwBytes, ")=", eax>
		ret
        align 4
_GDImalloc  endp

_GDImalloc2 proc stdcall public dwBytes:DWORD

		call checkheap
		invoke HeapAlloc, g_hHeap, HEAP_ZERO_MEMORY, dwBytes
		ret
        align 4
_GDImalloc2 endp

_GDIfree proc stdcall public handle:DWORD

		mov eax, g_hHeap
		.if (eax)
ifdef _DEBUG
			pushad
			invoke HeapValidate, eax, 0, handle
            and eax, eax
            jz @F
			invoke HeapSize, g_hHeap, 0, handle
			@strace <"GDIfree, handle=", handle, ", size=", eax>
            mov ecx, eax
            mov edi, handle
            shr ecx, 2
            mov eax,055AA55AAh
            rep stosd
@@:            
            popad
endif
			invoke HeapFree, eax, 0, handle
ifdef _DEBUG
			and eax, eax
            jnz @F
			@strace <"GDIfree, invalid handle=", handle>
@@:            
endif
        .endif
		ret
        align 4
_GDIfree endp

_GDIHeapDestroy proc public
		xor ecx, ecx
        xchg ecx, g_hHeap
		.if (ecx)
            .if (!g_bIsShared)
            	invoke HeapDestroy, ecx
            .endif
        .endif
		@strace <"GDIHeapDestroy">
		ret
        align 4
_GDIHeapDestroy endp

        END

