
;--- private sprintf version with limited features
;--- understands %s, %X, %u and %% only
;--- used by EXCEPT.ASM

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	.nolist
	include winbase.inc
	include dkrnl32.inc
	include macros.inc
	.list

	.CODE

_sprintf proc c public pBuffer:ptr byte, pFormat:ptr byte, parms:VARARG

	pushad
	mov edi,pBuffer
	mov esi,pFormat
	lea ebx,parms
	.while (1)
		lodsb
		.break .if (!al)
		.if (al == '%')
			lodsb
			.if (al == 'X')
				mov eax, [ebx]
				add ebx, 4
				invoke __dw2a
				.continue
			.elseif (al == 'u')
				mov eax, [ebx]
				add ebx, 4
				invoke __dw2aD
				.continue
			.elseif (al == 's')
				push esi
				mov esi, [ebx]
				add ebx, 4
				.while (byte ptr [esi])
					movsb
				.endw
				pop esi
				.continue
			.endif
		.endif
		stosb
	.endw
	mov al,0
	stosb
	popad
	ret

_sprintf endp

	end
