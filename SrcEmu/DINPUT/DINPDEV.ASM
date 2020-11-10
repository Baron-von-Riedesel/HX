
;--- implements IDirectInputDevice, IDirectInputDevice2, IDirectInputDevice7

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include winuser.inc
	include dinput.inc
	include ddinput.inc
	include macros.inc

?ENABLEMOUSE	equ 1	;DKRNL32 does NOT enable mouse input as default!

_GetKeyTable proto
_SetKbdEventHandler proto :DWORD, :DWORD
_SetMouEventHandler proto :DWORD, :DWORD

;--- structures copied from dkrnl32.inc

KEYEVNT struct
bScan	db ?	;bit 7 tells if key is released
		db ?
		db ?
		db ?
bStat96	db ?	;bit 1 tells if it is an extended key        
KEYEVNT ends

MOUEVNT struct
wPosX	dw ?
wPosY	dw ?
wPosZ	dw ?
wState	dw ?
wMask	dw ?
MOUEVNT ends

protoSetEventProc typedef proto :DWORD, :DWORD
LPFNSETEVENTPROC typedef ptr protoSetEventProc

DINPDEV struct
vft			dd ?
dwCnt		dd ?
hEvent		dd ?	;event set by SetEventNotification
hwnd		dd ?	;hwnd SetCooperativelevel
dwCoopFlags	dd ?	;flags SetCooperativelevel
dwFlags		dd ?	;flags DIDataFormat (rel|abs)
pBuffer		dd ?
dwBufferLen	dd ?	;size of buffer in bytes
dwOfsRead  	dd ?
dwOfsWrite	dd ?
dwFreeItems	dd ?	;free items in buffer
dwBufferSize dd ?	;max items in buffer
pEventProc	dd ?
pSetEventProc LPFNSETEVENTPROC ?
bType		db ?	;DIF_SYSKBD or DIF_SYSMOU
bAcquired	db ?	;set/reset by Acquire/Unacquire
DINPDEV ends

DIF_SYSKBD	equ 1
DIF_SYSMOU	equ 2

QueryInterface proto pThis:ptr DINPDEV,refiid:dword,pObj:dword
AddRef         proto pThis:ptr DINPDEV
Release        proto pThis:ptr DINPDEV
Unacquire      proto pThis:ptr DINPDEV

	.DATA

;protokeybd_event typedef proto :dword, :dword, :dword, :dword
;LPFNKEYBD_EVENT typedef ptr protokeybd_event
;protoMapVirtualKey typedef proto :dword, :dword
;LPFNMAPVIRTUALKEY typedef ptr protoMapVirtualKey
        
g_dwSequence	dd 0        
g_lPosX			SDWORD 0	;last mouse X pos
g_lPosY			SDWORD 0	;last mouse Y pos
g_lPosZ			SDWORD 0	;last mouse Z pos
g_lDiffX		SDWORD 0
g_lDiffY		SDWORD 0
g_lDiffZ		SDWORD 0
g_dwState		dd 0		;last mouse button state
;g_lpfnkeybd_event LPFNKEYBD_EVENT 0
;g_lpfnMapVirtualKey LPFNMAPVIRTUALKEY 0
g_bConMouEnabled db 0		;saved console mode mouse state

		.CONST
        
IID_IDirectInputDeviceA		GUID <5944E680h , 0C92Eh , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
IID_IDirectInputDevice2A	GUID <5944E682h , 0C92Eh , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
IID_IDirectInputDevice7A	GUID <57D7C6BCh ,  2356h , 11D3h , < 8Eh ,  9Dh , 00h ,0C0h , 4Fh , 68h , 44h ,0AEh>>

GUID_XAxis	GUID < 0A36D02E0h , 0C9F3h , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
GUID_YAxis	GUID < 0A36D02E1h , 0C9F3h , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
GUID_ZAxis	GUID < 0A36D02E2h , 0C9F3h , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
GUID_Button	GUID < 0A36D02F0h , 0C9F3h , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>
GUID_Key    GUID <  55728220h , 0D33Ch , 11CFh , <0BFh , 0C7h , 44h , 45h , 53h , 54h , 00h , 00h>>

didvf   label DINPDEVVFT
		dd QueryInterface, AddRef, Release
		dd GetCapabilities
		dd EnumObjects
		dd GetProperty
		dd SetProperty
		dd Acquire
		dd Unacquire
		dd GetDeviceState
		dd GetDeviceData
		dd SetDataFormat
		dd SetEventNotification
		dd SetCooperativeLevel
		dd GetObjectInfo
		dd GetDeviceInfo
		dd RunControlPanel
		dd Initialize
;--- IDirectInputDevice2 methods        
		dd CreateEffect
		dd EnumEffects
		dd GetEffectInfo
		dd GetForceFeedbackState
		dd SendForceFeedbackCommand
		dd EnumCreatedEffectObjects
		dd Escape
		dd Poll
		dd SendDeviceData
;--- IDirectInputDevice7 methods        
		dd EnumEffectsInFile
		dd WriteEffectToFile

BTNTABENTRY struct
bBit	db ?
bOfs	db ?
BTNTABENTRY ends

btntab label byte
	BTNTABENTRY <1, DIMOFS_BUTTON0>
	BTNTABENTRY <2, DIMOFS_BUTTON1>
	BTNTABENTRY <4, DIMOFS_BUTTON2>
	BTNTABENTRY <8, DIMOFS_BUTTON3>
btntab_end label byte    

AXISTABENTRY struct
dwOfs	dd ?
pGuid	dd ?
pName	dd ?
AXISTABENTRY ends

axistab label AXISTABENTRY
		AXISTABENTRY <DIMOFS_X, offset GUID_XAxis, offset szXAxis>
		AXISTABENTRY <DIMOFS_Y, offset GUID_YAxis, offset szYAxis>
		AXISTABENTRY <DIMOFS_Z, offset GUID_ZAxis, offset szZAxis>
axistab_end label byte

szXAxis	db "X-Axis",0
szYAxis	db "Y-Axis",0
szZAxis	db "Z-Axis",0

		.CODE

DeleteSysDevices proc public
		invoke  _SetKbdEventHandler, 0, 0
		invoke  _SetMouEventHandler, 0, 0
		ret
		align 4
DeleteSysDevices endp

Create@KbdDevice proc public uses ebx pDID:ptr dword

		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DINPDEV
		and eax,eax
		jz error
		mov ebx, eax
		mov [ebx].DINPDEV.vft, offset didvf
		mov [ebx].DINPDEV.dwCnt, 1
		mov [ebx].DINPDEV.bType, DIF_SYSKBD
		mov [ebx].DINPDEV.pEventProc, offset kbdeventproc
		mov [ebx].DINPDEV.pSetEventProc, offset _SetKbdEventHandler
		mov ecx,pDID
		mov [ecx], ebx
		mov eax,DI_OK
		jmp exit
error:
		mov eax,DIERR_OUTOFMEMORY
exit:  
		@strace <"Create@KbdDevice(", pDID, ")=", eax>
		ret
		align 4

Create@KbdDevice endp

if ?ENABLEMOUSE

EnableMouse proc uses ebx

		invoke GetStdHandle, STD_INPUT_HANDLE
		mov ebx, eax
		push eax
		invoke GetConsoleMode, ebx, esp
		pop	ecx
		.if (!(cl & ENABLE_MOUSE_INPUT))
			mov g_bConMouEnabled, TRUE
			or cl, ENABLE_MOUSE_INPUT
			invoke SetConsoleMode, ebx, ecx
		.endif
		xor ecx,ecx
		xor edx,edx
		mov ax,0003		;modifies BX
		int 33h
		movsx ecx,cx
		movsx edx,dx
		mov [g_lPosX],ecx
		mov [g_lPosY],edx
		ret
		align 4

EnableMouse endp

DisableMouse proc uses ebx

		.if (g_bConMouEnabled)
			mov g_bConMouEnabled, FALSE
			invoke GetStdHandle, STD_INPUT_HANDLE
			mov ebx, eax
			push eax
			invoke	GetConsoleMode, ebx, esp
			pop ecx
			and cl, not ENABLE_MOUSE_INPUT
			invoke SetConsoleMode, ebx, ecx
		.endif
		ret
		align 4

DisableMouse endp
endif

Create@MouDevice proc public uses ebx pDID:ptr dword

		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DINPDEV
		and eax,eax
		jz error
		mov ebx, eax
		mov [ebx].DINPDEV.vft, offset didvf
		mov [ebx].DINPDEV.dwCnt, 1
		mov [ebx].DINPDEV.bType, DIF_SYSMOU
		mov [ebx].DINPDEV.pEventProc, offset moueventproc
		mov [ebx].DINPDEV.pSetEventProc, offset _SetMouEventHandler
if ?ENABLEMOUSE
		invoke EnableMouse
endif
		mov ecx,pDID
		mov [ecx], ebx
		mov eax,DI_OK
		jmp exit
error:
		mov eax,DIERR_OUTOFMEMORY
exit:
		@strace <"Create@MouDevice(", pDID, ")=", eax>
		ret
		align 4

Create@MouDevice endp

QueryInterface proc uses esi edi pThis:ptr DINPDEV, pIID:dword, pObj:dword

		mov edx, pThis
		mov edi,offset IID_IDirectInputDeviceA
		mov eax,pIID
		mov esi,eax
		mov ecx,4
		repz cmpsd
		jz found
		mov edi,offset IID_IDirectInputDevice2A
		mov esi,eax
		mov cl,4
		repz cmpsd
		jz found
		mov edi,offset IID_IDirectInputDevice7A
		mov esi,eax
		mov cl,4
		repz cmpsd
		jz found
		mov ecx,pObj
		mov dword ptr [ecx],0
		mov eax,DIERR_NOINTERFACE
ifdef _DEBUG
		int 3
endif
		jmp exit
found:
		mov ecx, pObj
		mov [ecx], edx
		invoke AddRef, edx
		mov eax,DI_OK
exit:
ifdef _DEBUG
		mov edx, pIID
endif
		@strace <"DirectInputDevice::QueryInterface(", pThis, ", ", pIID, " [", [edx+0], " ", [edx+4], " ", [edx+8], " ", [edx+12], "])=", eax>
		ret
		align 4

QueryInterface endp

AddRef proc pThis:ptr DINPDEV
		mov ecx, pThis
		mov eax, [ecx].DINPDEV.dwCnt
		inc [ecx].DINPDEV.dwCnt
		@strace <"DirectInputDevice::AddRef(", pThis, ")=", eax>
		ret
		align 4
AddRef endp

Release proc uses ebx pThis:ptr DINPDEV
		mov ebx, pThis
		mov eax, [ebx].DINPDEV.dwCnt
		dec [ebx].DINPDEV.dwCnt
		.if (ZERO?)
			.if ([ebx].DINPDEV.bAcquired)
				invoke Unacquire, ebx
			.endif
			.if ([ebx].DINPDEV.pBuffer)
				invoke LocalFree, [ebx].DINPDEV.pBuffer
			.endif
if ?ENABLEMOUSE
			.if ([ebx].DINPDEV.bType == DIF_SYSMOU)
				invoke DisableMouse
			.endif
endif
			invoke LocalFree, ebx
			xor eax, eax
		.endif
		@strace <"DirectInputDevice::Release(", pThis, ")=", eax>
		ret
		align 4
Release endp

GetCapabilities proc uses ebx pThis:ptr DINPDEV, lpDIDevCaps:LPDIDEVCAPS
		mov ebx, pThis
		mov edx, lpDIDevCaps
		.if ([ebx].DINPDEV.bType == DIF_SYSMOU)
			mov [edx].DIDEVCAPS.dwFlags, DIDC_ATTACHED
			mov [edx].DIDEVCAPS.dwDevType, DIDEVTYPE_MOUSE
			mov [edx].DIDEVCAPS.dwAxes, 2
			mov [edx].DIDEVCAPS.dwButtons, 2
			mov [edx].DIDEVCAPS.dwPOVs, 0
			mov eax, DI_OK
		.elseif ([ebx].DINPDEV.bType == DIF_SYSKBD)
			mov [edx].DIDEVCAPS.dwFlags, DIDC_ATTACHED
			mov [edx].DIDEVCAPS.dwDevType, DIDEVTYPE_KEYBOARD
			mov [edx].DIDEVCAPS.dwAxes, 0
			mov [edx].DIDEVCAPS.dwButtons, 128
			mov [edx].DIDEVCAPS.dwPOVs, 0
			mov eax, DI_OK
		.else
			mov eax, DIERR_NOTINITIALIZED
		.endif
		@strace <"DirectInputDevice::GetCapabilities(", pThis, ")=", eax>
		ret
		align 4
GetCapabilities endp

EnumObjects proc uses ebx esi edi pThis:ptr DINPDEV, lpCallback:LPDIENUMDEVICEOBJECTSCALLBACKA, pvRef:LPVOID, dwFlags:DWORD

local	didoi:DIDEVICEOBJECTINSTANCEA

		invoke RtlZeroMemory, addr didoi, sizeof DIDEVICEOBJECTINSTANCEA
		mov didoi.dwSize, sizeof DIDEVICEOBJECTINSTANCEA

		mov ebx, pThis
		mov esi, dwFlags
		.if (esi == DIDFT_ALL)
			mov esi,-1
		.endif
		.if (esi & DIDFT_AXIS)
			call enumaxis
			cmp eax,DIENUM_CONTINUE
			jnz @exit
		.endif
		.if (esi & DIDFT_BUTTON)
			call enumbtn
		.endif
@exit:
		mov eax, DI_OK
		@strace	<"DirectInputDevice::EnumObjects(", pThis, ", ", lpCallback, ", ", pvRef, ", ", dwFlags, ")=", eax>
		ret
callcb:
		push pvRef
		lea eax, didoi
		push eax
		call lpCallback
		retn
enumaxis:
		.if ([ebx].DINPDEV.bType == DIF_SYSMOU)
			mov edi, offset axistab
			.while (edi < offset axistab_end)
				invoke RtlMoveMemory, addr didoi.guidType, [edi].AXISTABENTRY.pGuid, sizeof GUID
				mov eax, [edi].AXISTABENTRY.dwOfs
				mov didoi.dwOfs, eax
				invoke lstrcpy, addr didoi.tszName, [edi].AXISTABENTRY.pName
				call callcb
				add edi, sizeof AXISTABENTRY
				.break .if (eax != DIENUM_CONTINUE)
			.endw
		.else
			mov eax, DIENUM_CONTINUE
		.endif
		retn
enumbtn:
		.if ([ebx].DINPDEV.bType == DIF_SYSMOU)
			invoke RtlMoveMemory, addr didoi.guidType, addr GUID_Button, sizeof GUID
			mov edi, offset btntab
			.while (edi < offset btntab_end)
				movzx eax, [edi].BTNTABENTRY.bOfs
				mov didoi.dwOfs, eax
				call callcb
				add edi, sizeof BTNTABENTRY
				.break .if (eax != DIENUM_CONTINUE)
			.endw
		.elseif ([ebx].DINPDEV.bType == DIF_SYSKBD)
			invoke RtlMoveMemory, addr didoi.guidType, addr GUID_Key, sizeof GUID
			mov edi, 0
			.while (edi < 128)
				mov didoi.dwOfs, edi
				call callcb
				inc edi
				.break .if (eax != DIENUM_CONTINUE)
			.endw
		.else
			mov eax, DIENUM_CONTINUE
		.endif
		retn
		align 4

EnumObjects endp

GetProperty proc uses ebx pThis:ptr DINPDEV,  rguidProp:ptr GUID, pdiph:LPDIPROPHEADER

		mov ebx, pThis
		mov edx, rguidProp
		.if ((edx >= DIPROP_BUFFERSIZE) && (edx <= DIPROP_AUTOCENTER))
			.if (edx == DIPROP_BUFFERSIZE)
				mov eax, [ebx].DINPDEV.dwBufferSize
				mov [ecx].DIPROPDWORD.dwData, eax
				mov eax, DI_OK
			.elseif (edx == DIPROP_AXISMODE)
				.if ([ebx].DINPDEV.dwFlags & DIDF_ABSAXIS)
					mov [ecx].DIPROPDWORD.dwData, DIPROPAXISMODE_ABS
				.elseif ([ebx].DINPDEV.dwFlags & DIDF_RELAXIS)
					mov [ecx].DIPROPDWORD.dwData, DIPROPAXISMODE_REL
				.endif
				mov eax, DI_OK
			.else
				mov eax, DIERR_OBJECTNOTFOUND
			.endif
			@strace <"DirectInputDevice::GetProperty(", ebx, ", ", rguidProp, ", ", pdiph, ")=", eax>
		.else
			mov eax, DIERR_OBJECTNOTFOUND
			@strace <"DirectInputDevice::GetProperty(", ebx, ", ", rguidProp, " [", [edx+0], " ", [edx+4], " ", [edx+8], " ", [edx+12], "], ", pdiph, ")=", eax>
		.endif
		ret
		align 4

GetProperty endp

SetProperty proc uses ebx esi pThis:ptr DINPDEV, rguidProp:ptr GUID, pdiph:LPCDIPROPHEADER

		mov ebx, pThis
		mov edx, rguidProp
		mov esi, pdiph
ifdef _DEBUG
		@strace <"PropHeader: size=", [esi].DIPROPHEADER.dwSize, " hdrsize=", [esi].DIPROPHEADER.dwHeaderSize, " obj=", [esi].DIPROPHEADER.dwObj, " how=", [esi].DIPROPHEADER.dwHow>
endif	
		.if ((edx >= DIPROP_BUFFERSIZE) && (edx <= DIPROP_AUTOCENTER))
			.if (edx == DIPROP_BUFFERSIZE)
				.if ([ebx].DINPDEV.bAcquired)
					mov eax, DIERR_ACQUIRED
					jmp exit1
				.endif
				.if ([ebx].DINPDEV.pBuffer)
					mov [ebx].DINPDEV.dwFreeItems, 0
					invoke LocalFree, [ebx].DINPDEV.pBuffer
					mov [ebx].DINPDEV.pBuffer, 0
				.endif
				mov eax, [esi].DIPROPDWORD.dwData
				mov [ebx].DINPDEV.dwBufferSize, eax
				mov [ebx].DINPDEV.dwOfsRead, 0
				mov [ebx].DINPDEV.dwOfsWrite, 0
				@strace <"DirectInputDevice::SetProperty new BUFFERSIZE=", eax>
				.if (eax)
					mov ecx, sizeof DIDEVICEOBJECTDATA
					mul ecx
					invoke LocalAlloc, LMEM_FIXED, eax
					mov [ebx].DINPDEV.pBuffer, eax
					.if (eax)
						mov ecx, [ebx].DINPDEV.dwBufferSize
						shl ecx, 4
						mov [ebx].DINPDEV.dwBufferLen, ecx
						mov eax, [ebx].DINPDEV.dwBufferSize
						mov [ebx].DINPDEV.dwFreeItems, eax
					.endif
				.endif
				mov eax, DI_OK
			.elseif (edx == DIPROP_AXISMODE)
				mov eax, [esi].DIPROPDWORD.dwData
				.if (eax == DIPROPAXISMODE_ABS)
					and [ebx].DINPDEV.dwFlags, not (DIDF_ABSAXIS or DIDF_RELAXIS)
					or	[ebx].DINPDEV.dwFlags, DIDF_ABSAXIS
				.elseif (eax == DIPROPAXISMODE_REL)
					and [ebx].DINPDEV.dwFlags, not (DIDF_ABSAXIS or DIDF_RELAXIS)
					or	[ebx].DINPDEV.dwFlags, DIDF_RELAXIS
				.endif
				mov eax, DI_OK
			.else
				mov eax, DIERR_OBJECTNOTFOUND
			.endif
exit1:			  
			@strace <"DirectInputDevice::SetProperty(", ebx, ", ", rguidProp, ", ", pdiph, ")=", eax>
		.else
			mov eax, DIERR_OBJECTNOTFOUND
			@strace <"DirectInputDevice::SetProperty(", ebx, ", ", rguidProp, " [", [edx+0], " ", [edx+4], " ", [edx+8], " ", [edx+12], "], ", pdiph, ")=", eax>
		.endif
		ret
		align 4

SetProperty endp

;--- all registers can be modified!

kbdeventproc proc pThis:ptr DINPDEV, pEvent:ptr

		mov esi, pThis
		.if ([esi].DINPDEV.dwFreeItems)
			invoke _GetKeyTable
			mov edx, eax
			mov edi, [esi].DINPDEV.dwOfsWrite
			add edi, [esi].DINPDEV.pBuffer
			mov ebx, pEvent
			mov al, [ebx].KEYEVNT.bScan
			and al, 7Fh
			test [ebx].KEYEVNT.bStat96,2
			jz @F
			or al,80h
@@:
			movzx eax, al
			bt [edx], eax
			jnc @F			;is not pressed currently
			test [ebx].KEYEVNT.bScan,80h
			jz skipevent	;it is a key repeat event
@@:
			mov [edi].DIDEVICEOBJECTDATA.dwOfs, eax
			movzx eax, [ebx].KEYEVNT.bScan
			and al, 80h
			xor al, 80h
			mov [edi].DIDEVICEOBJECTDATA.dwData, eax
			invoke GetTickCount
			mov [edi].DIDEVICEOBJECTDATA.dwTimeStamp, eax
			inc g_dwSequence
			mov eax, g_dwSequence
			mov [edi].DIDEVICEOBJECTDATA.dwSequence, eax
			lea eax, [edi+sizeof DIDEVICEOBJECTDATA]
			sub eax, [esi].DINPDEV.pBuffer
			cmp eax, [esi].DINPDEV.dwBufferLen
			jnz @F
			xor eax, eax
@@:
			mov [esi].DINPDEV.dwOfsWrite, eax
			dec [esi].DINPDEV.dwFreeItems
			.if ([esi].DINPDEV.hEvent)
				invoke SetEvent, [esi].DINPDEV.hEvent
			.endif
		.endif
skipevent:
;--- return with Carry if dkrnl32 should queue the event
		mov eax,1	;DISCL_NONEXCLUSIVE is bit 1
		bt [esi].DINPDEV.dwCoopFlags, eax
		ret
		align 4

kbdeventproc endp

;--- SS is unknown!
;--- the pEvent is a flat ptr

moueventproc proc pThis:ptr DINPDEV, pEvent:ptr

		mov esi, pThis
		mov ebx, pEvent
		movsx eax, [ebx].MOUEVNT.wPosX	 
		.if (eax != g_lPosX)
			mov ecx, eax
			.if ([esi].DINPDEV.dwFlags & DIDF_RELAXIS)
				sub eax, g_lPosX
				mov g_lDiffX, eax
			.endif
			mov g_lPosX, ecx
			mov ecx, DIMOFS_X
			call writemouseevent
		.endif
		movsx eax, [ebx].MOUEVNT.wPosY	 
		.if (eax != g_lPosY)
			mov ecx, eax
			.if ([esi].DINPDEV.dwFlags & DIDF_RELAXIS)
				sub eax, g_lPosY
				mov g_lDiffY, eax
			.endif
			mov g_lPosY, ecx
			mov ecx, DIMOFS_Y
			call writemouseevent
		.endif
if 1
		movsx eax, [ebx].MOUEVNT.wPosZ	 
		.if (eax != g_lPosZ)
			mov ecx, eax
			.if ([esi].DINPDEV.dwFlags & DIDF_RELAXIS)
				sub eax, g_lPosZ
				mov g_lDiffZ, eax
			.endif
			mov g_lPosZ, ecx
			mov ecx, DIMOFS_Z
			call writemouseevent
		.endif
endif
		movzx eax, [ebx].MOUEVNT.wState
		.if (eax != g_dwState)
			mov edx, eax
			xor edx, g_dwState
			mov g_dwState, eax
			mov eax, offset btntab
			.repeat 
				test dl, [eax].BTNTABENTRY.bBit
				.if (!ZERO?)
					push edx
					push eax
					mov dl, [eax].BTNTABENTRY.bBit
					movzx ecx, [eax].BTNTABENTRY.bOfs
					test dl, byte ptr [ebx].MOUEVNT.wState
					setnz al
					shl al,7
					movzx eax,al
					call writemouseevent
					pop eax
					pop edx
				.endif
				add eax, sizeof BTNTABENTRY
			.until (eax == offset btntab_end)
		.endif
;--- return with Carry if dkrnl32 should queue the event
		mov eax,1	;DISCL_NONEXCLUSIVE is bit 1
		bt [esi].DINPDEV.dwCoopFlags, eax
		ret
		align 4
writemouseevent:
		.if ([esi].DINPDEV.dwFreeItems)
			mov edi, [esi].DINPDEV.dwOfsWrite
			add edi, [esi].DINPDEV.pBuffer
			
			mov [edi].DIDEVICEOBJECTDATA.dwOfs, ecx
			mov [edi].DIDEVICEOBJECTDATA.dwData, eax

;--- calling Win32 functions with SS != FLAT? Will this work?

			invoke GetTickCount
			mov [edi].DIDEVICEOBJECTDATA.dwTimeStamp, eax
			inc g_dwSequence
			mov eax, g_dwSequence
			mov [edi].DIDEVICEOBJECTDATA.dwSequence, eax
			lea eax, [edi+sizeof DIDEVICEOBJECTDATA]
			sub eax, [esi].DINPDEV.pBuffer
			cmp eax, [esi].DINPDEV.dwBufferLen
			jnz @F
			xor eax, eax
@@:
			mov [esi].DINPDEV.dwOfsWrite, eax
			dec [esi].DINPDEV.dwFreeItems
			.if ([esi].DINPDEV.hEvent)
				invoke SetEvent, [esi].DINPDEV.hEvent
			.endif
		.endif
		retn
		align 4

moueventproc endp

Acquire proc uses ebx pThis:ptr DINPDEV

		mov ebx, pThis
		.if ([ebx].DINPDEV.bAcquired)
			mov eax, DI_NOEFFECT
		.else
			mov [ebx].DINPDEV.bAcquired, TRUE
			invoke [ebx].DINPDEV.pSetEventProc, [ebx].DINPDEV.pEventProc, ebx
			.if ([ebx].DINPDEV.bType == DIF_SYSMOU)
			   .if ([ebx].DINPDEV.dwCoopFlags & DISCL_EXCLUSIVE)
					mov ax,0002
					int 33h
			   .endif
			.endif
			mov eax, DI_OK
		.endif
		@strace <"DirectInputDevice::Acquire(", pThis, ")=", eax>
		ret
		align 4

Acquire endp

Unacquire proc uses ebx pThis:ptr DINPDEV

		mov ebx, pThis
		.if ([ebx].DINPDEV.bAcquired)
			mov [ebx].DINPDEV.bAcquired, FALSE
			invoke [ebx].DINPDEV.pSetEventProc, 0, 0
			.if ([ebx].DINPDEV.bType == DIF_SYSMOU)
				.if ([ebx].DINPDEV.dwCoopFlags & DISCL_EXCLUSIVE)
					mov ax,0001
					int 33h
				.endif
			.endif
			mov eax, DI_OK
		.else
			mov eax, DI_NOEFFECT
		.endif
		@strace <"DirectInputDevice::Unacquire(", pThis, ")=", eax>
		ret
		align 4

Unacquire endp

GetDeviceState proc uses ebx esi pThis:ptr DINPDEV, cbData:DWORD, lpvData:LPVOID

		mov ebx, pThis
		mov ecx, lpvData
		.if ([ebx].DINPDEV.bType == DIF_SYSMOU)
			.if ([ebx].DINPDEV.dwFlags & DIDF_RELAXIS)
				mov eax, g_lDiffX
				mov edx, g_lDiffY
				mov esi, g_lDiffZ
			.else
				mov eax, g_lPosX
				mov edx, g_lPosY
				mov esi, g_lPosZ
			.endif
			mov [ecx].DIMOUSESTATE.lX, eax
			mov [ecx].DIMOUSESTATE.lY, edx
			mov [ecx].DIMOUSESTATE.lZ, esi
			mov edx, g_dwState
			mov esi, offset btntab
			.repeat
				movzx ebx, [esi].BTNTABENTRY.bOfs
				test dl, [esi].BTNTABENTRY.bBit
				setnz al
				shl al,7
				mov [ecx+ebx],al
				add esi, sizeof BTNTABENTRY
			.until (esi == offset btntab_end)
			mov eax, DI_OK
		.elseif ([ebx].DINPDEV.bType == DIF_SYSKBD)
			invoke _GetKeyTable
			mov ebx, eax			;index is scan code (2*128 bits)
			mov ecx, cbData
			xor edx, edx
			mov esi, lpvData
			.while (ecx)
				bt [ebx], edx
				setc al
				shl al,7
				mov [esi+edx],al
				inc edx
				dec ecx
			.endw
			mov eax, DI_OK
		.else
			mov eax, DIERR_NOTINITIALIZED
		.endif
		@strace <"DirectInputDevice::GetDeviceState(", pThis, ", ", cbData, ", ", lpvData, ")=", eax>
		ret
		align 4

GetDeviceState endp

;--- method to get data from the device
;--- cbObjData: size of DIDEVICEOBJECTDATA structure
;--- rgdod: pointer to array of DIDEVICEOBJECTDATA items (or NULL)
;--- pdwInOut: [in]: size of array to which rgdod points
;---          [out]: number of items returned
;--- dwFlags: if DIGDD_PEEK is set, dont remove items from buffer

GetDeviceData proc uses ebx esi edi pThis:ptr DINPDEV, cbObjData:DWORD, rgdod:LPDIDEVICEOBJECTDATA, pdwInOut:ptr DWORD, dwFlags:DWORD

		mov ecx, pdwInOut
		mov eax, [ecx]
		mov dword ptr [ecx],0
		mov ebx, pThis
		.if (![ebx].DINPDEV.bAcquired)
			mov eax, DIERR_NOTACQUIRED
		.elseif (![ebx].DINPDEV.dwBufferSize)
			mov eax, DIERR_NOTBUFFERED
		.else
			@strace <"DirectInputDevice::GetDeviceData(", pThis, "): items=", eax, ", ofsRead=", [ebx].DINPDEV.dwOfsRead, ", ofsWrite=", [ebx].DINPDEV.dwOfsWrite>
			mov edi, rgdod
			@noints
			cld
			mov esi, [ebx].DINPDEV.dwOfsRead
			mov edx, [ebx].DINPDEV.dwFreeItems
			mov ecx, eax
			.while (ecx && (esi != [ebx].DINPDEV.dwOfsWrite))
				.if (edi)
					push ecx
					push esi
					mov ecx, sizeof DIDEVICEOBJECTDATA
					add esi, [ebx].DINPDEV.pBuffer
					rep movsb
					pop esi
					pop ecx
				.endif
				add esi, sizeof DIDEVICEOBJECTDATA
				cmp esi, [ebx].DINPDEV.dwBufferLen
				jnz @F
				xor esi, esi
@@:
				dec ecx
				inc [ebx].DINPDEV.dwFreeItems
				mov eax, pdwInOut
				inc dword ptr [eax]
			.endw
			mov [ebx].DINPDEV.dwOfsRead, esi
			@restoreints
			mov eax, DI_OK
		.endif
ifdef _DEBUG
		mov ecx, pdwInOut
		mov edx, rgdod
		.if ((eax == DI_OK) && ecx && edx)
			@strace <"DeviceData: dwOfs=", [edx].DIDEVICEOBJECTDATA.dwOfs, " dwData=", [edx].DIDEVICEOBJECTDATA.dwData>
		.endif
endif
		@strace <"DirectInputDevice::GetDeviceData(", pThis, ", ", cbObjData, ", ", rgdod, ", ", pdwInOut, ", ", dwFlags, ")=", eax>
		ret
		align 4

GetDeviceData endp

SetDataFormat proc pThis:ptr DINPDEV, lpdf:LPCDIDATAFORMAT

		mov ecx, pThis
		.if ([ecx].DINPDEV.bAcquired)
			mov eax, DIERR_ACQUIRED
		.else
			mov edx, lpdf
			mov eax, [edx].DIDATAFORMAT.dwFlags
			mov [ecx].DINPDEV.dwFlags, eax
			mov eax, DI_OK
		.endif
ifdef _DEBUG
		mov edx, lpdf
		@strace <"DiDataFormat: dwSize=", [edx].DIDATAFORMAT.dwSize, " dwObjSize=", [edx].DIDATAFORMAT.dwObjSize, " dwFlags=", [edx].DIDATAFORMAT.dwFlags>
		@strace <"DiDataFormat: dwDataSize=", [edx].DIDATAFORMAT.dwDataSize, " dwNumObjs=", [edx].DIDATAFORMAT.dwNumObjs>
		mov ecx, [edx].DIDATAFORMAT.dwNumObjs
		mov edx, [edx].DIDATAFORMAT.rgodf
		.while (ecx)
			@strace <"DiObjectDataFormat: pguid=", [edx].DIOBJECTDATAFORMAT.pguid, " dwOfs=", [edx].DIOBJECTDATAFORMAT.dwOfs, " dwType=", [edx].DIOBJECTDATAFORMAT.dwType, " dwFlags=", [edx].DIOBJECTDATAFORMAT.dwFlags>
			add edx, sizeof DIOBJECTDATAFORMAT
			dec ecx
		.endw
endif
		@strace <"DirectInputDevice::SetDataFormat(", pThis, ", ", lpdf, ")=", eax>
		ret
		align 4

SetDataFormat endp

SetEventNotification proc pThis:ptr DINPDEV, hEvent:HANDLE

		mov ecx, pThis
		.if ([ecx].DINPDEV.bAcquired)
			mov eax, DIERR_ACQUIRED
		.else
			mov edx, hEvent
			.if (edx && [ecx].DINPDEV.hEvent)
				mov eax, DIERR_HANDLEEXISTS
			.else
				mov [ecx].DINPDEV.hEvent, edx
				mov eax, DI_OK
			.endif
		.endif
		@strace <"DirectInputDevice::SetEventNotification(", pThis, ", ", hEvent, ")=", eax>
		ret
		align 4

SetEventNotification endp

SetCooperativeLevel proc uses ebx pThis:ptr DINPDEV, hwnd:DWORD, dwFlags:DWORD

		mov ebx, pThis
		mov edx, hwnd
		mov eax, dwFlags
		mov [ebx].DINPDEV.hwnd, edx
		mov [ebx].DINPDEV.dwCoopFlags, eax
if 0
		.if (edx && (eax & DISCL_NONEXCLUSIVE) && ([ebx].DINPDEV.bType == DIF_SYSKBD))
			invoke GetModuleHandle, CStr("user32")
			.if (eax)
				mov ebx, eax
				invoke GetProcAddress, ebx, CStr("keybd_event")
				mov g_lpfnkeybd_event, eax
				invoke GetProcAddress, ebx, CStr("MapVirtualKeyA")
				mov g_lpfnMapVirtualKey, eax
			.endif
		.endif
endif
		mov eax, DI_OK
		@strace <"DirectInputDevice::SetCooperativeLevel(", pThis, ", ", hwnd, ", ", dwFlags, ")=", eax>
		ret
		align 4

SetCooperativeLevel endp

GetObjectInfo proc pThis:ptr DINPDEV, x:LPDIDEVICEOBJECTINSTANCEA, y:DWORD, z:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice::GetObjectInfo(", pThis, ")=", eax>
		ret
		align 4
GetObjectInfo endp

GetDeviceInfo proc pThis:ptr DINPDEV, x:LPDIDEVICEINSTANCEA
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice::GetDeviceInfo(", pThis, ")=", eax>
		ret
		align 4
GetDeviceInfo endp

RunControlPanel proc pThis:ptr DINPDEV, x:DWORD, y:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice::RunControlPanel(", pThis, ")=", eax>
		ret
		align 4
RunControlPanel endp

Initialize proc pThis:ptr DINPDEV, x:HINSTANCE, y:DWORD, z:ptr GUID
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice::Initialize(", pThis, ")=", eax>
		ret
		align 4
Initialize endp

;--- IDirectInputDevice2 methods

CreateEffect proc pThis:ptr DINPDEV, x:ptr GUID, y:LPCDIEFFECT, z:ptr LPDIRECTINPUTEFFECT, a:LPUNKNOWN
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::CreateEffect(", pThis, ")=", eax>
		ret
		align 4
CreateEffect endp

EnumEffects proc pThis:ptr DINPDEV, x:LPDIENUMEFFECTSCALLBACKA, y:LPVOID, z:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::EnumEffects(", pThis, ")=", eax>
		ret
		align 4
EnumEffects endp

GetEffectInfo proc pThis:ptr DINPDEV, x:LPDIEFFECTINFOA, y:ptr GUID
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::GetEffectInfo(", pThis, ")=", eax>
		ret
		align 4
GetEffectInfo endp

GetForceFeedbackState proc pThis:ptr DINPDEV, x:ptr DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::GetForceFeedbackState(", pThis, ")=", eax>
		ret
		align 4
GetForceFeedbackState endp

SendForceFeedbackCommand proc pThis:ptr DINPDEV, x:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::SendForceFeedbackCommand(", pThis, ")=", eax>
		ret
		align 4
SendForceFeedbackCommand endp

EnumCreatedEffectObjects proc pThis:ptr DINPDEV, x:LPDIENUMCREATEDEFFECTOBJECTSCALLBACK, y:LPVOID, z:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::EnumCreatedEffectObjects(", pThis, ")=", eax>
		ret
		align 4
EnumCreatedEffectObjects endp

Escape proc pThis:ptr DINPDEV, x:LPDIEFFESCAPE
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::Escape(", pThis, ")=", eax>
		ret
		align 4
Escape endp

Poll proc uses ebx pThis:ptr DINPDEV 

		mov ebx, pThis
		.if (![ebx].DINPDEV.bAcquired)
			mov eax, DIERR_NOTACQUIRED
		.else
			invoke [ebx].DINPDEV.pSetEventProc, -1, 0
			.if (eax != [ebx].DINPDEV.pEventProc)
				mov [ebx].DINPDEV.bAcquired, FALSE
				mov eax, DIERR_INPUTLOST
				jmp exit
			.endif
			mov eax, DI_NOEFFECT
		.endif
exit:
		@strace <"DirectInputDevice2::Poll(", pThis, ")=", eax>
		ret
		align 4

Poll endp

SendDeviceData proc pThis:ptr DINPDEV, x:DWORD, y:LPCDIDEVICEOBJECTDATA, z:ptr DWORD, a:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice2::SendDeviceData(", pThis, ")=", eax>
		ret
		align 4
SendDeviceData endp

;--- IDirectInputDevice7 methods

EnumEffectsInFile proc pThis:ptr DINPDEV, lpszFileName:ptr BYTE, pec:ptr, pvRef:ptr, dwFlags:DWORD
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice7::EnumEffectsInFile(", pThis, ")=", eax>
		ret
		align 4
EnumEffectsInFile endp

WriteEffectToFile proc pThis:ptr DINPDEV, lpszFileName:ptr BYTE, dwEntries:dword, rgDiFileEft:ptr, dwFlags:dword
		mov eax, DIERR_NOTINITIALIZED
		@strace <"DirectInputDevice7::WriteEffectToFile(", pThis, ")=", eax>
		ret
		align 4
WriteEffectToFile endp

		END

