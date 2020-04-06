
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

;--- the following switches may cause dkrnl32 to ignore
;--- failures of setting "lastacc" or "creation" date/time 
;--- but only if setting "last write" succeeded

?IGNORE_CREATION_ERROR	equ 1
?IGNORE_LASTACC_ERROR	equ 1

	.CODE

SetFileTime proc public uses ebx esi edi handle:dword,pCreation:ptr FILETIME,
			pLastAcc:ptr FILETIME,pLastWrite:ptr FILETIME

local	dwDate:dword
local	dwTime:dword

	xor edi, edi
	mov ebx,handle
	.if (pLastWrite)
		invoke _FileTimeToDosDateTime, pLastWrite, addr dwDate, addr dwTime
		mov edx, dwDate
		mov ecx, dwTime
		mov ax,5701h		;set last write time/date (CX/DX)
		int 21h
		.if (CARRY?)
ifdef _DEBUG
			@trace <"int 21h, ax=5701h (set last write date/time) failed",13,10>
endif
			or edi,1
			jmp exit@
		.endif
	.endif
	.if (pLastAcc)
		invoke _FileTimeToDosDateTime, pLastAcc, addr dwDate, addr dwTime
		mov edx, dwDate
if 0
		mov ecx, dwTime
else
		xor ecx, ecx		;must be NULL
endif
		mov ax,5705h		;set last Acc time/date (CX/DX)
		int 21h
if ?IGNORE_LASTACC_ERROR		   ;may fail!
		.if (CARRY? && (!pLastWrite))
else
		.if (CARRY?)
endif
ifdef _DEBUG
			@trace <"int 21h, ax=5705h (set last access date/time) failed",13,10>
endif
			or edi,2
		.endif
	.endif
	.if (pCreation)
		invoke _FileTimeToDosDateTime, pCreation, addr dwDate, addr dwTime
		mov edx, dwDate
		mov ecx, dwTime
		mov si, 50			;milliseconds 10 units
		mov ax,5707h		;set creation time/date (CX/DX)
		int 21h
if ?IGNORE_CREATION_ERROR		   ;may fail!
		.if (CARRY? && (!pLastWrite))
else
		.if (CARRY?)
endif
ifdef _DEBUG
			@trace <"int 21h, ax=5707h, bx=">
			movzx ebx,bx
			@tracedw ebx
			@trace <" (set creation date/time) failed [">
			movzx eax, ax
			@tracedw eax
			@trace <"]",13,10>
			@trace <"date[dx]=">
			movzx eax, word ptr dwDate
			shr ax, 5+4
			@tracedw eax
			@trace <"/">
			movzx eax, word ptr dwDate
			shr ax, 5
			and ax, 0Fh
			@tracedw eax
			@trace <"/">
			movzx eax, word ptr dwDate
			and ax, 1Fh
			@tracedw eax

			@trace <" time[cx]=">
			movzx eax, word ptr dwTime
			shr ax, 5+6
			@tracedw eax
			@trace <":">
			movzx eax, word ptr dwTime
			shr ax, 5
			and ax, 3Fh
			@tracedw eax
			@trace <":">
			movzx eax, word ptr dwTime
			and ax, 1Fh
			@tracedw eax
			@trace <13,10>
endif
			or edi,4
		.endif
	.endif
exit@:
	xor eax,eax
	.if (!edi)
		inc eax
	.endif
	@strace <"SetFileTime(", handle, ", ", pCreation, ", ", pLastAcc, ", ", pLastWrite, ")=", eax>
	ret

SetFileTime endp

	end
