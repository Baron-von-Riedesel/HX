
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

;?VERBOSE	equ 0	;1=log in debug mode

	.CODE

WaitForSingleObjectEx proc public uses ebx esi hObject:dword, dwMilliSecs:dword, bAlertable:dword

local	dwDeviceFlags:DWORD
local	dwTicks:DWORD

ifdef _DEBUG
	.if (g_dwDebugFlags & DBGF_WAIT)
		@strace <"WaitForSingleObjectEx(", hObject, ", ", dwMilliSecs, ") enter [thrd=", g_hCurThread, "]">
	.endif
endif
	mov esi, dwMilliSecs
	.if (esi && (esi != INFINITE))
		invoke GetTickCount
		mov dwTicks,eax
	.endif
	mov ebx, hObject
if ?NONULLHDL
	cmp ebx, 010000h
	jz isfile
endif
if ?FLAT
	cmp ebx, 010000h
else
	cmp ebx, 01000h
endif
	jnb @F
isfile:
	mov ax,4400h
	int 21h
	jc error
	test dl,80h				;is it a device?
	jz error
	mov dwDeviceFlags,edx
@@:
	.while (1)

		cmp bAlertable,0
		jz noalert
		push edi
		mov edi, fs:[THREAD_INFORMATION_BLOCK.ptibSelf]
		add edi, ?ASYNCSTART
		mov esi, [edi]
nextalert:
		and esi, esi
		jz noalert
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
			pop edi
			jmp exit
		.endif
		mov edi, esi
		mov esi, [esi]
		jmp nextalert
		align 4
alertex:
		pop edi
noalert:

if ?NONULLHDL
  if ?FLAT
		.if (ebx <= 10000h)
  else
		.if ((ebx == 10000h) || (ebx < 1000h))	;is file/device input?
  endif
else
  if ?FLAT
		.if (ebx < 10000h)
  else
		.if (ebx < 1000h)
  endif
endif
			.if (byte ptr dwDeviceFlags & 1)	;std input and a device?
				sub esp, sizeof INPUT_RECORD
				mov edx, esp
				push 0
				invoke PeekConsoleInput, ebx, edx, 1, esp
				pop eax
				add esp, sizeof INPUT_RECORD
				.break .if (eax)
			.else
				mov ax,4400h
				int 21h
				jc error
				.break .if (!(dl & 40h))	;EOF on input?
			.endif

		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_EVENT)

			.if ([ebx].EVENT.bFlags & EVNT_SIGNALED)
				.if (!([ebx].EVENT.bFlags & EVNT_MANRESET))
					and [ebx].EVENT.bFlags, not EVNT_SIGNALED
				.endif
if ?EVENTOPT
				mov [ebx].EVENT.hThread, 0
endif
				.break
if ?EVENTOPT
			.else
				mov eax, g_hCurThread
				mov [ebx].EVENT.hThread, eax
endif
			.endif

		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_TIMER)

			.if ([ebx].TIMER.bSignaled)
				.if (![ebx].TIMER.bManReset)
					mov [ebx].TIMER.bSignaled, FALSE
				.endif
				.break
			.endif

		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_MUTEX)

			invoke GetCurrentThread
			.if ((![ebx].MUTEX.dwOwner) || (eax == [ebx].MUTEX.dwOwner))
				mov [ebx].MUTEX.dwOwner, eax
				inc [ebx].MUTEX.wCnt
				.break
			.endif

		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_SEMAPHOR)

			.if ([ebx].SEMAPHORE.dwCurCnt)
				dec [ebx].SEMAPHORE.dwCurCnt
				.break
			.endif

		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_THREAD)

			.break .if ([ebx].THREAD.flags & TF_TERMINATED)

		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_PROCESS)

			.break .if ([ebx].PROCESS.wFlags & PF_TERMINATED)

		.elseif ([ebx].SYNCOBJECT.dwType == SYNCTYPE_CHANGENOT)

ifdef _DEBUG
			@strace <"unsupported synctype Change notification, obj=", ebx>
			externdef g_bDebugger:byte
			.if (g_bDebugger)
				int 3
			.endif
endif
			jmp error
		.else

ifdef _DEBUG
			@strace <"unknown synctype, obj=", ebx>
			int 3
endif
			jmp error

		.endif
		and esi, esi
		jz	timeout
		cmp esi, INFINITE
		jz releasetimeslice
		invoke GetTickCount
		sub eax, dwTicks
		cmp eax, esi
		jnc timeout
		mov ecx, esi
		sub ecx, eax
		cmp ecx, ?TIMESLICE
		jae releasetimeslice
		.if (ecx > 1)
			shr ecx, 1
		.endif
		invoke Sleep, ecx
		.continue
releasetimeslice:
		invoke Sleep, 0
	.endw
	@mov eax, WAIT_OBJECT_0
exit:
ifdef _DEBUG
	.if (g_dwDebugFlags & DBGF_WAIT)
		@strace <"WaitForSingleObject(", hObject, ", ", dwMilliSecs, ")=", eax>
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

WaitForSingleObjectEx endp

WaitForSingleObject proc public hObject:dword, dwMilliSecs:dword

	invoke WaitForSingleObjectEx, hObject, dwMilliSecs, 0
	ret
	align 4
WaitForSingleObject endp

	end
