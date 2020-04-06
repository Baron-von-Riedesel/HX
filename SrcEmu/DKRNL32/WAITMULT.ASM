
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif

	option proc:private
	option casemap:none

	include winbase.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

@If_IsFileHandle macro reg
if ?NONULLHDL
  if ?FLAT
	.if (reg <= 10000h)
  else
	.if ((reg == 10000h) || (reg < 1000h))	;is file/device input?
  endif                
else
  if ?FLAT
	.if (reg < 10000h)
  else
	.if (reg < 1000h)		;is file/device input?
  endif                
endif                
	endm


	.CODE

;--- if fWaitall is false, just 1 object state is changed

ClearState proc

	@If_IsFileHandle ebx
		;
	.else
		mov edx, [ebx].SYNCOBJECT.dwType
		.if (edx == SYNCTYPE_MUTEX)
			.if (![ebx].MUTEX.dwOwner)
				invoke _GetCurrentThread
				mov [ebx].MUTEX.dwOwner, eax
			.endif
			inc [ebx].MUTEX.wCnt
		.elseif (edx == SYNCTYPE_EVENT)
			mov [ebx].EVENT.hThread, 0
			.if (!([ebx].EVENT.bFlags & EVNT_MANRESET))
				and [ebx].EVENT.bFlags, not EVNT_SIGNALED
			.endif
		.elseif (edx == SYNCTYPE_SEMAPHOR)
			.if ([ebx].SEMAPHORE.dwCurCnt)
				dec [ebx].SEMAPHORE.dwCurCnt
			.endif
		.elseif (edx == SYNCTYPE_TIMER)
			.if (![ebx].TIMER.bManReset)
				mov [ebx].TIMER.bSignaled, FALSE
			.endif
		.endif
	.endif
	ret
	align 4

ClearState endp        


WaitForMultipleObjectsEx proc public nCount:DWORD, lpHandles:ptr dword,fWaitAll:DWORD, dwMilliSecs:dword, bAlertable:dword

local	dwTicks:DWORD

ifdef _DEBUG
	.if (cs:g_dwDebugFlags & DBGF_WAIT)
		@trace <"WaitForMultipleObjectsEx(">
		@tracedw nCount
		@trace <", ">
		@tracedw lpHandles
		@trace <" [">
		mov ecx, nCount
		.if (ecx > 3)
			mov ecx, 3
		.endif
		mov esi, lpHandles
		.while (ecx)
			lodsd
			@tracedw eax
			.if (eax > 10000h)
				@trace <":">
				@tracedw dword ptr [eax]
			.endif
			@trace <" ">
			add edx, 4
			dec ecx
		.endw
		@trace <"], ">
		@tracedw fWaitAll
		@trace <", ">
		@tracedw dwMilliSecs
		@trace <", ">
		@tracedw bAlertable
		@trace <") enter ESP=">
		@tracedw esp
		@trace <" thrd=">
		@tracedw g_hCurThread
		@trace <13,10>
	.endif
endif
	.if (dwMilliSecs && (dwMilliSecs != INFINITE))
		invoke GetTickCount
		mov dwTicks, eax
	.endif
	.while (1)
		.if (bAlertable)
			mov edi, fs:[THREAD_INFORMATION_BLOCK.ptibSelf]
			add edi, ?ASYNCSTART
			mov esi, [edi]
			.while (esi)
				test [esi].ASYNCFILE.dwFlags, 1
				.if (!ZERO?)
					mov edx, [esi].ASYNCFILE.lpOverlapped
					push edx
					push [edx].OVERLAPPED.InternalHigh
					push [edx].OVERLAPPED.Internal
					call [esi].ASYNCFILE.lpCompletionRoutine
					mov eax, [esi]
					mov [edi], eax
					invoke LocalFree, esi
					mov eax, WAIT_IO_COMPLETION
					jmp exit
				.endif
				mov edi, esi
				mov esi, [esi]
			.endw
		.endif
		xor edi, edi
		mov esi,lpHandles
		mov ecx, nCount
		.while (ecx)
			lodsd
			mov ebx,eax
			@If_IsFileHandle ebx
				mov ax,4400h
				int 21h
				jc error
				test dl,80h		;is it a device?
				jz error
				push ecx
				.if (dl & 1)		;std input and device?
					sub esp, sizeof INPUT_RECORD
					mov edx, esp
					push 0
					invoke PeekConsoleInput, ebx, edx, 1, esp
					pop eax
					add esp, sizeof INPUT_RECORD
					.if (eax)
						inc edi
					.endif
				.else
					mov ax,4400h
					int 21h
					jc error
					.if (!(dl & 40h))	;EOF on input?
						inc edi
					.endif
				.endif
				pop ecx

			.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_EVENT)
				.if ([ebx].EVENT.bFlags & EVNT_SIGNALED)
					inc edi
if ?EVENTOPT
				.else
					mov eax, g_hCurThread
					mov [ebx].EVENT.hThread, eax
endif
				.endif

			.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_TIMER)

				.if ([ebx].TIMER.bSignaled)
					inc edi
				.endif

			.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_MUTEX)

				;--- a Mutex is signaled when it's not owned
				invoke _GetCurrentThread
				.if ((![ebx].MUTEX.dwOwner) || (eax == [ebx].MUTEX.dwOwner))
					inc edi
				.endif

			.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_SEMAPHOR)
				.if ([ebx].SEMAPHORE.dwCurCnt)
					inc edi
				.endif

			.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_THREAD)
				.if ([ebx].THREAD.flags & TF_TERMINATED)
					inc edi
				.endif

			.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_PROCESS)
				.if ([ebx].PROCESS.wFlags & PF_TERMINATED)
					inc edi
				.endif

			.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_CHANGENOT)
ifdef _DEBUG
				@strace <"unsupported synctype Change notification, obj=", ebx>
				externdef g_bDebugger:byte
				.if (g_bDebugger)
					int 3
				.endif
endif
			.else
ifdef _DEBUG
				@strace <"unknown synctype, obj=", ebx>
				int 3
endif
				inc edi
			.endif

			.if (edi && (fWaitAll == FALSE))
				call ClearState
				sub esi, lpHandles
				shr esi, 2
				mov edi, esi
				jmp done
			.endif
			dec ecx
		.endw
		.break .if (edi == nCount)
		mov edi, dwMilliSecs
		and edi, edi
		jz timeout
		xor esi, esi
		cmp edi, INFINITE
		jz releasetimeslice
		invoke GetTickCount
		sub eax, dwTicks	;ticks we have been waiting	
		cmp eax, edi
		jnc timeout
		sub edi, eax		;edi = remaining ms to wait
		cmp edi, ?TIMESLICE
		jae releasetimeslice
		mov esi, edi
		.if (edi > 1)
			shr esi,1
		.endif
releasetimeslice:
		invoke Sleep, esi
	.endw
;--- this code runs for fWaitAll == TRUE
;--- the state of all objects is changed!
	mov ecx, nCount
	mov esi, lpHandles
	.while (ecx)
		lodsd
		mov ebx, eax
		call ClearState
		dec ecx
	.endw
	@mov edi, 1
done:
	lea eax, [edi + WAIT_OBJECT_0 - 1]
exit:        
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & DBGF_WAIT)
		@strace	<"WaitForMultipleObjectsEx()=",eax, " ESP=", esp>
	.endif
endif
	ret
timeout:
	@mov eax, WAIT_TIMEOUT
	jmp exit
error:
	invoke SetLastError, ERROR_INVALID_HANDLE
	@mov eax, WAIT_FAILED
	jmp exit
	align 4

WaitForMultipleObjectsEx endp


WaitForMultipleObjects proc public uses edi esi ebx nCount:DWORD, lpHandles:ptr dword,fWaitAll:DWORD, dwMilliSecs:dword

	invoke WaitForMultipleObjectsEx, nCount, lpHandles, fWaitAll, dwMilliSecs, 0
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & DBGF_WAIT)
		@strace	<"WaitForMultipleObjects()=",eax>
	.endif
endif
	ret
	align 4

WaitForMultipleObjects endp

	end
