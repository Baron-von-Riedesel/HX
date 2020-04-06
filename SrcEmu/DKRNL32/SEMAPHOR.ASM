
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

SEMA_WAIT equ 1 	  ;ein Thread musste warten

	.CODE

CreateSemaphoreA proc security:dword, dwInitCnt:dword, dwMaxCnt:dword,lpName:dword

	.if (lpName)
		invoke KernelHeapFindObject, lpName, SYNCTYPE_SEMAPHOR
		.if (eax)
			mov eax, edx
			jmp done
		.endif
		invoke SetLastError, ERROR_SUCCESS
	.endif

	invoke KernelHeapAllocObject, sizeof SEMAPHORE, lpName
	and eax,eax
	jz done
	mov ecx,dwInitCnt
	mov edx,dwMaxCnt
	mov dword ptr [eax-4], offset destructor
	mov [eax].SYNCOBJECT.dwType, SYNCTYPE_SEMAPHOR
	mov [eax].SEMAPHORE.dwRefCnt,1
	mov [eax].SEMAPHORE.dwCurCnt,ecx
	mov [eax].SEMAPHORE.dwMaxCnt,edx
done:
	@trace <"CreateSemaphoreA(">
	@tracedw security
	@trace <", ">
	@tracedw dwInitCnt
	@trace <", ">
	@tracedw dwMaxCnt
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
CreateSemaphoreA endp

destructor proc pObject:ptr SEMAPHOR
	mov ecx, pObject
	dec [ecx].SEMAPHORE.dwRefCnt
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

OpenSemaphoreA proc dwDesiredAccess:dword, bInheritHandle:dword, lpName:dword

	invoke KernelHeapFindObject, lpName, SYNCTYPE_SEMAPHOR
	mov eax, edx
	@strace <"OpenSemaphoreA(", dwDesiredAccess, ", ", bInheritHandle, ", ", &lpName, ")=", eax>
	ret
	align 4
OpenSemaphoreA endp

ReleaseSemaphore proc semaphor:dword, lReleaseCount:dword, lpPrevCount:dword

	mov ecx, lReleaseCount
	mov edx, FALSE
	call EnterSerialization
	mov eax,semaphor
	add ecx, [eax].SEMAPHORE.dwCurCnt
	.if (ecx <= [eax].SEMAPHORE. dwMaxCnt)
		xchg ecx, [eax].SEMAPHORE.dwCurCnt
		mov edx, TRUE
	.endif
	call LeaveSerialization
	mov eax, lpPrevCount
	.if (eax)
		mov [eax], ecx
	.endif
	mov eax, edx
;	@strace <"ReleaseSemaphore(", semaphor, ", ", lReleaseCount, ", ", lpPrevCount, ")=", eax)
	ret
	align 4

ReleaseSemaphore endp

CreateSemaphoreW proc security:dword, dwInitCnt:dword, dwMaxCnt:dword,lpName:ptr WORD

	mov eax,lpName
	.if (eax)
		call ConvertWStr
	.endif
	invoke CreateSemaphoreA, security, dwInitCnt, dwMaxCnt, eax
ifdef _DEBUG
	mov edx, lpName
	.if (!edx)
		mov edx, CStr("NULL")
	.endif
	@strace <"CreateSemaphoreW(", security, ", ", dwInitCnt, ", ", dwMaxCnt, ", ", &edx, ")=", eax>
endif
	ret
	align 4
CreateSemaphoreW endp

	end

