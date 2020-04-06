
;--- implements FatalAppExitA

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include wincon.inc
	include macros.inc

	.CODE

Display_szString proc public uses ebx pString:ptr BYTE

local	dwWritten:DWORD

;	invoke GetStdHandle,STD_OUTPUT_HANDLE
	invoke GetStdHandle, STD_ERROR_HANDLE
	mov ebx,eax
	invoke SetConsoleMode, ebx, ENABLE_PROCESSED_OUTPUT
	invoke lstrlen, pString
	lea ecx, dwWritten
	invoke WriteConsoleA, ebx, pString, eax, ecx, 0
;	test byte ptr g_dwDebugFlags, DBGF_FLUSH
;	jz @F
	invoke FlushFileBuffers, ebx
;@@:
	ret
	align 4

Display_szString endp

FatalAppExitA proc public dwAction:dword, pString:ptr BYTE

	@strace <"FatalAppExit(", dwAction, ", ", pString, ")">
	invoke Display_szString, pString
	invoke ExitProcess,-1
	ret
	align 4

FatalAppExitA endp

end
