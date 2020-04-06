
	.586
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.code

FlushInstructionCache proc public hProcess:DWORD, lpBaseAddress:ptr, dwSize:DWORD

	@mov eax, 1
	ret

FlushInstructionCache endp

	end
