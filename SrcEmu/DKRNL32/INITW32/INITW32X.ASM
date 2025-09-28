
;--- this initializes the statically linked Win32 DKRNL32.
;--- needed if HDLD32.BIN is used as stub for a DOS-PE.
;--- assumes DPMILD32 is used as loader.

	.386
	.MODEL FLAT, stdcall
	option casemap:none

IKF_DPMILDR  equ 1	; PE loader API is present
IKF_CALLTERM equ 2	; exit kernel when a int 21h, ah=4Ch is found

	public g_hInstance

	.DATA?

g_hInstance dd ?

	.CODE

__kernel32init proto
externdef g_bIntFl:byte
externdef c mainCRTStartup:near

start proc c
	or [g_bIntFl],IKF_DPMILDR or IKF_CALLTERM
	xor edx,edx
	mov ax,4B82h		;get module handle into EAX, stack into EDX,
	int 21h				;start of module list in ECX
	mov g_hInstance, eax
	call __kernel32init	;call DKRNL32 initialization
	jmp mainCRTStartup	;jump to the application's entry
start endp

	end start

