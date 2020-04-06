
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

?SAVEEBX	equ 1	;hiword ebx is destroyed in some doses

extern	__CHECKOS:abs

	include winbase.inc
	include macros.inc

	.CODE

if ?SAVEEBX
GetFullPathNameA proc uses ebx esi edi lpFileName:ptr BYTE,bufSize:dword,pBuffer:ptr BYTE,lpFilePart:ptr ptr BYTE
else
GetFullPathNameA proc uses esi edi lpFileName:ptr BYTE,bufSize:dword,pBuffer:ptr BYTE,lpFilePart:ptr ptr BYTE
endif

local	szFullPath[MAX_PATH]:byte

	@strace <"GetFullPathNameA(", &lpFileName, ", ", bufSize, ", ", pBuffer, ", ", lpFilePart, ")">
	mov esi,lpFileName
	lea edi,szFullPath
	mov cx,8000h			;dont resolve drive letter
	mov ax,7160h
	stc
	int 21h
	jnc ok
	cmp ax,7100h
	jnz error
	mov ah,60h
	int 21h
	jc error
ok:
	invoke lstrlen, edi
	inc eax
	.if (eax > bufSize)
		jmp done
	.endif
	mov edi, eax
	mov esi, pBuffer
	invoke CopyMemory, esi, addr szFullPath, eax
	mov eax, edi
	.while (eax)
		mov cl, [esi+eax-1]
		.if ((cl == '\') || (cl == ':'))
			.break
		.endif
		dec eax
	.endw
	lea ecx, [esi+eax]
	mov eax,lpFilePart
	and eax,eax
	jz @F
	mov [eax],ecx
@@:
	mov eax, edi
	dec eax
done:
	@strace <"GetFullPathNameA()=", eax, " [", &pBuffer, "]">
	ret
error:
	movzx eax, ax
	invoke SetLastError, eax
	@strace <"GetFullPathNameA() last error=", eax>
	xor eax, eax
	jmp done
	align 4

GetFullPathNameA endp

	end

