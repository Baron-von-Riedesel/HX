
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

GetVersionExW proc public pBuffer:ptr OSVERSIONINFO
	mov ecx, pBuffer
	mov [ecx].OSVERSIONINFO.szCSDVersion+1, 0
	invoke GetVersionExA, pBuffer
	@strace <"GetVersionExW(", pBuffer, ")=", eax>
	ret
GetVersionExW endp

	end

