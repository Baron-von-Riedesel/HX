
;--- implements SetConsoleMode, GetConsoleMode

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
	include macros.inc
	include dkrnl32.inc

?CHECKSTDINP	equ 1

extern	__DEFCTRLHANDLER:ABS	;make sure ctrl-break handler is included

	.DATA

;--- most console flags are still global, valid for all handles
;--- only ENABLE_PROCESSED_xxxPUT is a handle attribute

	.CODE

SetConsoleMode proc public handle:dword,flags:dword

	mov ecx, handle
if ?NONULLHDL
	cmp ecx, 10000h
	jnz @F
	movzx ecx, cx
@@:
endif
	cmp ecx, 100h
	jnc nofile
if ?CHECKSTDINP
	push ebx
	mov ebx, ecx
	mov ax,4400h
	int 21h
	jc nostdinp
	and dl,81h				;device + stdinp?
	cmp dl,81h
	jnz nostdinp
	mov eax,flags
	mov g_consoleflags,eax
nostdinp:
	pop ebx
	mov eax,flags
else
	mov eax,flags
	mov g_consoleflags,eax
endif
	.if (al & ENABLE_PROCESSED_INPUT)
		bts g_bProcessed, ecx
	.else
		btr g_bProcessed, ecx
	.endif
nofile:
if ?FLAT
InitMouse proto
DeinitMouse proto
	.if (al & ENABLE_MOUSE_INPUT)
		invoke InitMouse
	.else
		invoke DeinitMouse
	.endif
endif
	@mov eax,1
	@strace <"SetConsoleMode(", handle, ", ", flags, ")=", eax>
	ret
	align 4
SetConsoleMode endp

GetConsoleMode proc public handle:dword,pMode:ptr dword

	mov eax,g_consoleflags
	and al,not ENABLE_PROCESSED_INPUT
	mov edx, handle
if ?NONULLHDL
	cmp edx, 10000h
	jnz @F
	movzx edx, dx
@@:
endif
	cmp edx,100h
	jnc @F
	bt g_bProcessed, edx
	jnc @F
	or al, ENABLE_PROCESSED_INPUT
@@:
	mov ecx,pMode
	mov [ecx],eax
	@strace <"GetConsoleMode(", handle, ", ", pMode, ")=1 [", eax, "]">
	@mov eax,1
	ret
	align 4
GetConsoleMode endp

	END

