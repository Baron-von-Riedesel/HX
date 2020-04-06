
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

	.DATA

	.CODE

;--- if FILE_TYPE_UNKNOWN is returned, last error has to be set!

GetFileType proc public uses ebx handle:dword

	mov ebx,handle
	cmp ebx,10000h
	ja  unknown
	mov ax,4400h
	int 21h
	jc invalid
	test dl,80h				;device?
	mov eax,FILE_TYPE_CHAR
	jnz exit
	test dh,80h				;remote flag set?
	mov eax,FILE_TYPE_DISK
	jz exit
	mov eax,FILE_TYPE_REMOTE
	jmp exit
unknown:
	invoke SetLastError, NO_ERROR
	mov eax,FILE_TYPE_UNKNOWN
	jmp exit
invalid:
	movzx eax, ax
	invoke SetLastError, eax
	mov eax,FILE_TYPE_UNKNOWN
exit:
	@strace  <"GetFileType(", handle, ")=", eax>
	ret
GetFileType endp

end
