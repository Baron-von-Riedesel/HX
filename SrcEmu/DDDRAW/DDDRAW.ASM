
        .386
        .MODEL FLAT, stdcall
        option casemap:none
        option proc:private

		include winbase.inc
		include ddraw.inc
		include dddraw.inc

if ?VESADLL
	includelib vesa32.lib
else
	includelib vesa32s.lib
endif

        
        .CODE

DllMain proc public hModule:dword, reason:dword, reserved:dword

	
		.if (reason == DLL_PROCESS_ATTACH)
        	invoke DisableThreadLibraryCalls, hModule
        .endif
        mov eax,1
        ret
        align 4
DllMain endp

        END DllMain

