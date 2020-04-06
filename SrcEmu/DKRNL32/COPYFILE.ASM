
;--- implements CopyFileA

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

BUFSIZE	equ 8000h

@StackAlloc macro dwBytes
	mov eax, dwBytes
	.while (eax >= 1000h)
		sub esp, 1000h-4
		push 0
		sub eax, 1000h
	.endw
	sub esp, eax
	@loadesp eax
	push dwBytes
	endm

@StackFree	macro
	pop ecx
	add esp, ecx
	endm

	.CODE

CopyFileA proc public uses ebx esi edi lpExistingFileName:ptr BYTE, lpNewFileName:ptr BYTE, bFailIfExists:DWORD

local	hFileFrom:DWORD
local	hFileTo:DWORD

	mov hFileTo, HFILE_ERROR
	invoke _lopen, lpExistingFileName, OF_READ
	mov hFileFrom, eax
	.if (eax == HFILE_ERROR)
		jmp error
	.endif

	.if (bFailIfExists)
		mov ecx, CREATE_NEW
	.else
		mov ecx, CREATE_ALWAYS
	.endif
	invoke CreateFile, lpNewFileName, GENERIC_WRITE, 0, NULL, ecx, FILE_ATTRIBUTE_NORMAL, hFileFrom
	mov hFileTo, eax
	.if (eax == HFILE_ERROR)
		jmp error
	.endif

	@StackAlloc BUFSIZE
	mov esi, eax

	.while (1)
		invoke _lread, hFileFrom, esi, BUFSIZE
		.break .if (eax == HFILE_ERROR)
		.break .if (!eax)
		push eax
		invoke _lwrite, hFileTo, esi, eax
		pop ecx
		.break .if (eax == HFILE_ERROR)
		.break .if (ecx != BUFSIZE)
	.endw

		@StackFree

	.if (eax == HFILE_ERROR)
		jmp error
	.endif

	mov ebx, hFileFrom
	mov ax, 5700h
	int 21h
	.if (!CARRY?)
		mov ebx, hFileTo
		mov ax, 5701h
		int 21h
	.endif
	mov esi, 1
	jmp done
error:
	.if (hFileTo != HFILE_ERROR)
		invoke CloseHandle, hFileTo
		mov hFileTo, HFILE_ERROR
		invoke DeleteFile, lpNewFileName
	.endif
	xor esi, esi
done:
	.if (hFileFrom != HFILE_ERROR)
		invoke CloseHandle, hFileFrom
	.endif
	.if (hFileTo != HFILE_ERROR)
		invoke CloseHandle, hFileTo
	.endif
	mov eax, esi
	@strace <"CopyFileA(", lpExistingFileName, ", ", lpNewFileName, ", ",  bFailIfExists, ")=", eax>
	ret
	align 4

CopyFileA endp

END

