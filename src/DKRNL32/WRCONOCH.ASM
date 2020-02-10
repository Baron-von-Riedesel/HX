
;--- implements:
;--- WriteConsoleOutputCharacterA
;--- WriteConsoleOutputCharacterW
;--- ReadConsoleOutputCharacterA
;--- ReadConsoleOutputCharacterW

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

?MOUSE		equ 1
?SETATTR	equ 0	;1=set text attribute in WriteConsoleOutputCharacter()

	.CODE

WriteConsoleOutputCharacterA proc public uses edi esi hConOut:dword,
		lpBuffer:ptr BYTE, lstring:dword, coord:COORD, lpWritten:ptr dword

if ?MOUSE
	invoke KernelHideMouse
endif
	invoke getscreenptr, hConOut
	mov edi,eax
	movzx eax,word ptr coord+2
	movzx ecx,[ecx].SCREENBUF.dwSize.X
	mul ecx
	movzx ecx,word ptr coord+0
	add eax,ecx
	shl eax,1
	add edi,eax

	mov esi,lpBuffer
	mov ecx,lstring
	jecxz exit
ife ?FLAT
	push es
	push @flat
	pop es
endif
ife ?SETATTR
@@:
	lodsb
	stosb
	inc edi
else
	mov ah, byte ptr g_wAttributes
@@:
	lodsb
	stosw
endif
	loop @B
ife ?FLAT
	pop es
endif
exit:
	mov ecx, lpWritten
	jecxz @F
	mov eax, esi
	sub eax, lpBuffer
	mov [ecx], eax
@@:
	@mov eax,1
if ?MOUSE
	invoke KernelShowMouse
endif
	@straceF DBGF_COUT,<"WriteConsoleOutputCharacterA(", hConOut, ", ", lpBuffer, ", ", lstring, ", ", coord, ", ", lpWritten, ")=", eax>
	ret
	align 4

WriteConsoleOutputCharacterA endp

WriteConsoleOutputCharacterW proc public hConOut:dword,
		lpBuffer:ptr WORD, lstring:dword, coord:COORD, lpWritten:ptr dword

	mov eax, lpBuffer
	mov ecx, lstring
	call ConvertWStrN
	invoke WriteConsoleOutputCharacterA, hConOut, eax, lstring, coord, lpWritten
	@straceF DBGF_COUT,<"WriteConsoleOutputCharacterW(", hConOut, ", ", lpBuffer, ", ", lstring, ", ", coord, ", ", lpWritten, ")=", eax>
	ret
	align 4
WriteConsoleOutputCharacterW endp

ReadConsoleOutputCharacterA proc public uses edi esi hConOut:dword,
		lpBuffer:ptr BYTE, lstring:dword, coord:COORD, lpRead:ptr dword

	invoke getscreenptr, hConOut
	mov esi,eax
	movzx eax,word ptr coord+2
	movzx ecx,[ecx].SCREENBUF.dwSize.X
	mul ecx
	movzx ecx,word ptr coord+0
	add eax,ecx
	shl eax,1
	add esi,eax

	mov edi,lpBuffer
	mov ecx,lstring
	jecxz exit
ife ?FLAT
	push es
	push @flat
	pop es
endif
@@:
	lodsb
	stosb
	inc esi
	loop @B
ife ?FLAT
	pop es
endif
exit:
	mov ecx, lpRead
	jecxz @F
	mov eax, edi
	sub eax, lpBuffer
	mov [ecx], eax
@@:
	@mov eax,1
	@straceF DBGF_COUT,<"ReadConsoleOutputCharacterA(", hConOut, ", ", lpBuffer, ", ", lstring, ", ", coord, ", ", lpRead, ")=", eax>
	ret
	align 4

ReadConsoleOutputCharacterA endp

ReadConsoleOutputCharacterW proc public uses edi esi hConOut:dword,
		lpBuffer:ptr WORD, lstring:dword, coord:COORD, lpRead:ptr dword

	invoke getscreenptr, hConOut
	mov esi,eax
	movzx eax,word ptr coord+2
	movzx ecx,[ecx].SCREENBUF.dwSize.X
	mul ecx
	movzx ecx,word ptr coord+0
	add eax,ecx
	shl eax,1
	add esi,eax

	mov edi,lpBuffer
	mov ecx,lstring
	jecxz exit
ife ?FLAT
	push es
	push @flat
	pop es
endif
@@:
	lodsb
	stosw
	inc esi
	loop @B
ife ?FLAT
	pop es
endif
exit:
	mov ecx, lpRead
	jecxz @F
	mov eax, edi
	sub eax, lpBuffer
	shr eax,1
	mov [ecx], eax
@@:
	@mov eax,1
	@straceF DBGF_COUT,<"ReadConsoleOutputCharacterW(", hConOut, ", ", lpBuffer, ", ", lstring, ", ", coord, ", ", lpRead, ")=", eax>
	ret
	align 4

ReadConsoleOutputCharacterW endp

	end

