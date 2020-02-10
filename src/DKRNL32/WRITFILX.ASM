
;--- implements WriteFileEx

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

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

	.CODE
        
asyncwrite proc pParams:ptr ASYNCFILE

local	dwWritten:dword

	mov edi, pParams
	mov edx, [edi].ASYNCFILE.lpOverlapped
	.if ([edi].ASYNCFILE.numBytes)
		invoke SetFilePointerEx, [edi].ASYNCFILE.handle, qword ptr [edx].OVERLAPPED.Offset_, 0, FILE_BEGIN
		invoke WriteFile, [edi].ASYNCFILE.handle, [edi].ASYNCFILE.pBuffer,\
			[edi].ASYNCFILE.numBytes, addr dwWritten, 0
	.endif
	invoke GetLastError
	mov edx, [edi].ASYNCFILE.lpOverlapped
	mov ecx, dwWritten
	mov [edx].OVERLAPPED.Internal, eax	;error code
	mov [edx].OVERLAPPED.InternalHigh, ecx
	or [edi].ASYNCFILE.dwFlags, 1
	.if ([edx].OVERLAPPED.hEvent)
		invoke SetEvent, [edx].OVERLAPPED.hEvent
	.endif
	ret
	align 4
asyncwrite endp

WriteFileEx proc public uses ebx handle:dword, pBuffer:dword,
		numBytes:dword, lpOverlapped:ptr OVERLAPPED, lpCompletionRoutine:ptr

local	threadid:dword

	invoke LocalAlloc, LMEM_FIXED, sizeof ASYNCFILE
	.if (eax)
		mov ebx, eax
		mov eax, handle
		mov ecx, pBuffer
		mov edx, numBytes
		mov [ebx].ASYNCFILE.handle, eax
		mov [ebx].ASYNCFILE.pBuffer, ecx
		mov [ebx].ASYNCFILE.numBytes, edx
		mov ecx, lpOverlapped
		mov edx, lpCompletionRoutine
		xor eax, eax
		mov [ebx].ASYNCFILE.dwFlags, eax
		mov [ebx].ASYNCFILE.lpOverlapped, ecx
		mov [ebx].ASYNCFILE.lpCompletionRoutine, edx
		mov eax, ebx
		xchg eax, fs:[?ASYNCSTART]
		mov [ebx], eax
		invoke CreateThread, 0, 1000h, asyncwrite, ebx, 0, addr threadid
	.endif
	ret
	align 4
WriteFileEx endp

	END
