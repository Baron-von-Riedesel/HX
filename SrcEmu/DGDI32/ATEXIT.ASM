
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

if ?FLAT

        .DATA

g_pAtExit	dd 0

        .CODE

atexit	proc c public dwProc:DWORD

		invoke _GDImalloc, 2*4
        .if (eax)
        	mov edx, eax
        	mov ecx, dwProc
            mov [edx+4],ecx
            @noints 
            lea ecx, g_pAtExit
            mov eax,[ecx+0]
            mov [edx+0],eax
            mov [ecx+0], edx
            @restoreints
		.endif
		ret
        align 4
atexit  endp

doatexit	proc c public
		mov edx, g_pAtExit
		.while (edx)
			push dword ptr [edx+0]
			push dword ptr [edx+4]
			invoke _GDIfree, edx
			pop eax
			call eax
			pop edx
		.endw
		ret
        align 4
doatexit	endp

endif

        END

