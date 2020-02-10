
;--- implements GetBinaryTypeA()
;--- (this functions is not supported by Win95/Win98)

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

SCS_32BIT_BINARY	EQU	0
SCS_DOS_BINARY		EQU	1
SCS_WOW_BINARY		EQU	2
SCS_PIF_BINARY		EQU	3
SCS_POSIX_BINARY	EQU	4
SCS_OS216_BINARY	EQU	5
SCS_64BIT_BINARY	EQU	6

	.CODE

GetBinaryTypeA proc public uses ebx esi edi pszBinary:ptr BYTE, pType:ptr DWORD

local	mzhdr:IMAGE_DOS_HEADER

	invoke _lopen, pszBinary, OF_READ
	.if (eax != HFILE_ERROR)
		mov ebx, eax
		xor esi, esi
		invoke _lread, ebx, addr mzhdr, sizeof mzhdr
		.if (eax == sizeof mzhdr)
			.if (mzhdr.e_magic == "ZM")
				mov edi, SCS_DOS_BINARY
				inc esi
				.if (mzhdr.e_lfarlc >= 40h)
					invoke _llseek, ebx, mzhdr.e_lfanew, 0
					invoke _lread, ebx, addr mzhdr, sizeof mzhdr
					mov ax, mzhdr.e_magic
					.if (ax == "EP")
						mov edi, SCS_32BIT_BINARY
					.elseif (ax == "EN")
						mov edi, SCS_WOW_BINARY
					.endif
				.endif
			.endif
		.endif
		invoke _lclose, ebx
		mov eax, esi
		.if (eax)
			mov ecx, pType
			mov [ecx], edi
		.endif
	.else
		xor eax, eax
	.endif
	@strace <"GetBinaryTypeA('", pszBinary, "', ", pType, ")=", eax>
	ret
	align 4

GetBinaryTypeA endp

GetBinaryTypeW proc public uses ebx esi edi pszBinary:ptr WORD, pType:ptr DWORD

	mov eax,pszBinary
	call ConvertWStr
	invoke GetBinaryTypeA, eax, pType
	@strace <"GetBinaryTypeW(", pszBinary, ", ", pType, ")=", eax>
	ret

GetBinaryTypeW endp

	end

