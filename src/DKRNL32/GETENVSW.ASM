
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

GetEnvironmentStringsW proc public

	invoke GetEnvironmentStringsA
	.if (eax)
		pushad
		mov edi, eax
		mov esi, eax
		mov ecx, -1
		.while (byte ptr [edi])
			mov al,0
			repnz scasb
		.endw
		inc edi
		mov eax, edi
		sub eax, esi
		push eax
		add eax, eax
		invoke LocalAlloc, LMEM_FIXED, eax
		pop ecx
		mov [esp+1Ch],eax	;save in EAX of PUSHAD structure
		.if (eax)
			push esi
			mov edi, eax
			mov ah,0
			.while (ecx)
				lodsb
				stosw
				dec ecx
			.endw
			pop esi
		.endif
		invoke FreeEnvironmentStringsA, esi
		popad
	.endif
	@strace <"GetEnvironmentStringsW()=", eax>
	ret
	align 4

GetEnvironmentStringsW endp

FreeEnvironmentStringsW proc public pStrings:dword

	invoke LocalFree, pStrings
	@strace <"FreeEnvironmentStringsW(", pStrings, ")=", eax>
	ret
	align 4
FreeEnvironmentStringsW endp

ExpandEnvironmentStringsW proc public lpSrc:ptr WORD, lpDest:ptr WORD, nSize:DWORD

	mov eax,lpSrc
	invoke ConvertWStr
	mov ecx, nSize
	shl ecx, 1
	sub esp, ecx
	mov ecx, esp
	invoke ExpandEnvironmentStringsA, eax, ecx, nSize
	.if (eax)
		mov ecx, esp
		invoke ConvertAStrN, ecx, lpDest, nSize
	.endif
	mov ecx, nSize
	shl ecx, 1
	add esp, ecx
	@strace <"ExpandEnvironmentStringsW(", lpSrc, ", ", lpDest, ", ", nSize, ")=", eax>
	ret
	align 4

ExpandEnvironmentStringsW endp

	end

