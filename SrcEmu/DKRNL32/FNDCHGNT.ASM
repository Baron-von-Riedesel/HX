
;*** FindFirstChangeNotificationA
;*** FindNextChangeNotification
;*** FindCloseChangeNotification

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

?IMPLEMENT equ 1

if ?IMPLEMENT

CHANGENOT struct
dwType	dd ?
CHANGENOT ends

?SUPPORTED equ <" ">
else
?SUPPORTED equ <" *** unsupp ***">
endif

	.CODE

FindFirstChangeNotificationA proc public lpPathName:ptr BYTE, bWatchSubTree:dword, dwNotifyFilter:dword

if ?IMPLEMENT
	invoke KernelHeapAlloc, sizeof CHANGENOT
	.if (eax)
		mov [eax].CHANGENOT.dwType, SYNCTYPE_CHANGENOT
	.endif
else
	invoke SetLastError, ERROR_NOT_SUPPORTED
	mov eax, INVALID_HANDLE_VALUE
endif
	@strace <"FindFirstChangeNotificationA(", lpPathName, ", ", bWatchSubTree, ", ", dwNotifyFilter, ")=", eax, ?SUPPORTED>
	ret
	align 4
FindFirstChangeNotificationA endp

FindNextChangeNotification proc public hChange:dword

if ?IMPLEMENT
	xor eax, eax
	mov ecx, hChange
	jecxz @F
	.if ([ecx].CHANGENOT.dwType == SYNCTYPE_CHANGENOT)
		inc eax
	.endif
@@:
else
	invoke SetLastError, ERROR_NOT_SUPPORTED
	xor eax, eax
endif
	@strace <"FindNextChangeNotification(", hChange, ")=", eax, ?SUPPORTED>
	ret
	align 4
FindNextChangeNotification endp

FindCloseChangeNotification proc public hChange:dword

if ?IMPLEMENT
	xor eax, eax
	mov ecx, hChange
	jecxz @F
	.if ([ecx].CHANGENOT.dwType == SYNCTYPE_CHANGENOT)
		invoke KernelHeapFree, ecx
	.endif
@@:
else
	xor eax, eax
endif
	@strace <"FindCloseChangeNotification(", hChange, ")=", eax, ?SUPPORTED>
	ret
	align 4
FindCloseChangeNotification endp

	END

