
;--- implements timeXXX()
;--- multimedia timer

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include windef.inc
	include winbase.inc
	include mmsystem.inc
	include winmm.inc
	include macros.inc

	.DATA
        
g_pTimer 	dd 0
g_dwPeriod	dd 1
g_bInit  	db 0

	.CODE

AddToList	proc pObject:ptr

	invoke EnterCriticalSection, addr g_csMM
	mov eax, pObject
	mov ecx, g_pTimer
	mov g_pTimer, eax
	mov [eax].TIMEOBJ.pNext, ecx
	invoke LeaveCriticalSection, addr g_csMM
	ret
	align 4

AddToList endp

;--- returns eax == 0 if object wasn't found

DeleteFromList	proc pObject:ptr

	mov ecx, pObject
	cmp [ecx].TIMEOBJ.pNext,-1
	jz done
	invoke EnterCriticalSection, addr g_csMM
	mov ecx, pObject
	lea edx, g_pTimer
	mov eax, [edx]
	.while (eax)
		.if (ecx == eax)
			mov ecx,[eax].TIMEOBJ.pNext
			mov [edx].TIMEOBJ.pNext, ecx
			mov [eax].TIMEOBJ.pNext, -1
			.break
		.endif
		mov edx, eax
		mov eax, [eax].TIMEOBJ.pNext
	.endw
	invoke LeaveCriticalSection, addr g_csMM
	invoke StopMMThread			;reset the helper thread
done:
	ret
	align 4

DeleteFromList endp

timeKillEvent proto :DWORD

DeleteAllTimerObjects proc public uses ebx

	@strace <"DeleteAllTimerObjects() enter">
	mov eax, g_pTimer
	xor ebx, ebx
	.while (eax)
		inc ebx
		push [eax].TIMEOBJ.pNext
		invoke timeKillEvent, eax
		pop eax
	.endw
	@strace <"DeleteAllTimerObjects() exit">
	ret
	align 4

DeleteAllTimerObjects endp

;--- thread proc for mm thread

_timethreadproc proc public uses ebx hTimer:DWORD

	mov edx, hTimer
	mov ecx, g_pTimer
	.while (ecx && (edx != [ecx].TIMEOBJ.hTimer))
		mov ecx, [ecx].TIMEOBJ.pNext
	.endw
	.if (ecx)
		@strace <"timethreadproc: known timer">
		mov ebx, ecx
		mov edx, [ebx].TIMEOBJ.lpProc
		mov ecx, [ebx].TIMEOBJ.fuEvent
		.if (ecx & TIME_CALLBACK_EVENT_SET)
			@strace <"timethreadproc: calling SetEvent()">
			invoke SetEvent, edx
		.elseif (ecx & TIME_CALLBACK_EVENT_PULSE)
			@strace <"timethreadproc: calling PulseEvent()">
			invoke PulseEvent, edx
		.else
			@strace <"timethreadproc: calling timer proc">
			invoke [ebx].TIMEOBJ.lpProc, ebx, 0, [ebx].TIMEOBJ.dwUser, 0, 0
		.endif
		.if (!([ebx].TIMEOBJ.fuEvent & TIME_PERIODIC))
			@strace <"timethreadproc: timer not periodic, disabling">
			invoke DeleteFromList, ebx
			.if ([ebx].TIMEOBJ.hTimer)
				invoke CancelWaitableTimer, [ebx].TIMEOBJ.hTimer
			.endif
if 0
			xor ecx, ecx
			xchg ecx, [ebx].TIMEOBJ.hTimer
			invoke CloseHandle, ecx
endif
		.endif
ifdef _DEBUG
	.else
		@strace <"timethreadproc: unknown timer">
endif
	.endif
	ret
	align 4

_timethreadproc endp

;--- lpTimerProc may be an event handle or a event proc
;--- use manual reset waitable timers!

timeSetEvent proc public uses ebx uDelay:DWORD, uResolution:DWORD, lpTimerProc:DWORD, dwUser:DWORD, fuEvent:DWORD

local	filetime:FILETIME

	xor eax, eax
	cmp eax,uDelay
	jz	exit
	invoke CreateWaitableTimer, NULL, 0, 0
	and eax, eax
	jz exit
	mov ebx, eax
	invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof TIMEOBJ
	.if (eax)
		mov [eax].TIMEOBJ.hTimer, ebx
		mov ecx, uDelay
		mov edx, uResolution
		mov ebx, eax
		mov [ebx].TIMEOBJ.uDelay, ecx
		mov [ebx].TIMEOBJ.uResolution, edx
		mov ecx, lpTimerProc
		mov edx, dwUser
		mov eax, fuEvent
		mov [ebx].TIMEOBJ.lpProc, ecx
		mov [ebx].TIMEOBJ.dwUser, edx
		mov [ebx].TIMEOBJ.fuEvent, eax

		mov eax, [ebx].TIMEOBJ.uDelay
		mov ecx, 1000*10
		mul ecx
		not eax
		not edx
		add eax,1
		adc edx,0
		mov filetime.dwLowDateTime, eax
		mov filetime.dwHighDateTime, edx
		.if ([ebx].TIMEOBJ.fuEvent & TIME_PERIODIC)
			mov ecx, [ebx].TIMEOBJ.uDelay
		.else
			xor ecx, ecx
		.endif
		invoke SetWaitableTimer, [ebx].TIMEOBJ.hTimer, addr filetime, \
				ecx, 0, 0, 0
		and eax,eax
		jz error

		invoke AddToList, ebx
		.if (!g_bInit)
			mov g_bInit, 1
			invoke atexit, offset DeleteAllTimerObjects
		.endif

		invoke StartMMThread
		and eax, eax
		jz error
		mov eax, ebx
	.else
		invoke CloseHandle, ebx
		xor eax, eax
	.endif
exit:
	@strace <"timeSetEvent(", uDelay, ", ", uResolution, ", ", lpTimerProc, ", ", dwUser, ", ",  fuEvent, ")=", eax>
	ret
error:
	invoke CloseHandle, [ebx].TIMEOBJ.hTimer
	invoke LocalFree, ebx
	xor eax, eax
	jmp exit
	align 4
        
timeSetEvent endp

timeKillEvent proc public uses ebx hTimer:dword

local	duetime:qword

	@strace <"timeKillEvent(", hTimer, ")">
	mov ebx, hTimer
	.if (ebx)
		invoke DeleteFromList, ebx
		.if ([ebx].TIMEOBJ.hTimer)
		   invoke CancelWaitableTimer, [ebx].TIMEOBJ.hTimer
		   invoke CloseHandle, [ebx].TIMEOBJ.hTimer
		   mov [ebx].TIMEOBJ.hTimer, 0
		.endif
		invoke LocalFree, ebx
		mov eax, TIMERR_NOERROR
	.else
		mov eax, MMSYSERR_INVALPARAM
	.endif
	@strace <"timeKillEvent(", hTimer, ")=", eax>
	ret
	align 4

timeKillEvent endp

;--- set timer resolution in ms
;--- we can accept either value, since the default frequency of
;--- the RTC timer (used by CreateWaitableTimer) is 1024 Hz, which
;--- is just about 1 ms

timeBeginPeriod proc public uPeriod:DWORD

	mov ecx, uPeriod
	mov g_dwPeriod, ecx
	mov eax, TIMERR_NOERROR
	@strace <"timeBeginPeriod(", uPeriod, ")=", eax>
	ret
	align 4

timeBeginPeriod endp

timeEndPeriod proc public uPeriod:DWORD

	mov eax, TIMERR_NOERROR
	@strace <"timeEndPeriod(", uPeriod, ")=", eax>
	ret
	align 4

timeEndPeriod endp

timeGetTime proc public

	invoke GetTickCount
;	@strace <"timeGetTime()=", eax>
	ret
	align 4

timeGetTime endp

timeGetDevCaps proc public ptc:ptr TIMECAPS, cbtc:dword

	mov ecx, ptc
	mov [ecx].TIMECAPS.wPeriodMin,1
	mov [ecx].TIMECAPS.wPeriodMax,65535
	mov eax, TIMERR_NOERROR
	@strace <"timeGetDevCaps(", ptc, ", ", cbtc, ")=", eax>
	ret
	align 4

timeGetDevCaps endp

	end
