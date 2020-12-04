
;--- implements CoInitialize, CoUninitialize
;--- CoInitializeEx, OleInitialize, OleUninitialize

        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include windef.inc
        include winbase.inc
        include winreg.inc
        include winuser.inc
        include objbase.inc
        include macros.inc

		.DATA
        
externdef g_TlsSlot:DWORD

		.CONST
        
IID_IClassFactory GUID <00000001,0000,0000,<0C0h,00,00,00,00,00,00,46h>>

        .CODE

CoInitialize proc public pvReserved:DWORD

		invoke TlsGetValue, g_TlsSlot
        push eax
        inc eax
        invoke TlsSetValue, g_TlsSlot, eax
        pop eax
        .if (!eax)
			mov eax,S_OK
        .else
			mov eax,S_FALSE
        .endif
		@strace <"CoInitialize(", pvReserved, ")=", eax>
        ret
        align 4

CoInitialize endp

CoInitializeEx proc public pvReserved:DWORD, pcoInit:ptr

		invoke CoInitialize, pvReserved
		@strace <"CoInitializeEx(", pvReserved, ", ", pcoInit, ")=", eax>
        ret
        align 4

CoInitializeEx endp

CoInitializeSecurity proc public pVoid:ptr, cAuthSvc:dword, asAuthSvc:ptr, pReserved:ptr, dwAuthnLevel:dword, dwTmpLevel:dword, pAuthList:ptr, dwCapabilities:dword, pReserved3:ptr

	mov eax, S_OK
	@strace <"CoInitializeSecurity(", pVoid, ", ", cAuthSvc, ", ... )=", eax>
	ret
	align 4

CoInitializeSecurity endp

CoUninitialize proc public

		invoke TlsGetValue, g_TlsSlot
        .if (eax)
        	dec eax
	        invoke TlsSetValue, g_TlsSlot, eax
        .endif
		mov eax,S_OK
		@strace <"CoUninitialize()=", eax>
        ret
        align 4

CoUninitialize endp

OleInitialize proc public pvReserved:DWORD

		invoke CoInitialize, pvReserved
		@strace <"OleInitialize(", pvReserved, ")=", eax>
        ret
        align 4

OleInitialize endp

OleUninitialize proc public

		invoke CoUninitialize
		@strace <"OleUninitialize()=", eax>
        ret
        align 4

OleUninitialize endp

		end
