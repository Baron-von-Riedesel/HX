
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


	.CODE

BackupRead proc public hFile:DWORD, lpBuffer:DWORD, nNumberOfBytesToRead:DWORD,
		lpNumberOfBytesRead:ptr DWORD, bAbort:DWORD, bProcessSecurity:DWORD, lpContext:ptr

	xor eax, eax
	@strace <"BackupRead(", hFile, ", ", lpBuffer, ", ", nNumberOfBytesToRead, ", ",  lpNumberOfBytesRead, ", ", bAbort, ", ", bProcessSecurity, ", ", lpContext, ")=", eax, " *** unsupp ***">
	ret
	align 4

BackupRead endp

BackupSeek proc public hFile:DWORD, dwLowBytesToSeek:DWORD, dwHighBytesToSeek:DWORD,
		lpdwLowBytesSeeked:ptr DWORD, lpdwHighBytesSeeked:ptr DWORD, lpContext:ptr

	xor eax, eax
	@strace <"BackupSeek(", hFile, ", ", dwLowBytesToSeek, ", ", dwHighBytesToSeek, ", ", lpdwLowBytesSeeked, ", ", lpdwHighBytesSeeked, ")=", eax, " *** unsupp ***">
	ret
	align 4

BackupSeek endp

BackupWrite proc public hFile:DWORD, lpBuffer:DWORD, nNumberOfBytesToWrite:DWORD,
		lpNumberOfBytesWritten:ptr DWORD, bAbort:DWORD, bProcessSecurity:DWORD, lpContext:ptr

	xor eax, eax
	@strace <"BackupWrite(", hFile, ", ", lpBuffer, ", ", nNumberOfBytesToWrite, ", ",	lpNumberOfBytesWritten, ", ", bAbort, ", ", bProcessSecurity, ")=", eax, " *** unsupp ***">
	ret
	align 4

BackupWrite endp

	end
