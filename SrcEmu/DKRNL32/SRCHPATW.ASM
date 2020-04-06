
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

	.CODE

SearchPathW proc public lpPath:ptr WORD, lpFileName:ptr WORD, lpExtension:ptr WORD,
			nBufferLength:DWORD, lpBuffer:ptr WORD, lpFilePart:ptr ptr WORD

local	lpFilePartA:DWORD

	mov eax, lpPath
	.if (eax)
		call ConvertWStr
		mov lpPath, eax
	.endif
	mov eax, lpExtension
	.if (eax)
		call ConvertWStr
		mov lpExtension, eax
	.endif
	mov eax, lpFileName
	call ConvertWStr
	mov lpFileName, eax

	lea ecx, lpFilePartA
	invoke SearchPathA, lpPath, eax, lpExtension, nBufferLength, lpBuffer, ecx
	.if (eax)
		invoke ConvertAStr, lpBuffer
		mov ecx, lpFilePartA
		sub ecx, lpBuffer
		shl ecx, 1
		mov edx, lpFilePart
		mov [edx], ecx
	.endif
	@strace <"SearchPathW(", lpPath, ", ", lpFileName, ", ", lpExtension, ", ", nBufferLength, ", ", lpBuffer, ", ",  lpFilePart, ")=", eax>
	ret
	align 4

SearchPathW endp

	END
