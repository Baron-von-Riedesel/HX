
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

?LOCALTIME	equ 0	;1=transform time to UNC in DosDateTimeToFileTime 
?LOCAL2SYS	equ 1	;1=transform time to UNC in _DosDateTimeToFileTime 

	.code

;--- for SMALL we use following FILETIME format:
;--- dwLowDateTime:		HH/MM/SS/MS
;--- dwHighDateTime:	YY/MM/DD/00

ife ?FLAT
_DosDateTimeToFileTime proc public wDate:DWORD, wTime:DWORD, pFileTime:ptr FILETIME
_DosDateTimeToFileTime endp
endif

DosDateTimeToFileTime proc public uses ebx wDate:DWORD, wTime:DWORD, pFileTime:ptr FILETIME

local	systemtime:SYSTEMTIME

ifdef _DEBUG
	@trace <"DosDateTimeToFileTime(">
	@tracedw wDate
	@trace <"[">
	mov  eax,wDate
	movzx eax,ax
	and  ax,0FE00h
	shr  eax,5+4
	@tracedw eax
	@trace <"/">
	mov  eax,wDate
	movzx eax,ax
	and  ax,001E0h
	shr  eax,5
	@tracedw eax
	@trace <"/">
	mov  eax,wDate
	movzx eax,ax
	and  ax,0001Fh
	@tracedw eax
	@trace <"]">

	@trace <", ">
	@tracedw wTime
	@trace <"[">
	mov  eax,wTime
	movzx eax,ax
	and  ax,0F800h
	shr  eax,6+5
	@tracedw eax
	@trace <":">
	mov  eax,wTime
	movzx eax,ax
	and  ax,007E0h
	shr  eax,5
	@tracedw eax
	@trace <":">
	mov  eax,wTime
	movzx eax,ax
	and  ax,0001Fh
	@tracedw eax
	@trace <"]">
	@trace <", ">
	@tracedw pFileTime
	@trace <")",13,10>
endif
if ?FLAT
	mov systemtime.wMilliseconds, 0
	mov eax, wTime
	mov ecx, eax
	mov edx, eax
	shr ecx, 5
	shr edx, 11
	and ax, 1Fh				;seconds [bits 0-4] * 2
	and cx, 3Fh				;minutes [bits 5-10]
	and dx, 1Fh				;hours [bits 11-15]

	xor ebx, ebx        
	shl al, 1
	cmp al, 60				;dos may have returned 60 seconds!!!
	jc @F					;which is invalid for SystemTimeToFileTime
	mov al,0
	mov ebx, 60*1000*1000*10	;100 ns units for 1 minute
@@:
	mov systemtime.wSecond, ax
	mov systemtime.wMinute, cx
	mov systemtime.wHour, dx

	mov systemtime.wDayOfWeek, 0

	mov eax, wDate
	mov ecx, eax
	mov edx, eax
	and ax, 1Fh				;day of month [0-4]
	shr ecx, 5
	and cx, 0Fh				;month [5-8]
	shr edx, 9
	and dx, 7Fh				;years since 1980
	add dx, 1980
	mov systemtime.wDay, ax
	mov systemtime.wMonth, cx
	mov systemtime.wYear, dx

	invoke SystemTimeToFileTime, addr systemtime, pFileTime
	mov ecx, pFileTime
	add [ecx].FILETIME.dwLowDateTime, ebx
	adc [ecx].FILETIME.dwHighDateTime, 0
if ?LOCALTIME
	mov eax, [ecx+0]
	mov edx, [ecx+4]
	call localtosystem
	mov [ecx+0],eax
	mov [ecx+4],edx
endif
else
	mov edx, pFileTime
	mov byte ptr [edx], 0	;no milliseconds available
	mov eax, wTime
	and al, 1Fh				;seconds [bits 0-4] * 2
	shl al, 1
	mov [edx+1], al
	mov eax, wTime
	shr eax, 5
	and al, 3Fh				;minutes [bits 5-10]
	mov [edx+2], al		
	mov eax, wTime
	shr eax, 11
	and al, 1Fh				;hours [bits 11-15]
	mov [edx+3], al

	mov byte ptr [edx+4], 0	;no day of week

	mov eax, wDate
	and al, 1Fh				;day of month [0-4]
	mov [edx+5], al
	mov eax, wDate
	shr eax, 5
	and al, 0Fh				;month [5-8]
	mov [edx+6], al
	mov eax, wDate
	shr eax, 9
	and al, 7Fh				;year from 1980
	mov [edx+7], al
	@mov eax, 1
endif
	ret
	align 4

DosDateTimeToFileTime endp

ife ?FLAT
_FileTimeToDosDateTime proc public pFileTime:ptr FILETIME, pwDate:ptr WORD, pwTime:ptr WORD
_FileTimeToDosDateTime endp
endif

FileTimeToDosDateTime proc public pFileTime:ptr FILETIME, pwDate:ptr WORD, pwTime:ptr WORD

local	filetime:FILETIME
local	systemtime:SYSTEMTIME

if ?FLAT
	mov ecx, pFileTime
if ?LOCALTIME
	mov eax, [ecx].FILETIME.dwLowDateTime
	mov edx, [ecx].FILETIME.dwHighDateTime
	call systemtolocal
	lea ecx, filetime
	mov filetime.dwLowDateTime,eax
	mov filetime.dwHighDateTime,edx
endif
	invoke FileTimeToSystemTime, ecx, addr systemtime
	mov ax, systemtime.wHour
	shl eax, 6
	or al, byte ptr systemtime.wMinute
	shl eax, 5
	mov cx, systemtime.wSecond
	shr cl, 1
	or al, cl
	mov ecx, pwTime
	mov [ecx], ax
	mov ax, systemtime.wYear
	sub ax, 1980
	jc error
	shl eax, 4
	or al, byte ptr systemtime.wMonth
	shl eax, 5
	or al, byte ptr systemtime.wDay
	mov ecx, pwDate
	mov [ecx], ax
	@mov eax, 1
exit@:
else
	mov edx, pFileTime
	mov al, [edx+3]		;hour
	shl eax, 6
	or al, [edx+2]		;minute
	shl eax, 5
	mov cl, [edx+1] 	;second
	shr cl, 1
	or al, cl
	mov ecx, pwTime
	mov [ecx], ax

	mov al, [edx+7]     ;year
	shl eax, 4
	or al, [edx+6]		;month
	shl eax, 5
	or al, [edx+5] 		;day
	mov ecx, pwDate
	mov [ecx], ax
	@mov eax, 1
endif

	@strace	<"FileTimeToDosDateTime(", pFileTime, ", ", pwDate, ", ", pwTime, ")=", eax>
	ret
if ?FLAT
error:
	xor eax, eax
	jmp exit@
endif
	align 4

FileTimeToDosDateTime	endp

if ?FLAT

_DosDateTimeToFileTime proc public wDate:DWORD, wTime:DWORD, pFileTime:ptr FILETIME

	invoke DosDateTimeToFileTime, wDate, wTime, pFileTime
if ?LOCAL2SYS
	push eax
	mov ecx, pFileTime
	mov eax, [ecx+0]
	mov edx, [ecx+4]
	call localtosystem
	mov [ecx+0],eax
	mov [ecx+4],edx
	pop eax
endif
	ret
	align 4

_DosDateTimeToFileTime endp

_FileTimeToDosDateTime proc public pFileTime:ptr FILETIME, pwDate:ptr WORD, pwTime:ptr WORD

local	filetime:FILETIME

if ?LOCAL2SYS
	push eax
	mov ecx, pFileTime
	mov eax, [ecx+0]
	mov edx, [ecx+4]
	call systemtolocal
	mov dword ptr filetime+0,eax
	mov dword ptr filetime+4,edx
	pop eax
endif
	invoke FileTimeToDosDateTime, addr filetime, pwDate, pwTime
	ret
	align 4

_FileTimeToDosDateTime endp

endif

	end
