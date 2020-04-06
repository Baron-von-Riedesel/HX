
;--- implements GetModuleHandleW()

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

GetModuleHandleW proc public pName:ptr WORD
	mov eax, pName
	.if (eax)
		call ConvertWStr
	.endif
	invoke GetModuleHandleA, eax
	@strace <"GetModuleHandleW(",pName, ")=", eax>
	ret
	align 4
GetModuleHandleW endp

	end

