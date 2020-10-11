
        .386
        .MODEL FLAT, stdcall
        option casemap:none
        option proc:private

		include winbase.inc
        include dsound.inc
        include macros.inc

		.DATA
        
g_dwCnt	dd 0        

        .CODE

DllMain proc public hModule:dword,reason:dword,reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
        	invoke DisableThreadLibraryCalls, hModule
        	inc g_dwCnt
		.elseif (reason == DLL_PROCESS_DETACH)
        	dec g_dwCnt
        .endif
        @mov eax,1
        ret
        align 4
DllMain endp

        END DllMain

