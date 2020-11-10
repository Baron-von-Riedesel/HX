
;--- IClassFactory implementation for DirectInput
;--- required if CoCreateInstance is used to create an IDirectInput object

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
        include dinput.inc
        include macros.inc


		.DATA
        
g_DllRefCount dd 0

		.CONST
        
CClassFactoryVtbl label IClassFactoryVtbl
	dd QueryInterface_,	AddRef_, Release_, CreateInstance_, LockServer_

CClassFactory struct
vtbl		dd ?
ObjRefCount dd ?
CClassFactory ends

Create@CClassFactory proto
AddRef_  proto :ptr CClassFactory
Release_ proto :ptr CClassFactory

CLSID_DirectInput	GUID <25E609E0h , 0B259h , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
IID_IUnknown     	GUID <00000000,0000,0000,<0C0h,00,00,00,00,00,00,46h>>
IID_IClassFactory	GUID <00000001,0000,0000,<0C0h,00,00,00,00,00,00,46h>>

        .CODE

DllGetClassObject proc public uses esi edi pClsid:REFGUID, riid:REFGUID, ppv:ptr DWORD

local	pClassFactory:dword

        mov     edi,offset CLSID_DirectInput
        mov     esi,pClsid
        mov     ecx,4
        repz    cmpsd
        jz      found
        mov     eax, CLASS_E_CLASSNOTAVAILABLE
        jmp		exit
found:
		invoke	Create@CClassFactory
		.if (!eax)
        	mov eax, E_OUTOFMEMORY
            jmp exit
		.endif
        mov pClassFactory, eax
		invoke vf(pClassFactory,IClassFactory,QueryInterface),riid,ppv
        push eax
		invoke vf(pClassFactory,IClassFactory,Release)
        pop eax
exit:
        ret
DllGetClassObject endp

Create@CClassFactory PROC public

		invoke	LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof CClassFactory
    	and eax, eax
	    jz exit
		mov	[eax].CClassFactory.vtbl,OFFSET CClassFactoryVtbl
		mov	[eax].CClassFactory.ObjRefCount, 1
		inc g_DllRefCount
exit:    
		ret
        align 4
        
Create@CClassFactory ENDP

;------ destructor ClassFactory, return void

Destroy_ PROC this_:ptr CClassFactory

		invoke LocalFree, this_
		dec g_DllRefCount
		ret
        align 4
Destroy_ ENDP		

QueryInterface_ PROC uses esi edi this_:ptr CClassFactory ,riid:ptr IID,ppv:ptr

		mov		edx, this_
	    mov     edi,offset IID_IUnknown
    	mov     esi,riid
        mov     ecx,4
        repz    cmpsd
        jz      found
	    mov     edi,offset IID_IClassFactory
    	mov     esi,riid
        mov     ecx,4
        repz    cmpsd
        jz      found
        mov     ecx,ppv
        mov		dword ptr [ecx],0
        mov     eax,E_NOINTERFACE
        jmp		exit
found:
        mov     ecx,ppv
        mov     [ecx], edx
        invoke	AddRef_, edx
        mov     eax, S_OK
exit:
		ret
        align 4

QueryInterface_ ENDP


AddRef_ PROC this_:ptr CClassFactory

		mov	ecx, this_
		mov	eax, [ecx].CClassFactory.ObjRefCount
		inc	[ecx].CClassFactory.ObjRefCount
		ret
        align 4

AddRef_ ENDP


Release_ PROC this_:ptr CClassFactory

		mov	ecx, this_
		mov eax,[ecx].CClassFactory.ObjRefCount
		dec	[ecx].CClassFactory.ObjRefCount
		.if (eax == 1)
			invoke Destroy_, this_
			xor eax,eax
		.endif
		ret
        align 4

Release_ ENDP


CreateInstance_ PROC pThis:ptr CClassFactory, pUnkOuter:LPUNKNOWN,
					riid:ptr IID,ppObject:ptr LPUNKNOWN

local	pObject:ptr objectname
	
		mov	eax, ppObject
		mov	DWORD PTR [eax], NULL

if 0;?AGGREGATION
;------------- if pUnkOuter != NULL riid MUST be IID_IUnknown!
		.if (pUnkOuter != NULL)
			invoke IsEqualGUID, riid, addr IID_IUnknown
			.if (eax == FALSE)
				DebugOut "IClassFactory::CreateInstance failed (riid != IID_IUnknown)"
				return CLASS_E_NOAGGREGATION
			.endif
		.endif
else
		.if (pUnkOuter != NULL)
			return CLASS_E_NOAGGREGATION
		.endif
endif

;--- call constructor

	    invoke DirectInputCreateA, 0, 500, addr pObject, pUnkOuter
    	.if (eax != DI_OK)
	    	jmp exit
		.endif

;--- get the right interface

		invoke vf(pObject,IUnknown,QueryInterface), riid, ppObject
    	push eax
		invoke vf(pObject,IUnknown,Release)
    	pop eax    
exit:    
		ret
        align 4

CreateInstance_ ENDP


LockServer_ PROC pThis:ptr CClassFactory, bLockServer:DWORD

	    .if (bLockServer)
    	    inc g_DllRefCount
	    .else
    	    dec g_DllRefCount
	    .endif
		return S_OK
        align 4

LockServer_ ENDP

        END

