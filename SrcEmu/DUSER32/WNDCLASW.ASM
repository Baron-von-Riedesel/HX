
;--- functions included:

;--- RegisterClassW
;--- RegisterClassExW
;--- UnregisterClassW
;--- GetClassLongW
;--- SetClassLongW
;--- GetClassInfoW
;--- GetClassInfoExW
;--- GetClassNameW

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

	.CODE

RegisterClassW proc public pWndClass:ptr WNDCLASS

local	wc:WNDCLASS

	invoke RtlMoveMemory, addr wc, pWndClass, sizeof WNDCLASS
	mov eax, wc.lpszClassName
	invoke ConvertWStr
	mov wc.lpszClassName, eax
	invoke RegisterClassA, pWndClass
	@strace <"RegisterClassW(", pWndClass, ")=", eax>
	ret
	align 4

RegisterClassW endp

RegisterClassExW proc public pWndClass:ptr WNDCLASSEX

local	wcex:WNDCLASSEX

	invoke RtlMoveMemory, addr wcex, pWndClass, sizeof WNDCLASSEX
	mov eax, wcex.lpszClassName
	invoke ConvertWStr
	mov wcex.lpszClassName, eax
	invoke RegisterClassExA, pWndClass
	@strace <"RegisterClassExW(", pWndClass, ")=", eax>
	ret
	align 4

RegisterClassExW endp

UnregisterClassW proc public lpClassName:ptr WORD, hInstance: dword

	mov eax, lpClassName
	invoke ConvertWStr
	invoke UnregisterClassA, eax, hInstance
	@strace <"UnregisterClassW(", lpClassName, ", ", hInstance, ")=", eax>
	ret
	align 4
        
UnregisterClassW endp

GetClassLongW proc public hWnd:DWORD, nIndex:DWORD

	invoke GetClassLongA, hWnd, nIndex
	@strace <"GetClassLongW(", hWnd, ", ", nIndex, ")=", eax>
	ret
	align 4

GetClassLongW endp

SetClassLongW proc public hWnd:DWORD, nIndex:DWORD, newValue: dword

	invoke SetClassLongA, hWnd, nIndex, newValue
	@strace <"SetClassLongW(", hWnd, ", ", nIndex, ", ", newValue, ")=", eax>
	ret
	align 4

SetClassLongW endp

GetClassInfoW proc public hInstance:DWORD, lpClassName:ptr WORD, lpWndClass:ptr WNDCLASS

	mov eax, lpClassName
	call ConvertWStr
	invoke GetClassInfoA, hInstance, eax, lpWndClass
	@strace <"GetClassInfoW(", hInstance, ", ", lpClassName, ", ", lpWndClass, ")=", eax>
	ret
	align 4

GetClassInfoW endp

GetClassInfoExW proc public hInstance:DWORD, lpszClass:ptr BYTE, lpwcx:ptr WNDCLASSEX

	mov eax, lpszClass
	call ConvertWStr
	invoke GetClassInfoExA, hInstance, eax, lpwcx
	@strace <"GetClassInfoExW(", hInstance, ", ", lpszClass, ", ", lpwcx, ")=", eax>
	ret
	align 4
        
GetClassInfoExW endp

GetClassNameW proc public hwnd:DWORD, lpBuffer:ptr WORD, nMaxBuffer:dword

	sub esp, nMaxBuffer
	mov edx, esp
	invoke GetClassNameA, hwnd, edx, nMaxBuffer
	.if (eax)
		mov edx, esp
		invoke ConvertAStrN, edx, lpBuffer, nMaxBuffer
	.endif
	@strace <"GetClassNameW(", hwnd, ", ", lpBuffer, ", ", nMaxBuffer, ")=", eax>
	ret
	align 4

GetClassNameW endp

	end

