
;--- implements _WriteConsole()
;--- this function is used by:
;--- + WriteConsoleA() if handle is a console screen buffer
;--- + WriteFileA() if file handle is a console
;--- unlike WriteConsoleOutputCharacterA this function updates the
;--- cursor pos and handles CR/LF/TAB/BELL/BACKSPACE

;--- may not work if current mode is graphics and text attribute has
;--- been set!

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

?SETATTR	equ 1	;1=set text attribute

	.CODE

_UpdateScreenBuf proto

_WriteConsole proc public uses esi edi ebx hConOut:ptr SCREENBUF, lpBuffer:ptr BYTE, nNumberOfCharsToWrite:dword, lpWritten:ptr dword

local	hScrnptr:DWORD
local	dwEndOfScreen:DWORD
local	bProcessed:BYTE
local	bInt29:BYTE
ife ?FLAT
local	bNonActive:DWORD
endif

	mov esi, lpBuffer
	mov eax, hConOut
	invoke _GetScreenBuffer
	mov ebx, eax
	invoke _UpdateScreenBuf

	mov al,1
	mov ecx, hConOut
	.if (ecx < 1000h)
		bt g_bProcessed, ecx
		setc al
	.endif
	mov bProcessed, al
	mov bInt29, 0
	.if (al)
		.if ([ebx].SCREENBUF.dwFlags & SBF_ISACTIVE)
			.if ([ebx].SCREENBUF.dwFlags & SBF_ATTRSET)
				mov dx, 3ceh
				mov al, 6
				out dx, al
				inc dx
				in al, dx
				test al, 1
				jz noint29
			.endif
			mov bInt29, 1
		.endif
	.endif
noint29:

;--- this code is executed if
;--- 1. the output is *not* processed OR
;--- 2. the screen buffer is inactice OR
;--- 3. the text attribute has been set and no graphics mode active

	.if (!bInt29)
		invoke getscreenptr, hConOut
		mov hScrnptr, eax
ife ?FLAT
		mov bNonActive, edx
endif
		@straceF DBGF_COUT, <"_WriteConsole, screenptr=", eax>
		mov edi, eax

		movzx eax,[ebx].SCREENBUF.dwCursorPos.Y
		movzx ecx,[ebx].SCREENBUF.dwSize.X
		mul ecx
		movzx ecx,[ebx].SCREENBUF.dwCursorPos.X
		add eax,ecx
		shl eax,1
		add edi,eax

		movzx eax, [ebx].SCREENBUF.dwSize.Y
		movzx ecx, [ebx].SCREENBUF.dwSize.X
		mul ecx
		shl eax, 1
		add eax, hScrnptr
		mov dwEndOfScreen, eax
	.endif

	movzx edx, [ebx].SCREENBUF.dwCursorPos.X
	mov ecx, nNumberOfCharsToWrite
	.while (ecx)
		push ecx
		lodsb
		.if (bProcessed)
			call processed_out
		.else
			call charout
		.endif
		pop ecx
		dec ecx
	.endw

	.if (!bInt29)
		mov [ebx].SCREENBUF.dwCursorPos.X, dx
		.if ([ebx].SCREENBUF.dwFlags & SBF_ISACTIVE)
			invoke SetConsoleCursorPosition, hConOut, [ebx].SCREENBUF.dwCursorPos
		.endif
	.endif
	mov ecx, lpWritten
	sub esi, lpBuffer
	mov [ecx], esi
	@mov eax, 1
	ret

	align 4

int29:
	push edx
	int 29h
	pop edx
	retn

processed_out:
	cmp al,10		;lf?
	jz islf
	cmp al,13		;cr?
	jz iscr
	cmp al,9		;tab?
	jz istab
	cmp al,7		;bell?
	jz isbell
	cmp al,8		;bs?
	jz isbs
charout:
	.if (bInt29)
		call int29
	.else
		.while (edi >= dwEndOfScreen)
			call scrollbuffer
		.endw
ife ?FLAT
		push es
		cmp bNonActive,0
		jnz @F
		push @flat
		pop es
@@:
endif
if ?SETATTR
		mov ah, byte ptr [ebx].SCREENBUF.dwAttributes
		stosw
else
		stosb
		inc edi
endif
ife ?FLAT
		pop es
endif
	.endif
	inc edx
	cmp dx, [ebx].SCREENBUF.dwSize.X
	jb @F
	inc [ebx].SCREENBUF.dwCursorPos.Y
	xor edx, edx
@@:
	retn
istab:
@@:
	mov al,' '
	call charout
	test dl,7
	jnz @B
	retn
iscr:
	.if (bInt29)
		call int29
	.else
		shl edx, 1
		sub edi, edx
	.endif
	xor edx, edx
	retn
islf:
	mov al,13
	call iscr
	.if (bInt29)
		mov al,10
		call int29
	.else
		movzx eax, [ebx].SCREENBUF.dwSize.X
		shl eax, 1
		add edi, eax
		inc [ebx].SCREENBUF.dwCursorPos.Y
		cmp edi, dwEndOfScreen
		jb @F
		call scrollbuffer
@@:
	.endif
	retn
isbs:
	.if (bInt29)
		call int29
	.endif
	and edx, edx
	jnz dobs_1
	cmp [ebx].SCREENBUF.dwCursorPos.Y, dx
	jz skipbs
	dec [ebx].SCREENBUF.dwCursorPos.Y
	movzx edx, [ebx].SCREENBUF.dwSize.X
dobs_1:
	dec edx
	dec edi
	dec edi
skipbs:
	retn
isbell:
	call int29
	retn
	align 4

scrollbuffer:
	pushad
	mov edi, hScrnptr
	movzx ecx, [ebx].SCREENBUF.dwSize.X
	lea esi, [edi+ecx*2]
	movzx eax, [ebx].SCREENBUF.dwSize.Y
	dec eax
	mul ecx
	mov ecx, eax
	shr ecx, 1
ife ?FLAT
	push es
	push ds
	cmp bNonActive,0
	jnz @F
	push @flat
	pop ds
	push ds
	pop es
@@:
endif
	rep movsd
	movzx ecx, [ebx].SCREENBUF.dwSize.X
if 0
	mov ah, FOREGROUND_WHITE or BACKGROUND_BLACK
else
	mov ah, es:[edi+ecx*2-1]
endif
	mov al, ' '
	rep stosw
ife ?FLAT
	pop ds
	pop es
endif
	dec [ebx].SCREENBUF.dwCursorPos.Y
	movzx eax, [ebx].SCREENBUF.dwSize.X
	shl eax, 1
	sub [esp+0], eax	;this is rEDI
	popad
	retn
	align 4

_WriteConsole endp

	end

