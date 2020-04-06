
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

?LOCAL2SYS	equ 1

	.CODE

GetFileTime proc public uses ebx esi handle:dword, pCreation:ptr FILETIME,
		pLastAcc:ptr FILETIME, pLastWrite:ptr FILETIME

local	dwDate:DWORD
local	dwTime:DWORD

		mov ebx,handle
		mov ax,5700h	  ;get last write time/date (CX/DX)
		int 21h
		jc error
		mov dwDate, edx
		mov dwTime, ecx
		.if (pLastWrite)
			invoke _DosDateTimeToFileTime, edx, ecx, pLastWrite
		.endif
		.if (pLastAcc)
			mov ax,5704h	  ;get last access time/date (CX/DX)
			int 21h
			.if (CARRY?)
				mov ecx, dwTime
				mov edx, dwDate
			.endif
			invoke _DosDateTimeToFileTime, edx, ecx, pLastAcc
		.endif
		.if (pCreation)
			mov ax,5706h	  ;get creation time/date (CX/DX)
			int 21h
			.if (CARRY?)
				mov ecx, dwTime
				mov edx, dwDate
			.endif
			invoke _DosDateTimeToFileTime, edx, ecx, pCreation
		.endif
		@mov eax,1
		jmp exit
error:
		xor eax, eax
exit:        
	@strace <"GetFileTime(", handle, ", ", pCreation, ", ", pLastAcc, ", ", pLastWrite, ")=", eax>
	ret
GetFileTime endp

	end
