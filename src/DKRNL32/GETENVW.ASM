
;--- implements GetEnvironmentVariableW()

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

GetEnvironmentVariableW proc public key:ptr WORD,buffer:ptr WORD,maxsize:dword

	mov eax, key
	invoke ConvertWStr
	invoke GetEnvironmentVariableA, eax, buffer, maxsize
	.if (eax)
		invoke ConvertAStr, buffer
	.endif
	@strace <"GetEnvironmentVariableW(", key, ", ", buffer, ", ", maxsize, ")=", eax>
	ret
	align 4
GetEnvironmentVariableW endp

	end
