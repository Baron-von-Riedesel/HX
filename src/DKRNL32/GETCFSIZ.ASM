
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

;--- Win32 GetCompressedFileSize is not supported in Win9x

extern	__CHECKOS:abs

	.CODE

GetCompressedFileSizeA proc public uses ebx pName:dword,pHighword:dword

	mov edx,pName
	mov bl,02
	mov ax,7143h
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov ax,4302h
	int 21h
	jnc success
error:
	movzx eax, ax
	invoke SetLastError,eax
	mov eax,-1
	jmp exit
success:
	push dx
	push ax
	pop eax
exit:
	@strace <"GetCompressedFileSizeA(", pName, ", ", pHighword, ")=", eax>
	ret
	align 4

GetCompressedFileSizeA endp

end

