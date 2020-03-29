
        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
        option casemap:none
ifndef __POASM__        
        option proc:private
endif        

		include winbase.inc
		include winuser.inc
        include duser32.inc
        include macros.inc

if ?FLAT

        .DATA

g_pAtExit	DWORD 0

        .CODE

atexit	proc c public dwProc:DWORD

		invoke malloc, 2*4
        .if (eax)
        	mov ecx, dwProc
            mov [eax+4],ecx
            @serialize_enter
            lea ecx, g_pAtExit
            mov edx,[ecx]
            mov [eax],edx
            mov [ecx], eax
            @serialize_exit
		.endif
		ret
        align 4
atexit  endp

doatexit proc c public
		mov edx, g_pAtExit
		.while (edx)
			push dword ptr [edx+0]
			push dword ptr [edx+4]
			invoke free, edx
			pop eax
			call eax
			pop edx
		.endw
		ret
        align 4
doatexit endp

endif

        END

