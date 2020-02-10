
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include heap32.inc
	include macros.inc

?EXTCHK	equ 0

	.CODE

HeapLock proc public heap:dword

	mov eax,heap
	test byte ptr [eax].HEAPDESC.flags, HEAP_NO_SERIALIZE
	jnz @F
	invoke WaitForSingleObject,[eax].HEAPDESC.mutex,INFINITE
@@:
	@strace <"HeapLock(", heap, ")=", eax>
	ret
	align 4
HeapLock endp

HeapUnlock proc public heap:dword

	mov eax,heap
	test byte ptr [eax].HEAPDESC.flags, HEAP_NO_SERIALIZE
	jnz @F
	invoke ReleaseMutex,[eax].HEAPDESC.mutex
@@:
	@strace <"HeapUnlock(", heap, ")=", eax>
	ret
	align 4
HeapUnlock endp

HeapCompact proc public heap:dword, flags:dword
	xor eax,eax
	@strace <"HeapCompact(", heap, ", ", flags, ")=", eax>
	ret
	align 4
HeapCompact endp

;--- HeapSize is to return -1 on errors

HeapSize proc public heap:dword, flags:dword, pMem:dword

	mov ecx,pMem
	mov eax,[ecx-4]
	test al,1	;free flag set?
	jnz error
if ?EXTCHK
	sub eax,4
endif
@@:
	@strace <"HeapSize(", heap, ", ", flags, ", ", pMem, ")=", eax>
	ret
error:
	push -1
	pop eax
	jmp @B
	align 4
HeapSize endp

	end

