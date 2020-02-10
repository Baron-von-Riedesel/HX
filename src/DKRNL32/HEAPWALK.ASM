
;--- HeapWalk

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include heap32.inc
	include macros.inc

;--- HeapWalk() is not supported by win9x!

	.code

HeapWalk proc public uses ebx heap:dword, pEnum:ptr PROCESS_HEAP_ENTRY

	mov ecx, heap
	mov ebx, pEnum
	assume ebx:ptr PROCESS_HEAP_ENTRY
nextitem:
	mov eax, [ebx].lpData
	.if (eax)
		mov edx, [eax-4]
		and dl, 0FCh
		lea eax, [eax+edx+4]
	.else
		mov eax, [ecx].HEAPDESC.start
		lea eax, [eax+4]
	.endif
	mov [ebx].lpData, eax
	mov edx, [eax-4]
	cmp edx, _HEAP_END
	jnz @F
	invoke SetLastError, ERROR_NO_MORE_ITEMS
	xor eax, eax
	jmp exit@
@@:
	xor eax, eax
	test dl,FHEAPITEM_INTERNAL
	jnz nextitem
	test dl,FHEAPITEM_FREE
	jnz @F
	mov ax, PROCESS_HEAP_ENTRY_BUSY
@@:
	and dl,0FCh
	mov [ebx].cbData, edx
	mov [ebx].wFlags, ax
	mov [ebx].cbOverhead, 4
	mov [ebx].iRegionIndex, 0
	@mov eax,1
exit@:
	@strace  <"HeapWalk(", heap, ", ", pEnum, ")=", eax, " [", [ebx].lpData, " ", [ebx].cbData, "]">
	ret
	align 4
	assume ebx:nothing

HeapWalk endp

	end

