
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc

	.CODE

SetHandleCount proc public uses ebx newsize:dword

	mov ah,67h
	mov ebx,newsize
	int 21h
	mov eax,newsize
	jnc @F
	xor eax,eax
@@:
	@strace <"SetHandleCount(", newsize, ")=", eax>
	ret

SetHandleCount endp

	end
