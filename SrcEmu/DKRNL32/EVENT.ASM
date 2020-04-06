
;--- implements:
;--- CreateEventA
;--- OpenEventA
;--- SetEvent
;--- ResetEvent
;--- PulseEvent

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

;--- todo!!!!!
;--- if an auto-reset event is signaled, it remains signaled
;--- until a waiting thread is released. It is set to non-signaled
;--- then, but only if further threads are waiting.

CreateEventA proc public uses ebx security:dword,
		bManualReset:dword, bInitialState:dword, lpName:ptr BYTE

	mov eax, sizeof EVENT
	mov ebx, lpName
	.if (ebx && byte ptr [ebx])	;NULL or szNull is allowed
		invoke KernelHeapFindObject, lpName, SYNCTYPE_EVENT
		.if (eax)
			mov eax, edx
			jmp done
		.endif
		invoke SetLastError, ERROR_SUCCESS
	.endif
	invoke KernelHeapAllocObject, sizeof EVENT, lpName
	and eax,eax
	jz done
	mov [eax-4], offset destructor
	mov [eax].EVENT.dwType, SYNCTYPE_EVENT
	mov ecx, bManualReset
	and ecx, 1
	shl ecx, 1
	or [eax].EVENT.bFlags,cl
	mov ecx, bInitialState
	and ecx, 1
	or [eax].EVENT.bFlags, cl
	mov [eax].EVENT.bRefCnt, 1
done:
ifdef _DEBUG
	mov ecx,lpName
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
endif
	@strace <"CreateEventA(", security, ", ", bManualReset, ", ", bInitialState, ", ", &ecx, ")=", eax>
	ret
	align 4

CreateEventA endp

destructor proc pThis:DWORD

	mov ecx, pThis
	dec [ecx].EVENT.bRefCnt
	setz al
	.if ( al && [ecx].NAMEDOBJECT.lpName )
		invoke KernelHeapUnlinkObject, ecx
		mov al,1
	.endif
	movzx eax,al
	@strace <"event destructor: obj=", pThis, " rc=", eax>
	ret
	align 4

destructor endp

OpenEventA proc public dwDesiredAccess:DWORD, bInheritHandle:DWORD, lpName:ptr BYTE

	invoke KernelHeapFindObject, lpName, SYNCTYPE_EVENT
	mov eax, edx
	@strace <"OpenEventA(", dwDesiredAccess, ", ", bInheritHandle, ", ", &lpName, ")=", eax>
	ret
	align 4

OpenEventA endp

;--- SetEvent may be called during interrupt time
;--- dont call DOS then! SS is unknown!

SetEvent proc public hEvent:DWORD

	xor eax, eax
	mov ecx, hEvent
	cmp ecx, eax
	jz exit
	cmp [ecx].EVENT.dwType, SYNCTYPE_EVENT
	jnz exit
	bts dword ptr [ecx].EVENT.bFlags, EVNT_SIGNALED_BIT
if ?EVENTOPT
	jc done
	mov eax,[ecx].EVENT.hThread
	and eax, eax
	jz idle
 if 1
	cmp [eax].THREAD.bPriority, THREAD_PRIORITY_TIME_CRITICAL
	jnz @F
 endif
	call [g_dwBoostProc]
@@:
	invoke SwitchToThread	;added for v3.5
idle:
endif
done:
	@mov eax, 1
exit:
;	@strace <"SetEventA(", hEvent, ")=", eax>
	ret
	align 4

SetEvent endp

;--- set event object to "non-signaled"

ResetEvent proc public hEvent:DWORD

	mov ecx, hEvent
	jecxz error
	cmp [ecx].EVENT.dwType, SYNCTYPE_EVENT
	jnz error
	and [ecx].EVENT.bFlags, not EVNT_SIGNALED
	@mov eax, 1
exit:
	@strace <"ResetEventA(", hEvent, ")=", eax>
	ret
error:
	invoke SetLastError, ERROR_INVALID_HANDLE
	xor eax, eax
	jmp exit
	align 4

ResetEvent endp

PulseEvent proc public uses ebx hEvent:DWORD

	xor eax, eax
	mov ebx, hEvent
	cmp [ebx].EVENT.dwType, SYNCTYPE_EVENT
	jnz exit
	or [ebx].EVENT.bFlags, EVNT_SIGNALED
	xor ecx, ecx
	call [g_dwIdleProc]
	and [ebx].EVENT.bFlags, not EVNT_SIGNALED
	@mov eax, 1
exit:
	@strace <"PulseEventA(", hEvent, ")=", eax>
	ret
	align 4

PulseEvent endp

	end

