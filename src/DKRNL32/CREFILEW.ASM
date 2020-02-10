
;--- implements CreateFileW()

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
	include dkrnl32.inc

	.CODE

CreateFileW proc public fname:dword, access:dword, sharemode:dword,
						 pSecurity:dword, fCreation:dword, attributes:dword, handle:dword

	mov eax,fname
	call ConvertWStr
	invoke CreateFileA, eax, access, sharemode, pSecurity, fCreation, attributes, handle
	@strace <"CreateFileW(", fname, ", ", access, ", ", sharemode, ", ", pSecurity, ", ", fCreation, ", ", attributes, ", ", handle, ")=", eax>
	ret
	align 4

CreateFileW endp

	end

