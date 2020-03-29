
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
		include winuser.inc
        include macros.inc

        .CODE

LoadStringA proc public uses esi edi hModule:dword, dwID:dword, pszText:ptr BYTE, iMax:DWORD

		mov eax, dwID
		xor edx, edx
		mov ecx, 16
		div ecx
		inc eax
		mov edi, edx
		invoke FindResourceA, hModule, eax, RT_STRING
		.if (eax)
			invoke LoadResource, hModule, eax
			.if (eax)
				mov esi, eax
				xor eax, eax
				.while (edi)
					lodsw
					add eax, eax
					add esi, eax
					dec edi
				.endw
				lodsw
				mov edi, pszText
				mov ecx, iMax
				dec ecx
				.if (ecx > eax)
					mov ecx, eax
				.endif
				jecxz copydone
@@:
				lodsw
				stosb
				dec ecx
				jnz @B
copydone:
				mov byte ptr [edi], 0
				mov eax, edi
				sub eax, pszText
			.endif
		.endif
		@trace	<"LoadStringA(">
        @tracedw hModule
        @trace	<", ">
        @tracedw dwID
        @trace	<")=">
        @tracedw eax
        @trace	<" [">
        @trace	pszText
        @trace	<"]",13,10>
        ret
        align 4

LoadStringA endp

LoadStringW proc public uses esi edi hModule:dword, dwID:dword, pszText:ptr WORD, iMax:DWORD

		mov eax, dwID
		xor edx, edx
		mov ecx, 16
		div ecx
		inc eax
		mov edi, edx
		invoke FindResourceW, hModule, eax, RT_STRING
		.if (eax)
			invoke LoadResource, hModule, eax
			.if (eax)
				mov esi, eax
				xor eax, eax
				.while (edi)
					lodsw
					add eax, eax
					add esi, eax
					dec edi
				.endw
				lodsw
				mov edi, pszText
				mov ecx, iMax
				dec ecx
				.if (ecx > eax)
					mov ecx, eax
				.endif
				jecxz copydone
@@:
				lodsw
				stosw
				dec ecx
				jnz @B
copydone:
				mov word ptr [edi], 0
				mov eax, edi
				sub eax, pszText
                shr eax, 1
			.endif
		.endif
		@trace	<"LoadStringW(">
        @tracedw hModule
        @trace	<", ">
        @tracedw dwID
        @trace	<")=">
        @tracedw eax
;        @trace	<" [">
;        @trace	pszText
;        @trace	<"]">
        @trace	<13,10>
        ret
        align 4
LoadStringW endp

		end
