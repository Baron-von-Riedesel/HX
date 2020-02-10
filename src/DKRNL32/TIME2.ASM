
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

;--- the time slice is 1000 * 20/1024

	.CODE

GetSystemTimeAdjustment proc public lpTimeAdjustment:ptr DWORD, lpTimeIncrement:ptr DWORD, lpTimeAdjustmentDisabled:ptr DWORD

	mov ecx, lpTimeAdjustment
	mov edx, lpTimeIncrement
	mov eax, 10000 * ?TIMESLICE * 1000 / 1024	;value in 100 ns units
	mov [ecx], eax
	mov [edx], eax
	@mov eax,1
	mov ecx, lpTimeAdjustmentDisabled
	mov [ecx], eax
	@strace <"GetSystemTimeAdjustment()=", eax>
	ret
	align 4

GetSystemTimeAdjustment endp

if 1

SystemTimeToTzSpecificLocalTime proc public lpTimeZone:ptr TIME_ZONE_INFORMATION, lpUniversalTime:ptr SYSTEMTIME, lpLocalTime:ptr SYSTEMTIME

local	filetime:FILETIME

	invoke SystemTimeToFileTime, lpUniversalTime, addr filetime
	call tzset
	mov ecx, lpTimeZone
	mov eax, [ecx].TIME_ZONE_INFORMATION.Bias	;in minutes
	mov ecx, 60*1000*1000*10	;1 s == 1000 * 1000 * 10 (100 ns units)
	imul ecx
	sub dword ptr filetime+0,eax
	sbb dword ptr filetime+4,edx
	invoke FileTimeToSystemTime, addr filetime, lpLocalTime
	mov eax,1
	@strace <"SystemTimeToTzSpecificLocalTime(", lpTimeZone, ", ", lpUniversalTime, ", ", lpLocalTime, ")=", eax>
	ret
	align 4

SystemTimeToTzSpecificLocalTime endp

endif

	end
