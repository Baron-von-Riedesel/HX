
;--- implements DeleteFileW()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

DeleteFileW proc public pwszName:ptr WORD
	mov eax,pwszName
	call ConvertWStr
	invoke DeleteFileA, eax
	@strace <"DeleteFileW(", pwszName, ")=", eax>
	ret
	align 4
DeleteFileW endp

	end

