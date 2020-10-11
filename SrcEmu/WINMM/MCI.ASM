
;--- implements mciXXX()

        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include mmsystem.inc
        include macros.inc

        .CODE

mciSendCommandA proc public iddevice:DWORD, uMsg:DWORD, fdwCommand:DWORD, dwParam:DWORD

		mov eax, MCIERR_CANNOT_LOAD_DRIVER
		@strace <"mciSendCommandA(", iddevice, ", ", uMsg, ", ", fdwCommand, ", ", dwParam, ")=", eax, " *** unsupp ***">
		ret
        align 4

mciSendCommandA endp

mciSendStringA proc public lpszCommand:DWORD, lpszReturnString:DWORD, cchReturn:DWORD, hwndCallback:dword

		mov eax, MCIERR_CANNOT_LOAD_DRIVER
ifdef _DEBUG
		mov ecx, lpszCommand
		@strace <"mciSendStringA(", &ecx, ", ", lpszReturnString, ", ", cchReturn, ", ", hwndCallback, ")=", eax, " *** unsupp ***">
endif        
		ret
        align 4

mciSendStringA endp

mciGetErrorStringA proc public fdwError:DWORD, lpszError:ptr BYTE, cchErrorText:DWORD

		xor eax, eax
		@strace <"mciGetErrorStringA(", fdwError, ", ", lpszError, ", ", cchErrorText, ")=", eax, " *** unsupp ***">
		ret
        align 4

mciGetErrorStringA endp

		end
