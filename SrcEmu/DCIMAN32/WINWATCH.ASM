
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include winuser.inc
        include macros.inc
        include dciddi.inc

WWOBJ	struct
hwnd	dd ?
WWOBJ	ends

        .CODE

;--- returns a hwndWW

WinWatchOpen proc public hwnd:dword
		invoke LocalAlloc, LMEM_FIXED, sizeof WWOBJ
        .if (eax)
        	mov ecx, hwnd
            mov [eax].WWOBJ.hwnd, ecx
        .endif
        @strace <"WinWatchOpen(", hwnd, ")=", eax>
        ret
WinWatchOpen endp

WinWatchClose proc public hwndWW:dword
		invoke LocalFree, hwndWW
        @strace <"WinWatchClose(", hwndWW, ")=", eax>
        ret
WinWatchClose endp

WinWatchGetClipList proc public hwndWW:dword, lprc:ptr RECT, size_:dword, prd:ptr
		xor eax, eax
        @strace <"WinWatchGetClipList(", hwndWW, ", ", lprc, ", ", size_, ", ", prd, ")=", eax>
        ret
WinWatchGetClipList endp

WinWatchDidStatusChange proc public hwndWW:dword
		xor eax, eax
        @strace <"WinWatchDidStatusChange(", hwndWW, ")=", eax>
        ret
WinWatchDidStatusChange endp

		end
