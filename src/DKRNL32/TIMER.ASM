
;--- dkrnl32 uses the RTC periodic timer to implement
;--- kernel32 waitable timers. As default this timer
;--- has a frequency of 1024 Hz, this is not modified

;--- the bios functions int 15h, ah=83h/86h use the RTC timer as well
;--- they use some values in the BIOS data segment:
;--- 40:0098 (DWORD): far ptr to user variable (or 0:0)
;--- 40:009C (DWORD): user wait count in ms
;--- 40:00A0 (BYTE):


?TICKDUR	equ 977		;1000/1024=0.9765625
?SETFS		equ 0

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

?DISPATCH	equ 1

_DispatchRequest proto

	option dotname

;--- CMOS status register B (read/write):
;--- bit 6=1: enable periodic interrupts
;--- bit 5=1: enable alarm interrupt
;--- bit 4=1: enable update-ended interrupt

;--- CMOS status register C (read only):
;--- bit 7=1: any interrupt request 
;--- bit 6=1: periodic interrupts occured
;--- bit 5=1: alarm interrupt occured
;--- bit 4=1: update-ended interrupt occured

;--- reading status register C (index 0Ch) serves as int ack!

.BASE$XC segment dword public 'DATA'
	dd offset DeinitRTCTimer
.BASE$XC ends

	.DATA

externdef g_OldIrq08:fword	;is located in timer2.asm!	
	public g_cntTimer

g_pTimer	dd 0	;linked list of timers
g_cntTimer	dd 0	;number of timers

	.CODE

useralert proc hTimer:ptr TIMER
	mov ecx, hTimer
	invoke [ecx].TIMER.lpfnCompRoutine, [ecx].TIMER.lpArgCompRoutine,\
		[ecx].TIMER.filetime.dwLowDateTime, [ecx].TIMER.filetime.dwHighDateTime
	ret
	align 4
useralert endp

ifdef _DEBUG
TestTimerChain proc pTimer:dword
	cmp pTimer, 0abcdfedch
	jnz @F
	push esi
	mov ax,2
	xor esi, esi	;flush log file
	int 41h
	pop esi
	@trace <13,10,"FATAL: timer chain corrupted!",13,10>
	invoke GetCurrentProcess
	test [eax].PROCESS.wFlags, PF_TERMINATING
	jnz error
	call DeinitRTCTimer
	mov ax,4CFFh
	int 21h
@@:
	clc
	ret
error:
	stc
	ret
	align 4
TestTimerChain endp
endif

;--- this proc is called from IRQ 8!
;--- no register preservation needed
;--- ds = g_csalias, but ES is not set yet, SS is unknown
;--- the timer linked list is not modified here

checktimers proc        
;;	inc word ptr ds:[0b8000h+79*2]
	mov esi, g_pTimer
	xor edi, edi		;flag to indicate if the disp timer is signaled
	.while (esi)
ifdef _DEBUG
		invoke TestTimerChain, esi
		.break .if (CARRY?)
endif
		.break .if [esi].TIMER.dwType != SYNCTYPE_TIMER
if ?MICROSECS
		mov eax, dword ptr [esi].TIMER.lCnt+0
		mov edx, dword ptr [esi].TIMER.lCnt+4
		mov ecx, eax
		or ecx, edx
		jz skipitem
		sub eax, ?TICKDUR
		sbb edx, 0
		mov dword ptr [esi].TIMER.lCnt+0, eax
		mov dword ptr [esi].TIMER.lCnt+4, edx
		jnc skipitem
else
		cmp [esi].TIMER.lCnt,0
		jz skipitem
		dec [esi].TIMER.lCnt
		jnz skipitem
endif
		mov [esi].TIMER.bSignaled, TRUE

if ?MICROSECS
		mov eax, dword ptr [esi].TIMER.lPeriod+0
		mov edx, dword ptr [esi].TIMER.lPeriod+4
		mov dword ptr [esi].TIMER.lCnt+0, eax
		mov dword ptr [esi].TIMER.lCnt+4, edx
else
		mov eax, [esi].TIMER.lPeriod
		mov [esi].TIMER.lCnt, eax
endif
		.if ([esi].TIMER.lpfnCompRoutine)
			push es
			push ds
			pop es
			invoke GetSystemTimeAsFileTime, addr [esi].TIMER.filetime
			invoke QueueUserAPC, offset useralert, [esi].TIMER.hThread, esi
			pop es
		.endif
if ?DISPATCH

;--- if bDispatch = 0, do nothing special
;--- if bDispatch = 1, the timer interval is < the std disp interval
;--- then boost exactly the thread which is waiting for this timer
;--- if bDispatch = 2, the timer IS the std disp timer

		mov al,[esi].TIMER.bDispatch
		cmp al,0
		jz skipitem
		.if (al == 2)
			or edi,-1
		.elseif (!edi)
			invoke _GetCurrentThread
			cmp eax, [esi].TIMER.hThread
			jz skipitem
			mov eax, [esi].TIMER.hThread
;			test [eax].THREAD.flags, TF_LINKED
;			jz skipitem
			mov edi, eax
			call [g_dwBoostProc]
		.endif
else
		cmp [esi].TIMER.bDispatch,2
		jnz skipitem
		inc edi
endif
skipitem:
		mov esi, [esi].TIMER.pNext
	.endw
	ret
	align 4
checktimers endp

;--- the IRQ 8 proc

myirq08 proc
	cmp cs:[g_bIsActive],1	;do nothing if this instance is not active
	jb is_disabled
	push eax
	mov al,0Ch				;read RTC status register C
	out 70h,al
	xchg ebx, ebx
	in al,71h
	test al,40h				;periodic interrupt?
	pop eax
	jz is_disabled
	pushad
	push ds
	mov ds, cs:[g_csalias]
if ?SETFS
	push fs
	mov eax, [g_hCurThread]
	mov fs, [eax].THREAD.dwTibSel
endif
	inc g_dwRTCTicks		;used as timer on certain hosts!
	call checktimers
if ?SETFS
	pop fs
endif
	mov al,20h
	out 0A0h,al
	out 20h,al
	pop ds
	and edi, edi
	popad
	jnz _DispatchRequest
	sti
	@iret
is_disabled:
	jmp fword ptr cs:[g_OldIrq08]
	align 4
myirq08 endp

;--- this proc is called with ints disabled

InitRTCTimer proc public uses ebx

	mov bl,byte ptr g_wPics+0
	mov ax,204h
	int 31h
	mov word ptr g_OldIrq08+4,cx
if ?CLEARHIGHEBP
	movzx edx,dx
endif
	mov dword ptr g_OldIrq08+0,edx
	mov ecx, cs
	mov edx, offset myirq08
	mov ax,205h
	int 31h
	call _SetRTCTimer
	ret
	align 4
InitRTCTimer endp

DeinitRTCTimer proc public uses ebx
	@strace <"DeinitRTCTimer">
	.if (word ptr g_OldIrq08+4)
		call _RestoreRTCTimer
		xor ecx, ecx
		xchg cx, word ptr g_OldIrq08+4
		mov edx, dword ptr g_OldIrq08+0
		mov bl,byte ptr g_wPics+0
		mov ax,205h
		int 31h
	.endif
	ret
	align 4
DeinitRTCTimer endp

;--- add a timer to the timer chain
;--- pNext field is -1

AddTimerToList proc pTimer:DWORD

	mov eax, pTimer
	cmp [eax].TIMER.pNext, -1
	jnz done
	@noints
	mov edx, g_pTimer
	mov [eax].TIMER.pNext, NULL		;mark the end of the chain
	.if (edx)
		.while ([edx].TIMER.pNext)
ifdef _DEBUG
			invoke TestTimerChain, edx
			.break .if (CARRY?)
endif
			mov edx, [edx].TIMER.pNext
		.endw
		mov [edx].TIMER.pNext, eax
	.else
		mov g_pTimer, eax
	.endif
	inc g_cntTimer
	.if (!word ptr g_OldIrq08+4)
		invoke InitRTCTimer
	.endif
	@restoreints
	@strace <"AddTimerToList(", pTimer, ")">
done:
	ret
	align 4
AddTimerToList endp

DeleteTimerFromList proc pTimer:DWORD

	mov eax, pTimer
	cmp [eax].TIMER.pNext, -1
	jz done
	@noints
	mov edx, g_pTimer
	xor ecx, ecx
	.while (edx)
ifdef _DEBUG
		invoke TestTimerChain, edx
		.break .if (CARRY?)
endif
		.if (edx == pTimer)
			 mov eax, [edx].TIMER.pNext
			 .if (ecx)
				 mov [ecx].TIMER.pNext, eax
			 .else
				 mov g_pTimer, eax
			 .endif
			 mov [edx].TIMER.pNext,-1
			 dec g_cntTimer
			 .break
		.endif
		mov ecx, edx
		mov edx, [edx].TIMER.pNext
	.endw
	.if (!g_cntTimer)
		push edx
		invoke DeinitRTCTimer
		pop edx
	.endif
	@restoreints
	@strace <"DeleteTimerFromList(", pTimer, "), found=", edx, ", pTimer=", g_pTimer>
done:
	ret
	align 4
DeleteTimerFromList endp

destructor proc hTimer:DWORD

	xor eax, eax
	mov ecx, hTimer
ifdef _DEBUG
	movzx edx, [ecx].TIMER.bRefCnt
endif
	@strace <"destructor TIMER, obj=", hTimer, " type=", [ecx].TIMER.dwType, " cnt=", edx, " name=", [ecx].TIMER.lpName>
	dec [ecx].TIMER.bRefCnt
	jnz done
	invoke DeleteTimerFromList, ecx
	mov ecx, hTimer
	.if ( [ecx].NAMEDOBJECT.lpName )
		invoke KernelHeapUnlinkObject, ecx
	.endif
ifdef _DEBUG
	invoke _FlushLogFile
endif
	@mov eax, 1
done:
	ret
	align 4
destructor endp

CreateWaitableTimerA proc public security:dword, bManualReset:dword, lpName:ptr BYTE

	.if (lpName)
		invoke KernelHeapFindObject, lpName, SYNCTYPE_TIMER
		.if (eax)
			mov eax, edx
			jmp done
		.endif
		invoke SetLastError, ERROR_SUCCESS
	.endif

	invoke KernelHeapAllocObject, sizeof TIMER, lpName
	and eax,eax
	jz done
	mov dword ptr [eax-4], offset destructor
	mov [eax].SYNCOBJECT.dwType, SYNCTYPE_TIMER
	mov [eax].TIMER.bRefCnt,1
	mov ecx, bManualReset
	mov [eax].TIMER.bManReset, cl
	mov [eax].TIMER.pNext, -1
done:
ifdef _DEBUG
	.if (lpName)
		mov ecx, lpName
	.else
		mov ecx, CStr("NULL")
	.endif
endif
	@strace <"CreateWaitableTimerA(", security, ", ", bManualReset, ", ", &ecx, ")=", eax>
	ret
	align 4

CreateWaitableTimerA endp

OpenWaitableTimerA proc public dwDesiredAccess:dword, bInheritHandle:dword, lpName:dword

	invoke KernelHeapFindObject, lpName, SYNCTYPE_TIMER
	mov eax, edx
	@strace <"OpenWaitableTimerA(", dwDesiredAccess, ", ", bInheritHandle, ", ", lpName, ")=", eax>
	ret
	align 4
OpenWaitableTimerA endp

;--- CancelWaitableTimer should not signal the timer!

CancelWaitableTimer proc public hTimer:dword

	mov ecx, hTimer
	xor eax, eax
	.if ([ecx].SYNCOBJECT.dwType == SYNCTYPE_TIMER)
if 0
		xor edx, edx
 if ?MICROSECS
		mov dword ptr [ecx].TIMER.lCnt+0, edx
		mov dword ptr [ecx].TIMER.lCnt+4, edx
		mov dword ptr [ecx].TIMER.lPeriod+0, edx
		mov dword ptr [ecx].TIMER.lPeriod+4, edx
 else
		mov [ecx].TIMER.lCnt, edx
		mov [ecx].TIMER.lPeriod, edx
 endif
		mov [ecx].TIMER.lpfnCompRoutine, edx
		mov [ecx].TIMER.hThread, edx
		mov [ecx].TIMER.bDispatch, dl
endif
		invoke DeleteTimerFromList, ecx
		@mov eax, 1
	.endif
	@strace <"CancelWaitableTimer(", hTimer, ")=", eax>
	ret
	align 4

CancelWaitableTimer endp

;--- convert time to microsecs or timerticks
;--- in: edx->FILETIME
;--- out: eax=æs or timerticks

converttime proc

local	filetime:FILETIME

	test byte ptr [edx].FILETIME.dwHighDateTime+3,80h
	jz @F
	mov eax, [edx].FILETIME.dwLowDateTime
	mov edx, [edx].FILETIME.dwHighDateTime
	not eax
	not edx
	add eax,1
	adc edx,0
	jmp ct_1
@@:
	push edx
	invoke GetSystemTimeAsFileTime, addr filetime
	pop edx
	mov eax, [edx].FILETIME.dwLowDateTime
	mov edx, [edx].FILETIME.dwHighDateTime
	sub eax, filetime.dwLowDateTime
	sbb edx, filetime.dwHighDateTime
ct_1:
if ?MICROSECS
	mov ecx, 10
	div ecx
	cdq
else
	mov ecx, 10*?TICKDUR
	div ecx
	shr ecx, 1
	cmp ecx, edx
	adc eax, 0
endif
	ret
	align 4
converttime endp

;--- calling SetWaitableTimer for a non-periodic timer should
;--- set state to non-signaled!

;--- lCnt + lPeriod hold time in timerticks if ?MICROSECS=0
;--- else they hold time in æsecs

SetWaitableTimer proc public uses ebx hTimer:dword, pDueTime:ptr QWORD, lPeriod:DWORD, pfnCompRoutine:DWORD, lpArg:DWORD, fResume:DWORD
	xor eax, eax
	mov ebx, hTimer
	.if ([ebx].SYNCOBJECT.dwType == SYNCTYPE_TIMER)
		mov [ebx].TIMER.bSignaled, FALSE
		mov [ebx].TIMER.bDispatch, 0
		mov edx, pfnCompRoutine
		mov ecx, lpArg
		mov eax, lPeriod
		mov [ebx].TIMER.lpfnCompRoutine, edx
		mov [ebx].TIMER.lpArgCompRoutine, ecx
ife ?MICROSECS
		mov ecx, 1024
		mul ecx
		mov ecx, 1000
		div ecx
		mov [ebx].TIMER.lPeriod, eax
else
		mov ecx, 1000
		mul ecx
		mov dword ptr [ebx].TIMER.lPeriod+0, eax
		mov dword ptr [ebx].TIMER.lPeriod+4, edx
endif
		mov edx, pDueTime
		call converttime
if ?MICROSECS
		mov dword ptr [ebx].TIMER.lCnt+0, eax
		mov dword ptr [ebx].TIMER.lCnt+4, edx
		mov ecx, eax
		or ecx, edx
else
		mov [ebx].TIMER.lCnt, eax
		and eax, eax				;is the interval == 0?
endif
		jnz @F
		mov [ebx].TIMER.bSignaled, TRUE	
if ?MICROSECS
		mov ecx, dword ptr [ebx].TIMER.lPeriod+0
		mov dword ptr [ebx].TIMER.lCnt+0, ecx
		mov ecx, dword ptr [ebx].TIMER.lPeriod+4
		mov dword ptr [ebx].TIMER.lCnt+4, ecx
else
		mov ecx, [ebx].TIMER.lPeriod
		mov [ebx].TIMER.lCnt, ecx
endif
@@:
if ?DISPATCH
  if ?MICROSECS
		and edx, edx	;test HIDWORD()
		jnz @F
  endif

;--- see if the period is >= the dispatcher timeslice
;--- if no, set bDispatch and hTread
 
		cmp eax, ?TIMESLICE*2
		jnc @F
		invoke _GetCurrentThread
		mov [ebx].TIMER.hThread, eax
		mov [ebx].TIMER.bDispatch,1
@@:
endif
		invoke AddTimerToList, ebx
		@mov eax, 1
	.endif
	@strace <"SetWaitableTimer(", hTimer, ", ", pDueTime, ", ", lPeriod, ", ", pfnCompRoutine, ", ", lpArg, ", ", fResume, ")=", eax>
	ret
	align 4
SetWaitableTimer endp

	end

