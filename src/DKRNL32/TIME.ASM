
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

GetLocalTime proc public uses ebx pTime:ptr SYSTEMTIME

	mov ebx,pTime
	xor eax,eax
	mov [ebx+0],eax
	mov [ebx+4],eax
	mov [ebx+8],eax
	mov [ebx+12],eax
	mov ah,2Ah
	int 21h
	mov [ebx.SYSTEMTIME.wYear],cx
	mov byte ptr [ebx.SYSTEMTIME.wMonth],dh
	mov byte ptr [ebx.SYSTEMTIME.wDayOfWeek],al
	mov byte ptr [ebx.SYSTEMTIME.wDay],dl
	mov ah,2Ch
	int 21h
	mov byte ptr [ebx.SYSTEMTIME.wHour],ch
	mov byte ptr [ebx.SYSTEMTIME.wMinute],cl
	mov byte ptr [ebx.SYSTEMTIME.wSecond],dh
	mov al,10
	mul dl
	add ax,5
	mov [ebx.SYSTEMTIME.wMilliseconds],ax
	@strace <"GetLocalTime(", pTime, ")=", eax>
	ret
	align 4

GetLocalTime endp


SetLocalTime proc public pTime:dword

	xor eax,eax
	@strace <"SetLocalTime(", pTime, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetLocalTime endp

GetSystemTime proc public pTime:ptr SYSTEMTIME

local	filetime:FILETIME

	invoke GetLocalTime, pTime
	invoke SystemTimeToFileTime, pTime, addr filetime
	mov eax, filetime.dwLowDateTime
	mov edx, filetime.dwHighDateTime
	call localtosystem
	mov filetime.dwLowDateTime,eax
	mov filetime.dwHighDateTime,edx
	invoke FileTimeToSystemTime, addr filetime, pTime
	@strace <"GetSystemTime(", pTime, ")=", eax>
	ret
	align 4

GetSystemTime endp


SetSystemTime proc public pTime:ptr SYSTEMTIME

	xor eax, eax
	@strace <"SetSystemTime(", pTime, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetSystemTime endp


GetSystemTimeAsFileTime proc public pFileTime:ptr FILETIME

local	systime:SYSTEMTIME

	invoke GetSystemTime,addr systime
	invoke SystemTimeToFileTime,addr systime,pFileTime
	@strace <"GetSystemTimeAsFileTime(", pFileTime, ")=", eax>
	ret
	align 4

GetSystemTimeAsFileTime endp

	end


