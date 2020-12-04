
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

	.CODE

CommDlgExtendedError proc public
	xor eax, eax
	@strace <"CommDlgExtendedError()=", eax>
	ret
	align 4
CommDlgExtendedError endp

GetOpenFileNameA proc public lpOFN:ptr
	xor eax, eax
	@strace <"GetOpenFileNameA(", lpOFN, ")=", eax>
	ret
	align 4
GetOpenFileNameA endp

GetOpenFileNameW proc public lpOFN:ptr
	xor eax, eax
	@strace <"GetOpenFileNameW(", lpOFN, ")=", eax>
	ret
	align 4
GetOpenFileNameW endp

GetSaveFileNameA proc public lpSFN:ptr
	xor eax, eax
	@strace <"GetSaveFileNameA(", lpSFN, ")=", eax>
	ret
	align 4
GetSaveFileNameA endp

PrintDlgA proc public lpPD:ptr
	xor eax, eax
	@strace <"PringDlgA(", lpPD, ")=", eax>
	ret
	align 4
PrintDlgA endp

GetFileTitleA proc public lpszFile:ptr BYTE, lpszTitle: ptr BYTE, cbBuf:dword
	invoke lstrlen, lpszFile
	inc eax
	.if (lpszTitle && cbBuf >= eax)
		invoke RtlMoveMemory, lpszTitle, lpszFile, eax
		xor eax, eax
	.endif
	@strace <"GetFileTitleA(", lpszFile, ", ", lpszTitle, ", ", cbBuf, ")=", eax>
	ret
	align 4
GetFileTitleA endp

	end
