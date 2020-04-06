
;--- CharUpperA/W, CharLowerA/W
;--- CharUpperBuffA/W, CharLowerBuffA/W
;--- IsCharUpperA/W, IsCharLowerA/W

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

	.CODE

;------------ upper/lower conversions

CharUpperBuffW proc public pszSource:dword, dwSize:dword
CharUpperBuffW endp
	@mov eax, 2
	jmp CharUpperBuff
	align 4

CharUpperBuffA proc public pszSource:dword, dwSize:dword
CharUpperBuffA endp
	@mov eax, 1

CharUpperBuff proc private uses esi pszSource:dword, dwSize:dword

	mov edx, eax
	mov esi,pszSource
	mov ecx,dwSize
	.while (ecx)
		mov al, [esi]
		cmp al, 'a'
		jb @F
		cmp al, 'z'
		ja @F
		sub al, 'a' - 'A'
		mov [esi], al
@@:
		add esi, edx
		dec ecx
	.endw
	@strace <"CharUpperBuffx(", pszSource, ", ", dwSize, ")=", eax>
	ret
	align 4

CharUpperBuff endp

CharUpperA proc public uses esi lpsz:ptr BYTE

	mov esi, lpsz
	.if (esi < 10000h)
		lea esi, lpsz
	.endif
	.repeat
		lodsb
		cmp al, 'a'
		jb @F
		cmp al, 'z'
		ja @F
		sub al, 'a'-'A'
		mov [esi-1],al
@@:
	.until (!al)
	mov eax, lpsz
	@strace <"CharUpperA(", lpsz, ")=", eax>
	ret
	align 4
CharUpperA endp

CharUpperW proc public uses esi lpsz:ptr WORD

	mov esi, lpsz
	.if (esi < 10000h)
		lea esi, lpsz
	.endif
	.repeat
		lodsw
		cmp al, 'a'
		jb @F
		cmp al, 'z'
		ja @F
		sub al, 'a'-'A'
		mov [esi-2],ax
@@:
	.until (!ax)
	mov eax, lpsz
	@strace <"CharUpperW(", lpsz, ")=", eax>
	ret
	align 4
CharUpperW endp

CharLowerBuffW proc public pszSource:dword, dwSize:dword
CharLowerBuffW endp
	@mov eax, 2
	jmp CharLowerBuff
	align 4

CharLowerBuffA proc public pszSource:dword, dwSize:dword
CharLowerBuffA endp
	@mov eax, 1

CharLowerBuff proc private uses esi pszSource:dword, dwSize:dword

	mov edx, eax
	mov esi,pszSource
	mov ecx,dwSize
	.while (ecx)
		mov al, [esi]
		cmp al, 'A'
		jb @F
		cmp al, 'Z'
		ja @F
		add al, 'a' - 'A'
		mov [esi], al
@@:
		add esi, edx
		dec ecx
	.endw
	@strace <"CharLowerBuffx(", pszSource, ", ", dwSize, ")=", eax>
	ret
	align 4

CharLowerBuff endp


CharLowerA proc public uses esi lpsz:ptr BYTE

	mov esi, lpsz
	.if (esi < 10000h)
		lea esi, lpsz
	.endif
	.repeat
		lodsb
		cmp al, 'A'
		jb @F
		cmp al, 'Z'
		ja @F
		add al, 'a'-'A'
		mov [esi-1],al
@@:
	.until (!al)
	mov eax, lpsz
	@strace <"CharLowerA(", lpsz, ")=", eax>
	ret
	align 4
CharLowerA endp

CharLowerW proc public uses esi lpsz:ptr WORD
	mov esi, lpsz
	.if (esi < 10000h)
		lea esi, lpsz
	.endif
	.repeat
		lodsw
		cmp al, 'A'
		jb @F
		cmp al, 'Z'
		ja @F
		add al, 'a'-'A'
		mov [esi-2],ax
@@:
	.until (!ax)
	mov eax, lpsz
	@strace <"CharLowerW(", lpsz, ")=", eax>
	ret
	align 4
CharLowerW endp

IsCharLowerA proc public character:BYTE

	xor eax, eax
	mov cl, character
	.if (cl >= 'a' && cl <= 'z')
		inc eax
	.endif
;	@strace <"IsCharLowerA(", character, ")=", eax>
	ret
	align 4
IsCharLowerA endp

IsCharLowerW proc public character:WORD

	xor eax, eax
	mov cx, character
	.if (cx >= 'a' && cx <= 'z')
		inc eax
	.endif
;	@strace <"IsCharLowerW(", character, ")=", eax>
	ret
	align 4
IsCharLowerW endp

IsCharUpperA proc public character:BYTE

	xor eax, eax
	mov cl, character
	.if (cl >= 'A' && cl <= 'Z')
		inc eax
	.endif
;	@strace	<"IsCharUpperA(", character, ")=", eax>
	ret
	align 4
IsCharUpperA endp

IsCharUpperW proc public character:WORD

	xor eax, eax
	mov cx, character
	.if (cx >= 'A' && cx <= 'Z')
		inc eax
	.endif
;	@strace <"IsCharUpperW(", character, ")=", eax>
	ret
	align 4
IsCharUpperW endp

	end

