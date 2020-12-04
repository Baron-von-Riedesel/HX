
        .386
        .MODEL FLAT, stdcall
        
        option casemap:none

		include winbase.inc

        .DATA

		public g_TlsSlot
        
g_TlsSlot dd -1

        .CODE

DllMain proc stdcall public hModule:dword, reason:dword, reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
			invoke	TlsAlloc
    	    mov	g_TlsSlot, eax
        .elseif (reason == DLL_PROCESS_DETACH)
			invoke	TlsFree, g_TlsSlot
            mov g_TlsSlot, -1
        .endif
        mov     eax,1
        ret
DllMain endp

        END DllMain

