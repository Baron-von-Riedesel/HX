
;--- implements:
;--- CreateMutexW
;--- OpenMutexW

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

CreateMutexW proc public security:dword, bInitialOwner:dword, lpName:ptr WORD

	mov eax,lpName
	.if (eax)
		call ConvertWStr
	.endif
	invoke CreateMutexA, security, bInitialOwner, eax
	@strace <"CreateMutexW()=", eax>
	ret
	align 4
CreateMutexW endp

OpenMutexW proc public dwDesiredAccess:dword, bInheritHandle:dword, lpName:ptr WORD

	mov eax, lpName
	call ConvertWStr
	invoke OpenMutexA, dwDesiredAccess, bInheritHandle, eax
	@strace <"OpenMutexW(", dwDesiredAccess, ", ", bInheritHandle, ", ", lpName, ")=", eax>
	ret
	align 4

OpenMutexW endp

	end

