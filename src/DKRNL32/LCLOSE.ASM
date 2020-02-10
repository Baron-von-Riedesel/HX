
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc

	.CODE

_lclose proc public handle:dword

	invoke CloseHandle,handle
	cmp eax, 1
	sbb eax, eax
	ret
_lclose endp

	end

