
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
        include dgdi32.inc
        include macros.inc

        .CODE

FloodFill proc public uses esi edi ebx hdc:DWORD, nXStart:DWORD, nYStart:DWORD, crFill:COLORREF

        invoke HideMouse
        @mov eax, 1
        invoke ShowMouse
		@strace <"FloodFill(", hdc, ", ", nXStart, ", ", nYStart, ", ", crFill, ")=", eax, " *** unsupp ***">
        ret
        align 4
        
FloodFill endp


		end
