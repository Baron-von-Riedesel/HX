
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

SetEndOfFile proc uses ebx handle:dword

	mov ebx,handle
	xor ecx,ecx
	mov ah,40h
	int 21h
	jc error
	@mov eax,1
exit:
	@strace <"SetEndOfFile(", handle, ")=", eax>
	ret
error:
	movzx eax,ax
	invoke SetLastError, eax
	xor eax,eax
	jmp exit

SetEndOfFile endp

	END
