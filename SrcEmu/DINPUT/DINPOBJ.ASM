
;--- implements IDirectInput, IDirectInput2, IDirectInput7

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
        include wincon.inc
        include dinput.inc
        include ddinput.inc
        include macros.inc


DINPOBJ   struct
vft			dd ?
dwCnt		dd ?
DINPOBJ   ends

QueryInterface proto pThis:ptr DINPOBJ,refiid:dword,pObj:dword
AddRef         proto pThis:ptr DINPOBJ
Release        proto pThis:ptr DINPOBJ

Create@MouDevice proto :ptr LPDIRECTINPUTDEVICEA
Create@KbdDevice proto :ptr LPDIRECTINPUTDEVICEA

		.CONST
        
IID_IDirectInputA	GUID <89521360h , 0AA8Ah , 11CFh , <0BFh , 0C7h , 44h ,  45h , 53h , 54h , 00h ,  00h>>
IID_IDirectInput2A	GUID <5944E662h , 0AA8Ah , 11CFh , <0BFh , 0C7h , 44h ,  45h , 53h , 54h , 00h ,  00h>>
IID_IDirectInput7A	GUID <9A4CB684h ,  236Dh , 11D3h , < 8Eh ,  9Dh , 00h , 0C0h , 4Fh , 68h , 44h , 0AEh>>

GUID_SysMouse		GUID <6F1D2B60h , 0D5A0h , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
GUID_SysKeyboard	GUID <6F1D2B61h , 0D5A0h , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>

divf    label DINPUTVFT
         dd QueryInterface, AddRef, Release
         dd _CreateDevice, _EnumDevices, _GetDeviceStatus
         dd _RunControlPanel, _Initialize
;--- IDirectInput2 methods
         dd _FindDevice
;--- IDirectInput7 methods
         dd _CreateDeviceEx

        .CODE

DirectInputCreateA proc public uses ebx pGUID:ptr, dwVersion:DWORD, pDI:ptr dword, pIUnknown:ptr

        invoke	LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DINPOBJ
        and     eax,eax
        jz      error
        mov		ebx, eax
        mov     [ebx].DINPOBJ.vft, offset divf
        mov		[ebx].DINPOBJ.dwCnt, 1
        mov     ecx,pDI
        mov     [ecx], ebx
        mov     eax,DI_OK
        jmp		exit
error:
        mov     eax,DIERR_OUTOFMEMORY
exit:  
		@strace	<"DirectInputCreateA(", pGUID, ", ", dwVersion, ", ", pDI, ", ", pIUnknown, ")=", eax>
        ret
        align 4
DirectInputCreateA endp

DirectInputCreateEx proc public uses ebx hInst:DWORD, dwVersion:DWORD, refiid:ptr, lplpDI:ptr dword, pIUnknown:ptr

local	lpDI:dword

		invoke	DirectInputCreateA, NULL, dwVersion, addr lpDI, pIUnknown
        .if (eax == DI_OK)
        	invoke vf(lpDI, IUnknown, QueryInterface), refiid, lplpDI
            push eax
            invoke vf(lpDI, IUnknown, Release)
            pop eax
        .endif
		@strace	<"DirectInputCreateEx(", hInst, ", ", dwVersion, ", ", refiid, ", ", lplpDI, ", ", pIUnknown, ")=", eax>
        ret
        align 4
DirectInputCreateEx endp

QueryInterface proc uses esi edi ebx pThis:ptr DINPOBJ, pIID:dword, pObj:dword

		mov		edx, pThis
        mov     edi,offset IID_IDirectInputA
        mov     esi,pIID
        mov     ecx,4
        repz    cmpsd
        jz      found
        mov     edi,offset IID_IDirectInput2A
        mov     esi,pIID
        mov     cl,4
        repz    cmpsd
        jz      found
        mov     edi,offset IID_IDirectInput7A
        mov     esi,pIID
        mov     cl,4
        repz    cmpsd
        jz      found
        mov     ecx,pObj
        mov		dword ptr [ecx],0
        mov     eax,DIERR_NOINTERFACE
ifdef _DEBUG
        int		3
endif   
        jmp		exit
found:
        mov     ecx, pObj
        mov     [ecx], edx
        invoke	AddRef, edx
        mov     eax,DI_OK
exit:        
		@strace	<"DirectInput::QueryInterface(", pThis, ")=", eax>
        ret
        align 4
QueryInterface endp

AddRef proc pThis:ptr DINPOBJ
		mov ecx, pThis
        mov eax, [ecx].DINPOBJ.dwCnt
        inc [ecx].DINPOBJ.dwCnt
		@strace	<"DirectInput::AddRef(", pThis, ")=", eax>
        ret
        align 4
AddRef endp

Release proc uses ebx pThis:ptr DINPOBJ
		mov ebx, pThis
        mov eax, [ebx].DINPOBJ.dwCnt
        dec [ebx].DINPOBJ.dwCnt
        .if (ZERO?)
        	invoke LocalFree, ebx
            xor eax, eax
        .endif
		@strace	<"DirectInput::Release(", pThis, ")=", eax>
        ret
        align 4
Release endp

_CreateDevice proc uses esi edi pThis:ptr DINPOBJ, refguid:ptr GUID, lplpDirectInputDevice:ptr LPDIRECTINPUTDEVICEA, lpUnkOuter:LPUNKNOWN

		mov edi, offset GUID_SysMouse
        mov esi, refguid
        mov ecx, 4
        repz cmpsd
        jz foundmouse
		mov edi, offset GUID_SysKeyboard
        mov esi, refguid
        mov ecx, 4
        repz cmpsd
        jz foundkeyboard
		mov eax, DIERR_DEVICENOTREG
        jmp exit
foundmouse:
		invoke Create@MouDevice, lplpDirectInputDevice
        jmp exit
foundkeyboard:
		invoke Create@KbdDevice, lplpDirectInputDevice
exit:        
ifdef _DEBUG
		mov edx, refguid
endif
		@strace	<"DirectInput::CreateDevice(", pThis, ", ", refguid, " [", [edx+0], " ", [edx+4], " ", [edx+8], " ", [edx+12], ", ", lplpDirectInputDevice, ", ", lpUnkOuter, ")=", eax>
		ret
        align 4
_CreateDevice endp

_EnumDevices proc pThis:ptr DINPOBJ, dwDevType:DWORD, lpCallback:LPDIENUMDEVICESCALLBACKA, pvRef:LPVOID, dwFlags:DWORD

local	didi:DIDEVICEINSTANCEA

		mov ecx, dwDevType
        .if (ecx)
            .if (cl == DIDEVTYPE_KEYBOARD)
            	call enumkbd
	            mov eax, DI_OK
            .elseif (cl == DIDEVTYPE_MOUSE)
            	call enummou
	            mov eax, DI_OK
            .else
				mov eax, DIERR_INVALIDPARAM
            .endif
        .else
        	call enumkbd
            .if (eax == DIENUM_CONTINUE)
	            call enummou
            .endif
            mov eax, DI_OK
        .endif
		@strace	<"DirectInput::EnumDevices(", pThis, ", ", dwDevType, ", ", lpCallback, ", ", pvRef, ", ", dwFlags, ")=", eax>
		ret
enumkbd:
		mov didi.dwSize,sizeof DIDEVICEINSTANCEA
		mov didi.dwDevType,DIDEVTYPE_KEYBOARD or (DIDEVTYPEKEYBOARD_PCENH shl 8)
        invoke lstrcpy, addr didi.tszInstanceName, CStr("Keyboard")
        invoke lstrcpy, addr didi.tszProductName, CStr("Keyboard")
        invoke RtlMoveMemory, addr didi.guidInstance, addr GUID_SysKeyboard, sizeof GUID
        invoke RtlMoveMemory, addr didi.guidProduct, addr GUID_SysKeyboard, sizeof GUID
		push pvRef
        lea eax, didi
        push eax
		call lpCallback
		retn
enummou:
		mov didi.dwSize,sizeof DIDEVICEINSTANCEA
		mov didi.dwDevType,DIDEVTYPE_MOUSE or (DIDEVTYPEMOUSE_TRADITIONAL shl 8)
        invoke lstrcpy, addr didi.tszInstanceName, CStr("Mouse")
        invoke lstrcpy, addr didi.tszProductName, CStr("Mouse")
        invoke RtlMoveMemory, addr didi.guidInstance, addr GUID_SysMouse, sizeof GUID
        invoke RtlMoveMemory, addr didi.guidProduct, addr GUID_SysMouse, sizeof GUID
		push pvRef
        lea eax, didi
        push eax
		call lpCallback
		retn
        align 4
_EnumDevices endp

_GetDeviceStatus proc pThis:ptr DINPOBJ, refguid:ptr GUID
		mov eax, DIERR_NOTINITIALIZED
		@strace	<"DirectInput::GetDeviceStatus(", pThis, ", ", refguid, ")=", eax>
		ret
        align 4
_GetDeviceStatus endp

_RunControlPanel proc pThis:ptr DINPOBJ, hwndOwner:DWORD, dwFlags:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace	<"DirectInput::RunControlPanel(", pThis, ", ", hwndOwner, ", ", dwFlags, ")=", eax>
		ret
        align 4
_RunControlPanel endp

_Initialize proc pThis:ptr DINPOBJ, hinst:HINSTANCE, dwVersion:DWORD
		mov eax, DI_OK
		@strace	<"DirectInput::Initialize(", pThis, ", ", hinst, ", ", dwVersion, ")=", eax>
		ret
        align 4
_Initialize endp

;--- IDirectInput2 function

_FindDevice proc pThis:ptr DINPOBJ, rguidClass:REFGUID, ptszName:ptr BYTE, pguidInstance:REFGUID
		mov eax, DIERR_DEVICENOTREG
		@strace	<"DirectInput::FindDevice(", pThis, ", ", ptszName, ", ", pguidInstance, ")=", eax>
		ret
        align 4
_FindDevice endp

;--- IDirectInput7 function

_CreateDeviceEx proc uses esi edi pThis:ptr DINPOBJ, rguid:ptr GUID, riid:ptr GUID, lplpDirectInputDevice:ptr LPDIRECTINPUTDEVICEA, lpUnkOuter:LPUNKNOWN

local	lpDID:dword

		invoke _CreateDevice, pThis, rguid, addr lpDID, lpUnkOuter
        .if (eax == DI_OK)
        	invoke vf(lpDID, IUnknown, QueryInterface), riid, lplpDirectInputDevice
            push eax
            invoke vf(lpDID, IUnknown, Release)
            pop eax
        .endif
		@strace	<"DirectInput::CreateDeviceEx(", pThis, ", ", rguid, " [", [edx+0], " ", [edx+4], " ", [edx+8], " ", [edx+12], ", ", lplpDirectInputDevice, ", ", lpUnkOuter, ")=", eax>
		ret
        align 4
_CreateDeviceEx endp

        END

