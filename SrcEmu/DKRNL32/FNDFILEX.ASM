
if ?FLAT

;*** implements
;--- FindFirstFileExA()
;--- FindFirstFileExW()

	.386
	.MODEL FLAT, stdcall
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

FINDEX_INFO_LEVELS typedef DWORD
FindExInfoStandard equ 0
FindExInfoBasic    equ 1
FindExInfoMaxInfoLevel equ 2

FINDEX_SEARCH_OPS typedef DWORD
FindExSearchNameMatch          equ 0
FindExSearchLimitToDirectories equ 1
FindExSearchLimitToDevices     equ 2
FindExSearchMaxSearchOp        equ 3

;--- dwAdditionalFlags
FIND_FIRST_EX_CASE_SENSITIVE       equ 1
FIND_FIRST_EX_LARGE_FETCH          equ 2
FIND_FIRST_EX_ON_DISK_ENTRIES_ONLY equ 4

	.CODE

FindFirstFileExA proc public uses esi edi ebx lpFileName:ptr BYTE,fInfoLevelId:FINDEX_INFO_LEVELS,lpFindFileData:LPVOID,fSearchOp:FINDEX_SEARCH_OPS,lpSearchFilter:LPVOID,dwAdditionalFlags:DWORD

	@strace <"FindFirstFileExA(", lpFileName, ",", fInfoLevelId , ",", fSearchOp, ",", dwAdditionalFlags, ") enter">
	cmp lpSearchFilter, 0
	jnz error
	invoke FindFirstFileA, lpFileName, lpFindFileData
	ret
error:
	invoke SetLastError, ERROR_INVALID_FUNCTION
	mov eax,INVALID_HANDLE_VALUE
	ret
	align 4

FindFirstFileExA endp

FindFirstFileExW proc public uses esi edi ebx lpFileName:ptr WORD,fInfoLevelId:FINDEX_INFO_LEVELS,lpFindFileData:LPVOID,fSearchOp:FINDEX_SEARCH_OPS,lpSearchFilter:LPVOID,dwAdditionalFlags:DWORD

	@strace <"FindFirstFileExW(", lpFileName, ",", fInfoLevelId , ",", fSearchOp, ",", dwAdditionalFlags, ") enter">
	cmp lpSearchFilter, 0
	jnz error
	invoke FindFirstFileW, lpFileName, lpFindFileData
	ret
error:
	invoke SetLastError, ERROR_INVALID_FUNCTION
	mov eax,INVALID_HANDLE_VALUE
	ret
	align 4

FindFirstFileExW endp

endif

	END
