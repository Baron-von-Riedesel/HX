
;--- communication API

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private
	option dotname

	include winbase.inc
	include winioctl.inc
	include dkrnl32.inc
	include macros.inc

	.code

if ?COMMSUPP
	include INCLUDE\comm.inc
else
ClearCommBreak proc public hFile:dword
	xor eax, eax
	@strace <"ClearCommBreak(", hFile, ")=", eax>
	ret
	align 4
ClearCommBreak endp
SetCommBreak proc public hFile:dword
	xor eax,eax
	@strace <"SetCommBreak(", hFile, ")=", eax>
	ret
	align 4
SetCommBreak endp
ClearCommError proc public hFile:dword, lpErrors:ptr DWORD, lpStat:ptr COMSTAT
	xor eax, eax
	@strace <"ClearCommError(", hFile, ", ", lpErrors, ", ", lpStat, ")=", eax>
	ret
	align 4
ClearCommError endp
GetCommModemStatus proc public hFile:dword, lpModemStat:ptr DWORD
	xor eax, eax
	@strace <"GetCommModemStatus(", hFile, ", ", lpModemStat, ")=", eax>
	ret
	align 4
GetCommModemStatus endp
GetCommState proc public hFile:dword, lpDCB:ptr DCB
	xor eax, eax
	@strace <"GetCommState(", hFile, ", ", lpDCB, ")=", eax>
	ret
	align 4
GetCommState endp
SetCommState proc public hFile:dword, lpDCB:ptr DCB
	xor eax, eax
	@strace <"SetCommState(", hFile, ", ", lpDCB, ")=", eax>
	ret
	align 4
SetCommState endp
GetCommConfig proc public hCommDev:DWORD, lpCC:ptr COMMCONFIG, lpdwSize: ptr DWORD
	xor eax, eax
	@strace <"GetCommConfig(", hCommDev, ", ", lpCC, ", ", lpdwSize, ")=", eax>
	ret
	align 4
GetCommConfig endp
SetCommConfig proc public hCommDev:DWORD, lpCC:ptr COMMCONFIG, dwSize: DWORD
	xor eax, eax
	@strace <"SetCommConfig(", hCommDev, ", ", lpCC, ", ", dwSize, ")=", eax>
	ret
	align 4
SetCommConfig endp
GetDefaultCommConfigA proc public lpszName:ptr BYTE, lpCC:ptr, lpdwSize:ptr DWORD
	xor eax, eax
	@strace <"GetDefaultCommConfigA(", lpszName, ", ", lpCC, ", ", lpdwSize, ")=", eax>
	ret
	align 4
GetDefaultCommConfigA endp
SetDefaultCommConfigA proc public lpszName:ptr BYTE, lpCC:ptr, dwSize:DWORD
	xor eax, eax
	@strace <"SetDefaultCommConfigA(", lpszName, ", ", lpCC, ", ", dwSize, ")=", eax>
	ret
	align 4
SetDefaultCommConfigA endp
GetCommTimeouts proc public hFile:dword, lpCommTimeouts:ptr COMMTIMEOUTS
	xor eax, eax
	@strace <"GetCommTimeouts(", hFile, ", ", lpCommTimeouts, ")=", eax>
	ret
	align 4
GetCommTimeouts endp
SetCommTimeouts proc public hFile:dword, lpTimeouts:ptr COMMTIMEOUTS
	xor eax, eax
	@strace <"SetCommTimeouts(", hFile, ", ", lpTimeouts, ")=", eax>
	ret
	align 4
SetCommTimeouts endp
GetCommMask proc public hFile:dword, lpEvtMask:ptr DWORD
	xor eax, eax
	@strace <"GetCommMask(", hFile, ", ", lpEvtMask, ")=", eax>
	ret
	align 4
GetCommMask endp
SetCommMask proc public hFile:dword, dwEvtMask:DWORD
	xor eax, eax
	@strace <"SetCommMask(", hFile, ", ", dwEvtMask, ")=", eax>
	ret
	align 4
SetCommMask endp
WaitCommEvent proc public hFile:dword, lpEvtMask:ptr DWORD, lpOverlapped:ptr OVERLAPPED
	xor eax, eax
	@strace <"WaitCommEvent(", hFile, ", ", lpEvtMask, ", ", lpOverlapped, ")=", eax>
	ret
	align 4
WaitCommEvent endp
PurgeComm proc public hFile:dword, dwFlags:DWORD
	xor eax, eax
	@strace <"PurgeComm(", hFile, ", ", dwFlags, ")=", eax>
	ret
	align 4
PurgeComm endp
TransmitCommChar proc public hFile:dword, cChar:dword
	xor eax, eax
	@strace <"TransmitCommChar(", hFile, ", ", cChar, ")=", eax>
	ret
	align 4
TransmitCommChar endp
EscapeCommFunction proc public hFile:dword, dwFunc:dword
	xor eax, eax
	@strace <"EscapeCommFunction(", hFile, ", ", dwFunc, ")=", eax>
	ret
	align 4
EscapeCommFunction endp
GetCommProperties proc public hFile:dword, lpCommProp
	xor eax, eax
	@strace <"GetCommProperties(", hFile, ", ", lpCommProp, ")=", eax>
	ret
	align 4
GetCommProperties endp
BuildCommDCBAndTimeoutsA proc public lpDef:ptr BYTE, lpDCB:ptr DCB, lpCommTimeouts:ptr COMMTIMEOUTS
	xor eax,eax
	@strace <"BuildCommDCBAndTimeoutsA(", lpDef, ", ", lpDCB, ", ", lpCommTimeouts, ")=", eax>
	ret
	align 4
BuildCommDCBAndTimeoutsA endp
BuildCommDCBA proc public lpDef:ptr BYTE, lpDCB:ptr DCB
	xor eax,eax
	@strace <"BuildCommDCBAA(", lpDef, ", ", lpDCB, ")=", eax>
	ret
	align 4
BuildCommDCBA endp
SetupComm proc public hFile:DWORD, dwInQueue:DWORD, dwOutQueue:DWORD
	xor eax, eax
	@strace <"SetupComm(", hFile, ", ", dwInQueue, ", ", dwOutQueue, ")=", eax>
	ret
	align 4
SetupComm endp
CommConfigDialogA proc public lpszName:ptr BYTE, hWnd:DWORD, lpCC:ptr
	xor eax, eax
	@strace <"CommConfigDialogA(", lpszName, ", ", hWnd, ", ", lpCC, ")=", eax>
	ret
	align 4
CommConfigDialogA endp
endif

	end
