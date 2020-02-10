
;--- simple thread functions
;--- this is to avoid the linker to link the whole thread code
;--- just because a function like GetExitCodeThread() is used
;--- Functions implemented here:
;--- GetExitCodeThread, GetCurrentThreadId
;--- GetThreadPriority, SetThreadPriority
;--- GetThreadContext, SetThreadContext

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP group _TEXT
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dpmi.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

;--- Win32 API GetCurrentThreadId

GetCurrentThreadId proc public
	invoke _GetCurrentThread	;always return a valid thread handle here
	ret
	align 4
GetCurrentThreadId endp

;--- Win32 API GetExitCodeThread

GetExitCodeThread proc public hThread:dword, pExitcode:ptr dword
	mov ecx,hThread
	xor eax, eax
	.if ([ecx].THREAD.dwType == SYNCTYPE_THREAD)
		mov edx, pExitcode
		mov eax,[ecx].THREAD.dwExitCode
		mov [edx],eax
		@mov eax,1
	.endif
	@strace <"GetExitCodeThread(", hThread, ", ", pExitcode, ")=", eax>
	ret
	align 4
GetExitCodeThread endp

;--- Win32 API SetThreadPriority

SetThreadPriority proc public hThread:dword, priority:dword
	xor eax, eax
	mov edx, priority
	mov ecx, hThread
	.if ([ecx].THREAD.dwType == SYNCTYPE_THREAD)
		mov [ecx].THREAD.bPriority, dl
		inc eax
	.endif
	@strace <[ebp+4], ": SetThreadPriority(", hThread, ", ", priority, ")=", eax>
	ret
	align 4
SetThreadPriority endp

;--- Win32 API GetThreadPriority

GetThreadPriority proc public hThread:dword
	mov eax, THREAD_PRIORITY_ERROR_RETURN
	mov ecx, hThread
	.if ([ecx].THREAD.dwType == SYNCTYPE_THREAD)
		movsx eax, [ecx].THREAD.bPriority
	.endif
	@strace <[ebp+4], ": GetThreadPriority(", hThread, ")=", eax>
	ret
	align 4
GetThreadPriority endp

if 1

SetThreadAffinityMask proc public hThread:dword, dwMask:dword
	xor eax, eax
	@strace <[ebp+4], ": SetThreadAffinityMask(", hThread, ", ", dwMask, ")=", eax, " *** unsupp ***">
	ret
	align 4
SetThreadAffinityMask endp

GetThreadTimes proc public hThread:DWORD, lpft1:ptr FILETIME, lpft2:ptr FILETIME, lpft3:ptr FILETIME, lpft4:ptr FILETIME
	xor eax, eax
	@strace <"GetThreadTimes(", hThread, ", ", lpft1, ", ", lpft2, ", ", lpft3, ", ", lpft4, ")=", eax, " *** unsupp ***">
	ret
	align 4
GetThreadTimes endp

endif

;--- GetThreadContext

GetThreadContext proc public hThread:DWORD, lpContext:ptr
	xor eax, eax
	mov edx, hThread
	.if ([edx].THREAD.dwType == SYNCTYPE_THREAD)
		invoke RtlMoveMemory, lpContext, [edx].THREAD.pContext, sizeof CONTEXT
	.endif
	@strace <[ebp+4], ": GetThreadContext(", hThread, ", ", lpContext, ")=", eax>
	ret
	align 4
GetThreadContext endp

;--- SetThreadContext

SetThreadContext proc public hThread:DWORD, lpContext:ptr
	xor eax, eax
	mov edx, hThread
	.if ([edx].THREAD.dwType == SYNCTYPE_THREAD)
		invoke RtlMoveMemory, [edx].THREAD.pContext, lpContext, sizeof CONTEXT
	.endif
	@strace <[ebp+4], ": SetThreadContext(", hThread, ", ", lpContext, ")=", eax>
	ret
	align 4
SetThreadContext endp

	end
