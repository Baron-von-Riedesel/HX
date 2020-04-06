

	.386
if ?FLAT
	.model flat, stdcall
else
	.model small, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

;--- FILETIME is supported, but only for FLAT it counts
;--- 100-nanosecond intervals since A.D. 1.1.1601.
;--- For SMALL its a "compressed" SYSTEMTIME, which in most
;--- cases is no problem, since FILETIMEs are used for
;--- comparisons only. And the true FILETIME occupies a lot
;--- of space, which is no problem for DKRNL32.DLL, but 
;--- bad for statically linked apps as in SMALL model.

if ?FLAT

	.const

;--- DayTab1 to get month from DayOfYear (leap year)

DayTab1	db 31 dup (0)
		db 29 dup (1)
		db 31 dup (2)
		db 30 dup (3)
		db 31 dup (4)
		db 30 dup (5)
		db 31 dup (6)
		db 31 dup (7)
		db 30 dup (8)
		db 31 dup (9)
		db 30 dup (10)
		db 31 dup (11)
		db 2  dup (0)
        
;--- DayTab2 to get month from DayOfYear (normal year)

DayTab2	db 31 dup (0)
		db 28 dup (1)
		db 31 dup (2)
		db 30 dup (3)
		db 31 dup (4)
		db 30 dup (5)
		db 31 dup (6)
		db 31 dup (7)
		db 30 dup (8)
		db 31 dup (9)
		db 30 dup (10)
		db 31 dup (11)
		db 3  dup (0)


;--- MonthTab1 for leap year

MonthTab1	dw 0
			dw 31
			dw 31+29
			dw 31+29+31
			dw 31+29+31+30
			dw 31+29+31+30+31
			dw 31+29+31+30+31+30
			dw 31+29+31+30+31+30+31
			dw 31+29+31+30+31+30+31+31
			dw 31+29+31+30+31+30+31+31+30
			dw 31+29+31+30+31+30+31+31+30+31
			dw 31+29+31+30+31+30+31+31+30+31+30
			dw 31+29+31+30+31+30+31+31+30+31+30+31
			dw 0, 0, 0

;--- MonthTab2 for normal year

MonthTab2	dw 0
			dw 31
			dw 31+28
			dw 31+28+31
			dw 31+28+31+30
			dw 31+28+31+30+31
			dw 31+28+31+30+31+30
			dw 31+28+31+30+31+30+31
			dw 31+28+31+30+31+30+31+31
			dw 31+28+31+30+31+30+31+31+30
			dw 31+28+31+30+31+30+31+31+30+31
			dw 31+28+31+30+31+30+31+31+30+31+30
			dw 31+28+31+30+31+30+31+31+30+31+30+31
			dw 0, 0, 0

	.code


SystemTimeToFileTime proc public uses ebx esi edi pSource:ptr SYSTEMTIME,pDest:ptr FILETIME

local	dwTemp:DWORD
local	dwMilliseconds:DWORD
local	dwSecond:DWORD
local	dwMinute:DWORD
local	dwHour:DWORD
local	dwDay:DWORD

	mov ecx,pSource
ifdef _DEBUG
	@trace <"SystemTimeToFileTime(">
	movzx eax,[ecx].SYSTEMTIME.wYear
	@tracedw eax
	@trace <"/">
	movzx eax,[ecx].SYSTEMTIME.wMonth
	@tracedw eax
	@trace <"/">
	movzx eax,[ecx].SYSTEMTIME.wDay
	@tracedw eax
	@trace <" ">
	movzx eax,[ecx].SYSTEMTIME.wHour
	@tracedw eax
	@trace <":">
	movzx eax,[ecx].SYSTEMTIME.wMinute
	@tracedw eax
	@trace <":">
	movzx eax,[ecx].SYSTEMTIME.wSecond
	@tracedw eax
	@trace <")",13,10>
endif
	movsx eax,[ecx].SYSTEMTIME.wDay
	dec eax
	mov dwDay,eax
	movsx esi,[ecx].SYSTEMTIME.wMonth
	movsx edx,[ecx].SYSTEMTIME.wHour
	movsx ebx,[ecx].SYSTEMTIME.wMinute
	dec esi
	mov dwHour,edx
	mov dwMinute,ebx
	movsx edi,[ecx].SYSTEMTIME.wYear
	movsx eax,[ecx].SYSTEMTIME.wSecond
	movsx edx,[ecx].SYSTEMTIME.wMilliseconds
	mov dwSecond,eax
	mov dwMilliseconds,edx

	cmp edi,1601				;year must be >= 1601
	jc error1
	cmp esi,11					;month must be 0-11
	ja error2
	@mov ecx,400
	mov eax,edi
	sub edx,edx
	div ecx
	test edx,edx					;year/400 no rest?
	jz IsLeap
	@mov ecx,100
	mov eax,edi
	sub edx,edx
	div ecx
	test edx,edx					;year/100 no rest?
	jz IsNoLeap
	test edi,3
	jz IsLeap
IsNoLeap:
	movsx ecx,word ptr [MonthTab2 + esi*2 + sizeof WORD]
	movsx edx,word ptr [MonthTab2 + esi*2]
	sub ecx,edx
	jmp @F
IsLeap:
	movsx ecx,word ptr [MonthTab1 + esi*2 + sizeof WORD]
	movsx eax,word ptr [MonthTab1 + esi*2]
	sub ecx,eax
@@:
	mov eax,dwDay
	cmp eax,ecx						;day ok?
	jge error3
	cmp dwHour,23
	ja error4
	cmp dwMinute,59
	ja error5
	cmp dwSecond,59
	ja error6
	cmp dwMilliseconds,999
	ja error7

;--- all fields in SYSTEMTIME are checked now
;--- edi = year
;--- esi = month

	lea ecx,[edi-1601]
	sub edx,edx
	mov ebx,ecx
	mov eax,ecx
	mov dwTemp,100
	div dwTemp
	mov dwTemp,400
	shr ebx,02
	sub edx,edx
	sub ebx,eax
	mov eax,edi
	imul eax,eax,365
	add ebx,eax
	mov eax,ecx
	div dwTemp
	mov dwTemp,400
	lea ecx,[ebx+eax*1-08EAADh]	;8EAAD = days until 31.12.1600
	sub edx,edx
	lea ebx,[edi-1600]
	mov eax,ebx
	div dwTemp
	test edx,edx
	jz IsLeap2
	mov eax,ebx
	sub edx,edx
	mov dwTemp,100
	div dwTemp
	test edx,edx
	jz IsNoLeap2
	test edi,3
	jz IsLeap2
IsNoLeap2:
	movsx eax,word ptr [MonthTab2 + esi*2]
	jmp @F
IsLeap2:
	movsx eax,word ptr [MonthTab1 + esi*2]
@@:
	add ecx,eax
	mov eax,dwHour
	imul eax,eax,60
	add ecx,dwDay
	add eax,dwMinute
	imul eax,eax,60
	add eax,dwSecond
	imul eax,eax,1000
	add dwMilliseconds, eax

	mov eax,ecx
	mov ecx,24*60*60*1000			;milliseconds a day
	imul ecx

	add eax,dwMilliseconds
	adc edx,0

	invoke _mul64, edx::eax, 10000	;multiply with 10000 -> 100 ns units

	mov ecx,pDest
	mov [ecx].FILETIME.dwLowDateTime,eax
	mov [ecx].FILETIME.dwHighDateTime,edx
	@mov eax,1
done:
	ret
error1:
ifdef _DEBUG
	mov cl,1
	jmp error
endif
error2:
ifdef _DEBUG
	mov cl,2
	jmp error
endif
error3:
ifdef _DEBUG
	mov cl,3
	jmp error
endif
error4:
ifdef _DEBUG
	mov cl,4
	jmp error
endif
error5:
ifdef _DEBUG
	mov cl,5
	jmp error
endif
error6:
ifdef _DEBUG
	mov cl,6
	jmp error
endif
error7:
ifdef _DEBUG
	mov cl,7
	jmp error
endif
error:
	@trace <"SystemTimeToFileTime() failed, reason=">
ifdef _DEBUG
	movzx ecx,cl
	@tracedw ecx
endif
	@trace <13,10>
	xor eax,eax
	jmp done
	align 4

SystemTimeToFileTime endp


;-------------------------------------------------------------------------------------------

GetDaysAndMSecs proto :ptr FILETIME, :ptr DWORD, :ptr DWORD
DaysToYears		proto :DWORD


FileTimeToSystemTime proc public uses ebx esi edi pSource:ptr FILETIME, pDest:ptr SYSTEMTIME

local	dwDays:DWORD
local	dwMilliseconds:DWORD
local	dwSeconds:DWORD
local	dwTemp2:DWORD

	invoke GetDaysAndMSecs, pSource, addr dwDays, addr dwMilliseconds
	mov eax,dwDays
	@mov ecx,7					;days a week
	inc eax
	sub edx,edx
	div ecx
	mov esi,pDest
	mov [esi].SYSTEMTIME.wDayOfWeek,dx

	invoke DaysToYears, dwDays

	mov edi,eax
	mov ecx,eax
	shr eax,02
	sub edx,edx
	imul edi,edi,-365
	sub edi,eax
	mov ebx,400
	mov eax,ecx
	div ebx
	sub edi,eax
	sub edx,edx
	mov eax,ecx
	@mov ebx,100
	div ebx
	add edi,eax
	sub edx,edx
	mov ebx,400

	add dwDays,edi

	lea edi,[ecx+01h]
	mov eax,edi
	div ebx
	test edx,edx
	jz IsLeap3
	@mov ebx,100
	mov eax,edi
	sub edx,edx
	div ebx
	test edx,edx
	jz IsNoLeap3
	test edi,3
	jz IsLeap3
IsNoLeap3:
	@mov edi,365
	mov eax,dwDays
	sub edx,edx
	div edi
	movzx edi,byte ptr [edx + DayTab2]
	movsx eax,word ptr [MonthTab2 + edi*2]
	jmp @F
IsLeap3:
	@mov edi,366
	mov eax,dwDays
	sub edx,edx
	div edi
	movzx edi,byte ptr [edx + DayTab1]
	movsx eax,word ptr [MonthTab1 + edi*2]
@@:
	@mov ebx,1000
	sub edx,edx
	sub dwDays,eax
	mov eax,dwMilliseconds
	div ebx
	sub edx,edx
	mov dwSeconds,eax

	mov eax,dwMilliseconds
	div ebx
	mov eax,dwSeconds
	@mov ebx,60
	mov dwMilliseconds,edx

	sub edx,edx
	div ebx
	sub edx,edx
	mov dwTemp2,eax
	mov eax,dwSeconds
	div ebx
	mov eax,dwTemp2
	mov dwSeconds,edx
	add cx,1601
	sub edx,edx
	div ebx
	inc edi
	sub edx,edx
	mov [esi].SYSTEMTIME.wYear,cx
	mov cx,ax
	mov eax,dwTemp2
	div ebx
	mov [esi].SYSTEMTIME.wMonth,di
	mov eax,dwDays
	inc eax
	mov [esi].SYSTEMTIME.wDay,ax
	mov eax,dwMilliseconds
	mov [esi].SYSTEMTIME.wHour,cx
	mov [esi].SYSTEMTIME.wMinute,dx
	mov edx,dwSeconds
	mov [esi].SYSTEMTIME.wSecond,dx
	mov [esi].SYSTEMTIME.wMilliseconds,ax

ifdef _DEBUG
	@trace <"FileTimeToSystemTime(">
	@tracedw pSource
	@trace <", ">
	@tracedw pDest
	@trace <" [">

	movzx eax,[esi].SYSTEMTIME.wYear
	@tracedw eax
	@trace <"/">
	movzx eax,[esi].SYSTEMTIME.wMonth
	@tracedw eax
	@trace <"/">
	movzx eax,[esi].SYSTEMTIME.wDay
	@tracedw eax
	@trace <" ">
	movzx eax,[esi].SYSTEMTIME.wHour
	@tracedw eax
	@trace <":">
	movzx eax,[esi].SYSTEMTIME.wMinute
	@tracedw eax
	@trace <":">
	movzx eax,[esi].SYSTEMTIME.wSecond
	@tracedw eax
	@trace <"])",13,10>
endif

	@mov eax,1
	ret
	align 4

FileTimeToSystemTime endp

GetDaysAndMSecs proc uses ebx pSource:ptr FILETIME, pDays:ptr DWORD, pMilliseconds:ptr DWORD

	.const

g_Const1 label qword
	dd 0E219652Ch, 0D1B71758h
g_Const2 label qword
	dd 0FA67B90Eh, 0C6D750EBh

	.code

	mov eax,pSource
	invoke _div64, qword ptr [eax].FILETIME.dwLowDateTime, g_Const1, 0Dh
;------------------------------- save milliseconds        
	push edx
	push eax

	invoke _div64, edx::eax, g_Const2, 1Ah

	mov edx,pDays
	mov [edx],eax					;days since 1.1.1601

	mov ecx,24*60*60*1000			;milliseconds a day
	imul ecx

	mov ecx, eax
	mov ebx, edx

	pop eax
	pop edx

	sub eax, ecx
	sbb edx, ebx

	mov edx,pMilliseconds
	mov [edx],eax					;milliseconds current day

	ret
	align 4

GetDaysAndMSecs endp


DaysToYears proc uses ebx esi edi dwDays:DWORD

;--- 1. value / 146097 * -146097

	mov ecx,00023AB1h				;146097
	sub edx,edx
	mov esi,dwDays
	mov eax,esi
	div ecx
	mov edi,eax
	mov ecx,0037BB49h				;3652425
	imul eax,eax,0FFFDC54Fh		;-146097
	add esi,eax
	sub edx,edx
	mov eax,esi
	imul eax,eax,100
	add eax,+4Bh					;75
	div ecx
	mov ebx,eax
	mov ecx,000005B5h				;1461
	imul eax,eax,0FFFF7154h		;-36524
	add esi,eax
	sub edx,edx
	mov eax,esi
	lea edi,[ebx+edi*4]
	div ecx
	imul edi,edi,19h				;25
	mov ecx,eax
	add edi,eax
	imul ecx,ecx,0FFFFFA4Bh		;-1461
	sub edx,edx
	lea eax,[esi+ecx*1]
	imul eax,eax,100
	mov ecx,00008EADh				;36525
	add eax,+4Bh					;75
	div ecx
	lea eax,[eax+edi*4]
	ret
	align 4
DaysToYears endp

else

FileTimeToSystemTime proc public uses ebx pSource:ptr FILETIME, pDest:ptr SYSTEMTIME

	mov edx, pDest
	mov ecx, pSource
	mov ebx, [ecx].FILETIME.dwHighDateTime
	xor eax, eax
	mov al, bl
;;	mov [edx].SYSTEMTIME.wDayOfWeek, ax
	mov [edx].SYSTEMTIME.wDayOfWeek, 0
	mov al, bh
	mov [edx].SYSTEMTIME.wDay, ax
	shr ebx, 16
	mov al, bl
	mov [edx].SYSTEMTIME.wMonth, ax
	mov al, bh
	add ax, 1980
	mov [edx].SYSTEMTIME.wYear, ax

	mov ebx, [ecx].FILETIME.dwLowDateTime
	movzx eax, bl
	shl ax, 4
	mov [edx].SYSTEMTIME.wMilliseconds, ax
	movzx ax, bh
	mov [edx].SYSTEMTIME.wSecond, ax
	shr ebx, 16
	mov al, bl
	mov [edx].SYSTEMTIME.wMinute, ax
	mov al, bh
	mov [edx].SYSTEMTIME.wHour, ax
	@mov eax, 1
	@strace <"FileTimeToSystemTime(", pSource, ", ", pDest, ")=", eax>
	ret
	align 4

FileTimeToSystemTime endp

;--- systime (yy,mm, dow, day, hour, min, sec)
;--- filetime: normally 64 bit integer (1.1.1601)
;--- but a simplified use here

SystemTimeToFileTime proc public pSource:ptr SYSTEMTIME, pDest:ptr FILETIME

	mov edx, pSource
	mov ah, byte ptr [edx].SYSTEMTIME.wHour
	mov al, byte ptr [edx].SYSTEMTIME.wMinute
	shl eax, 16
	mov ah, byte ptr [edx].SYSTEMTIME.wSecond
	mov cx, [edx].SYSTEMTIME.wMilliseconds
	shr cx, 4
	mov al, cl
	mov ecx, pDest
	mov [ecx].FILETIME.dwLowDateTime, eax

	mov ax, [edx].SYSTEMTIME.wYear
	sub ax, 1980
	shl eax, 8
	mov al, byte ptr [edx].SYSTEMTIME.wMonth
	shl eax, 8
	mov al, byte ptr [edx].SYSTEMTIME.wDay
	shl eax, 8
;;	mov al, byte ptr [edx].SYSTEMTIME.wDayOfWeek
	mov al, 0								;dont use day of week 
	mov [ecx].FILETIME.dwHighDateTime, eax
	@mov eax, 1
	@strace <"SystemTimeToFileTime(", pSource, ", ", pDest, ")=", eax>
	ret
	align 4

SystemTimeToFileTime endp

endif


FileTimeToLocalFileTime proc public pSource:ptr FILETIME, pDest:ptr FILETIME

	mov ecx,pSource
	mov eax,[ecx].FILETIME.dwLowDateTime
	mov edx,[ecx].FILETIME.dwHighDateTime
	call systemtolocal
	mov ecx,pDest
	mov [ecx].FILETIME.dwLowDateTime,eax
	mov [ecx].FILETIME.dwHighDateTime,edx
	@mov eax,1
	@strace <"FileTimeToLocalFileTime(", pSource, ", ", pDest, ")=", eax>
	ret
	align 4

FileTimeToLocalFileTime endp

LocalFileTimeToFileTime proc public pSource:ptr FILETIME, pDest:ptr FILETIME

	mov ecx,pSource
	mov eax,[ecx].FILETIME.dwLowDateTime
	mov edx,[ecx].FILETIME.dwHighDateTime
	call localtosystem
	mov ecx,pDest
	mov [ecx].FILETIME.dwLowDateTime,eax
	mov [ecx].FILETIME.dwHighDateTime,edx
	@mov eax,1
	@strace <"LocalFileTimeToFileTime(", pSource, ", ", pDest, ")=", eax>
	ret
	align 4

LocalFileTimeToFileTime endp

	end
