
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

FreeDDElParam proc public msg:DWORD, lParam:DWORD

		xor eax, eax
		@strace <"FreeDDElParam(", msg, ", ", lParam, ")=", eax, " *** unsupp ***">
        ret

FreeDDElParam endp

PackDDElParam proc public msg:DWORD, uiLow:DWORD, uiHigh:DWORD

		xor eax, eax
		@strace <"PackDDElParam(", msg, ", ", uiLow, ", ", uiHigh, ")=", eax, " *** unsupp ***">
        ret

PackDDElParam endp

UnpackDDElParam proc public msg:DWORD, lParam:DWORD, puiLow:ptr DWORD, puiHigh:ptr DWORD

		xor eax, eax
		@strace <"UnpackDDElParam(", msg, ", ", lParam, ", ", puiLow, ", ", puiHigh, ")=", eax, " *** unsupp ***">
        ret

UnpackDDElParam endp


        end

