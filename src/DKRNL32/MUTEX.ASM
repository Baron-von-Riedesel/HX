
;--- implements:
;--- CreateMutexA
;--- OpenMutexA
;--- ReleaseMutex

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

;--- bInitialOwner == 1: mutex is owned by current thread
;--- bInitialOwner == 0: mutex is unowned

CreateMutexA proc public security:dword, bInitialOwner:dword, lpName:ptr BYTE

	.if (lpName)
		invoke KernelHeapFindObject, lpName, SYNCTYPE_MUTEX
		.if (eax)
			mov eax, edx
			jmp done
		.endif
		invoke SetLastError, ERROR_SUCCESS
	.endif

	invoke KernelHeapAllocObject, sizeof MUTEX, lpName
	and eax,eax
	jz done
	mov [eax].SYNCOBJECT.dwType, SYNCTYPE_MUTEX
	mov [eax].MUTEX.wRefCnt,1
	mov dword ptr [eax-4], offset destructor
	.if (bInitialOwner)
		push eax
		invoke _GetCurrentThread
		mov ecx, eax
		pop eax
		mov [eax].MUTEX.dwOwner, ecx
		mov [eax].MUTEX.wCnt,1
	.endif
done:
	@trace <"CreateMutexA(">
	@tracedw security
	@trace <", ">
	@tracedw bInitialOwner
	@trace <", ">
ifdef _DEBUG
	.if (lpName)
		@trace lpName
	.else
		@tracedw lpName
	.endif
endif
	@strace <")=", eax>
	ret
	align 4
CreateMutexA endp

destructor proc pObject:ptr MUTEX
	mov ecx, pObject
	dec [ecx].MUTEX.wRefCnt
	setz al
	.if ( al && [ecx].NAMEDOBJECT.lpName )
		invoke KernelHeapUnlinkObject, ecx
		mov al,1
	.endif
	movzx eax,al
	@strace <"Mutex destructor: obj=", pObject, " rc=", eax >
	ret
	align 4
destructor endp

OpenMutexA proc public dwDesiredAccess:dword, bInheritHandle:dword, lpName:dword

	invoke KernelHeapFindObject, lpName, SYNCTYPE_MUTEX
	mov eax, edx
	@strace <"OpenMutexA(", dwDesiredAccess, ", ", bInheritHandle, ", ", lpName, ")=", eax>
	ret
	align 4
OpenMutexA endp

;--- ReleaseMutex is to return 1 if the
;--- thread owns the mutex, else it is to return 0

ReleaseMutex proc public hMutex:dword

	invoke _GetCurrentThread
	mov ecx, hMutex
	and ecx, ecx
	jz error
	cmp [ecx].SYNCOBJECT.dwType, SYNCTYPE_MUTEX
	jnz error
	mov edx, eax
	xor eax, eax
	cmp edx, [ecx].MUTEX.dwOwner	;thread must own the mutex!
	jnz exit
	cmp [ecx].MUTEX.wCnt, ax
	jz exit
	dec [ecx].MUTEX.wCnt
	jnz @F
	mov [ecx].MUTEX.dwOwner, eax
@@:
	inc eax
exit:
ifdef _DEBUG
	mov ecx, hMutex
	.if ( ecx == 0 )
		@strace <"ReleaseMutex(", ecx, ")=", eax>
	.else
		movzx edx, [ecx].MUTEX.wCnt
		@strace <"ReleaseMutex(", ecx, ")=", eax, " [cnt=", edx, "]">
	.endif
endif
	ret
error:
	invoke SetLastError, ERROR_INVALID_HANDLE
	xor eax, eax
	jmp exit
	align 4

ReleaseMutex endp

	end

