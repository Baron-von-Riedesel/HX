
;--- implements GetStartupInfoA

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc

	.CODE

;--- void GetStartupInfoA(lpStartupInfo);
;--- this function is called by GetStartupInfoW()!

GetStartupInfoA proc public uses edi pInfo:ptr STARTUPINFOA

	mov edi,pInfo
if 0								;some apps dont supply a full structure!
	add edi,4						;do not touch the cb field
	mov ecx,sizeof STARTUPINFOA/4 - 1
	xor eax,eax
	rep stosd
else
	xor eax,eax
	mov [edi].STARTUPINFOA.lpReserved, eax
	mov [edi].STARTUPINFOA.lpDesktop, eax
	mov [edi].STARTUPINFOA.lpTitle, eax
	mov [edi].STARTUPINFOA.cbReserved2, ax	;DOSXNT needs that
	mov [edi].STARTUPINFOA.lpReserved2, eax	;DOSXNT needs that
	mov [edi].STARTUPINFOA.dwFlags,STARTF_RUNFULLSCREEN
endif
	@strace <"GetStartupInfoA(", pInfo, ")=void">
	ret
	align 4

GetStartupInfoA endp

	end

