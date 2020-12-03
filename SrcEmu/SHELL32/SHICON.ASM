
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include windef.inc
        include winbase.inc
        include macros.inc

        .CODE

Shell_NotifyIcon proc public dwMsg:dword, pnid:ptr
Shell_NotifyIcon endp
Shell_NotifyIconA proc public dwMsg:dword, pnid:ptr

		xor eax, eax
		@strace <"Shell_NotifyIconA(", dwMsg, ", ", pnid, ")=", eax>                
		ret
        align 4
        
Shell_NotifyIconA endp

		end
