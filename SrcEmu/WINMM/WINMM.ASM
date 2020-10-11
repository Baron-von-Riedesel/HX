
        .386
if ?FLAT        
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif

		option casemap:none
        option proc:private

		include winbase.inc        
        include mmsystem.inc
        include macros.inc
        include winmm.inc


		.DATA
        
g_dwCnt		dd 0

        .CODE

InitMM		proto
DeinitMM	proto

DllMain proc public handle:dword,reason:dword,reserved:dword

		.if (reason == DLL_PROCESS_ATTACH)
        	.if (!g_dwCnt)
            	call InitMM
            .endif
        	inc g_dwCnt
            invoke DisableThreadLibraryCalls, handle
	        @mov eax,1
		.elseif (reason == DLL_PROCESS_DETACH)
        	dec g_dwCnt
            jnz @F
            call DeinitMM
@@:
		.endif
        ret
DllMain endp

        END DllMain

