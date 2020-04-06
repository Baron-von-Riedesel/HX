
;--- implements WriteConsoleA()

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

	.CODE

WriteConsoleA proc public hConOut:dword, lpBuffer:ptr BYTE, nNumberOfCharsToWrite:dword, lpWritten:ptr dword, lpReserved:dword

;--- the handle may be a console screen buffer
;--- which WriteFile cannot handle!

	mov ecx, hConOut
	.if (ecx >= 1000h)
		invoke _WriteConsole, ecx, lpBuffer, nNumberOfCharsToWrite, lpWritten
	.else
;		bt g_bIsConsole, ecx
;		jnc @F
		invoke WriteFile, ecx, lpBuffer, nNumberOfCharsToWrite, lpWritten, lpReserved
@@:
	.endif
	@strace <"WriteConsoleA(", hConOut, ", ", lpBuffer, ", ", nNumberOfCharsToWrite, ", ", lpWritten, ", ", lpReserved, ")=", eax>
	ret
	align 4

WriteConsoleA endp

	end

