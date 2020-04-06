
;--- implements GetModuleFileNameW()

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

GetModuleFileNameW proc public handle:dword,pBuffer:ptr word,lBuffer:dword

	invoke GetModuleFileNameA, handle, pBuffer, lBuffer
	.if (eax)
		invoke ConvertAStr, pBuffer
	.endif
	@strace <"GetModuleFileNameW(", handle, ", ", pBuffer, ", ", lBuffer, ")=", eax>
	ret
	align 4

GetModuleFileNameW endp

	end

