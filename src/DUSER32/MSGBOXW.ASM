
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include macros.inc
	include duser32.inc

	.code

MessageBoxW proc public hWnd:dword, pszStr:dword, pStr2:dword, flags:dword

	mov eax, pszStr
	and eax, eax
	jz @F
	call ConvertWStr
	mov pszStr, eax
@@:
	mov eax, pStr2
	and eax, eax
	jz @F
	call ConvertWStr
	mov pStr2, eax
@@:
	invoke MessageBoxA, hWnd, pszStr, pStr2, flags
	@strace <"MessageBoxW(", hWnd, ", ", pszStr, ", ", pStr2, ", ", flags, ")=", eax>
	ret
	align 4

MessageBoxW endp

	end
