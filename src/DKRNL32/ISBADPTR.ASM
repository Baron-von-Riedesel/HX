
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
	include macros.inc

	assume fs:nothing

	.CODE

IsBadReadPtr proc public pMem:dword, dwSize:dword

	xor edx, edx
	push offset exception_read
	push fs:[edx]
	mov fs:[edx], esp

	mov eax,1		;1 means error!
	mov ecx, pMem
	mov dl,[ecx]
	add ecx, dwSize
	mov dl,[ecx-1]
	dec eax			;this code doesn't run if ptr was bad
donebrp:
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
	@strace <[ebp+4], ": IsBadReadPtr(", pMem, ", ", dwSize, ")=", eax>
	ret
exception_read:
	mov eax, [esp+12]	;get context
	mov [eax].CONTEXT.rEip, offset donebrp
	@strace <"*** exception caught inside IsBadReadPtr()">
	xor eax, eax		;== _XCPT_CONTINUE_EXECUTION
	retn
	align 4

IsBadReadPtr endp

IsBadWritePtr proc public pMem:dword, dwSize:dword

	xor edx, edx
	push offset exception_write
	push fs:[edx]
	mov fs:[edx], esp

	mov eax,1		 ;1 means: yes, pointer is BAD!
	mov ecx, pMem
	or byte ptr [ecx],00
	add ecx, dwSize
	or byte ptr [ecx-1],00
	dec eax
donebwp:
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
	@strace <[ebp+4], ": IsBadWritePtr(", pMem, ", ", dwSize, ")=", eax>
	ret
exception_write:
	mov eax, [esp+12]	;get context
	mov [eax].CONTEXT.rEip, offset donebwp
	xor eax, eax		;== _XCPT_CONTINUE_EXECUTION
	@strace <"*** exception caught inside IsBadWritePtr()">
	retn
	align 4

IsBadWritePtr endp

IsBadCodePtr proc public pFunc:dword

	invoke IsBadReadPtr, pFunc, 1
	@strace <[ebp+4], ": IsBadCodePtr(", pFunc, ")=", eax>
	ret
	align 4

IsBadCodePtr endp

	end
