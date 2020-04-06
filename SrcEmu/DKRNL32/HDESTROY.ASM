
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include heap32.inc
	include macros.inc

	.CODE

;*** a heap can consist of 1 or more regions allocated with virtualalloc()

;--- ebx -> heap descriptor
;--- additional regions were allocated by _growseg

;--- for the kernel heap there's no such list
;--- since it would be a problem - and it is not needed either.

HeapFreeMemBlocks proc uses ebx hHeap:DWORD

	@strace <"HeapFreeMemBlocks(", hHeap, ")">
	mov ebx, hHeap
	mov ebx,[ebx].HEAPDESC.pNextRegion
	.while (ebx)
		push [ebx].HBLOCK.pNext

		mov eax,[ebx].HBLOCK.dwAddr
		push eax
		invoke VirtualFree, eax, 0, MEM_RELEASE
		pop eax
		.if (eax != ebx)	;the HBLOCK might be part of the memory block
			invoke KernelHeapFree, ebx
		.endif

		pop ebx
	.endw
	ret
	align 4

HeapFreeMemBlocks endp

HeapDestroy proc public uses ebx handle:dword

	mov eax,handle
	and eax, eax
	jz exit
	mov ebx, eax
	invoke HeapFreeMemBlocks, ebx
	.if ([ebx].HEAPDESC.mutex)
		invoke CloseHandle, [ebx].HEAPDESC.mutex
	.endif
	invoke VirtualFree, ebx, 0, MEM_RELEASE
exit:
	@strace <"HeapDestroy(", handle, ")=", eax>
	ret
	align 4

HeapDestroy endp

	end

