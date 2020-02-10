
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

?MOUSE	equ 1

	.CODE

;--- moves rectangle specified in pRect to dwDestinationOrigin
;--- scrolling in both directions is possible

ScrollConsoleScreenBufferA proc public uses ebx edi esi hConOut:dword,
	pRect:ptr SMALL_RECT, pClipRect:ptr SMALL_RECT, dwDestinationOrigin:COORD,
	pFillCell:ptr CHAR_INFO

local	bytesrow:dword
local	screenptr:dword

if ?MOUSE
		invoke KernelHideMouse
endif
		invoke getscreenptr, hConOut
		mov edi,eax
		mov screenptr,eax
		mov ebx,pRect
		movzx eax,[ebx.SMALL_RECT.Top]
		movzx ecx,word ptr [VIOCOLS]  ;no of columns
		mul ecx
		movzx edx,[ebx.SMALL_RECT.Left]
		add eax,edx
		shl eax,1 			;2 bytes/character
		mov esi,eax
		add esi,edi			;ESI holds source now

		movsx eax,dwDestinationOrigin.Y	;COORD contains signed WORDs!
		imul ecx
		movsx edx,dwDestinationOrigin.X
		add eax,edx
		shl eax,1
		add edi,eax			;EDI holds dest now
		shl ecx,1
		mov bytesrow,ecx
		movzx ecx,[ebx.SMALL_RECT.Bottom]
		movzx eax,[ebx.SMALL_RECT.Top]
		sub ecx,eax
if 0
		jbe error
else
		jb error
		inc ecx
endif

		movzx edx,[ebx.SMALL_RECT.Right]
		movzx eax,[ebx.SMALL_RECT.Left]
		sub edx,eax
if 0
		jbe error
else
		jb error
		inc edx
endif
		mov eax,bytesrow
ife ?FLAT
		push ds
		push es
		push @flat
		pop ds
		push @flat
		pop es
endif
		mov ebx, screenptr
		.if (esi >= edi)
@@:
			.if ((edi >= ebx) && (esi >= ebx))
				pushad
				mov   ecx,edx
				rep   movsw
				popad
			.endif
			add   edi,eax
			add   esi,eax
			loop  @B
		.else
			push eax
			push edx
			dec ecx
			mul ecx
			inc ecx
			add esi, eax
			add edi, eax
			pop edx
			pop eax
@@:
			.if ((edi >= ebx) && (esi >= ebx))
				pushad
				mov ecx,edx
				rep movsw
				popad
			.endif
			sub edi,eax
			sub esi,eax
			loop @B
		.endif

		.if (edi >= ebx)
			mov ecx,pFillCell
			mov al,byte ptr [ecx].CHAR_INFO.Char
			mov ah,byte ptr [ecx].CHAR_INFO.Attributes
			mov ecx,edx
			rep stosw
		.endif
ife ?FLAT
		pop es
		pop ds
endif
		@mov eax,1
		jmp done
error:
		xor eax,eax
done:
if ?MOUSE
		invoke KernelShowMouse
endif
ifdef _DEBUG
		.if (cs:g_dwDebugFlags & DBGF_COUT)
			@strace	<"ScrollConsoleScreenBufferA(", hConOut, ", ", pRect, ", ", pClipRect, ", ", dwDestinationOrigin, ", ", pFillCell, ")">
		.endif
endif
		ret
	align 4

ScrollConsoleScreenBufferA endp

ScrollConsoleScreenBufferW proc public hConOut:dword,
	pRect:ptr SMALL_RECT, pClipRect:ptr SMALL_RECT, dwDestinationOrigin:COORD,
	pFillCell:ptr CHAR_INFO
	
	invoke ScrollConsoleScreenBufferA, hConOut, pRect, pClipRect, dwDestinationOrigin,\
		pFillCell
	ret
	align 4
ScrollConsoleScreenBufferW endp

	end

