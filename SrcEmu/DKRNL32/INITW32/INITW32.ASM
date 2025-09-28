
;--- this initializes the statically linked Win32 DKRNL32.
;--- needed if LOADPE[X].BIN is used as stub for a DOS-PE.

	.386
	.MODEL FLAT, stdcall
	option casemap:none

	include winbase.inc
	include ..\dkrnl32.inc

	public g_hInstance

	.data?

g_hInstance dd ?	;referenced by some modules in DUSER32

	.CODE

;extern ___kernel32init@0:near
;extern _g_bIntFl:byte
externdef c mainCRTStartup:near

start proc c
	or [g_bIntFl],IKF_CALLTERM
	mov  eax,esi			;get the module's base address
	mov g_hInstance, eax
	call __kernel32init		;call DKRNL32 initialization
	jmp mainCRTStartup		;jump to the application's entry
start endp

	end start

