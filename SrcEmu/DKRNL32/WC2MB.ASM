
;--- implements MultiByteToWideChar() and WideCharToMultiByte();
;--- also dummies: IsValidCodePage(), IsDBCSLeadByte(), IsDBCSLeadByteEx().
;--- CP_UTF8 is converted to/from UTF-16 (with surrogate pairs);
;--- all other code pages still map bytes 1:1 to 0000h-00FFh.

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include winerror.inc
	include macros.inc

ifndef CP_UTF8
CP_UTF8 equ 65001
endif
ifndef WC_ERR_INVALID_CHARS
WC_ERR_INVALID_CHARS equ 80h
endif

Utf8ToWide proto pSrc:ptr BYTE, cbSrc:dword, pDst:ptr WORD, cchDst:dword, flags:dword
WideToUtf8 proto pSrc:ptr WORD, cchSrc:dword, pDst:ptr BYTE, cbDst:dword, flags:dword

	.CODE


;--- returns number of characters written to pMultByte
;--- if cWideChar == -1, pWideChar is assumed to be zero-terminated.
;--- if nBuffSize == 0 pMultByte is not used
;--- and eax return the number of bytes required for the buffer

WideCharToMultiByte proc public uses esi edi codepage:dword,
							flags:dword,
							pWideChar:ptr WORD,
							cWideChar:dword,
							pMultByte:ptr BYTE,
							nBuffSize:dword,
							pDefaultChar:dword,
							pUsedDefaultChar:dword

	mov esi, pWideChar
	mov edi, pMultByte
	cmp esi, edi
	jz error1
	mov ecx, cWideChar
	.if (ecx == -1)
		invoke lstrlenW, esi
		inc eax
		mov ecx, eax
	.endif
	.if (codepage == CP_UTF8)
		.if (!ecx)
			jmp error1
		.endif
		invoke WideToUtf8, esi, ecx, edi, nBuffSize, flags
		jmp done
	.endif
	.if (!nBuffSize)
		mov eax, ecx
		jmp done
	.endif
	.if (ecx > nBuffSize)
		invoke SetLastError, ERROR_INSUFFICIENT_BUFFER
		xor eax,eax
		jmp done
	.endif
	xor eax, eax
	.while (ecx)
		lodsw
		stosb
		dec ecx
	.endw
	mov eax, edi
	sub eax, pMultByte
done:
ifdef _DEBUG
	@trace <"WideCharToMultiByte(">
	@tracedw codepage
	@trace <", ">
	@tracedw flags
	@trace <", ">
	@tracedw pWideChar
	@trace <", ">
	@tracedw cWideChar
	@trace <", ">
	.if (pMultByte)
		@traceN pMultByte, eax
	.else
		@trace <"NULL">
	.endif
	@trace <", ">
	@tracedw nBuffSize
	@trace <")=">
	@tracedw eax
	@trace <13,10>
endif
	ret
error1:
	invoke SetLastError, ERROR_INVALID_PARAMETER
	xor eax,eax
	jmp done
	align 4

WideCharToMultiByte endp

;--- returns number of characters written to pWideCharString
;--- if nMultByte == -1, pMultiByteString is assumed to be zero terminated.
;--- if nBuffSize == 0 pWideCharString is not used
;--- and eax return the number of wide chars required for the buffer


MultiByteToWideChar proc public uses esi edi codepage:dword,
							flags:dword,
							pMultiByteString:ptr BYTE,
							nMultByte:dword,
							pWideCharString:ptr WORD,
							nBuffSize:dword

	mov esi, pMultiByteString
	mov edi, pWideCharString
	cmp esi, edi
	jz error1
	mov ecx, nMultByte
	.if (ecx == -1)
		invoke lstrlenA, esi
		inc eax
		mov ecx, eax
	.endif
	.if (codepage == CP_UTF8)
		.if (!ecx)
			jmp error1
		.endif
		invoke Utf8ToWide, esi, ecx, edi, nBuffSize, flags
		jmp done
	.endif
	.if (!nBuffSize)
		mov eax, ecx
		jmp done
	.endif
	.if (ecx > nBuffSize)
		invoke SetLastError, ERROR_INSUFFICIENT_BUFFER
		xor eax,eax
		jmp done
	.endif
	xor eax, eax
	.while (ecx)
		lodsb
		stosw
		dec ecx
	.endw
	mov eax, esi
	sub eax, pMultiByteString
done:
ifdef _DEBUG
	@trace <"MultiByteToWideChar(">
	@tracedw codepage
	@trace <", ">
	@tracedw flags
	@trace <", ">
	@traceN pMultiByteString, eax
	@strace <", ", nMultByte, ", ^wc=", pWideCharString, ", ", nBuffSize, ")=", eax, " esp=", esp>
endif
	ret
error1:
	invoke SetLastError, ERROR_INVALID_PARAMETER
	xor eax,eax
	jmp done
	align 4

MultiByteToWideChar endp

IsValidCodePage proc public codepage:dword
	mov eax,1
	@strace <"IsValidCodePage(", codepage, ")=", eax, " *** unsupp ***">
	ret
	align 4
IsValidCodePage endp

IsDBCSLeadByte proc public testchar:dword
	xor eax, eax
	@strace <"IsDBCSLeadByte(", testchar, ")=", eax, " *** unsupp ***">
	ret
	align 4
IsDBCSLeadByte endp

IsDBCSLeadByteEx proc public codepage:dword, testchar:dword
	xor eax, eax
	@strace <"IsDBCSLeadByteEx(", codepage, ", ", testchar, ")=", eax, " *** unsupp ***">
	ret
	align 4
IsDBCSLeadByteEx endp

	end

