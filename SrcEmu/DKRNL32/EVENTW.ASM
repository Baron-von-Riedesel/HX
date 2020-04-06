
;--- WIDE events functions implementation

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

	.CODE

CreateEventW proc public security:dword, bManualReset:dword, bInitialState:dword, lpName:ptr WORD

	mov eax, lpName
	.if (eax)
		call ConvertWStr
	.endif
	invoke CreateEventA, security, bManualReset, bInitialState, eax
	@strace <"CreateEventW(", security, ", ", bManualReset, ", ", bInitialState, ", ", lpName, ")=", eax>
	ret
	align 4

CreateEventW endp

OpenEventW proc public dwDesiredAccess:DWORD, bInheritHandle:DWORD, lpName:ptr WORD

	mov eax, lpName
	call ConvertWStr
	invoke OpenEventA, dwDesiredAccess, bInheritHandle, eax
	@strace <"OpenEventW(", dwDesiredAccess, ", ", bInheritHandle, ", ", lpName, ")=", eax>
	ret
	align 4

OpenEventW endp

	end

