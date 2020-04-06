
;--- implements:
;--- GetFileAttributesW
;--- GetFileAttributesExW
;--- SetFileAttributesW

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

GetFileAttributesW proc public pName:dword
	mov eax,pName
	invoke ConvertWStr
	invoke GetFileAttributesA, eax
	@strace <"GetFileAttributesW(", pName, ")=", eax>
	ret
	align 4
GetFileAttributesW endp

GetFileAttributesExW proc public pName:ptr WORD, fInfoLevelId:DWORD, lpFileInformation:ptr WIN32_FILE_ATTRIBUTE_DATA
	mov eax,pName
	invoke ConvertWStr
	invoke GetFileAttributesExA, eax, fInfoLevelId, lpFileInformation
	@strace <"GetFileAttributesExW(", pName, ", ", fInfoLevelId, ", ", lpFileInformation, ")=", eax>
	ret
	align 4
GetFileAttributesExW endp

SetFileAttributesW proc public pName:dword,attribs:dword
	mov eax,pName
	call ConvertWStr
	invoke SetFileAttributesA, eax, attribs
	@strace <"SetFileAttributesW(", pName, ", ", attribs, ")=", eax>
	ret
	align 4
SetFileAttributesW endp

	end
