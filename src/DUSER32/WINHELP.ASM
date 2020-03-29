
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

WinHelpA proc public hWnd:DWORD, lpszHelp:ptr BYTE, uCommand:DWORD, dwData:DWORD

		xor eax, eax
		@strace <"WinHelpA(", hWnd, ", ", lpszHelp, ", ", uCommand, ", ", dwData, ")=", eax, " *** unsupp ***">
        ret

WinHelpA endp

WinHelpW proc public hWnd:DWORD, lpszHelp:ptr WORD, uCommand:DWORD, dwData:DWORD

		xor eax, eax
		@strace <"WinHelpW(", hWnd, ", ", lpszHelp, ", ", uCommand, ", ", dwData, ")=", eax, " *** unsupp ***">
        ret

WinHelpW endp


        end

