
;--- implements:
;--- CreateNamedPipeA
;--- PeekNamedPipe
;--- GetNamedPipeHandleStateA
;--- SetNamedPipeHandleState
;--- GetNamedPipeInfo
;--- WaitNamedPipeA
;--- ConnectNamedPipe
;--- DisconnectNamedPipe

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include winerror.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

if 1
CreateNamedPipeA proc public lpName:ptr BYTE, dwOpenMode:dword, dwPipeMode:dword,nMaxInstances:dword,
		nOutBufferSize:dword, nInBufferSize:dword, nDefaultTimeOut:dword, lpSecurity:ptr
	xor eax, eax
	@strace <"CreateNamedPipeA(",  lpName, ", ", dwOpenMode, ", ", dwPipeMode, ", ", nMaxInstances, ", ", nOutBufferSize, ", ", nInBufferSize, ", ", nDefaultTimeOut, ")=", eax>
	ret
	align 4
CreateNamedPipeA endp
endif

;--- PeekNamedPipe accepts handles to both named and anonymous pipes!

PeekNamedPipe proc public handle:dword,lpbuffer:dword,
                           nsize:dword,lpBytesRead:ptr dword,pTotalBytes:dword,
                           pBytesLeft:dword
local	dwCurPos:DWORD
local	dwRead:DWORD

	.if (!lpBytesRead)
		lea eax, dwRead
		mov lpBytesRead, eax
	.endif

	invoke SetFilePointer, handle, 0, 0, FILE_CURRENT
	mov dwCurPos, eax
	cmp eax,-1
	jz error
	.if (lpbuffer && nsize)
		invoke ReadFile, handle, lpbuffer, nsize, lpBytesRead, 0
	.endif
	.if (pTotalBytes)
		invoke SetFilePointer, handle, 0, 0, FILE_END
		sub eax, dwCurPos
		mov ecx, pTotalBytes
		mov [ecx],eax
	.endif
	invoke SetFilePointer, handle, dwCurPos, 0, FILE_BEGIN
	@mov eax, 1
exit:
	@strace <"PeekNamedPipe(", handle, ", ", lpbuffer, ", ", nsize, ", ", lpBytesRead, ", ", pTotalBytes, ", ", pBytesLeft, ")=", eax>
	ret
error:
	invoke SetLastError, ERROR_INVALID_HANDLE
	xor eax,eax
	jmp exit
	align 4

PeekNamedPipe endp

GetNamedPipeHandleStateA proc public handle:dword, lpState:ptr dword, lpCurInstances:ptr dword, lpMaxCollectionCount:ptr dword,
		lpCollectDataTimeout:ptr dword, lpUserName:ptr BYTE, nMaxUserNameSize:dword

	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax,eax
	@strace <[ebp+4],": GetNamedPipeHandleStateA(", handle, ", ", lpState, ", ", lpCurInstances, ", ", lpMaxCollectionCount, ", ", lpCollectDataTimeout, ", ", lpUserName, ", ", nMaxUserNameSize, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetNamedPipeHandleStateA endp

SetNamedPipeHandleState proc public handle:dword, lpMode:ptr dword, lpMaxCollectionCount:ptr dword, lpCollectDataTimeout:ptr dword

	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax,eax
	@strace <[ebp+4],": SetNamedPipeHandleState(", handle, ", ", lpMode, ", ", lpMaxCollectionCount, ", ", lpCollectDataTimeout, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetNamedPipeHandleState endp

;--- on Win2k/XP, GetNamedPipeInfo also works for anonymous pipes!

GetNamedPipeInfo proc public handle:dword, lpFlags:ptr dword, lpOutBufferSize:ptr dword, lpInBufferSize:ptr dword, lpMaxInstances:ptr dword

	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax,eax
	mov ecx, lpFlags
	jecxz @F
	mov [ecx],eax
@@:
	mov ecx, lpOutBufferSize
	jecxz @F
	mov [ecx],eax
@@:
	mov ecx, lpInBufferSize
	jecxz @F
	mov [ecx],eax
@@:
	mov ecx, lpMaxInstances
	jecxz @F
	mov [ecx],eax
@@:
	@strace <[ebp+4],": GetNamedPipeInfo(", handle, ", ", lpFlags, ", ", lpOutBufferSize, ", ", lpInBufferSize, ", ", lpMaxInstances, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetNamedPipeInfo endp

WaitNamedPipeA proc public lpNamedPipeName:ptr BYTE, nTimeOut:dword

	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax,eax
	@strace <[ebp+4],": WaitNamedPipeA(", lpNamedPipeName, ", ", nTimeOut, ")=", eax, " *** unsupp ***">
	ret
	align 4

WaitNamedPipeA endp

ConnectNamedPipe proc public hNamedPipe:DWORD, lpOverlapped:ptr

	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax, eax
	@strace <"ConnectNamedPipe(", hNamedPipe, ", ", lpOverlapped, ")=", eax, " *** unsupp ***">
	ret
	align 4

ConnectNamedPipe endp

DisconnectNamedPipe proc public hNamedPipe:DWORD

	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax, eax
	@strace	<"DisconnectNamedPipe(", hNamedPipe, ")=", eax, " *** unsupp ***">
	ret
	align 4

DisconnectNamedPipe endp

	end
