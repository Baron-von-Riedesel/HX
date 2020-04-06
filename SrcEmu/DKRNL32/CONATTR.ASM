
;--- Win32 console functions handling with attributes

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
	include macros.inc
	include dkrnl32.inc

?MOUSE	equ 1

	.CODE

ReadConsoleOutputAttribute proc public uses esi edi hConOut:dword,\
		lpAttr:ptr WORD, nLength:dword, dwReadCoord:COORD, lpRead:ptr DWORD

	invoke getscreenptr, hConOut
	mov esi,eax
	movzx eax,word ptr dwReadCoord+2
	movzx ecx,word ptr [VIOCOLS] ;spalten
	mul ecx
	movzx ecx,word ptr dwReadCoord+0
	add eax,ecx
	shl eax,1
	add esi,eax

	inc esi		;now points to screen attribute

	mov edi,lpAttr
	mov ecx,nLength
	jecxz exit
ife ?FLAT
	push es
	push @flat
	pop es
endif
	mov ah,0
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
	sub eax, lpAttr
	shr eax, 1
	mov [ecx], eax
@@:
	@mov eax,1
	@straceF DBGF_COUT,<"ReadConsoleOutputAttribute(", hConOut, ", ", lpAttr, ", ", nLength, ", ", dwReadCoord, ", ", lpRead, ")=", eax>
	ret
	align 4

ReadConsoleOutputAttribute endp

WriteConsoleOutputAttribute proc public uses esi edi hConOut:dword,\
		lpAttr:ptr WORD, nLength:dword, dwWriteCoord:COORD, lpWritten:ptr DWORD

if ?MOUSE
	invoke KernelHideMouse
endif
	invoke getscreenptr, hConOut
	mov edi,eax
	movzx eax,word ptr dwWriteCoord+2
	movzx ecx,word ptr [VIOCOLS] ;spalten
	mul ecx
	movzx ecx,word ptr dwWriteCoord+0
	add eax,ecx
	shl eax,1
	add edi,eax

	inc edi				;now points to screen attribute

	mov esi,lpAttr
	mov ecx,nLength
	jecxz exit
ife ?FLAT
	push es
	push @flat
	pop es
endif
@@:
	lodsw
	stosb
	inc edi
	loop @B
ife ?FLAT
	pop es
endif
exit:
if ?MOUSE
	invoke KernelShowMouse
endif
	mov ecx, lpWritten
	jecxz @F
	mov eax, esi
	sub eax, lpAttr
	shr eax, 1
	mov [ecx], eax
@@:
	@mov eax,1
	@straceF DBGF_COUT,<"WriteConsoleOutputAttribute(", hConOut, ", ", lpAttr, ", ", nLength, ", ", dwWriteCoord, ", ", lpWritten, ")=", eax>
	ret
	align 4

WriteConsoleOutputAttribute endp

	end
