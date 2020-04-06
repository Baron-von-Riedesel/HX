
;--- implements:
;--- CreateConsoleScreenBuffer
;--- SetConsoleActiveScreenBuffer

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

CreateConsoleScreenBuffer proc public dwDesiredAccess:dword, dwShareMode:DWORD, lpSA:DWORD, dwFlags:DWORD, lpScreenBufferData:ptr

	invoke KernelHeapAlloc, sizeof SCREENBUF
	.if (eax)
		mov [eax].SCREENBUF.dwType,TYPE_SCREENBUF
		mov ecx, dwDesiredAccess
		mov [eax].SCREENBUF.dwAccess,ecx
		mov ecx, dwShareMode
		mov [eax].SCREENBUF.dwShareMode,ecx
;		 mov [eax].SCREENBUF.dwFlags, 0
;		 mov [eax].SCREENBUF.pMem, 0
		mov [eax].SCREENBUF.cci.dwSize, 10
		mov [eax].SCREENBUF.cci.bVisible, TRUE
if 1
		mov cl, [VIOROWS]
		mov ch,00
		inc ecx
		shl ecx,16
		mov cx, [VIOCOLS]
else
		mov ecx, 00190050h
endif
		mov [eax].SCREENBUF.dwSize, ecx
	.else
		dec eax		;return INVALID_HANDLE_VALUE on error
	.endif
	@strace <"CreateConsoleScreenBuffer(", dwDesiredAccess, ", ", dwShareMode, ", ", lpSA, ", ", dwFlags, ", ", lpScreenBufferData, ")=", eax>
	ret
	align 4

CreateConsoleScreenBuffer endp

_UpdateScreenBuf proto

DisableCurrentScreenBuffer proc

	pushad
	mov  ebx, g_dwActiveScreenBuffer
	invoke getscreenptr, ebx
	mov  esi, eax
	invoke _UpdateScreenBuf
	invoke GetConsoleCursorInfo, 0, addr [ebx].SCREENBUF.cci
	and [ebx].SCREENBUF.dwFlags, not SBF_ISACTIVE
	invoke getscreenptr, ebx
	mov  edi, eax
	movzx ecx, [ebx].SCREENBUF.dwSize.X
	movzx eax, [ebx].SCREENBUF.dwSize.Y
	mul ecx
	mov ecx, eax
	shr ecx, 1
ife ?FLAT
	push ds
	push @flat
	pop  ds
endif
	rep movsd
ife ?FLAT
	pop ds
endif
	popad
	ret
	align 4

DisableCurrentScreenBuffer endp

EnableScreenBuffer proc pBuffer:dword        

	pushad
	mov ebx, pBuffer
	or [ebx].SCREENBUF.dwFlags, SBF_ISACTIVE
	mov g_dwActiveScreenBuffer, ebx
	mov esi, [ebx].SCREENBUF.pMem
	and esi, esi
	jz nobuffer
	invoke getscreenptr, ebx
	mov edi, eax
ife ?FLAT
	push es
	push @flat
	pop es
endif
	movzx eax, [ebx].SCREENBUF.dwSize.X
	movzx edx, [ebx].SCREENBUF.dwSize.Y
	mul edx
	movzx ecx, word ptr [VIOPAGESIZ]
	shr ecx, 1
	cmp ecx, eax
	jc @F
	mov ecx, eax
@@:
	shr ecx, 1
	rep movsd
ife ?FLAT
	pop es
endif
nobuffer:
	invoke SetConsoleCursorPosition, pBuffer, [ebx].SCREENBUF.dwCursorPos
	invoke SetConsoleCursorInfo, pBuffer, addr [ebx].SCREENBUF.cci
	popad
	ret
	align 4

EnableScreenBuffer endp

SetConsoleActiveScreenBuffer proc public handle:DWORD

	mov eax, handle
	invoke _GetScreenBuffer
	cmp [eax].SCREENBUF.dwType, TYPE_SCREENBUF
	jnz error
	test [eax].SCREENBUF.dwFlags, SBF_ISACTIVE
	jnz exit
	invoke DisableCurrentScreenBuffer
	invoke EnableScreenBuffer, eax
exit:
	@mov eax,1
	@strace <"SetConsoleActiveScreenBuffer(", handle, ")=", eax>
	ret
error:
	xor eax, eax
	jmp exit
	align 4

SetConsoleActiveScreenBuffer endp

	end

