
;--- implements:
;--- WriteConsoleOutputW
;--- ReadConsoleOutputW

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
?BOXDRAWING	equ 1	;1=convert box drawing

	.CODE

;--- [in] lpBuffer: source buffer, ptr to CHAR_INFO items
;--- [in] dwBufferSize: size (X and Y) of source buffer
;--- [in] dwBufferCoord: upper left cell of source buffer to write data from
;--- [in/out] lpWriteRegion: destination rectangle in screen buffer

;--- the difference between A and W is just the "Char" field in CHAR_INFO
;--- so there is no need to convert it.

WriteConsoleOutputW proc public hConOut:dword,
		lpBuffer:ptr CHAR_INFO, dwBufferSize:COORD, dwBufferCoord:COORD,
		lpWriteRegion:ptr SMALL_RECT

if ?BOXDRAWING

local	offs:dword
local	dwCols:DWORD

	push esi
	push edi
	push ebx
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
	lodsd
	mov dl,al
	shr eax,8
if ?BOXDRAWING
	cmp al,21h	;arrow drawing?
	jz arrowdraw
	cmp al,25h	;box drawing?
	jz boxdraw
boxcont:
endif
	mov al,dl
	stosw
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

	pop ebx
	pop edi
	pop esi
else
	invoke WriteConsoleOutputA, hConOut, lpBuffer, dwBufferSize, dwBufferCoord, lpWriteRegion
endif
	@straceF DBGF_COUT, <"WriteConsoleOutputW(", hConOut, ", ", lpBuffer, ", ", dwBufferSize, ", ", dwBufferCoord, ", ", lpWriteRegion, " [", dword ptr [ecx].SMALL_RECT.Left, " ", dword ptr [ecx].SMALL_RECT.Right, "])=", eax>
	ret
if ?BOXDRAWING
arrowdraw:
	mov dh,''
	cmp dl,091h		;csr up
	jz @F
	mov dh,''
	cmp dl,093h		;csr down
	jz @F
	jmp boxcont
@@:
	mov dl,dh
	jmp boxcont
boxdraw:
	cmp dl,0D0h
	jnc boxcont
	movzx edx,dl
	cmp byte ptr [edx+boxchars],0
	jz boxcont
	mov dl,byte ptr [edx+boxchars]
	jmp boxcont
endif
	align 4

WriteConsoleOutputW endp

if ?BOXDRAWING
boxchars label byte
;--------- 0   1 2
		db 'Ä',0,'³',0,0,0,0,0,  0,0,0,0,'Ú',0,0,0 ;00-0F
		db '¿',0,0,0,'À',0,0,0,'Ù',0,0,0,'Ã',0,0,0 ;10-1F
		db 0,  0,0,0,'´',0,0,0,  0,0,0,0,'Â',0,0,0 ;20-2F
		db 0,  0,0,0,'Á',0,0,0,  0,0,0,0,'Å',0,0,0 ;30-3F
		db 0,  0,0,0, 0,0,0,0,0,0,0,0,     0,0,0,0 ;40-4F
		db 'Í','º',0,0,'É',0,0,'»',0,0,'È',0,'¼',0,0,0   ;50-5F
		db 'Ì',0,0,'¹',0,0,'Ë',0,0,'Ê',0,0,0,0,0,0 ;60-6F
		db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0         ;70-7F
		db 'ß',0,0,0,'Ü',0,0,0,'Û',0,0,0,'Ý',0,0,0 ;80-8F
		db 'Þ','°','±','²',0,0,0,0,0,0,0,0,0,0,0,0 ;90-9F
		db 'þ',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0       ;A0-AF
		db 0,0,'',0,0,0,'',0,0,0,'',0,'',0,0,0 ;B0-BF
		db '',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0       ;C0-CF
endif

ReadConsoleOutputW proc public hConOut:dword,
		pBuffer:ptr CHAR_INFO, dwBufferSize:COORD, dwBufferCoord:COORD,
		lpReadRegion:ptr SMALL_RECT

	invoke ReadConsoleOutputA, hConOut, pBuffer, dwBufferSize, dwBufferCoord, lpReadRegion
	@straceF DBGF_COUT,<"ReadConsoleOutputW(", hConOut, ", ", pBuffer, ", ", dwBufferSize, ", ", dwBufferCoord, ", ", lpReadRegion, ")=", eax>
	ret
	align 4

ReadConsoleOutputW endp

	end

