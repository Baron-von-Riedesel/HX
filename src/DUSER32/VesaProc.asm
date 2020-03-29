
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

		include winbase.inc
		include winuser.inc
		include wingdi.inc
        include macros.inc
        include duser32.inc
        include vesa32.inc

		.data
        
if ?FLAT

		public g_hVesa32	;is checked in CURSOR.ASM
        
g_hVesa32	DD 0        

proctable label dword

g_lpfnEnumVesaModes LPFNENUMVESAMODES 0
	dd CStr("EnumVesaModes")
g_lpfnGetVesaMemoryBufferSize LPFNGETVESAMEMORYBUFFERSIZE 0
	dd CStr("GetVesaMemoryBufferSize")
g_lpfnGetVesaMode LPFNGETVESAMODE 0
	dd CStr("GetVesaMode")
g_lpfnGetVesaModeInfo LPFNGETVESAMODEINFO 0
	dd CStr("GetVesaModeInfo")
g_lpfnGetVesaStateBufferSize LPFNGETVESASTATEBUFFERSIZE 0
	dd CStr("GetVesaStateBufferSize")
g_lpfnRestoreVesaVideoMemory LPFNRESTOREVESAVIDEOMEMORY 0
	dd CStr("RestoreVesaVideoMemory")
g_lpfnRestoreVesaVideoState LPFNRESTOREVESAVIDEOSTATE 0
	dd CStr("RestoreVesaVideoState")
g_lpfnSaveVesaVideoMemory LPFNSAVEVESAVIDEOMEMORY 0
	dd CStr("SaveVesaVideoMemory")
g_lpfnSaveVesaVideoState LPFNSAVEVESAVIDEOSTATE 0
	dd CStr("SaveVesaVideoState")
g_lpfnSearchVesaMode LPFNSEARCHVESAMODE 0
	dd CStr("SearchVesaMode")
g_lpfnSetVesaMode LPFNSETVESAMODE 0
	dd CStr("SetVesaMode")
g_lpfnVesaMouseInit LPFNVESAMOUSEINIT 0
	dd CStr("VesaMouseInit")
g_lpfnVesaMouseExit LPFNVESAMOUSEEXIT 0
	dd CStr("VesaMouseExit")
SIZEPROCTABLE equ ($ - proctable) / (2*4)
    
else
g_lpfnEnumVesaModes				LPFNENUMVESAMODES			offset EnumVesaModes
g_lpfnGetVesaMemoryBufferSize	LPFNGETVESAMEMORYBUFFERSIZE	offset GetVesaMemoryBufferSize
g_lpfnGetVesaMode				LPFNGETVESAMODE				offset GetVesaMode
g_lpfnGetVesaModeInfo			LPFNGETVESAMODEINFO			offset GetVesaModeInfo
g_lpfnGetVesaStateBufferSize	LPFNGETVESASTATEBUFFERSIZE	offset GetVesaStateBufferSize
g_lpfnRestoreVesaVideoMemory	LPFNRESTOREVESAVIDEOMEMORY	offset RestoreVesaVideoMemory
g_lpfnRestoreVesaVideoState		LPFNRESTOREVESAVIDEOSTATE	offset RestoreVesaVideoState
g_lpfnSaveVesaVideoMemory		LPFNSAVEVESAVIDEOMEMORY		offset SaveVesaVideoMemory
g_lpfnSaveVesaVideoState		LPFNSAVEVESAVIDEOSTATE		offset SaveVesaVideoState
g_lpfnSearchVesaMode			LPFNSEARCHVESAMODE 			offset SearchVesaMode
g_lpfnSetVesaMode				LPFNSETVESAMODE				offset SetVesaMode
g_lpfnVesaMouseInit				LPFNVESAMOUSEINIT			offset VesaMouseInit
g_lpfnVesaMouseExit				LPFNVESAMOUSEEXIT			offset VesaMouseExit
endif

		.code

unloadvesa proc
if ?FLAT
		invoke FreeLibrary, g_hVesa32
endif        
		ret
unloadvesa endp

_GetVesaProcs proc public uses esi
if ?FLAT
		mov eax, g_hVesa32
		.if (!eax)
       		invoke LoadLibrary, CStr("vesa32")
            mov g_hVesa32, eax
	        .if (eax)
            	invoke atexit, offset unloadvesa
    	    	mov esi, offset proctable
                mov ecx, SIZEPROCTABLE
                .while (ecx)
                	push ecx
	        	   	invoke GetProcAddress, g_hVesa32, [esi+4]
                    pop ecx
                    mov [esi+0], eax
                    add esi, 2*4
                    dec ecx
                .endw
	        .endif
        .endif
else
		mov eax, 1
endif
		ret
_GetVesaProcs endp

		end
