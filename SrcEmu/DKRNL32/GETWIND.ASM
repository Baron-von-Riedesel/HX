
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

	.CODE

GetSystemWindowsDirectoryA proc public pBuffer:ptr WORD, nSize:DWORD
GetSystemWindowsDirectoryA endp

GetWindowsDirectoryA proc public pBuffer:ptr byte, nSize:DWORD

if 1
	invoke GetSystemDirectoryA, pBuffer, nSize
else
	mov ecx, pBuffer
	mov dword ptr [ecx],"\:C"
	mov eax, 3
endif
	@strace <"GetWindowsDirectoryA(", pBuffer, ", ", nSize, ")=", eax>
	ret
	align 4
GetWindowsDirectoryA endp

GetSystemWindowsDirectoryW proc public pBuffer:ptr WORD, nSize:DWORD
GetSystemWindowsDirectoryW endp

GetWindowsDirectoryW proc public pBuffer:ptr WORD, nSize:DWORD
	invoke GetWindowsDirectoryA, pBuffer, nSize
	.if (eax && pBuffer)
		invoke ConvertAStr, pBuffer
	.endif
	@strace <"GetWindowsDirectoryW(", pBuffer, ", ", nSize, ")=", eax>
	ret
	align 4
GetWindowsDirectoryW endp

	end

