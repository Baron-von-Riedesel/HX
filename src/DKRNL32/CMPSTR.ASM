
;--- implements CompareStringA

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
	include macros.inc
	include dkrnl32.inc

	.CODE

CompareStringA proc public uses esi edi lcid:dword, flags:dword,
         pString1:ptr BYTE, cString1:dword, pString2:ptr BYTE, cString2:dword

	mov esi, pString1
	mov edi, pString2
	.if (cString1 == -1)
		invoke lstrlen, esi
		mov cString1, eax
	.endif
	.if (cString2 == -1)
		invoke lstrlen, edi
		mov cString2, eax
	.endif
	mov ecx, cString1
	.if (ecx > cString2)
		mov edx, CSTR_GREATER_THAN
		mov ecx, cString2
	.else
		mov edx, CSTR_LESS_THAN
	.endif
	.if (flags & NORM_IGNORECASE)
		.while (ecx)
			lodsb
			mov ah, [edi]
			inc edi
			.if ((al >= 'a') && (al <= 'z'))
				sub al, 'a'
				add al, 'A'
			.endif
			.if ((ah >= 'a') && (ah <= 'z'))
				sub ah, 'a'
				add ah, 'A'
			.endif
			cmp al, ah
			.break .if (!ZERO?)
			dec ecx
		.endw
	.else
		repz cmpsb
	.endif
	.if (ZERO?)
		mov ecx, cString1
		.if (ecx != cString2)
			mov eax, edx
		.else
			mov eax, CSTR_EQUAL
		.endif
	.else
		sbb eAX,eAX
		sbb eAX,-1
		inc eax
		inc eax
	.endif
	@strace <"CompareStringA(", lcid, ", ", flags, ", ", pString1, ", ", cString1, ", ", pString2, ", ", cString2, ")=", eax>
	ret
	align 4

CompareStringA endp

end

