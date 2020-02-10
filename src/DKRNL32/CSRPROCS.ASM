
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

?USEI10 equ 0	;1=use int 10h, 0=program CRT directly

	.CODE

;*** set cursor position ***
;--- to get cursor pos, use GetConsoleScreenBufferInfo

SetConsoleCursorPosition proc public uses ebx handle:dword, pos:COORD

	mov eax, handle
	invoke _GetScreenBuffer
	test byte ptr [eax].SCREENBUF.dwFlags, SBF_ISACTIVE
	jnz @F
	mov edx, pos
	mov [eax].SCREENBUF.dwCursorPos, edx
	jmp done
@@:
if ?USEI10
	mov dl,byte ptr pos+0
	mov dh,byte ptr pos+2
	mov bh,[VIOPAGE]
	mov ah,02
	int 10h
else
	movzx ebx,byte ptr [VIOPAGE]
	mov dx,[VIOCRTPORT]
	mov ah,byte ptr pos+2			;Y
	mov al,byte ptr pos+0			;X
	movzx ecx,al
	mov [ebx*2+VIOCSRPOS],ax
	mov al,byte ptr [VIOCOLS]	;this is a WORD variable
	mul ah
	add eax,ecx
	mov cx,[VIOPAGEOFS]
	shr cx,1
	add eax,ecx
	mov cl,al

	mov al,0Eh
	out dx,ax
	inc al
	mov ah,cl
	out dx,ax
endif
done:
	@straceF DBGF_COUT, <"SetConsoleCursorPosition(", handle, ", ", pos, ")=", eax>
	ret
	align 4

SetConsoleCursorPosition endp

;*** set size, position and visibility of text mode cursor shape

SetConsoleCursorInfo proc public uses ebx handle:dword, pCINFO:ptr CONSOLE_CURSOR_INFO

local	dwPos:COORD

	mov eax, handle
	invoke _GetScreenBuffer
	mov ecx,pCINFO
	mov edx, [ecx].CONSOLE_CURSOR_INFO.bVisible
	test byte ptr [eax].SCREENBUF.dwFlags, SBF_ISACTIVE
	jnz @F
	mov [eax].SCREENBUF.cci.bVisible, edx
	mov edx, [ecx].CONSOLE_CURSOR_INFO.dwSize
	mov [eax].SCREENBUF.cci.dwSize, edx
	jmp done
@@:
	and edx,edx
	jz scci_1

	movzx ebx,byte ptr [VIOPAGE]
if ?USEI10
	mov dx,[ebx*2+VIOCSRPOS]
	mov ah,02
	int 10h
else
	movzx ecx,byte ptr [ebx*2+VIOCSRPOS+1]
	shl ecx,16
	mov cl,byte ptr [ebx*2+VIOCSRPOS+0] ;set current cursor pos
	mov dwPos, ecx
	invoke SetConsoleCursorPosition, handle, dwPos
endif
	movzx eax,byte ptr [VIOCHARSIZE]	 ;char height (16,8,...)
	dec eax
	mov ecx,pCINFO
	mov ecx,[ecx].CONSOLE_CURSOR_INFO.dwSize	;0 < ecx <= 100!
	jecxz error
	cmp ecx,100
	ja error
	mul ecx
	mov ecx,100
	div ecx
	mov ch,[VIOCHARSIZE]
	dec ch
	mov cl,ch
	sub ch,al
if ?USEI10
	mov ah,01
	mov al,[VIOMODE]	;bug in some bioses
	int 10h
else
	mov [VIOCSRSHAPE],cx
	mov dx,[VIOCRTPORT]
	mov ah,ch
	mov al,0Ah
	out dx,ax
	mov ah,cl
	mov al,0Bh
	out dx,ax
endif
	jmp done
error:
	xor eax,eax
	jmp exit

scci_1:  	;set cursor off
if ?USEI10
	mov cx,[VIOCSRSHAPE]
	and ch,9fh
	or ch,20h				;bit 5+6=01 -> cursor off
	mov ah,01
	mov al,[VIOMODE]	;bug in some bioses
	int 10h
else
	mov dx, [VIOCRTPORT]
	mov ah, byte ptr [VIOCSRSHAPE+1]
	and ah, 9Fh
	or ah, 20h
	mov byte ptr [VIOCSRSHAPE+1], ah
	mov al, 0Ah
	out dx, ax
endif
done:
exit:
ifdef _DEBUG
	mov ecx, pCINFO
	@straceF DBGF_COUT, <"SetConsoleCursorInfo(", handle, ", ", ecx, " [", [ecx].CONSOLE_CURSOR_INFO.dwSize, ", ", [ecx].CONSOLE_CURSOR_INFO.bVisible, "])=", eax>
endif
	ret
	align 4

SetConsoleCursorInfo endp

;*** get text mode cursor shape attributes

GetConsoleCursorInfo proc public handle:dword, pCINFO:ptr CONSOLE_CURSOR_INFO

	mov eax, handle
	invoke _GetScreenBuffer
	test byte ptr [eax].SCREENBUF.dwFlags, SBF_ISACTIVE
	jnz @F
	mov edx, [eax].SCREENBUF.cci.bVisible
	mov eax, [eax].SCREENBUF.cci.dwSize
	jmp setvalue
@@:
	mov dx, [VIOCRTPORT]

;	invoke EnterSerialization
	mov al,0Ah	;start line
	out dx,al
	inc dx
	in al,dx
	dec dx
	mov ah,al

	mov al,0Bh
	out dx,al
	inc dx
	in al,dx
	dec dx
;	invoke LeaveSerialization

	xor edx, edx
	test ah,20h
	setz dl

	and ax,1F1Fh

	sub al,ah
	jnc @F
	mov al,0
@@:
	inc al
	mov cl,100
	mul cl
	mov cl,[VIOCHARSIZE]
	div cl
	movzx eax,al

setvalue:
	mov ecx,pCINFO
	mov [ecx].CONSOLE_CURSOR_INFO.dwSize, eax
	mov [ecx].CONSOLE_CURSOR_INFO.bVisible, edx

	@mov eax, 1
ifdef _DEBUG
	mov ecx, pCINFO
	@straceF DBGF_COUT,<"GetConsoleCursorInfo(", handle, ", ", ecx, " [", [ecx].CONSOLE_CURSOR_INFO.dwSize, ", ", [ecx].CONSOLE_CURSOR_INFO.bVisible, "])=", eax>
endif
	ret
	align 4

GetConsoleCursorInfo endp

	end
