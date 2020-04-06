
	.386
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

	.CODE

GetVDMCurrentDirectories proc public p1:dword, p2:dword

	xor eax, eax
	@strace <"GetVDMCurrentDirectories(", p1, ", ", p2, ")=", eax>
	ret
	align 4

GetVDMCurrentDirectories endp

CmdBatNotification proc public p1:dword

	xor eax, eax
	@strace <"CmdBatNotification(", p1, ")=", eax>
	ret
	align 4

CmdBatNotification endp

	end

