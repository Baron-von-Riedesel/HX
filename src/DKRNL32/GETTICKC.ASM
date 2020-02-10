
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

	.CODE

;--- this function may be called during interrupt time
;--- SS is unknown

GetTickCount proc public

	call g_dwGetTimerValuems	;this gets ticks in 1/1000 sec units
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & DBGF_WAIT)
		@strace  <"GetTickCount()=", eax>
	.endif
endif
	ret
	align 4

GetTickCount endp

	end
