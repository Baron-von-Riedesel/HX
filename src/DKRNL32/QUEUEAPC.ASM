
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

?USETSC	equ 0

USERAPC struct
pNext	dd ?
lpfnAPC	dd ?
dwData	dd ?
USERAPC ends

	.code

QueueUserAPC proc public pfnAPC:DWORD, hThread:DWORD, dwData:DWORD

	xor eax, eax
if 0
	mov ecx, hThread
	.if ([ecx].SYNCOBJECT.dwType == SYNCTYPE_THREAD)
		invoke LocalAlloc, LMEM_FIXED, sizeof USERAPC
		.if (eax)
			mov [eax].USERAPC.pNext,0
			mov ecx, pfnAPC
			mov [eax].USERAPC.lpfnAPC, ecx
			mov ecx, dwData
			mov [eax].USERAPC.lpfnAPC, ecx
			@noints
			mov ecx, hThread
			lea edx, [ecx].THREAD.pAPC
			.while ([edx].USERAPC.pNext)
				mov edx, [edx].USERAPC.pNext
			.endw
			mov [edx].USERAPC.pNext, eax
			@mov eax, 1
			@restoreints
		.endif
	.endif
endif
	@strace <"QueueUserAPC(", pfnAPC, ", ", hThread, ", ", dwData, ")=", eax>
	ret
	align 4

QueueUserAPC endp

	end
