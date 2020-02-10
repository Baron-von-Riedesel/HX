
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

	.DATA

g_dwActiveScreenBuffer dd offset g_sb

;--- screen buffer object for standard console output		 

externdef g_sb:SCREENBUF

	dd 0	;offset this-4 for destructor
g_sb SCREENBUF <TYPE_SCREENBUF, SBF_ISACTIVE, 0,\
		GENERIC_READ or GENERIC_WRITE,\
		FILE_SHARE_READ or FILE_SHARE_WRITE,\
		FOREGROUND_WHITE or BACKGROUND_BLACK>

	.CODE

_GetScreenBuffer proc public
	.if (eax < 1000h)
		mov eax, offset g_sb
	.endif
	ret
	align 4
_GetScreenBuffer endp

;--- helper proc for console functions.
;--- in: a console output handle
;--- out: EAX=screen memory pointer
;---      ECX=ptr SCREENBUF
;---      EDX=NULL if screen is active (non-Flat only)

getscreenptr proc public hConOut:DWORD

	mov eax, hConOut
	call _GetScreenBuffer
	mov ecx, eax
	test [ecx].SCREENBUF.dwFlags, SBF_ISACTIVE
	jnz isstandard
	mov eax, [ecx].SCREENBUF.pMem
ife ?FLAT
	or edx,-1
endif
	and eax, eax
	jnz exit
	push ecx
	invoke GetLargestConsoleWindowSize, ecx
	movzx ecx,ax
	shr eax,16	;rows
	mul ecx
	push eax 	;save cells
	shl eax,2
	invoke LocalAlloc, LMEM_FIXED, eax
	pop edx					;get cells
	pop ecx
	and eax, eax
	.if (!ZERO?)
		mov [ecx].SCREENBUF.pMem, eax
		mov dword ptr [ecx-4], offset destructor
		push edi
		push eax
		mov edi, eax
		mov ah, byte ptr [ecx].SCREENBUF.dwAttributes
		mov al,' '
		push ecx
		mov ecx, edx
		rep stosw
		pop ecx
		pop eax
		pop edi
ife ?FLAT
		or edx,-1
endif
		jmp exit
	.endif
isstandard:

;--- 2013/04: added 
	mov dx, [VIOCOLS]
	mov [ecx].SCREENBUF.dwSize.X, dx

	movzx eax,word ptr [VIOPAGEOFS] ;start page
	mov edx,0B8000H
	cmp byte ptr [VIOCRTPORT],0D4h
	jz @F
	mov edx,0B0000H
@@:
	add eax,edx
ife ?FLAT
	xor edx,edx
endif
exit:
	ret
	align 4

getscreenptr endp

;--- get active screen attribute

_SetDefaultAttribute proc public

	movzx edx, word ptr [VIOCOLS]
	movzx eax, byte ptr [VIOROWS]
	inc eax
	mul edx
	movzx ecx,word ptr [VIOPAGEOFS] ;start page
	mov edx,0B8000H
	cmp byte ptr [VIOCRTPORT],0D4h
	jz @F
	mov edx,0B0000H
@@:
	add ecx,edx
	mov al,@flat:[ecx+eax*2-1]
	and al,al
	jz @F
	mov byte ptr g_sb.dwAttributes, al
@@:
	ret
	align 4

_SetDefaultAttribute endp

;--- is called by CloseHandle

destructor proc pThis:dword

	@strace <"destructor console screen buffer(", pThis, ")">
	mov ecx, pThis
	xor edx, edx
	xchg edx, [ecx].SCREENBUF.pMem
	invoke LocalFree, edx
	@mov eax,1
	ret
	align 4

destructor endp

	end
