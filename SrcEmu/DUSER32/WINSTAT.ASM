
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include wincon.inc
	include macros.inc

	.CODE

GetThreadDesktop proc public dwThreadId:dword

	xor eax, eax
	@strace <"GetThreadDesktop(", dwThreadId, ")=", eax>
	ret
	align 4

GetThreadDesktop endp

GetProcessWindowStation proc public

	xor eax, eax
	@strace <"GetProcessWindowStation()=", eax>
	ret
	align 4

GetProcessWindowStation endp

GetUserObjectInformationW proc public handle:dword, nIndex:dword, pvInfo:ptr, nLength:dword, lpnLengthNeeded:ptr DWORD

	xor eax, eax
	@strace <"GetUserObjectInformationW(", handle, ", ", nIndex, ", ", pvInfo, ", ", nLength, ", ", lpnLengthNeeded, ")=", eax>
	ret
	align 4

GetUserObjectInformationW endp

end
