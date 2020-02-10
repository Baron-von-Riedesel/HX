
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

	.CODE

LockFileEx proc public hFile:dword,
				dwFlags:dword, dwReserved:dword,
				dwNumBytesLow:dword, dwNumBytesHigh:dword,
				lpOverlapped:ptr OVERLAPPED

	xor eax,eax
	@strace <"LockFileEx(", hFile, ", ", dwFlags, ", ", dwReserved, ", ", dwNumBytesLow, ", ", dwNumBytesHigh, ", ", lpOverlapped, ")=", eax, " *** unsupp ***">
	ret
	align 4
LockFileEx endp

UnlockFileEx proc public hFile:dword,
				dwReserved:dword,
				dwNumBytesLow:dword, dwNumBytesHigh:dword,
				lpOverlapped:ptr OVERLAPPED

	xor eax,eax
	@strace <"UnlockFileEx(", hFile, ", ", dwReserved, ", ", dwNumBytesLow, ", ", dwNumBytesHigh, ", ", lpOverlapped, ")=", eax, " *** unsupp ***">
	ret
	align 4
UnlockFileEx endp

	end

