
;--- IClassFactory implementation for IDirectDraw
;--- required if CoCreateInstance is used to create an IDirectDraw object

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
        include ddraw.inc
        include dddraw.inc
        include macros.inc

if ?DD7
DirectDrawCreateEx	proto :ptr, :ptr dword, :ptr IID, :LPUNKNOWN
endif

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

CLSID_DirectDraw	GUID <0D7B70EE0h,4340h,11CFh,<0B0h, 63h,00h, 20h,0AFh,0C2h,0CDh, 35h>>
if ?DD7
CLSID_DirectDraw7	GUID <03c305196h,50dbh,11d3h,< 9ch,0feh,00h,0c0h, 4fh,0d9h, 30h,0c5h>>
;;IID_IDirectDraw7	GUID <015e65ec0h, 03b9ch,  11d2h, <0b9h,  2fh,  00h,  60h,  97h,  97h, 0eah,  5bh>>
endif
IID_IUnknown     	GUID <00000000,0000,0000,<0C0h,00,00,00,00,00,00,46h>>
IID_IClassFactory	GUID <00000001,0000,0000,<0C0h,00,00,00,00,00,00,46h>>

        .CODE

DllGetClassObject proc public uses esi edi pClsid:REFGUID, riid:REFGUID, ppv:ptr DWORD

local	pClassFactory:dword

        mov     edi,offset CLSID_DirectDraw
        mov     esi,pClsid
        mov     ecx,4
        repz    cmpsd
        jz      found
if ?DD7
        mov     edi,offset CLSID_DirectDraw7
        mov     esi,pClsid
        mov     ecx,4
        repz    cmpsd
        jz      found
endif
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
        align 4
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

if ?DD7
		push	esi
        push	edi
        mov     edi,offset IID_IDirectDraw7
        mov     esi,riid
        mov     ecx,4
        repz    cmpsd
        pop		edi
        pop		esi
        jnz		@F
	    invoke DirectDrawCreateEx, 0, addr pObject, riid, pUnkOuter
   		jmp exit
@@:        
endif

	    invoke DirectDrawCreate, 0, addr pObject, pUnkOuter
	    .if (eax != DD_OK)
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

