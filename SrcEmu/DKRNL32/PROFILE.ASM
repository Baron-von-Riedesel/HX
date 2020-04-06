
;--- implements
;--- GetProfileIntA
;--- GetProfileStringA
;--- WriteProfileStringA

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.CODE

GetProfileIntA proc public lpAppName:ptr byte, lpKeyName:ptr byte, nDefault:DWORD

	xor eax, eax
	@strace <"GetProfileIntA(", &lpAppName, ", ", &lpKeyName, ", ", nDefault, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetProfileIntA endp

GetProfileStringA proc public lpAppName:ptr byte, lpKeyName:ptr byte, lpDefault:ptr byte, lpBuffer:ptr byte, cbBuffer:DWORD

	xor eax, eax
	@strace <"GetProfileStringA(", &lpAppName, ", ", &lpKeyName, ", ", lpDefault, ", ", lpBuffer, ", ", cbBuffer, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetProfileStringA endp

WriteProfileStringA proc public lpAppName:ptr byte, lpKeyName:ptr byte, lpString:ptr byte

	xor eax, eax
	@strace <"WriteProfileStringA(", &lpAppName, ", ", lpKeyName, ", ", lpString, ")=", eax, " *** unsupp ***">
	ret
	align 4

WriteProfileStringA endp

	end

