
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

;*** return: handle in eax ***

	.CODE

FlushFileBuffers proc public uses ebx handle:dword

	mov ah,68h
	mov ebx,handle
	int 21h
	@strace <"FlushFileBuffers(",handle, ")=", eax>
	ret
	align 4
FlushFileBuffers endp

	end
