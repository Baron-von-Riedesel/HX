
	.586
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

?USETSC	equ 0

	.code

QueryPerformanceCounter proc public lpPerformanceCount:ptr QWORD

if ?USETSC
	rdtsc
else
	call g_dwGetTimerValue
	push dx					;DX->HIWORD(eax)
	push ax
	pop eax
	shr edx, 16				;HIWORD(EDX)->DX
endif
	mov ecx, lpPerformanceCount
	.if (ecx)
		mov [ecx+0], eax
		mov [ecx+4], edx
	.endif
	@mov eax, 1
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & DBGF_WAIT)
	@strace <"QueryPerformanceTimer(", lpPerformanceCount, ")=", eax>		
	.endif
endif
	ret

QueryPerformanceCounter endp

QueryPerformanceFrequency proc public lpFrequency:ptr QWORD

	mov eax, lpFrequency
	.if (eax)
		mov dword ptr [eax+0],1234DCh	;=1.193.180
		mov dword ptr [eax+4],0
		@mov eax,1
	.endif
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & DBGF_WAIT)
	@strace <"QueryPerformanceFrequency(", lpFrequency, ")=", eax>
	.endif
endif
	ret

QueryPerformanceFrequency endp

	end
