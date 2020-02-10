
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.DATA

	.CODE

;--- this is in fact rather "dummy". just copy the
;--- memory block. Works if both apps are in same address space
;--- which is true for DPMILD32 with switch DPMILDR=8 NOT set

ReadProcessMemory proc public hProcess:dword,lpBaseAddress:ptr,lpBuffer:ptr,dwSize:dword,pBytesRead:ptr dword

	invoke CopyMemory, lpBuffer, lpBaseAddress, dwSize
	.if (eax)
		mov ecx, pBytesRead
		mov eax, dwSize
		mov [ecx], eax
	.endif
	@strace <"ReadProcessMemory(", hProcess, ", ", lpBaseAddress, ", ", lpBuffer, ", ", dwSize, ", ", pBytesRead, ")=", eax>
	ret
	align 4

ReadProcessMemory endp

WriteProcessMemory proc public hProcess:dword,lpBaseAddress:ptr,lpBuffer:ptr,dwSize:dword,pBytesWritten:ptr dword

	invoke CopyMemory, lpBaseAddress, lpBuffer, dwSize
	.if (eax)
		mov ecx, pBytesWritten
		mov eax, dwSize
		mov [ecx], eax
	.endif
	@strace <"WriteProcessMemory(", hProcess, ", ", lpBaseAddress, ", ", lpBuffer, ", ", dwSize, ", ", pBytesWritten, ")=", eax>
	ret
	align 4

WriteProcessMemory endp

	end

