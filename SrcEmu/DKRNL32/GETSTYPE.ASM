
;--- implements:
;--- GetStringTypeA
;--- GetStringTypeExA
;--- GetStringTypeW
;--- GetStringTypeExW

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
	include dkrnl32.inc
	include macros.inc

	.CODE

GetStringTypeA proc public uses esi edi lcid:dword,
         infotype:dword, pString:ptr BYTE, cString:dword, pCharType:ptr word

	test infotype, CT_CTYPE2 or CT_CTYPE3
	jnz  error
	mov ecx, cString
	.if (ecx == -1)
		invoke lstrlen, pString
		mov ecx, eax
	.endif
	mov esi, pString
	mov edi, pCharType
	.while (ecx)
		lodsb
		mov dx, C1_CNTRL
		cmp al,20h
		jb @F
		mov dx, C1_SPACE
		jz @F
		cmp al,'0'
		mov dx, C1_PUNCT
		jb @F
		mov dx, C1_DIGIT
		cmp al, '9'
		jbe @F
		mov dx, C1_PUNCT
		cmp al,'A'
		jb @F
		cmp al,'Z'
		mov dx, C1_UPPER
		jbe @F
		mov dx, C1_PUNCT
		cmp al,'a'
		jb @F
		mov dx, C1_LOWER
		cmp al,'z'
		jbe @F
		xor dx,dx
@@:
		mov ax,dx
		stosw
		dec ecx
	.endw
	@mov eax,1
done:
	@strace <"GetStringTypeA(", lcid, ", ", infotype, ", , ", cString, ")=", eax>
	ret
error:
	invoke SetLastError,ERROR_INVALID_PARAMETER
	xor eax,eax
	jmp done
	align 4

GetStringTypeA endp

GetStringTypeExA proc public  lcid:dword,
		infotype:dword, pString:ptr BYTE, cString:dword, pCharType:ptr word

	invoke GetStringTypeA, lcid, infotype, pString, cString, pCharType
	ret
	align 4

GetStringTypeExA endp         

;--- GetStringTypeW has no lcid parameter!!!

GetStringTypeW proc public uses esi edi infotype:dword, pString:dword, 
			cString:dword, pCharType:dword

	test infotype, CT_CTYPE2 or CT_CTYPE3
	jnz  error
	mov ecx, cString
	.if (ecx == -1)
		invoke lstrlenW, pString
		mov ecx, eax
	.endif
	mov esi, pString
	mov edi, pCharType
	.while (ecx)
		lodsw
		mov dx, C1_CNTRL
		cmp ax,20h
		jb @F
		mov dx, C1_SPACE
		jz @F
		cmp ax,'0'
		mov dx, C1_PUNCT
		jb @F
		mov dx, C1_DIGIT
		cmp ax, '9'
		jbe @F
		mov dx, C1_PUNCT
		cmp ax,'A'
		jb @F
		cmp ax,'Z'
		mov dx, C1_UPPER
		jbe @F
		mov dx, C1_PUNCT
		cmp ax,'a'
		jb @F
		mov dx, C1_LOWER
		cmp ax,'z'
		jbe @F
		xor dx,dx
@@:
		mov ax,dx
		stosw
		dec ecx
	.endw
	@mov eax,1
done:
	@strace <"GetStringTypeW(", infotype, ", , ", cString, ")=", eax>
	ret
error:
	invoke SetLastError,ERROR_INVALID_PARAMETER
	xor eax,eax
	jmp done
	align 4

GetStringTypeW endp

GetStringTypeExW proc public  lcid:dword,
		infotype:dword, pString:ptr WORD, cString:dword, pCharType:ptr word

	invoke GetStringTypeW, infotype, pString, cString, pCharType
	ret
	align 4

GetStringTypeExW endp

	end

