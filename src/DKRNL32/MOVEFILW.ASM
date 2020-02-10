
;--- implements MoveFileW and MoveFileExW

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

MoveFileExW proc public pOldName:ptr WORD,pNewName:ptr WORD, dwFlags:dword

	mov eax, pOldName
	call ConvertWStr
	mov pOldName, eax
	mov eax, pNewName
	call ConvertWStr
	invoke MoveFileExA, pOldName, eax, dwFlags
	@strace <"MoveFileExW(", pOldName, ", ", pNewName, ", ", dwFlags, ")=", eax>
	ret
	align 4

MoveFileExW endp

MoveFileW proc public pOldName:ptr WORD,pNewName:ptr WORD

	invoke MoveFileExW, pOldName, pNewName, MOVEFILE_COPY_ALLOWED
	@strace <"MoveFileW(", pOldName, ", ", pNewName, ")=", eax>
	ret
	align 4

MoveFileW endp

	END

