
;--- implements:
;--- ExpandEnvironmentStringsA

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


PUSHADS struct
rEdi    dd ?
rEsi    dd ?
rEbp    dd ?
        dd ?
rEbx    dd ?
rEdx    dd ?
rEcx    dd ?
rEax    dd ?
PUSHADS ends

	.CODE

ExpandEnvironmentStringsA proc public uses esi edi lpSrc:ptr BYTE, lpDest:ptr BYTE, nSize:DWORD

local	dwEsp:dword
local	szVar[64]:byte

	mov dwEsp, esp
	mov eax, nSize
	add eax, 3
	and al, not 3
	sub esp, eax

	mov ecx, nSize
	mov edi, esp
	mov esi, lpSrc
	add ecx, edi
	.while (1)
		lodsb
		.break .if (!al)
		.if (al == '%')
			pushad
			lea edi, szVar
			mov ecx, sizeof szVar
			.while (ecx)
				lodsb
				.break .if ((al == '%') || (al == 0))
				stosb
				dec ecx
			.endw
			.if (ecx && (al == '%'))
				mov al,0
				stosb
				mov ecx, [esp].PUSHADS.rEcx
				mov edi, [esp].PUSHADS.rEdi
				sub ecx, edi
				jnc @F
				xor ecx, ecx
@@:
				push ecx
				invoke GetEnvironmentVariable, addr szVar, edi, ecx
				pop ecx
				.if (eax)
					.if (eax > ecx)	;if buffer is too small, the
						dec eax		;return value includes a term. 0
					.endif
					mov [esp].PUSHADS.rEsi, esi
					add [esp].PUSHADS.rEdi, eax
					mov [esp].PUSHADS.rEax, 0
				.endif
			.endif
			popad
			.continue .if (!eax)
		.endif
		.if (edi < ecx)
			mov [edi],al
		.endif
		inc edi
	.endw
	.if (edi < ecx)
		mov byte ptr [edi],0
	.endif
	inc edi
	sub edi, esp
	.if (edi <= nSize)
		invoke lstrcpy, lpDest, esp
	.endif
	mov esp, dwEsp
	mov eax, edi
	@strace  <"ExpandEnvironmentStringsA(", lpSrc, ", ", lpDest, ", ", nSize, ")=", eax>
	ret
	align 4

ExpandEnvironmentStringsA endp

end

