
;--- this initializes the statically linked Win32 DKRNL32.
;--- needed if LOADPE[X].BIN is used as stub for a DOS-PE.

;--- Open Watcom needs a special version, because it
;--- defines mainCRTStartup without an '_'-prefix.

	.386
	.MODEL FLAT
	option casemap:none

IKF_CALLTERM	equ 2	;call terminators in int 21h, ah=4Ch handler

	.CODE

__kernel32init proto stdcall
externdef stdcall g_bIntFl:byte
externdef mainCRTStartup:near

start proc c
	or [g_bIntFl],IKF_CALLTERM
	mov  eax,esi		;get the module's base address
	call __kernel32init	;call DKRNL32 initialization
	jmp mainCRTStartup	;jump to the application's entry
start endp

	end start

