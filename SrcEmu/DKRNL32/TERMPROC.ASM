
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

;--- 0 = failure

OpenProcess proc public accflgs:dword,inhflg:dword,procid:dword

	invoke GetCurrentProcessId
	.if (eax == procid)
		invoke GetCurrentProcess
	.else
		xor eax,eax
	.endif
	@strace <"OpenProcess(", accflgs, ", ", inhflg, ", ", procid, ")=", eax>
	ret
	align 4

OpenProcess endp

;--- 0 = failure

TerminateProcess proc public hProcess:dword, dwExitcode:dword

	invoke GetCurrentProcess
	.if (eax == hProcess)
		invoke ExitProcess, dwExitcode
	.else
		xor eax,eax
	.endif
	@strace <"TerminateProcess(", hProcess, ", ", dwExitcode, ")=", eax>
	ret
	align 4
TerminateProcess endp

GetPriorityClass proc public hProcess:dword

	mov ecx, hProcess
	xor eax, eax
	.if (ecx && ([ecx].PROCESS.dwType == SYNCTYPE_PROCESS))
		mov    eax, NORMAL_PRIORITY_CLASS
	.endif
	@strace <"GetPriorityClass(", hProcess, ")=", eax>
	ret
	align 4
GetPriorityClass endp

;--- 1 = ok, 0 = failure

SetPriorityClass proc public hProcess:dword, dwClass:dword

	mov ecx, hProcess
	xor eax,eax
	.if (ecx && ([ecx].PROCESS.dwType == SYNCTYPE_PROCESS))
		inc eax
	.endif
	@strace <"SetPriorityClass(", hProcess, ", ", dwClass, ")=", eax>
	ret
	align 4
SetPriorityClass endp

	end
