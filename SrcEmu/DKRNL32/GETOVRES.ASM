
;--- implements GetOverlappedResult

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

	.code

GetOverlappedResult proc public uses ebx hFile:DWORD, lpOverlapped:ptr OVERLAPPED, lpNumberOfBytesTransfered:ptr DWORD, bWait:DWORD

	mov ebx, lpOverlapped
	.if (bWait)

;--- for win9x the hEvent member MUST be set.
;--- for NT, the wait is done on the file handle itself
;--- which is not recommended, however. And not possible with dkrnl32!

		.if (![ebx].OVERLAPPED.hEvent)
			xor eax, eax
			jmp exit
		.endif
		invoke WaitForSingleObject, [ebx].OVERLAPPED.hEvent, INFINITE
	.else
		.if (![ebx].OVERLAPPED.InternalHigh)
			invoke SetLastError, ERROR_IO_INCOMPLETE
			xor eax, eax
			jmp exit
		.endif
	.endif
	mov ecx, lpNumberOfBytesTransfered
	mov eax, [ebx].OVERLAPPED.InternalHigh
	mov [ecx], eax
	@mov eax, 1
exit:
	@strace <"GetOverlappedResult(", hFile, ", ", lpOverlapped, ", ", lpNumberOfBytesTransfered, ", ", bWait, ")=", eax>
	ret
	align 4

GetOverlappedResult endp

	end
