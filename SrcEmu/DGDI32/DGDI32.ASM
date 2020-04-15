
        .386
        .MODEL FLAT, stdcall

		option casemap:none
        option proc:private

		include winbase.inc        
        include wingdi.inc
        include dgdi32.inc
        include macros.inc

        .DATA

g_dwCnt		dd 0

        .CODE

_GDIHeapDestroy proto            

DllMain proc public handle:dword,reason:dword,reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
        	invoke DisableThreadLibraryCalls, handle
        	inc g_dwCnt
		.elseif (reason == DLL_PROCESS_DETACH)
        	dec g_dwCnt
            jnz @F
            call doatexit
            invoke _GDIHeapDestroy
@@:            
        .endif
        @mov eax,1
        ret
        align 4
DllMain endp

        END DllMain

