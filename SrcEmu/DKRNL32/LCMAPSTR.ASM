
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winerror.inc
	include dkrnl32.inc
	include macros.inc

	.DATA

	.CODE

LCMapStringA proc public lcid:dword, flags:dword,
				lpStrSrc:dword, cchSrc:dword,
				lpStrDest:dword, cchDest:dword

	test flags, LCMAP_HIRAGANA or LCMAP_KATAKANA or \
		LCMAP_SIMPLIFIED_CHINESE or	LCMAP_TRADITIONAL_CHINESE or \
		LCMAP_HALFWIDTH or LCMAP_FULLWIDTH
	jz @F
	invoke SetLastError, ERROR_INVALID_PARAMETER
	xor eax,eax
	jmp exit
@@:
	mov ecx, cchSrc
	.if (ecx == -1)
		invoke lstrlen, lpStrSrc
		inc eax
		mov ecx, eax
	.endif
	.if (cchDest)
		.if (ecx > cchDest)
			invoke SetLastError, ERROR_INSUFFICIENT_BUFFER
			xor eax, eax
		.else
			mov eax, ecx
			pushad
			mov esi, lpStrSrc
			mov edi, lpStrDest
			.if (flags & LCMAP_LOWERCASE)
				.while (ecx)
					lodsb
					cmp al, 'A'
					jb @F
					cmp al, 'Z'
					ja @F
					sub al, 'A'
					add al, 'a'
@@:
					stosb
					dec ecx
				.endw
			.elseif (flags & LCMAP_UPPERCASE)
				.while (ecx)
					lodsb
					cmp al, 'a'
					jb @F
					cmp al, 'z'
					ja @F
					sub al, 'a'
					add al, 'A'
@@:
					stosb
					dec ecx
				.endw
			.else
				rep movsb
			.endif
			popad
		.endif
	.else
		mov eax, ecx
	.endif
exit:
	@strace <"LCMapStringA(", lcid, ", ", flags, ", ", lpStrSrc, ", ", cchSrc, ", ", lpStrDest, ", ", cchDest, ")=", eax>
	ret
	align 4

LCMapStringA endp

;--- wide string version
;--- cchDest may be 0, in which case eax returns requested size of buffer 

LCMapStringW proc public lcid:dword,
			flags:dword,
			lpStrSrc:dword,
			cchSrc:dword,
			lpStrDest:dword,
			cchDest:dword

		mov eax, lpStrSrc
		call ConvertWStr
		invoke LCMapStringA, lcid, flags, eax, cchSrc, lpStrDest, cchDest
		.if (eax && cchDest)
			dec eax							;here eax includes term. 0
			invoke ConvertAStr, lpStrDest
			inc eax
		.endif
		@strace <"LCMapStringW(", lcid, ", ", flags, ", ", lpStrSrc, ", ", cchSrc, ", ", lpStrDest, ", ", cchDest, ")=", eax>
		ret
LCMapStringW endp

end

