
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

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

	.CODE

CancelIo proc public uses esi edi hFile:DWORD

	mov edi, fs:[THREAD_INFORMATION_BLOCK.ptibSelf]
	add edi, ?ASYNCSTART
	mov esi, [edi]
	.while (esi)
		mov eax, hFile
		.if (eax == [esi].ASYNCFILE.handle)
			mov edx, [esi].ASYNCFILE.lpOverlapped
			push edx
			push [edx].OVERLAPPED.InternalHigh
			push ERROR_OPERATION_ABORTED
			call [esi].ASYNCFILE.lpCompletionRoutine
			mov eax, [esi]
			mov [edi], eax
			invoke LocalFree, esi
			mov esi, [edi]
		.else
			mov edi, esi
			mov esi, [esi]
		.endif
	.endw
	@mov eax, 1
	@strace <"CancelIo(", hFile, ")=", eax>
	ret

CancelIo endp

	end
