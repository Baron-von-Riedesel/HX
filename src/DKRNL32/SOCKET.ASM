
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

;--- the socket handle is valid for DuplicateHandle() and CloseHandle()
;--- so it needs a reference counter

CreateSocketHandle proc public

	invoke KernelHeapAlloc, sizeof SOCKET
	.if (eax)
		mov [eax].SOCKET.dwType, SYNCTYPE_SOCKET
		mov [eax].SOCKET.dwRefCnt, 1
	.endif
	@strace <"CreateSocketHandle()=", eax>
	ret
	align 4

CreateSocketHandle endp

	end

