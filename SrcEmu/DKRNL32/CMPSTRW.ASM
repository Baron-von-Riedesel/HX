
;--- implements CompareStringW

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

CompareStringW proc public uses esi edi lcid:dword, flags:dword,
         pString1:ptr WORD, cString1:dword, pString2:ptr WORD, cString2:dword

	mov esi, pString1
	mov edi, pString2
	.if (cString1 == -1)
		invoke lstrlenW, esi
		mov cString1, eax
	.endif
	.if (cString2 == -1)
		invoke lstrlenW, edi
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
		push edx
		.while (ecx)
			lodsw
			mov dx, [edi]
			inc edi
			inc edi
			.if ((ax >= 'a') && (ax <= 'z'))
				sub ax, 'a'
				add ax, 'A'
			.endif
			.if ((dx >= 'a') && (dx <= 'z'))
				sub dx, 'a'
				add dx, 'A'
			.endif
			cmp ax, dx
			.break .if (!ZERO?)
			dec ecx
		.endw
		pop edx
	.else
		repz cmpsw
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
	@strace  <"CompareStringW(", lcid, ", ", flags, ", ", pString1, ", ", cString1, ", ", pString2, ", ", cString2, ")=", eax>
	ret
	align 4

CompareStringW endp

end

