
;--- heapvalidate

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

?VERBOSE	equ 0	;1=verbose mode in debug mode

	assume fs:nothing

	.code

;--- check if heap item is in heap and is allocated
;--- pMem may be NULL!

HeapValidate proc public uses ebx esi heap:dword, flags:dword, pMem:dword

	@strace <[ebp+4],": HeapValidate(", heap, ", ", flags, ", ", pMem, ") enter">
        
	xor edx, edx
	push offset exception
	push fs:[edx]
	mov fs:[edx], esp

	mov ebx, heap
	test byte ptr [ebx].HEAPDESC.flags, HEAP_NO_SERIALIZE
	jnz @F
	invoke WaitForSingleObject, [ebx].HEAPDESC.mutex, INFINITE
@@:
	mov esi, [ebx].HEAPDESC.start
	mov edx, pMem
	.if (edx)
		sub edx, 4
	.endif
	xor eax, eax
	.while (dword ptr [esi] != _HEAP_END)
if ?VERBOSE
		@strace <"HeapValidate: heap item ", esi, " flitem=", [esi] >
endif
ife ?FREELIST
		.break .if (esi > [ebx].HEAPDESC.last)
endif
		test byte ptr [esi].FLITEM.dwSize, FHEAPITEM_INTERNAL
		jnz nextitem
		.if (esi == edx)
;--------------------------------- is heap item freed?
			test byte ptr [esi].FLITEM.dwSize,FHEAPITEM_FREE
			jnz done
			inc eax
			.break
		.endif
nextitem:
		mov ecx, [esi].FLITEM.dwSize
ifdef _DEBUG
		.if (ecx == 0ABCDFEDCh)	;is size overwritten?
			@strace <"*** error: heap chain corrupted at ", esi>
			xor eax, eax
			.break
		.endif
endif
		and cl, 0FCh
		lea esi, [esi+ecx+4]
	.endw
done:
	test byte ptr [ebx].HEAPDESC.flags, HEAP_NO_SERIALIZE
	jnz @F
	push eax
	invoke ReleaseMutex,[ebx].HEAPDESC.mutex
	pop eax
@@:
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
ifdef _DEBUG
	.if (!eax)
		@strace <"*** error: heap item ", pMem, " invalid ***">
		invoke IsDebuggerPresent
		.if (eax)
			int 3
		.endif
		xor eax, eax
	.endif
endif
	@strace <"HeapValidate(", heap, ", ", flags, ", ", pMem, ")=", eax>
	ret
exception:
	mov eax, [esp+12]	;get context
	mov ecx, [eax].CONTEXT.rEip
	mov [eax].CONTEXT.rEdx, ecx
	mov [eax].CONTEXT.rEip, offset cont_exc
	xor eax, eax		;== _XCPT_CONTINUE_EXECUTION
	retn
cont_exc:
	@strace <"*** exception inside HeapValidate() at EIP=", edx, " curr item=", esi> 
ifdef _DEBUG
	mov edx, esi
	mov esi, [ebx].HEAPDESC.start
	.while ( dword ptr [esi] != _HEAP_END )
		.break .if esi == edx
		@strace <"HeapValidate: heap item ", esi, " flitem=", [esi] >
		mov ecx, [esi].FLITEM.dwSize
		and cl, 0FCh
		lea esi, [esi+ecx+4]
	.endw
endif
	xor eax, eax
	jmp done

HeapValidate endp

	end

