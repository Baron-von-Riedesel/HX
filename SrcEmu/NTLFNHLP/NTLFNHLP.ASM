
        .386
        .MODEL FLAT, stdcall
        option proc:private

		include winnt.inc

InstallLFNHLP		proto bCheckOS:dword
DeinstallLFNHLP		proto

        .CODE

DllMain proc public hModule:dword,reason:dword,reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
			invoke InstallLFNHLP, 1
        .elseif (reason == DLL_PROCESS_DETACH)
        	invoke DeinstallLFNHLP
        .endif
        mov     eax,1
        ret
DllMain endp

        END DllMain

