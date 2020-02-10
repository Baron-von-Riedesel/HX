
;--- implements MoveFileA and MoveFileExA

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
	include macros.inc

extern __CHECKOS:abs

?SAVEEBX equ 1

	.CODE

;--- MoveFile(Ex) can move files and directories (including children)
;--- files may be moved to another volume
;--- todo: check for directories!

if ?SAVEEBX
MoveFileExA proc public uses ebx edi pOldName:ptr BYTE,pNewName:ptr BYTE, dwFlags:dword
else
MoveFileExA proc public uses edi pOldName:ptr BYTE,pNewName:ptr BYTE, dwFlags:dword
endif

	test dwFlags, MOVEFILE_DELAY_UNTIL_REBOOT
	jnz error_not_supp
	mov edx,pOldName
	mov edi,pNewName
	mov cx,[edx]
	mov ax,[edi]
	.if (ch == ':')
		or cl,20h
	.endif
	.if (ah == ':')
		or al,20h
	.endif

;--- check if the rename would involve a drive change
;--- this will not work with a simple DOS function

	.if ((ch == ':') || (ah == ':'))
		jmp checkdrives
	.endif
drivesok:
	mov ax,7156h
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov ah,56h
	int 21h
	jc error
success:
	@mov eax, 1
exit:
	@strace <"MoveFileExA(", &pOldName, ", ", &pNewName, ", ", dwFlags, ")=", eax>
	ret
error_not_supp:
	mov ax, ERROR_NOT_SUPPORTED
error:
	movzx eax, ax
	invoke SetLastError,eax
	xor eax,eax
	jmp exit
checkdrives:
	.if (ch != ah)
		push edx
		push ecx
		mov ah,19h
		int 21h
		add al,'a'
		pop ecx
		pop edx
		.if (ch == ':') 
			.if (al != cl)
				jmp  drivesdiffer
			.endif
		.else
			mov cx,[edi]
			or cl,20h
			.if (al != cl)
				jmp  drivesdiffer
			.endif
		.endif
	.elseif (al != cl)
		jmp drivesdiffer
	.endif
	jmp drivesok
drivesdiffer:
	mov ax, ERROR_NOT_SAME_DEVICE
	test dwFlags, MOVEFILE_COPY_ALLOWED
	jz error
	xor ecx, ecx
	test dwFlags, MOVEFILE_REPLACE_EXISTING
	setz cl
	invoke CopyFileA, pOldName, pNewName, ecx
	.if (eax)
		invoke DeleteFileA, pOldName
		.if (eax)
if 0
			test dwFlags, MOVEFILE_WRITE_THROUGH
			jz @F
@@:
endif
		.else
			invoke DeleteFileA, pNewName
			xor eax, eax
		.endif
	.endif
	jmp exit
	align 4

MoveFileExA endp

MoveFileA proc public pOldName:ptr BYTE,pNewName:ptr BYTE

	invoke MoveFileExA, pOldName, pNewName, MOVEFILE_COPY_ALLOWED
	@strace <"MoveFileA(", pOldName, ", ", pNewName, ")=", eax>
	ret
	align 4
MoveFileA endp

	END

