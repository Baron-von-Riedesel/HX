
;--- implements:
;--- WriteConsoleOutputA
;--- ReadConsoleOutputA

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

;--- [in] lpBuffer: source buffer, ptr to CHAR_INFO items
;--- [in] dwBufferSize: size (X and Y) of source buffer (=lpBuffer)
;--- [in] dwBufferCoord: upper left cell of source buffer to write data from
;--- [in/out] lpWriteRegion: destination rectangle in screen buffer

;--- only the intersect of src and screen buffer is written

WriteConsoleOutputA proc public uses edi esi ebx hConOut:dword,
		lpBuffer:ptr CHAR_INFO, dwBufferSize:COORD, dwBufferCoord:COORD,
		lpWriteRegion:ptr SMALL_RECT

local	offs:dword
local	dwCols:DWORD

if ?MOUSE
	invoke KernelHideMouse
endif
	invoke getscreenptr, hConOut	;gets SCREENBUF in ecx
	mov edi, eax
	mov ebx, ecx
	mov esi,lpWriteRegion
	movzx ecx,[esi].SMALL_RECT.Left
	movzx edx,[esi].SMALL_RECT.Top
	movzx eax,[ebx].SCREENBUF.dwSize.X
	mul edx
	add eax,ecx
	shl eax,1
	add edi,eax					;edi=upper left corner in lpWriteRegion

	mov esi, lpBuffer
	movzx eax, dwBufferCoord.Y
	cmp ax, dwBufferSize.Y
	jnc done
	movzx ecx, dwBufferSize.X
	mul ecx
	movzx ecx, dwBufferCoord.X
	cmp cx, dwBufferSize.X
	jnc done
	add eax, ecx
	shl eax, 2					;size of CHAR_INFO
	add esi, eax				;esi = upper left corner in lpBuffer

;--- get X-size of screen rectangle
	mov edx, lpWriteRegion
	mov cx, [edx].SMALL_RECT.Right
	sub cx, [edx].SMALL_RECT.Left
	jc done
	movzx ecx,cx
	inc ecx
	cmp cx, dwBufferSize.X      ;use X-size of src or screen, whatever is smaller
	jc @F
	mov cx, dwBufferSize.X
@@:
	mov dwCols, ecx

	movzx eax, [ebx].SCREENBUF.dwSize.X
	movzx ebx, dwBufferSize.X
	sub ebx, ecx
	shl ebx, 2					;* sizeof CHAR_INFO
	sub eax, ecx
	shl eax, 1
	mov offs, eax

;--- get Y-size of screen rectangle
	mov cx, [edx].SMALL_RECT.Bottom
	sub cx, [edx].SMALL_RECT.Top
	jc done
;	movzx ecx,cx
	inc ecx
	cmp cx, dwBufferSize.Y      ;use Y-size of src or screen, whatever is smaller
	jc @F
	mov cx, dwBufferSize.Y
@@:

ife ?FLAT
	push es
	push @flat
	pop es
endif
nextrow:
	push ecx
	mov ecx, dwCols
nextcell:
	mov al,byte ptr [esi].CHAR_INFO.Char
	mov ah,byte ptr [esi].CHAR_INFO.Attributes
	stosw
	add esi,sizeof CHAR_INFO
	loop nextcell
	pop ecx
	add edi,offs
	add esi,ebx
	loop nextrow
ife ?FLAT
	pop es
endif
done:
	@mov eax,1
if ?MOUSE
	invoke KernelShowMouse
endif
ifdef _DEBUG
	mov ecx, lpWriteRegion
endif
	@straceF DBGF_COUT, <"WriteConsoleOutputA(", hConOut, ", ", lpBuffer, ", ", dwBufferSize, ", ", dwBufferCoord, ", ", lpWriteRegion, " [", dword ptr [ecx].SMALL_RECT.Left, " ", dword ptr [ecx].SMALL_RECT.Right, "])=", eax>
	ret
	align 4

WriteConsoleOutputA endp

ReadConsoleOutputA proc public uses edi esi ebx hConOut:dword,
		pBuffer:ptr CHAR_INFO, dwBufferSize:COORD, dwBufferCoord:COORD,
		lpReadRegion:ptr SMALL_RECT

local	offs:dword
local	dwCols:DWORD

	invoke getscreenptr, hConOut
	mov esi,eax
	mov ebx,ecx
	mov edi,lpReadRegion
	movzx ecx,[edi].SMALL_RECT.Left
	movzx edx,[edi].SMALL_RECT.Top

	movzx eax,[ebx].SCREENBUF.dwSize.X
	mul edx
	add eax,ecx
	shl eax,1					;*2
	add esi,eax

	mov edi, pBuffer
	movzx eax, dwBufferCoord.Y
	movzx ecx, dwBufferSize.X
	mul ecx
	movzx ecx, dwBufferCoord.X
	add eax, ecx
	shl eax, 2					;size of CHAR_INFO
	add edi, eax

	mov edx, lpReadRegion
	mov cx, [edx].SMALL_RECT.Right
	sub cx, [edx].SMALL_RECT.Left
	jc done
	movzx ecx,cx
	inc ecx
	mov dwCols, ecx

	movzx eax, [ebx].SCREENBUF.dwSize.X
	movzx ebx, dwBufferSize.X
	sub ebx, ecx
	shl ebx, 2					;* sizeof CHAR_INFO
	sub eax, ecx
	shl eax, 1					;* sizeof screen cells
	mov offs, eax

	mov cx, [edx].SMALL_RECT.Bottom
	sub cx, [edx].SMALL_RECT.Top
	jc done
;	movzx ecx,cx
	inc ecx
ife ?FLAT
	push ds
	push @flat
	pop ds
endif
	xor eax,eax 	;clear bits 24-31
nextrow:
	push ecx
	mov ecx, dwCols
nextcell:
	mov al,[esi+1]		;attribute
	shl eax,16
	mov al,[esi+0]		;character
	stosd				;save a CHAR_INFO
	add esi,2
	loop nextcell
	pop ecx
	add esi,offs
	add edi, ebx
	loop nextrow
ife ?FLAT
	pop ds
endif
done:
	@mov eax,1
	@straceF DBGF_COUT,<"ReadConsoleOutputA(", hConOut, ", ", pBuffer, ", ", dwBufferSize, ", ", dwBufferCoord, ", ", lpReadRegion, ")=", eax>
	ret
	align 4

ReadConsoleOutputA endp

	end

