
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

?MCSG	equ 1	;implement MakeCriticalSectionGlobal

	.code

;------------------------------------------------------------

;--- void EnterCriticalSection(pCS) 

EnterCriticalSection proc public uses ebx esi pCS:ptr CRITICAL_SECTION

	mov ebx,pCS
if ?GBLCURRENT
	mov esi, [g_hCurThread]
else
	invoke _GetCurrentThread
	mov esi, eax
endif
	cmp esi, [ebx].CRITICAL_SECTION.OwningThread
	jz is_ours
	invoke WaitForSingleObject, [ebx].CRITICAL_SECTION.LockSemaphore, INFINITE
	cmp eax, WAIT_OBJECT_0
	jnz exit
	mov [ebx].CRITICAL_SECTION.OwningThread,esi
is_ours:
	inc [ebx].CRITICAL_SECTION.LockCount
exit:
;	@strace	<"EnterCriticalSection(", pCS, ")=void">
	ret
	align 4

EnterCriticalSection endp

;--- void LeaveCriticalSection(pCS) 

LeaveCriticalSection proc public uses ebx pCS:ptr CRITICAL_SECTION

	mov ebx,pCS
	cmp [ebx].CRITICAL_SECTION.LockCount,0
	jz exit
if ?GBLCURRENT
	mov eax, [g_hCurThread]
else
	invoke _GetCurrentThread
endif
	cmp eax,[ebx].CRITICAL_SECTION.OwningThread
	jnz exit
	dec [ebx].CRITICAL_SECTION.LockCount
	jnz exit
	mov [ebx].CRITICAL_SECTION.OwningThread,0
	invoke SetEvent, [ebx].CRITICAL_SECTION.LockSemaphore
if ?EVENTOPT	;isn't this done in SetEvent already?
	mov ecx, [ebx].CRITICAL_SECTION.LockSemaphore
	mov eax, [ecx].EVENT.hThread
	.if (eax)				;was another thread blocked?
		xor ecx,ecx			;flag TF_WAITING cleared
		call [g_dwIdleProc]
	.endif
endif
exit:
;	@strace	<"LeaveCriticalSection(", pCS, ")=void">
	ret
	align 4

LeaveCriticalSection endp

;--- void InitializeCriticalSection(pCS)
;--- the event initial state is signaled

InitializeCriticalSection proc public uses ebx pCS:ptr CRITICAL_SECTION

	mov ebx,pCS
	xor eax, eax
	mov byte ptr [ebx].CRITICAL_SECTION.DebugInfo, 4
	mov [ebx].CRITICAL_SECTION.LockCount, eax
	mov [ebx].CRITICAL_SECTION.OwningThread, eax
	mov [ebx].CRITICAL_SECTION.SpinCount, eax
	invoke CreateEvent, NULL, 0, 1, 0
	mov [ebx].CRITICAL_SECTION.LockSemaphore, eax
	@strace <"InitializeCriticalSection(", pCS, ")=void">
	ret
	align 4

InitializeCriticalSection endp

InitializeCriticalSectionAndSpinCount proc public pCS:ptr CRITICAL_SECTION, dwSpinCount:dword

	invoke InitializeCriticalSection, pCS
	mov edx, dwSpinCount
	mov ecx, pCS
	mov [ecx].CRITICAL_SECTION.SpinCount, edx
	@strace <"InitializeCriticalSectionAndSpinCount(", pCS, ", ", dwSpinCount, ")=", eax>
	ret
	align 4

InitializeCriticalSectionAndSpinCount endp

;--- void DeleteCriticalSection(pCS) 

DeleteCriticalSection proc public pCS:ptr CRITICAL_SECTION

	mov eax, pCS
	mov byte ptr [eax].CRITICAL_SECTION.DebugInfo, 0
	mov [eax].CRITICAL_SECTION.LockCount, 0
	xchg eax, [eax].CRITICAL_SECTION.LockSemaphore
	.if (eax)
		invoke CloseHandle, eax
	.endif
	@strace <"DeleteCriticalSection(", pCS, ")=void">
	ret
	align 4

DeleteCriticalSection endp

if ?MCSG

;--- this function is undocumented and vanished in Win2k/XP

MakeCriticalSectionGlobal proc public handle:dword
	mov eax, handle
	@strace <"MakeCriticalSectionGlobal(", handle, ")=", eax>
	ret
	align 4
MakeCriticalSectionGlobal endp

endif

	end
