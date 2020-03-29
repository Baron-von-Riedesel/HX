
;--- functions included:
;--- PostMessageW
;--- SendMessageW
;--- PostThreadMessageW
;--- DispatchMessageW
;--- PeekMessageW
;--- GetMessageW
;--- RegisterWindowMessageW

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include wincon.inc
	include macros.inc
	include duser32.inc

	.DATA

	.CODE

PostMessageW proc public hWnd:dword,message:dword,wParam:dword,lParam:dword

	invoke PostMessageA, hWnd, message, wParam, lParam
	@strace <"PostMessageW(", hWnd, ", ", message, ", ", wParam, ", ", lParam, ")=", eax>
	ret
	align 4

PostMessageW endp

PostThreadMessageW proc public idThread:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

	invoke PostThreadMessageA, idThread, msg, wParam, lParam
	@strace <"PostThreadMessageW(", idThread, ", ", msg, ", ", wParam, ", ", lParam, ")=", eax>
	ret
	align 4

PostThreadMessageW endp

SendMessageW proc public hWnd:dword,message:dword,wParam:dword,lParam:dword

	invoke SendMessageA, hWnd, message, wParam, lParam
	@strace <"SendMessageW(", hWnd, ", ", message, ", ", wParam, ", ", lParam, ")=", eax>
	ret
	align 4

SendMessageW endp

DispatchMessageW proc public pMsg:ptr MSG

	invoke DispatchMessageA, pMsg
	@strace <"DispatchMessageW(", pMsg, ")=", eax>
	ret
	align 4

DispatchMessageW endp

PeekMessageW proc public pMsg:dword, hWnd:dword, dwMin:dword, dwMax:dword, flags:dword

	invoke PeekMessageA, pMsg, hWnd, dwMin, dwMax, flags
	@strace <"PeekMessageW(", pMsg, ", ", hWnd, ", ",dwMin, ", ", dwMax, ", ", flags, ")=", eax>
	ret
	align 4

PeekMessageW endp

GetMessageW proc public pMsg:dword, hWnd:dword, dwMin:dword, dwMax:dword

	invoke GetMessageA, pMsg, hWnd, dwMin, dwMax
	@strace <"GetMessageW(", pMsg, ", ", hWnd, ", ", dwMin, ", ", dwMax, ")=", eax>
	ret
	align 4

GetMessageW endp

RegisterWindowMessageW proc public lpString:ptr BYTE

	mov eax, lpString
	invoke ConvertWStr
	invoke RegisterWindowMessageA, eax
	@strace <"RegisterWindowMessageW(", lpString, ")=", eax>
	ret
	align 4

RegisterWindowMessageW endp

	end
