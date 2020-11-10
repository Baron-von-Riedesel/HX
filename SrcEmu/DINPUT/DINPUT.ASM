
        .386
        .MODEL FLAT, stdcall
        option casemap:none
        option proc:private

		include winbase.inc

DeleteSysDevices proto

		.DATA
        
g_dwCnt	dd 0        

        .CODE

DllMain proc public hModule:dword,reason:dword,reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
        	invoke DisableThreadLibraryCalls, hModule
        	inc g_dwCnt
	        mov eax,1
		.elseif (reason == DLL_PROCESS_DETACH)
        	dec g_dwCnt
            .if (ZERO?)
            	invoke DeleteSysDevices
            .endif
        .endif
        ret
DllMain endp

        END DllMain

