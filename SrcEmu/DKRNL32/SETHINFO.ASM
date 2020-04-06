
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc

	.CODE

SetHandleInformation proc public hObject:dword, hMask:dword, hFlags:dword

	xor eax, eax
	@strace <"SetHandleInformation(", hObject, ", ", hMask, ", ", hFlags, ")=", eax, " *** unsupp ***">
	ret

SetHandleInformation endp

	end
