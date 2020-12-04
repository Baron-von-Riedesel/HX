
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

		.nolist
        .nocref
        include winbase.inc
        include winuser.inc
        include oleauto.inc
        include macros.inc
        .list
        .cref

        .CODE

GetActiveObject proc public refclsid:DWORD, xx:DWORD, xxx:DWORD

		@trace	<"GetActiveObject() *** unsupp ***",13,10>
        mov eax, E_FAIL
        ret

GetActiveObject endp

		end
