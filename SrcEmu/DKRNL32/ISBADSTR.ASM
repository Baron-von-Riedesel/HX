
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

IsBadStringPtrA proc public uses edi pStr:dword

	xor edx, edx
	push offset exception_string
	push fs:[edx]
	mov fs:[edx], esp

	xor eax,eax 	 ;0 means no error!
	mov edi, pStr
	repnz scasb
done:
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
	@strace <[ebp+4], ": IsBadStringPtrA(", pStr, ")=", eax>
	ret
exception_string:
	mov eax, [esp+12]	;get context
	mov [eax].CONTEXT.rEip, offset cont_exc_string
	xor eax, eax		;== _XCPT_CONTINUE_EXECUTION
	retn
cont_exc_string:
	@strace <"*** exception catched inside IsBadStringPtrA()">
	inc eax
	jmp done
	align 4

IsBadStringPtrA endp

IsBadStringPtrW proc public uses edi pStr:dword

	xor edx, edx
	push offset exception_string
	push fs:[edx]
	mov fs:[edx], esp

	or ecx,-1
	xor eax,eax 	 ;0 means no error!
	mov edi, pStr
	repnz scasw
done: 
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
	@strace <[ebp+4], ": IsBadStringPtrW(", pStr, ")=", eax>
	ret
exception_string:
	mov eax, [esp+12]	;get context
	mov [eax].CONTEXT.rEip, offset cont_exc_string
	xor eax, eax		;== _XCPT_CONTINUE_EXECUTION
	retn
cont_exc_string:
	@strace <"*** exception catched inside IsBadStringPtrW()">
	inc eax
	jmp done
	align 4

IsBadStringPtrW endp

	end
