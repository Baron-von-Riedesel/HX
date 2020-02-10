
;--- implements CopyFileW

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

CopyFileW proc public lpExistingFileName:ptr WORD, lpNewFileName:ptr WORD, bFailIfExists:DWORD

	mov eax, lpExistingFileName
	call ConvertWStr
	mov lpExistingFileName, eax
	mov eax, lpNewFileName
	call ConvertWStr
	invoke CopyFileA, lpExistingFileName, eax, bFailIfExists
	@strace	<"CopyFileW(", lpExistingFileName, ", ", lpNewFileName, ", ",  bFailIfExists, ")=", eax>
	ret
	align 4

CopyFileW endp

END

