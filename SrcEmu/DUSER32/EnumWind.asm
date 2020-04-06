
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
	include duser32.inc
	include macros.inc

externdef g_pWindows:DWORD

	.CODE

protoEnumThreadWndProc typedef proto :DWORD, :LPARAM
WNDENUMPROC typedef ptr protoEnumThreadWndProc

EnumThreadWindows proc public uses ebx esi dwThreadId:dword, lpEnumFunc:WNDENUMPROC, lParam:DWORD

	mov esi, esp
	@serialize_enter
	mov ebx, g_pWindows
	.while (ebx)
		mov eax, [ebx].WNDOBJ.dwThreadId
		.if (eax == dwThreadId)
			push ebx
		.endif
		mov ebx, [ebx].WNDOBJ.pNext
	.endw
	@serialize_exit
	mov ebx, esi
	.while ( ebx != esp )
		sub ebx, 4
		mov eax, [ebx]
		.if ([eax].WNDOBJ.dwType == USER_TYPE_HWND)
			invoke lpEnumFunc, eax, lParam
		.endif
	.endw
	mov esp, esi

	@strace <"EnumThreadWindows(", dwThreadId, ", ", lpEnumFunc, ", ", lParam, ")=", eax, " *** unsupp ***">
	ret
	align 4

EnumThreadWindows endp

EnumChildWindows proc public uses ebx esi hwndParent:dword, lpEnumFunc:WNDENUMPROC, lParam:dword

	xor eax, eax
	mov esi, esp
	mov ebx, hwndParent
	.if (ebx && [ebx].WNDOBJ.dwType == USER_TYPE_HWND)
		@serialize_enter
		mov ebx, [ebx].WNDOBJ.hwndChilds
		.while (ebx)
			push ebx
			mov ebx, [ebx].WNDOBJ.hwndSibling
		.endw
		@serialize_exit
		mov ebx, esi
		.while (ebx != esp)
			sub ebx, 4
			mov eax, [ebx]
			.if (([eax].WNDOBJ.dwType == USER_TYPE_HWND) && [eax].WNDOBJ.hwndChilds)
				push eax
				invoke EnumChildWindows, eax, lpEnumFunc, lParam
				pop eax
			.endif
			.if ([eax].WNDOBJ.dwType == USER_TYPE_HWND)
				invoke lpEnumFunc, eax, lParam
			.endif
		.endw
	.endif
	mov esp, esi
	@strace <"EnumChildWindows(", hwndParent, ", ", lpEnumFunc, ", ", lParam, ")=", eax>
	ret
	align 4
EnumChildWindows endp

EnumWindows proc public uses ebx esi lpEnumFunc:WNDENUMPROC, lParam:dword

	mov esi, esp
	@serialize_enter
	mov ebx, g_pWindows
	.while (ebx)
		mov eax, [ebx].WNDOBJ.dwThreadId
		push ebx
		mov ebx, [ebx].WNDOBJ.pNext
	.endw
	@serialize_exit
	mov ebx, esi
	.while (ebx != esp)
		sub ebx, 4
		mov eax, [ebx]
		.if ([eax].WNDOBJ.dwType == USER_TYPE_HWND)
			invoke lpEnumFunc, eax, lParam
		.endif
	.endw
	mov esp, esi

	@strace <"EnumWindows(", lpEnumFunc, ", ", lParam, ")=", eax>
	ret
	align 4
EnumWindows endp

	end
