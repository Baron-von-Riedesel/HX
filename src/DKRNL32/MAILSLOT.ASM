
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none
	option dotname

	include winbase.inc
	include dkrnl32.inc
	include macros.inc


	.CODE

CreateMailslotA proc public lpName:ptr BYTE, nMaxMsgSize:DWORD, lReadTimeout:DWORD, lpSecAttr:DWORD

	xor eax, eax
	@strace <"CreateMailslotA(", lpName, ", ", nMaxMsgSize, ", ", lReadTimeout, ", ", lpSecAttr, ")=", eax, " *** unsupp ***">
	ret
	align 4

CreateMailslotA endp

GetMailslotInfo proc public hMailslot:DWORD, lpMaxMsgSize:ptr DWORD, lpNextSize:ptr DWORD, lpMsgCount:ptr DWORD, lpReadTimeout:ptr DWORD

	xor eax, eax
	@strace <"GetMailslotInfo(", hMailslot, ", ", lpMaxMsgSize, ", ", lpNextSize, ", ", lpMsgCount, ", ", lpReadTimeout, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetMailslotInfo endp

SetMailslotInfo proc public hMailslot:DWORD, lReadTimeout:DWORD

	xor eax, eax
	@strace <"SetMailslotInfo(", hMailslot, ", ", lReadTimeout, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetMailslotInfo endp

	end
