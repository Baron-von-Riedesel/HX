
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

        .CODE

SetWindowsHookExA proc public idHook:DWORD, lpfn:HOOKPROC, hMod:HINSTANCE, dwThreadId:DWORD

		xor eax, eax
        @strace <"SetWindowsHookExA(", idHook, ", ", lpfn, ", ", hMod, ", ", dwThreadId, ")=", eax>
		ret
        align 4
SetWindowsHookExA endp

UnhookWindowsHookEx proc public hhk:dword

		xor eax, eax
        @strace <"UnhookWindowsHookEx(", hhk, ")=", eax>
		ret
        align 4
UnhookWindowsHookEx endp

CallNextHookEx proc public hhk:dword, nCode:dword, wParam:WPARAM, lParam:LPARAM

		xor eax, eax
        @strace <"CallNextHookEx(", hhk, ", ", nCode, ", ", wParam, ", ", lParam, ")=", eax>
		ret
        align 4
CallNextHookEx endp

        END

