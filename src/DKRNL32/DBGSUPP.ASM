
;--- implements:
;--- IsDebuggerPresent
;--- WaitForDebugEvent
;--- ContinueDebugEvent
;--- DebugActiveProcess
;--- GetThreadSelectorEntry

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.CODE

IsDebuggerPresent proc public

	mov ax, 004Fh
	int 41h
	cmp ax,0F386h
	@mov eax,0
	jnz @F
	inc eax
@@:
;	@strace <"IsDebuggerPresent()=", eax>	;don't log this call!
	ret
	align 4

IsDebuggerPresent endp

WaitForDebugEvent proc public lpDebugEvent:ptr, dwMilliseconds:DWORD

	xor eax, eax
	@strace <"WaitForDebugEvent(", lpDebugEvent, ", ", dwMilliseconds, ")=", eax>
	ret
	align 4

WaitForDebugEvent endp

ContinueDebugEvent proc public dwProcessId:DWORD, dwThreadId:DWORD, dwContinueStatus:DWORD 

	xor eax, eax
	@strace <"ContinueDebugEvent(", dwProcessId, ", ", dwThreadId, ", ", dwContinueStatus, ")=", eax>
	ret
	align 4

ContinueDebugEvent endp

DebugActiveProcess proc public hProcess:DWORD

	xor eax, eax
	@strace <"DebugActiveProcess(", hProcess, ")=", eax>
	ret
	align 4

DebugActiveProcess endp

;--- return a LDT descriptor

GetThreadSelectorEntry proc public uses ebx edi hThread:DWORD, dwSelector:DWORD, lpSelectorEntry:ptr LDT_ENTRY

	mov ebx, dwSelector
	mov edi, lpSelectorEntry
	mov ax, 000Bh
	int 31h
	@mov eax,1
	sbb eax,0
	@strace <"GetThreadSelectorEntry(", hThread, ", ", dwSelector, ", ", lpSelectorEntry, ")=", eax>
	ret
	align 4

GetThreadSelectorEntry endp

	end

