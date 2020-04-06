
;--- implements:
;--- CharToOemBuffA
;--- CharToOemA
;--- CharToOemBuffW
;--- CharToOemW
;--- OemToCharBuffA
;--- OemToCharA
;--- OemToCharBuffW
;--- OemToCharW

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
;	include winuser.inc
	include macros.inc

	.DATA

	.CODE

xstr	db 0A7H,0C4h,0D6h,0DCh,0DFh,0E4h,0F6h,0FCh	;ANSI db "§ÄÖÜßäöü"
lxstr	equ $ - xstr
		db 015h,08EH,099h,09Ah,0E1h,084h,094h,081h
;-------------- OEM §,AE,OE,UE,SS,ae,oe,ue

;------------ Char/OEM conversions

CharToOemBuffA proc public uses esi edi pszSource:ptr BYTE, pszDest:ptr BYTE, dwSize:dword

	mov esi,pszSource
	mov edi,pszDest
	mov ecx,dwSize
	jecxz done
@@:
	lodsb
	test al,80h
	jnz special
cont:
	stosb
	loop @B
done:
	@strace <"CharToOemBuffA(", pszSource, ", ", pszDest, ", ", dwSize, ")=", eax>
	ret
special:
	mov edx,edi
	push ecx
	mov edi,offset xstr
	mov ecx,lxstr
	repnz scasb
	pop ecx
	xchg edx,edi
	jnz cont
	mov al,[edx+lxstr-1]
	jmp cont
	align 4

CharToOemBuffA endp

CharToOemA proc public lpszSrc:ptr BYTE, lpszDest:ptr BYTE

	invoke lstrlen, lpszSrc
	inc eax
	invoke CharToOemBuffA, lpszSrc, lpszDest, eax
	@strace <"CharToOemA(", lpszSrc, ", ", lpszDest, ")=", eax>
	ret
	align 4
CharToOemA endp

;--- does not stop if a NULL character occurs in the source

CharToOemBuffW proc public uses esi edi pszSource:ptr WORD, pszDest:ptr BYTE, dwSize:dword

	mov esi,pszSource
	mov edi,pszDest
	mov ecx,dwSize
	jecxz done
@@:
	lodsw
	stosb
	loop @B
done:
	@strace <"CharToOemBuffW(", pszSource, ", ", pszDest, ", ", dwSize, ")=", eax>
	ret
	align 4
CharToOemBuffW endp

CharToOemW proc public lpszSrc:ptr WORD, lpszDest:ptr BYTE

	invoke lstrlenW, lpszSrc
	inc eax
	invoke CharToOemBuffW, lpszSrc, lpszDest, eax
	@strace <"CharToOemW(", lpszSrc, ", ", lpszDest, ")=", eax>
	ret
	align 4
CharToOemW endp

;--- does not stop if a NULL character occurs in the source

OemToCharBuffA proc public pszSource:ptr BYTE, pszDest:ptr BYTE, dwSize:dword
	invoke RtlMoveMemory, pszDest, pszSource, dwSize
	@strace <"OemToCharBuffA(", pszSource, ", ", pszDest, ", ", dwSize, ")=", eax>
	ret
	align 4
OemToCharBuffA endp

OemToCharA proc public lpszSrc:ptr BYTE, lpszDest:ptr BYTE
	invoke lstrlen, lpszSrc
	inc eax
	invoke OemToCharBuffA, lpszSrc, lpszDest, eax
	@strace <"OemToCharA(", lpszSrc, ", ", lpszDest, ")=", eax>
	ret
	align 4
OemToCharA endp

;--- does not stop if a NULL character occurs in the source

OemToCharBuffW proc public uses esi edi pszSource:ptr BYTE, pszDest:ptr WORD, dwSize:dword

	mov ecx, dwSize
	mov esi, pszSource
	mov edi, pszDest
	jecxz done
	mov ah,0
@@:
	lodsb
	stosw
	loop @B
done:
	or eax,1
	@strace <"OemToCharBuffW(", pszSource, ", ", pszDest, ", ", dwSize, ")=", eax>
	ret
	align 4
OemToCharBuffW endp

OemToCharW proc public lpszSrc:ptr BYTE, lpszDest:ptr WORD
	invoke lstrlen, lpszSrc
	inc eax
	invoke OemToCharBuffW, lpszSrc, lpszDest, eax
	@strace <"OemToCharW(", lpszSrc, ", ", lpszDest, ")=", eax>
	ret
	align 4
OemToCharW endp

	end

