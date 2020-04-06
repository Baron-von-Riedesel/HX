
        .386
        .MODEL FLAT, stdcall
        option casemap:none
        option proc:private

		include winbase.inc
		include winuser.inc
        include duser32.inc
        include macros.inc

        .DATA

g_hInstance	HINSTANCE 0
g_dwCnt		DWORD 0

        .CODE

InitUser proto
DeinitUser proto

DllMain proc public handle:dword,reason:dword,reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
        	inc g_dwCnt
			mov	eax, handle
    	    mov	g_hInstance, eax
            invoke DisableThreadLibraryCalls, handle
            invoke InitUser
	        @mov eax,1
        .elseif (reason == DLL_PROCESS_DETACH)
        	dec g_dwCnt
            jnz @F
            call doatexit
            invoke DeinitUser
@@:            
        .endif
        ret
DllMain endp

        END DllMain

