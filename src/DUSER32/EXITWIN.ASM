
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

ExitWindowsEx proc public uFlags:DWORD, dwReserved:DWORD

		xor eax, eax
		@strace <"ExitWindowsEx(", uFlags, ", ", dwReserved, ")=", eax, " *** unsupp ***">
        ret

ExitWindowsEx endp


        end

