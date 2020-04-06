
;--- PE part of HXLdr32.exe
;--- without an cmdline param it displays a message that it hasn't installed
;--- with param -u it tries to deinstall the TSR

	.386
	.model flat, stdcall
	option casemap:none

	include winbase.inc
	include wincon.inc
	include hxldr32.inc

	.code

szKernel32 db "KERNEL32",0
szGetDKrnl32Version db "GetDKrnl32Version",0

szMsg1  db "HXLdr32 version "
		db ?VERSION,13,10
		db "Copyright (C) japheth 2004-2009",13,10
LSIZEMSG1 equ $ - szMsg1

szMsg2  db "The OS knows how to run Win32 applications.",13,10
LSIZEMSG2 equ $ - szMsg2

szMsg3  db "HXLdr32 already installed",13,10
LSIZEMSG3 equ $ - szMsg3

szMsg4  db "usage: HXLdr32 [ options ]",13,10
		db "  -q: be quiet",13,10 
		db "  -u: uninstall",13,10 
LSIZEMSG4 equ $ - szMsg4

szMsg5  db "HXLdr32 not installed or cannot be uninstalled",13,10
LSIZEMSG5 equ $ - szMsg5

szMsg6  db "HXLdr32 has not been installed as a TSR",13,10
LSIZEMSG6 equ $ - szMsg6

szMsg7  db "HXLdr32 uninstalled",13,10
LSIZEMSG7 equ $ - szMsg7

HXLdrDev db 'HXLDR32$'

Uninstall proc hConOut:DWORD

local	dwWritten:DWORD
local	dwAddr:DWORD
local	wPSPSeg:WORD

	mov ah,62h
	int 21h
	mov ax,0006
	int 31h
	push cx
	push dx
	pop edx
	shr edx, 4
	mov wPSPSeg, dx

	mov bl,21h
	mov ax,0200h
	int 31h
	movzx ecx, cx
	shl ecx, 4
	movzx edx, dx
	add edx, ecx
	mov dwAddr, edx
	mov ebx, ecx
	add ecx, 5*2
	mov esi, ecx
	mov edi, offset HXLdrDev
	mov ecx, 8
	repz cmpsb
	jnz error1
	sub ebx, 100h
	cmp word ptr [ebx],20CDh	;must be a PSP
	jnz error2
	sub ebx, 10h
	cmp byte ptr [ebx],'M'
	jz @F
	cmp byte ptr [ebx],'Z'
	jnz error2
@@:
	mov ax,wPSPSeg
	mov [ebx+1], ax

	mov edx, dwAddr
	add edx, ?OLDVECOFS
	mov cx,[edx+2]
	mov dx,[edx+0]
	mov bl,21h
	mov ax,0201h
	int 31h

	invoke WriteConsole, hConOut, offset szMsg7, LSIZEMSG7, addr dwWritten, 0
	ret
error1:
	invoke WriteConsole, hConOut, offset szMsg5, LSIZEMSG5, addr dwWritten, 0
	ret
error2:
	invoke WriteConsole, hConOut, offset szMsg6, LSIZEMSG6, addr dwWritten, 0
	ret
Uninstall endp

main proc

local hConOut:DWORD
local dwDKrnl32:DWORD
local dwWritten:DWORD
local bCmdLineInvalid:BYTE
local bUninstall:BYTE

	invoke GetStdHandle, STD_OUTPUT_HANDLE
	mov hConOut, eax

	mov dwDKrnl32, 0
	invoke GetModuleHandle, offset szKernel32
	.if (eax)
		mov esi, eax
		invoke GetProcAddress, esi, offset szGetDKrnl32Version
		mov dwDKrnl32, eax
		.if (eax)					;running with DKRNL32
			mov bCmdLineInvalid, 0	;means int 21h is available
			mov bUninstall, 0
			mov ah,62h
			int 21h
			mov ds, ebx
			mov esi, 80h
			lodsb
			mov cl,al
			.while (cl)
				lodsb
				.if ((cl > 1) && ((al == '-') || (al == '/')))
					lodsb
					dec cl
					or al,20h
					.if (al == 'u')
						mov bUninstall,1
					.else
						mov bCmdLineInvalid,1
					.endif
				.elseif ((al == ' ') || (al == 9))
				.else
					mov bCmdLineInvalid,1
				.endif
				dec cl
			.endw
			push es
			pop ds
			.if (bCmdLineInvalid)
				invoke WriteConsole, hConOut, offset szMsg4, LSIZEMSG4, addr dwWritten, 0
				jmp exit
			.endif
			.if (bUninstall)
				invoke Uninstall, hConOut
				jmp exit
			.endif
		.endif
	.endif
	invoke WriteConsole, hConOut, offset szMsg1, LSIZEMSG1, addr dwWritten, 0
	.if (dwDKrnl32)
		mov ecx, offset szMsg3
		mov edx, LSIZEMSG3
	.else
		mov ecx, offset szMsg2
		mov edx, LSIZEMSG2
	.endif
	invoke WriteConsole, hConOut, ecx, edx, addr dwWritten, 0
exit:
	invoke ExitProcess, 0

main endp

	end main

