
;--- implements directory support (ansi)
;--- CreateDirectoryA
;--- CreateDirectoryExA
;--- RemoveDirectoryA

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

?SAVEEBX	equ 1	;create code compatible with FreeDOS + MSDOS < 7

extern	__CHECKOS:abs


	.CODE

if ?SAVEEBX
CreateDirectoryA proc public uses ebx pName:ptr BYTE, pSecurity:dword
else
CreateDirectoryA proc public pName:ptr BYTE, pSecurity:dword
endif

	mov edx,pName
	mov ax,7139h
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov ah,39h
	int 21h
	jc error
success:
	@mov eax, 1
exit:        
	@strace <"CreateDirectoryA(", &pName, ", ", pSecurity, ")=", eax, " ebx=", ebx>
	ret
error:
	movzx eax, ax
	.if (ax == 5)
		mov ax, ERROR_ALREADY_EXISTS
	.endif
	@strace	<"CreateDirectoryA() lasterror=", eax>
if 0;def _DEBUG
	mov ecx,pName
	.if (byte ptr [ecx+1] != ':')
		push eax
		sub esp, 260
		mov edx, esp
		invoke GetCurrentDirectoryA, 260, edx
		@trace <"current dir=">
		mov edx, esp
		@trace edx
		@trace <13,10>
		add esp, 260
		pop eax
	.endif
endif
	invoke SetLastError, eax
	xor eax,eax
	jmp exit
	align 4

CreateDirectoryA endp

CreateDirectoryExA proc public lpTemplate:ptr BYTE, lpNewDir:ptr BYTE, lpSecurity:ptr

	invoke CreateDirectoryA, lpNewDir, lpSecurity
	@strace <"CreateDirectoryExA(", lpTemplate, ", ", lpNewDir, ", ", lpSecurity, ")=", eax>
	ret
	align 4

CreateDirectoryExA endp

if ?SAVEEBX
RemoveDirectoryA proc public uses ebx pName:ptr BYTE
else
RemoveDirectoryA proc public pName:ptr BYTE
endif

	mov edx,pName
	mov ax,713Ah
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov ah,3Ah
	int 21h
	jc error
success:
	@mov eax, 1
exit:
	@strace <"RemoveDirectoryA(", pName, ")=", eax>
	ret
error:
	movzx eax, ax
	@strace <"RemoveDirectoryA() lasterror=", eax>
	invoke SetLastError, eax
	xor eax,eax
	jmp exit
	align 4

RemoveDirectoryA endp

	end

