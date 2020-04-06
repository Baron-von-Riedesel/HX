
;--- the DKRNL32 "main" file

	.386
	.MODEL FLAT, stdcall
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc
	include version.inc

	.CONST

versionstring textequ @CatStr(!",%?VERMAJOR,.,%?VERMINOR,.,%?VERMINOR2,!")

copyright db "dkrnl32.dll V",versionstring," (c) 1996-2012 japheth",0

	.CODE

@dummy macro suffix
_dummy&suffix proc public
_dummy&suffix endp
?EXPORT = ?EXPORT+1
	endm

?EXPORT = 10
	repeat 40
		@dummy %?EXPORT
	endm
	int 3
	ret
	align 4

GetDKrnl32Version proc public
	mov eax, ?VERMAJOR + ?VERMINOR * 100h + ?VERMINOR2 * 10000h
	ret
	align 4
GetDKrnl32Version endp

;--- to make borland powerpack apps happy

Borland32 proc public
	ret
	align 4
Borland32 endp

DllMain proc stdcall hModule:dword,reason:dword,reserved:dword

	mov eax, reason
	.if (eax == DLL_PROCESS_ATTACH)

ifdef _DEBUG            
		@strace <"-----------------------------------------">
		@strace <"kernel32 DllMain(", hModule, ", ", reason, ", ", reserved, ") enter">
endif
		or [g_bIntFl],IKF_PELDR
		xor edx,edx
		mov ax,4B82h	;get module handle into EAX, stack into EDX,
		int 21h			;start of module list in ECX
		call __kernel32init

		invoke DisableThreadLibraryCalls, hModule

		@strace <"kernel32 process attach end">
		mov eax, 1

	.elseif (eax == DLL_PROCESS_DETACH)

		call __kernel32exit

	.endif
	ret
	align 4
DllMain endp

	END DllMain

