
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

;g_wAttributes dw FOREGROUND_WHITE or BACKGROUND_BLACK

	.CODE

;--- dont modify edx here!
;--- inp: EBX=screen buffer

_UpdateScreenBuf proc public
	.if ([ebx].SCREENBUF.dwFlags & SBF_ISACTIVE)
		movzx eax,byte ptr [VIOPAGE]
		mov ax, word ptr [eax*2+VIOCSRPOS]
		mov cl,al
		shl eax,8
		movzx ax,cl
		mov [ebx].SCREENBUF.dwCursorPos, eax
		mov al, [VIOROWS]
		mov ah,00
		inc eax
		shl eax,16
		mov ax, [VIOCOLS]
		mov [ebx].SCREENBUF.dwSize, eax
	.endif
	ret
	align 4
_UpdateScreenBuf endp

GetConsoleScreenBufferInfo proc public uses ebx hConsole:dword, pSBInfo:ptr CONSOLE_SCREEN_BUFFER_INFO

	mov edx,pSBInfo
	mov eax, hConsole
	call _GetScreenBuffer
	mov ebx, eax
	invoke _UpdateScreenBuf
	mov eax, [ebx].SCREENBUF.dwSize
	mov ecx, [ebx].SCREENBUF.dwAttributes
	mov [edx].CONSOLE_SCREEN_BUFFER_INFO.dwSize,eax
	mov [edx].CONSOLE_SCREEN_BUFFER_INFO.dwMaximumWindowSize,eax
	mov [edx].CONSOLE_SCREEN_BUFFER_INFO.wAttributes,cx
	mov dword ptr [edx].CONSOLE_SCREEN_BUFFER_INFO.srWindow.Left,0
	sub eax,10001h
	mov dword ptr [edx].CONSOLE_SCREEN_BUFFER_INFO.srWindow.Right,eax
	mov eax, [ebx].SCREENBUF.dwCursorPos
	mov [edx].CONSOLE_SCREEN_BUFFER_INFO.dwCursorPosition,eax
	@mov eax,1
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & DBGF_COUT)
		@strace	<"GetConsoleScreenBufferInfo(", hConsole, ", ", pSBInfo, ")=", eax>
	.endif
endif
	ret
	align 4
GetConsoleScreenBufferInfo endp

SetConsoleTextAttribute proc public hConsole:DWORD, wAttribute:dword

	mov eax, hConsole
	call _GetScreenBuffer
	mov ecx,wAttribute
	mov [eax].SCREENBUF.dwAttributes, ecx
	or [eax].SCREENBUF.dwFlags, SBF_ATTRSET
	@mov eax,1
	@strace <"SetConsoleTextAttribute(", hConsole, ", ", wAttribute, ")=", eax>
	ret
	align 4

SetConsoleTextAttribute endp

	end

