
;--- implements directory support (wide)
;--- CreateDirectoryW
;--- CreateDirectoryExW
;--- RemoveDirectoryW

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

CreateDirectoryW proc public pName:ptr WORD,pSecurity:dword
	mov eax, pName
	call ConvertWStr
	invoke CreateDirectoryA, eax, pSecurity
	@strace <"CreateDirectoryW(", pName, ", ", pSecurity, ")=", eax>
	ret
	align 4
CreateDirectoryW endp

CreateDirectoryExW proc public uses ebx lpTemplate:ptr WORD, lpNewDir:ptr WORD, lpSecurity:ptr
	mov eax, lpTemplate
	call ConvertWStr
	mov ebx, eax
	mov eax, lpNewDir
	call ConvertWStr
	invoke CreateDirectoryExA, ebx, eax, lpSecurity
	@strace <"CreateDirectoryExW(", lpTemplate, ", ", lpNewDir, ", ", lpSecurity, ")=", eax>
	ret
	align 4
CreateDirectoryExW endp

RemoveDirectoryW proc public pName:ptr WORD
	mov eax, pName
	call ConvertWStr
	invoke RemoveDirectoryA, eax
	@strace <"RemoveDirectoryW(", pName, ")=", eax>
	ret
	align 4
RemoveDirectoryW endp

	end

