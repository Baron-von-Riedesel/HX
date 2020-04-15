
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

;--- this code is used to hide the mouse during drawing operations

        .CODE

ShowMouse proc public
        .if (g_bMouse)
        	push eax
        	mov ax,1
            int 33h
            pop eax
        .endif
        ret
        align 4
ShowMouse endp

HideMouse proc public
        .if (g_bMouse)
        	mov ax,2
            int 33h
        .endif
        ret
        align 4
HideMouse endp        

	end
    
