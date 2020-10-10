
;--- implements:
;--- IDirectDraw
;--- IDirectDraw2
;--- IDirectDraw4
;--- IDirectDraw7

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	.nolist
	.nocref
	include winbase.inc
	include wincon.inc
	include wingdi.inc
	include winuser.inc
	include ddraw.inc
	include dddraw.inc
	include vesa32.inc
	include macros.inc
	.list
	.cref

?ALWAYSSETOLDMODE	equ 1	;set prev mode in any case because
							;some VESA bioses will not restore video state
                            ;properly

protoChangeDisplaySettingsA typedef proto :ptr DEVMODEA, :dword
LPFNCHANGEDISPLAYSETTINGSA typedef ptr protoChangeDisplaySettingsA
protoSendMessageA typedef proto :dword, :dword, :dword, :dword
LPFNSENDMESSAGEA typedef ptr protoSendMessageA
protoGetCursorPos typedef proto :dword
LPFNGETCURSORPOS typedef ptr protoGetCursorPos
protoShowWindow typedef proto :dword, :dword
LPFNSHOWWINDOW typedef ptr protoShowWindow

protoGetProfileString typedef proto :ptr BYTE, :ptr BYTE, :ptr BYTE, :DWORD
LPFNGETPROFILESTRING typedef ptr protoGetProfileString

DDOBJ   struct
vft			dd ?
vft2		dd ?
dwCnt		dd ?
dwFlags		dd ?
hUser32		dd ?
hwnd		dd ?		;hwnd from SetCooperativeLevel
dwCoFlags	dd ?		;flags from SetCooperativeLevel
lpVidMem	dd ?		;video memory start
dwVideoTotal dd ?		;total size of video ram
dwVideoFree  dd ?		;free size of video ram
if ?ALWAYSSETOLDMODE
dwPrevMode	dd ?
endif
dwVStateSize dd ?		;size of saved display mode register
pVStateBuffer dd ?		;saved display mode register
dwVMemSize	dd ?		;size of saved display mode video memory
pVMemBuffer	dd ?		;saved display mode buffer
DDOBJ   ends

DDOBJF_MODESET	equ 1	;SetDisplayMode called in FULLSCREEN mode
DDOBJF_MODESET2	equ 2	;IDirectDraw2::SetDisplayMode called!

QueryInterface proto pThis:ptr DDOBJ,refiid:dword,pObj:dword
AddRef         proto pThis:ptr DDOBJ
Release        proto pThis:ptr DDOBJ
Compact        proto pThis:ptr DDOBJ
CreateClipper  proto pThis:ptr DDOBJ, dwFlags:dword, ppDDClipper:ptr LPDIRECTDRAWCLIPPER, pIUnknown:dword
_CreatePalette proto pThis:ptr DDOBJ, dwFlags:dword, pPaletteEntry:LPPALETTEENTRY, ppDDPalette:ptr LPDIRECTDRAWPALETTE, pIUnknown:dword
CreateSurface  proto pThis:ptr DDOBJ, pSurfaceDesc:ptr DDSURFACEDESC, ppDDSurface:ptr LPDIRECTDRAWSURFACE, pIUnknown:dword
RestoreDisplayMode proto pThis:ptr DDOBJ

	.DATA

	public g_bMouse

g_lpfnChangeDisplaySettingsA LPFNCHANGEDISPLAYSETTINGSA 0
g_lpfnSendMessageA 			LPFNSENDMESSAGEA 0
g_lpfnGetCursorPos			LPFNGETCURSORPOS 0
g_lpfnShowWindow			LPFNSHOWWINDOW 0
g_lpfnGetDC					LPFNGETDC 0
g_lpfnReleaseDC				LPFNRELEASEDC 0

g_lpfnGetProfileString		LPFNGETPROFILESTRING 0

if ?USEXMM
        public g_dwCpuFeature
g_dwCpuFeature	dd 0
g_bCpuId		db 0
endif
g_bMouse		db 0			;1 -> mouse installed
g_bMouseInit	db 0			;1 -> VesaMouseInit returned 1
g_bConMouEnabled db 0

	.CONST

IID_IDirectDraw		GUID <06c14db80H, 0a733H, 011ceH, <0a5H, 021H, 000H, 020H, 0afH, 00bH, 0e5H, 060H>>
IID_IDirectDraw2	GUID <0b3a6f3e0H, 02b43H, 011cfH, <0a2H, 0deH, 000H, 0aaH, 000H, 0b9H, 033H, 056H>>
if ?DD4
IID_IDirectDraw4	GUID <09c59509ah, 039bdh, 011d1h, <08ch,  4ah,  00h, 0c0h,  4fh, 0d9h,  30h, 0c5h>>
endif
if ?DD7
IID_IDirectDraw7	GUID <015e65ec0h, 03b9ch,  11d2h, <0b9h,  2fh,  00h,  60h,  97h,  97h, 0eah,  5bh>>
endif

ddvf    label IDirectDrawVtbl
	dd QueryInterface, AddRef, Release
	dd Compact, CreateClipper, _CreatePalette, CreateSurface
	dd DuplicateSurface, EnumDisplayModes, EnumSurfaces, FlipToGDISurface
	dd GetCaps, GetDisplayMode, GetFourCCCodes, GetGDISurface
	dd GetMonitorFrequency, GetScanLine, GetVerticalBlankStatus
	dd Initialize, RestoreDisplayMode, SetCooperativeLevel, SetDisplayMode
	dd WaitForVerticalBlank

dd2vf   label IDirectDraw2Vtbl
	dd QueryInterface2, AddRef2, Release2
	dd Compact2, CreateClipper2, _CreatePalette2, CreateSurface2
	dd DuplicateSurface2, EnumDisplayModes2, EnumSurfaces2, FlipToGDISurface2
	dd GetCaps2, GetDisplayMode2, GetFourCCCodes2, GetGDISurface2
	dd GetMonitorFrequency2, GetScanLine2, GetVerticalBlankStatus2
	dd Initialize2, RestoreDisplayMode2, SetCooperativeLevel2, SetDisplayMode2
	dd WaitForVerticalBlank2
	dd GetAvailableVidMem
if ?DD4
	dd GetSurfaceFromDC
	dd RestoreAllSurfaces 
	dd TestCooperativeLevel 
	dd GetDeviceIdentifier
endif
if ?DD7
	dd StartModeTest
	dd EvaluateMode
endif

	.CODE

	.586

@MakeStub macro name, suffix, offs, bNoJump
name&suffix:
	sub dword ptr [esp+4], offs
ifb <bNoJump>
	jmp name
	align 4
endif
	endm

DDHAL32_VidMemAlloc proc public pThis:ptr DDOBJ, dwBytes:DWORD
DDHAL32_VidMemAlloc endp

AllocVideoMemory proc public pThis:ptr DDOBJ, dwBytes:DWORD

	mov edx, pThis
	xor eax, eax
	.if ([edx].DDOBJ.lpVidMem)
		mov ecx, dwBytes
		cmp [edx].DDOBJ.dwVideoFree, ecx
		jc exit
		mov eax, ecx
		mov ecx, [edx].DDOBJ.dwVideoTotal
		sub ecx, [edx].DDOBJ.dwVideoFree
		sub [edx].DDOBJ.dwVideoFree, eax
		mov eax, [edx].DDOBJ.lpVidMem
		add eax, ecx
	.endif
exit:
	@strace <"IDirectDraw::AllocVideoMemory(", pThis, ", ", dwBytes, ")=", eax>
	ret
	align 4

AllocVideoMemory endp

DDHAL32_VidMemFree  proc public pThis:ptr DDOBJ, dwBytes:DWORD
	mov eax, 1
	ret
	align 4
DDHAL32_VidMemFree  endp

GetVideoMemoryStart proc public pThis:ptr DDOBJ
	mov edx, pThis
	mov eax, [edx].DDOBJ.lpVidMem
	ret
	align 4
GetVideoMemoryStart endp

GetCoopLevel proc public pThis:ptr DDOBJ
	mov edx, pThis
	mov eax, [edx].DDOBJ.dwCoFlags
	ret
	align 4
GetCoopLevel endp

GetHwnd proc public pThis:ptr DDOBJ
	mov edx, pThis
	mov eax, [edx].DDOBJ.hwnd
	ret
	align 4
GetHwnd endp

_SendMessage proc public pThis:ptr DDOBJ, msg:dword, wParam:dword, lParam:dword
	mov ecx, pThis
	.if ([ecx].DDOBJ.hwnd && g_lpfnSendMessageA)
		mov eax, [ecx].DDOBJ.hwnd
		.if (msg == WM_PALETTECHANGED)
			.if ([ecx].DDOBJ.dwCoFlags & DDSCL_EXCLUSIVE)
				jmp exit
			.endif
			mov edx, [ecx].DDOBJ.hwnd
			mov wParam, edx
			mov eax, HWND_BROADCAST
		.endif
		invoke g_lpfnSendMessageA, eax, msg, wParam, lParam
	.endif
exit:
	ret
	align 4
_SendMessage endp

EnableMouse proc uses ebx
	invoke GetStdHandle, STD_INPUT_HANDLE
	mov ebx, eax
	push eax
	invoke GetConsoleMode, ebx, esp
	pop ecx
	.if (!(cl & ENABLE_MOUSE_INPUT))
		mov g_bConMouEnabled, TRUE
		or cl, ENABLE_MOUSE_INPUT
		invoke SetConsoleMode, ebx, ecx
	.endif
	ret
	align 4
EnableMouse endp

DisableMouse proc uses ebx
	.if (g_bConMouEnabled)
		mov g_bConMouEnabled, FALSE
		invoke GetStdHandle, STD_INPUT_HANDLE
		mov ebx, eax
		push eax
		invoke GetConsoleMode, ebx, esp
		pop ecx
		and cl, not ENABLE_MOUSE_INPUT
		invoke SetConsoleMode, ebx, ecx
	.endif
	ret
	align 4
DisableMouse endp

SetVideoVars proc uses esi pThis:ptr DDOBJ

local	svi:SVGAINFO                                    

	invoke GetVesaMode
	mov esi, eax
	.if (eax)
		invoke GetVesaModeInfo, esi, addr svi
		.if (eax)
			mov ecx, pThis
			mov eax, svi.PhysBasePtr
			mov [ecx].DDOBJ.lpVidMem, eax
			movzx eax, svi.BytesPerScanLine
			movzx edx, svi.YResolution
			mul edx
			mov edx, [ecx].DDOBJ.dwVideoTotal
			sub edx, eax
			mov [ecx].DDOBJ.dwVideoFree, edx
			mov eax, esi
			movzx edx, svi.ModeAttributes
		.endif
	.endif
	@strace <"SetVideoVars()=", eax, " edx=", edx > 
	ret
	align 4
SetVideoVars endp

if ?USEXMM
checkcpuid proc uses ebx

	pushfd
	push 200000h		;push ID flag
	popfd
	pushfd
	pop eax
	test eax,200000h	;is it set now?
	mov al,00
	jz exit
	push 1
	pop eax
	cpuid				;returns cpu in AH, step in AL, flags in EDX
	popfd
	mov [g_dwCpuFeature],edx
	clc
	ret
exit:
	popfd
	stc
	ret
	align 4
checkcpuid endp
endif

GetUser32Procs proc hUser32:dword
	.if (!hUser32)
		invoke GetModuleHandle, CStr("USER32")
		mov hUser32, eax
	.endif
	invoke GetProcAddress, hUser32, CStr("ChangeDisplaySettingsA")
	mov g_lpfnChangeDisplaySettingsA, eax
	invoke GetProcAddress, hUser32, CStr("SendMessageA")
	mov g_lpfnSendMessageA, eax
	invoke GetProcAddress, hUser32, CStr("ShowWindow")
	mov g_lpfnShowWindow, eax
	invoke GetProcAddress, hUser32, CStr("GetCursorPos")
	mov g_lpfnGetCursorPos, eax
	invoke GetProcAddress, hUser32, CStr("GetDC")
	mov g_lpfnGetDC, eax
	invoke GetProcAddress, hUser32, CStr("ReleaseDC")
	mov g_lpfnReleaseDC, eax
	@strace <"GetUser32Procs: GetDC=", g_lpfnGetDC, " ReleaseDC=", g_lpfnReleaseDC > 
	ret
	align 4
GetUser32Procs endp            

DirectDrawCreate proc public uses ebx pGUID:ptr, pDD:ptr dword, pIUnknown:LPUNKNOWN

local	pt:POINT
local	svi:SVGAINFO
local	szTmp[32]:byte

	invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DDOBJ
	and eax,eax
	jz error
	mov ebx, eax
	mov [ebx].DDOBJ.vft,offset ddvf
	mov [ebx].DDOBJ.vft2,offset dd2vf
	mov [ebx].DDOBJ.dwCnt, 1
	mov ecx,pDD
	mov [ecx],ebx
	invoke GetVesaVideoMemorySize
	mov [ebx].DDOBJ.dwVideoTotal, eax
	invoke SetVideoVars, ebx
	.if (eax && (edx & VESAATTR_IS_GFX_MODE))
		invoke LoadLibrary, CStr("USER32")
		mov [ebx].DDOBJ.hUser32, eax
		invoke GetUser32Procs, eax
		invoke g_lpfnGetCursorPos, addr pt
		.if (eax)
			mov g_bMouse, 1
		.endif
	.endif
if ?USEXMM
	.if (!g_bCpuId == 0)
		mov g_bCpuId, TRUE
		call checkcpuid
	.endif
endif
	.if (![ebx].DDOBJ.hUser32)
		invoke EnableMouse
		invoke VesaMouseInit
		mov g_bMouseInit, al
		mov g_bMouse, al
	.endif
	mov eax,DD_OK
exit:
	@strace <"DirectDrawCreate(", pGUID, ", ", pDD, ", ", pIUnknown, ")=", eax, " [", ebx, "]"> 
	ret
error:
	mov eax,DDERR_OUTOFMEMORY
	jmp exit
	align 4

DirectDrawCreate endp

if ?DD7

DirectDrawCreateEx proc public uses esi edi pGUID:ptr, lplpDD:ptr dword, iid:ptr IID, pIUnknown:LPUNKNOWN

local	lpDD:DWORD

	mov edi,offset IID_IDirectDraw7
	mov esi,iid
	mov ecx,4
	repz cmpsd
	mov eax, DDERR_INVALIDPARAMS
	jnz error
	invoke DirectDrawCreate, pGUID, addr lpDD, pIUnknown
	.if (eax == DD_OK)
		invoke vf(lpDD, IUnknown, QueryInterface), iid, lplpDD
		push eax
		invoke vf(lpDD, IUnknown, Release)
		pop eax
	.endif
error:
	@strace <"DirectDrawCreateEx(", pGUID, ", ", lplpDD, ", ", iid, ", ", pIUnknown, ")=", eax> 
	ret
	align 4

DirectDrawCreateEx endp

endif

	@MakeStub QueryInterface, 2, DDOBJ.vft2, 1

QueryInterface proc uses esi edi pThis:ptr DDOBJ,pIID:dword,pObj:dword

	mov edx, pThis
	mov edi,offset IID_IDirectDraw
	mov esi,pIID
	mov ecx,4
	repz cmpsd
	jz found
	mov edi,offset IID_IDirectDraw2
	mov esi,pIID
	mov ecx,4
	repz cmpsd
	jz found2
if ?DD4
	mov edi,offset IID_IDirectDraw4
	mov esi,pIID
	mov ecx,4
	repz cmpsd
	jz found2
endif
if ?DD7
	mov edi,offset IID_IDirectDraw7
	mov esi,pIID
	mov ecx,4
	repz cmpsd
	jz found2
endif
	mov ecx,pObj
	mov dword ptr [ecx],0
;	mov eax,DDERR_INVALIDOBJECT
	mov eax,E_NOINTERFACE
	jmp exit
found2:
	lea eax, [edx + DDOBJ.vft2]
	jmp @F
found:
	lea eax, [edx]
@@:
	mov ecx,pObj
	mov [ecx],eax
	invoke AddRef, edx
	mov eax, DD_OK
exit:
ifdef _DEBUG
	mov edx, pIID
	mov ecx, pObj
endif
	@strace <"DirectDraw::QueryInterface(", pThis, ", ", pIID, " [", [edx+0], " ", [edx+4], " ", [edx+8], " ", [edx+12], "], ", pObj, " [", [ecx], "])=", eax>
	ret
	align 4
QueryInterface endp

	@MakeStub AddRef, 2, DDOBJ.vft2, 1

AddRef proc pThis:ptr DDOBJ
	mov ecx, pThis
	mov eax, [ecx].DDOBJ.dwCnt
	inc [ecx].DDOBJ.dwCnt
	@strace <"DirectDraw::AddRef(", pThis, ")=", eax>
	ret
	align 4
AddRef endp

	@MakeStub Release, 2, DDOBJ.vft2, 1

Release proc uses ebx pThis:ptr DDOBJ
	mov ebx, pThis
	mov eax, [ebx].DDOBJ.dwCnt
	dec [ebx].DDOBJ.dwCnt
	.if (ZERO?)
		.if ([ebx].DDOBJ.dwFlags & DDOBJF_MODESET)
			invoke RestoreDisplayMode, ebx
		.endif
		.if ([ebx].DDOBJ.pVMemBuffer)
			invoke LocalFree, [ebx].DDOBJ.pVMemBuffer
			mov [ebx].DDOBJ.pVMemBuffer, 0
		.endif
		.if ([ebx].DDOBJ.pVStateBuffer)
			invoke LocalFree, [ebx].DDOBJ.pVStateBuffer
			mov [ebx].DDOBJ.pVStateBuffer, 0
		.endif
		.if ([ebx].DDOBJ.hUser32)
			invoke FreeLibrary, [ebx].DDOBJ.hUser32
		.endif
		.if (g_bMouseInit)
			invoke VesaMouseExit
		.endif
		invoke DisableMouse
		invoke LocalFree, ebx
		xor eax, eax
	.endif
	@strace <"DirectDraw::Release(", pThis, ")=", eax>
	ret
	align 4
Release endp

	@MakeStub Compact, 2, DDOBJ.vft2, 1

Compact proc pThis:ptr DDOBJ
	mov eax, E_FAIL
	@strace <"DirectDraw::Compact(", pThis, ")=", eax>
	ret
	align 4
Compact endp

	@MakeStub CreateClipper, 2, DDOBJ.vft2, 1

CreateClipper proc pThis:ptr DDOBJ, dwFlags:dword, lplpDDClipper:ptr LPDIRECTDRAWCLIPPER, lpUnknown:dword

	invoke Create@DDClipper, pThis
	and eax, eax
	jz error
	mov ecx, lplpDDClipper
	mov [ecx], eax
	mov eax, DD_OK
	jmp exit
error:
	mov eax,DDERR_OUTOFMEMORY
exit:
	@strace <"DirectDraw::CreateClipper(", pThis, ", ", dwFlags, ", ", lplpDDClipper, ", ", lpUnknown, ")=", eax>
	ret
	align 4

CreateClipper endp

	@MakeStub _CreatePalette, 2, DDOBJ.vft2, 1

_CreatePalette proc pThis:ptr DDOBJ, dwFlags:dword, lpDDColorArray:LPPALETTEENTRY,
			lplpDDPalette:ptr LPDIRECTDRAWPALETTE, lpUnknown:dword

	invoke Create@DDPalette, pThis, dwFlags, lpDDColorArray, lplpDDPalette
	@strace <"DirectDraw::CreatePalette(", pThis, ", ", dwFlags, ", ", lpDDColorArray, ", ", lplpDDPalette, ", ", lpUnknown, ")=", eax>
	ret
	align 4

_CreatePalette endp

	@MakeStub CreateSurface, 2, DDOBJ.vft2, 1
        
CreateSurface proc uses ebx pThis:ptr DDOBJ,
                            lpSurfaceDesc:ptr DDSURFACEDESC,
                            lplpDDSurface:ptr LPDIRECTDRAWSURFACE,
                            lpUnknown:dword

	mov ecx, pThis
	invoke Create@DDSurface, ecx, lpSurfaceDesc, 0
	and eax, eax
	jz error
	mov ecx,lplpDDSurface
	mov [ecx], eax
	mov eax,DD_OK
	jmp exit
error:
	mov eax,DDERR_OUTOFMEMORY
exit:
	@strace <"DirectDraw::CreateSurface(", pThis, ", ", lpSurfaceDesc, ", ", lplpDDSurface, ", ", lpUnknown, ")=", eax>
	ret
	align 4
CreateSurface endp

	@MakeStub DuplicateSurface, 2, DDOBJ.vft2, 1

DuplicateSurface proc pThis:ptr DDOBJ,pDDSurface:ptr DIRECTDRAWSURFACE,ppDDSurface:ptr LPDIRECTDRAWSURFACE
	mov eax, E_FAIL
	@strace <"DirectDraw::DuplicateSurface(", pThis, ")=", eax>
	ret
	align 4
DuplicateSurface endp

;--- set pixel format in [EBX].DDSURFACEDESC from [EDX].SVGAINFO

SetPixelFormat proc

	assume ebx:ptr DDSURFACEDESC

	mov cl,[edx].SVGAINFO.RedMaskSize
	add cl,[edx].SVGAINFO.GreenMaskSize
	add cl,[edx].SVGAINFO.BlueMaskSize
	.if (!cl)
		.if (eax == 15)
			mov [ebx].ddpfPixelFormat.dwRBitMask, 001Fh
			mov [ebx].ddpfPixelFormat.dwGBitMask, 03E0h
			mov [ebx].ddpfPixelFormat.dwBBitMask, 07C00h
		.elseif (eax == 16)
			mov [ebx].ddpfPixelFormat.dwRBitMask, 001Fh
			mov [ebx].ddpfPixelFormat.dwGBitMask, 07E0h
			mov [ebx].ddpfPixelFormat.dwBBitMask, 0F800h
		.elseif ((eax == 24) || (eax == 32))
			mov [ebx].ddpfPixelFormat.dwRBitMask, 0FFh
			mov [ebx].ddpfPixelFormat.dwGBitMask, 0FF00h
			mov [ebx].ddpfPixelFormat.dwBBitMask, 0FF0000h
		.endif
		jmp exit
	.endif

	mov cl, [edx].SVGAINFO.RedMaskSize
	xor eax, eax
	.while (cl)
		shl eax,1
		or al,1
		dec cl
	.endw
	mov cl, [edx].SVGAINFO.RedFieldPosition
	shl eax, cl
	mov [ebx].ddpfPixelFormat.dwRBitMask, eax

	mov cl, [edx].SVGAINFO.GreenMaskSize
	xor eax, eax
	.while (cl)
		shl eax,1
		or al,1
		dec cl
	.endw
	mov cl, [edx].SVGAINFO.GreenFieldPosition
	shl eax, cl
	mov [ebx].ddpfPixelFormat.dwGBitMask, eax

	mov cl, [edx].SVGAINFO.BlueMaskSize
	xor eax, eax
	.while (cl)
		shl eax,1
		or al,1
		dec cl
	.endw
	mov cl, [edx].SVGAINFO.BlueFieldPosition
	shl eax, cl
	mov [ebx].ddpfPixelFormat.dwBBitMask, eax
exit:
	ret
	align 4
	assume ebx:nothing

SetPixelFormat endp


;--- fill a DDSURFACEDESC from a SVGAINFO

FillDDSD proc uses ebx pSVGA:ptr SVGAINFO, pDDSD:ptr DDSURFACEDESC

	mov edx, pSVGA
	assume edx:ptr SVGAINFO
	mov ebx, pDDSD
	assume ebx:ptr DDSURFACEDESC
	mov [ebx].dwSize, sizeof DDSURFACEDESC
	mov [ebx].dwFlags, DDSD_HEIGHT or DDSD_WIDTH or DDSD_PITCH or DDSD_REFRESHRATE or DDSD_PIXELFORMAT
	movzx eax, [edx].YResolution
	mov [ebx].dwHeight, eax
	movzx ecx, [edx].XResolution
	mov [ebx].dwWidth, ecx
	movzx eax, [edx].BytesPerScanLine
	mov [ebx].lPitch, eax
if 0
	mov [ebx].dwRefreshRate, 0
else
	mov [ebx].dwRefreshRate, 60
endif
	mov [ebx].ddpfPixelFormat.dwSize, sizeof DDPIXELFORMAT
	mov [ebx].ddpfPixelFormat.dwFlags, DDPF_RGB
	movzx eax, [edx].BitsPerPixel
	mov [ebx].ddpfPixelFormat.dwRGBBitCount,eax

	invoke SetPixelFormat

;	mov [ebx].ddpfPixelFormat.dwRGBAlphaBitMask,
;	mov [ebx].ddpfPixelFormat.dwRGBZBitMask,
	ret
	align 4
	assume edx:nothing
	assume ebx:nothing

FillDDSD endp

protoDDEnumModeCallback typedef proto :ptr DDSURFACEDESC, :DWORD
LPDDENUMMODECALLBACK typedef ptr protoDDEnumModeCallback

ENUMMODECONTEXT struct
pThis			dd ?
dwFlags			dd ?
lpDDSurfaceDesc dd ?
lpContext		dd ?
lpCallback		LPDDENUMMODECALLBACK ?
ENUMMODECONTEXT ends

mycb proc dwVesaMode:dword, pSVGA:ptr SVGAINFO, pMyContext:ptr

local	sfd:DDSURFACEDESC

	xor eax, eax
	mov ecx, pSVGA
	mov dx, [ecx].SVGAINFO.ModeAttributes
	and dx, VESAATTR_IS_GFX_MODE or VESAATTR_LFB_SUPPORTED or VESAATTR_SUPPORTED
	.if (dx == (VESAATTR_IS_GFX_MODE or VESAATTR_LFB_SUPPORTED or VESAATTR_SUPPORTED))
		invoke FillDDSD, pSVGA, addr sfd
		mov ecx,pMyContext
		invoke [ecx].ENUMMODECONTEXT.lpCallback, addr sfd, [ecx].ENUMMODECONTEXT.lpContext
		.if (eax == DDENUMRET_OK)
			xor eax, eax	;continue!
		.else
			mov eax, 1
		.endif
		@strace <"DirectDraw::EnumDisplayModesCallback(", sfd.dwWidth, ", ", sfd.dwHeight, ", ", sfd.ddpfPixelFormat.dwRGBBitCount, ")=", eax>
	.endif
	ret
	align 4

mycb endp

	@MakeStub EnumDisplayModes, 2, DDOBJ.vft2, 1

EnumDisplayModes proc pThis:ptr DDOBJ, dwFlags:DWORD, pDDSurfaceDesc:ptr DDSURFACEDESC, lpContext:ptr, pEnumCallback:dword

	.if (!pDDSurfaceDesc)
		invoke EnumVesaModes, offset mycb, addr pThis
		mov eax, DD_OK
	.else
		mov eax, E_FAIL
	.endif
	@strace <"DirectDraw::EnumDisplayModes(", pThis, ", ", dwFlags, ", ", pDDSurfaceDesc, ", ", lpContext, ", ", pEnumCallback, ")=", eax>
	ret
	align 4

EnumDisplayModes endp

	@MakeStub EnumSurfaces, 2, DDOBJ.vft2, 1

EnumSurfaces proc pThis:ptr DDOBJ, pDDSurfaceDesc:dword, pEnumCallback:dword

	mov eax, E_FAIL
	@strace <"DirectDraw::EnumSurfaces(", pThis, ", ", pDDSurfaceDesc, ", ", pEnumCallback, ")=", eax>
	ret
	align 4

EnumSurfaces endp

	@MakeStub FlipToGDISurface, 2, DDOBJ.vft2, 1

FlipToGDISurface proc pThis:ptr DDOBJ

	mov eax, E_FAIL
	@strace <"DirectDraw::FlipToGDISurface(", pThis, ")=", eax>
	ret
	align 4

FlipToGDISurface endp

	@MakeStub GetCaps, 2, DDOBJ.vft2, 1

?DDCAPSVALUE = 0
if 0            
?DDCAPSVALUE = ?DDCAPSVALUE or DDCAPS_NOHARDWARE
endif            
if 0           
?DDCAPSVALUE = ?DDCAPSVALUE or DDCAPS_BLT
endif            
if ?OVERLAYEMU
?DDCAPSVALUE = ?DDCAPSVALUE or DDCAPS_OVERLAY
endif

GetCaps proc uses ebx edi pThis:ptr DDOBJ, pDDDriverCaps:ptr DDCAPS_DX1, pDDHELCaps:ptr DDCAPS_DX1

	mov edx, pThis
	mov ebx, pDDDriverCaps
	.if (ebx)
		mov ecx, [ebx].DDCAPS_DX1.dwSize
		.if ((ecx < sizeof DDCAPS_DX1))
			mov eax, E_FAIL
			jmp exit
		.endif
		lea edi, [ebx+4]
		shr ecx, 2
		dec ecx
		xor eax, eax
		rep stosd
		mov eax, [edx].DDOBJ.dwVideoTotal
		mov ecx, [edx].DDOBJ.dwVideoFree
		mov [ebx].DDCAPS_DX1.dwVidMemTotal, eax
		mov [ebx].DDCAPS_DX1.dwVidMemFree, ecx
		mov eax, ?DDCAPSVALUE
		mov [ebx].DDCAPS_DX1.dwCaps, eax
		or [ebx].DDCAPS_DX1.dwPalCaps, DDPCAPS_ALLOW256 or DDPCAPS_PRIMARYSURFACE
if ?OVERLAYEMU
		mov [ebx].DDCAPS_DX1.dwMaxVisibleOverlays, 1
		mov [ebx].DDCAPS_DX1.dwAlignSizeSrc, 1
		mov [ebx].DDCAPS_DX1.dwAlignSizeDest, 1
		mov [ebx].DDCAPS_DX1.dwAlignBoundarySrc, 4
		mov [ebx].DDCAPS_DX1.dwAlignBoundaryDest, 4
		or [ebx].DDCAPS_DX1.dwCaps, DDCAPS_ALIGNSIZEDEST or DDCAPS_ALIGNSIZESRC or DDCAPS_ALIGNBOUNDARYSRC or DDCAPS_ALIGNBOUNDARYDEST or DDCAPS_OVERLAYSTRETCH
		mov [ebx].DDCAPS_DX1.dwMinOverlayStretch, 1000
		mov [ebx].DDCAPS_DX1.dwMaxOverlayStretch, 1000

		or [ebx].DDCAPS_DX1.dwFXCaps, DDFXCAPS_OVERLAYSHRINKX or DDFXCAPS_OVERLAYSHRINKY or DDFXCAPS_OVERLAYSTRETCHX or DDFXCAPS_OVERLAYSTRETCHY
endif
	.endif
	mov ebx, pDDHELCaps
	.if (ebx)
		mov ecx, [ebx].DDCAPS_DX1.dwSize
		lea edi, [ebx+4]
		shr ecx, 2
		dec ecx
		xor eax, eax
		rep stosd
		mov eax, [edx].DDOBJ.dwVideoTotal
		mov ecx, [edx].DDOBJ.dwVideoFree
		mov [ebx].DDCAPS_DX1.dwVidMemTotal, eax
		mov [ebx].DDCAPS_DX1.dwVidMemFree, ecx
	.endif
	mov eax, DD_OK
exit:
	@strace <"DirectDraw::GetCaps(", pThis, ", ", pDDDriverCaps, ", ", pDDHELCaps, ")=", eax>
	ret
	align 4

GetCaps endp

	@MakeStub GetDisplayMode, 2, DDOBJ.vft2, 1

GetDisplayMode proc pThis:ptr DDOBJ, pSurfaceDesc:ptr DDSURFACEDESC

local	svi:SVGAINFO

	invoke GetVesaMode
	lea ecx, svi
	invoke GetVesaModeInfo, eax, ecx
	.if (eax)
		invoke FillDDSD, addr svi, pSurfaceDesc
		mov eax, DD_OK
	.else
		mov eax, DDERR_UNSUPPORTEDMODE
	.endif
	@strace <"DirectDraw::GetDisplayMode(", pThis, ", ", pSurfaceDesc, ")=", eax>
	ret
	align 4

GetDisplayMode endp

	@MakeStub GetFourCCCodes, 2, DDOBJ.vft2, 1

GetFourCCCodes proc pThis:ptr DDOBJ, lpNumCodes:ptr dword, lpCodes:ptr dword
	mov eax, E_FAIL
	@strace <"DirectDraw::GetFourCCCodes(", pThis, ", ", lpNumCodes, ", ", lpCodes, ")=", eax>
	ret
	align 4
GetFourCCCodes endp

	@MakeStub GetGDISurface, 2, DDOBJ.vft2, 1

GetGDISurface proc pThis:ptr DDOBJ, lplpDDSurface:ptr LPDIRECTDRAWSURFACE

local	ddsd:DDSURFACEDESC
	invoke GetDisplayMode, pThis, addr ddsd
	.if (eax == DD_OK)
		and ddsd.dwFlags, not (DDSD_HEIGHT or DDSD_WIDTH)
		or ddsd.ddsCaps.dwCaps, DDSCAPS_PRIMARYSURFACE
		invoke CreateSurface, pThis, addr ddsd, lplpDDSurface, 0
	.endif
	@strace <"DirectDraw::GetGDISurface(", pThis, ", ", lplpDDSurface, ")=", eax>
	ret
	align 4

GetGDISurface endp

	@MakeStub GetMonitorFrequency, 2, DDOBJ.vft2, 1

GetMonitorFrequency proc pThis:ptr DDOBJ, lpdwFrequency:ptr dword
	mov ecx, lpdwFrequency
	mov dword ptr [ecx],60
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw::GetMonitorFrequency(", pThis, ", ", lpdwFrequency, ")=", eax>
	ret
	align 4
GetMonitorFrequency endp

	@MakeStub GetScanLine, 2, DDOBJ.vft2, 1

GetScanLine proc pThis:ptr DDOBJ, lpdwScanLine:ptr dword
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw::GetScanLine(", pThis, ", ", lpdwScanLine, ")=", eax>
	ret
	align 4
GetScanLine endp

	@MakeStub GetVerticalBlankStatus, 2, DDOBJ.vft2, 1

GetVerticalBlankStatus proc pThis:ptr DDOBJ,pBool:dword

	mov ecx, pBool
	mov dx, 3dah
	in al, dx
	test al,8
	setnz dl
	movzx edx,dl
	mov [ecx],edx
	mov eax, DD_OK
	@strace <"DirectDraw::GetVerticalBlankStatus(", pThis, ", ", pBool, ")=", eax>
	ret
	align 4

GetVerticalBlankStatus endp

	@MakeStub Initialize, 2, DDOBJ.vft2, 1

Initialize proc pThis:ptr DDOBJ, pGUID:dword
	mov eax, DDERR_ALREADYINITIALIZED
	@strace <"DirectDraw::Initialize(", pThis, ")=", eax>
	ret
	align 4
Initialize endp

	@MakeStub RestoreDisplayMode, 2, DDOBJ.vft2, 1

RestoreDisplayMode proc uses ebx pThis:ptr DDOBJ

	mov ebx, pThis
	.if (!([ebx].DDOBJ.dwFlags & DDOBJF_MODESET))
		jmp done
	.endif
	and byte ptr [ebx].DDOBJ.dwFlags, not (DDOBJF_MODESET or DDOBJF_MODESET2)
	.if ((![ebx].DDOBJ.pVStateBuffer) && (g_lpfnChangeDisplaySettingsA))
		@strace <"DirectDraw::RestoreDisplayMode: using ChangeDisplaySettings to restore state">
		invoke g_lpfnChangeDisplaySettingsA, 0, 0
		.if (eax == DISP_CHANGE_SUCCESSFUL)
			jmp done
		.endif
	.endif

	@strace <"DirectDraw::RestoreDisplayMode: restoring VESA video state">
	.if ([ebx].DDOBJ.pVStateBuffer)
if ?ALWAYSSETOLDMODE
		mov eax, [ebx].DDOBJ.dwPrevMode
		or ah,80h	;dont clear video memory
		invoke SetVesaMode, eax
endif
		invoke RestoreVesaVideoState, [ebx].DDOBJ.pVStateBuffer
	.endif
	.if ([ebx].DDOBJ.pVMemBuffer)
		invoke RestoreVesaVideoMemory, [ebx].DDOBJ.pVMemBuffer
	.endif
done:
	mov eax, DD_OK
	@strace <"DirectDraw::RestoreDisplayMode(", pThis, ")=", eax>
	ret
	align 4

RestoreDisplayMode endp

	@MakeStub SetCooperativeLevel, 2, DDOBJ.vft2, 1

SetCooperativeLevel proc uses ebx pThis:ptr DDOBJ, hwnd:dword, dwFlags:dword

	mov ebx, pThis
	mov edx, hwnd
	mov eax, dwFlags
	test eax, DDSCL_EXCLUSIVE or DDSCL_NORMAL
	jz error
	mov [ebx].DDOBJ.hwnd, edx
	mov [ebx].DDOBJ.dwCoFlags, eax
	.if (edx && (eax & DDSCL_EXCLUSIVE))
		.if (!g_lpfnShowWindow)
			invoke GetUser32Procs, 0
		.endif
		.if (g_lpfnShowWindow)
			invoke g_lpfnShowWindow, hwnd, SW_SHOWMAXIMIZED
		.endif
	.endif
	.if (dwFlags & DDSCL_NORMAL)
		.if ([ebx].DDOBJ.dwFlags & DDOBJF_MODESET2)
			invoke RestoreDisplayMode, ebx
		.endif
	.endif

	mov eax,DD_OK
exit:
	@strace <"DirectDraw::SetCooperativeLevel(", pThis, ", ", hwnd, ", ", dwFlags, ")=", eax>
	ret
error:
	mov eax,DDERR_INVALIDPARAMS
	jmp exit
	align 4

SetCooperativeLevel endp

;--- savecurrentmode used only if USER32 is not available

savecurrentmode proc

	invoke GetVesaStateBufferSize
	.if (eax)
		mov [ebx].DDOBJ.dwVStateSize, eax
		invoke LocalAlloc, LMEM_FIXED, eax
		mov [ebx].DDOBJ.pVStateBuffer, eax
		.if (eax)
			invoke SaveVesaVideoState, eax, [ebx].DDOBJ.dwVStateSize
		.endif
	.endif
	invoke GetVesaMode
if ?ALWAYSSETOLDMODE
	mov [ebx].DDOBJ.dwPrevMode, eax
endif
	invoke GetVesaMemoryBufferSize, eax
	.if (eax)
		mov [ebx].DDOBJ.dwVMemSize, eax
		invoke LocalAlloc, LMEM_FIXED, eax
		mov [ebx].DDOBJ.pVMemBuffer, eax
		.if (eax)
			invoke SaveVesaVideoMemory, eax, [ebx].DDOBJ.dwVMemSize
		.endif
	.endif
	ret
	align 4

savecurrentmode endp

;*** DirectDraw 1 version of SetDisplayMode ***

SetDisplayMode proc uses ebx pThis:ptr DDOBJ,
                                    dwCols:dword,
                                    dwRows:dword,
                                    dwBpp:dword
local	dm:DEVMODEA

	mov ebx, pThis
	test [ebx].DDOBJ.dwCoFlags, DDSCL_EXCLUSIVE
	jz error2
	.if (g_lpfnChangeDisplaySettingsA)
		@strace <"DirectDraw::SetDisplayMode: use ChangeDisplaySettings to set mode">
		mov eax, dwCols
		mov dm.dmPelsWidth, eax
		mov eax, dwRows
		mov dm.dmPelsHeight, eax
		mov eax, dwBpp
		mov dm.dmBitsPerPel, eax
		mov dm.dmFields, DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT
		invoke g_lpfnChangeDisplaySettingsA, addr dm, 0
		.if (eax == DISP_CHANGE_SUCCESSFUL)
			jmp setvars
		.endif
	.endif
if ?USEMODE13
	.if ((dwCols == 320) && (dwRows == 200) && (dwBpp == 8))
		mov eax, 013h
	.else
endif
	@strace <"DirectDraw::SetDisplayMode: saving VESA video state">
	invoke SearchVesaMode, dwCols, dwRows, dwBpp
if ?USEMODE13
	.endif
endif
	and eax,eax
	jz error
	or ah,40h			;use LFB!
	push eax
	.if (![ebx].DDOBJ.pVStateBuffer)
		call savecurrentmode
	.endif
	pop eax
	invoke SetVesaMode, eax
	and eax,eax
	jz error
setvars:
	or [ebx].DDOBJ.dwFlags, DDOBJF_MODESET
	and [ebx].DDOBJ.dwFlags, not DDOBJF_MODESET2
	invoke SetVideoVars, ebx
	mov eax,DD_OK
exit:
	@strace <"DirectDraw::SetDisplayMode(", pThis, ", ", dwCols, ", ", dwRows, ", ", dwBpp, ")=", eax>
	ret
error:
	mov eax,DDERR_UNSUPPORTEDMODE
	jmp exit
error2:
	mov eax,DDERR_NOEXCLUSIVEMODE
	jmp exit
	align 4

SetDisplayMode endp

;*** DirectDraw 2 version of SetDisplayMode ***

SetDisplayMode2:
	sub dword ptr [esp+4], DDOBJ.vft2

_SetDisplayMode2 proc pThis:ptr DDOBJ, dwCols:dword, dwRows:dword, dwBpp:dword,
                      dwRefresh:dword, dwFlags:dword

	invoke	SetDisplayMode,pThis,dwCols,dwRows,dwBpp
	.if (eax == DD_OK)
		mov ecx, pThis
		or [ecx].DDOBJ.dwFlags, DDOBJF_MODESET2
	.endif
	@strace <"DirectDraw2::SetDisplayMode(", pThis, ", ", dwCols, ", ", dwRows, ", ", dwBpp, ", ", dwRefresh, ", ", dwFlags, ")=", eax>
	ret
	align 4
_SetDisplayMode2 endp

	@MakeStub WaitForVerticalBlank, 2, DDOBJ.vft2, 1

WaitForVerticalBlank proc pThis:ptr DDOBJ, dwFlags:dword, hEvent:dword

if 1
	pushfd
	cli
endif
	mov dx, 3dah
@@:
	in al, dx
	test al,8
	jnz @B
@@:
	in al, dx
	test al,8
	jz @B
if 1
	pop eax
	test ah,2
	jz @F
	sti
@@:
endif
	mov eax, DD_OK
	@strace <"DirectDraw::WaitForVerticalBlank(", pThis, ", ", dwFlags, ", ", hEvent, ")=", eax>
	ret
	align 4

WaitForVerticalBlank endp

;--- IDirectDraw2 methods

GetAvailableVidMem:
	sub dword ptr [esp+4], DDOBJ.vft2

_GetAvailableVidMem proc pThis:ptr DDOBJ,pDDCaps:ptr DDCAPS_DX1,
                  lpdwTotal:ptr dword, lpdwFree:ptr dword
	mov edx, pThis
	mov ecx, lpdwTotal
	jecxz @F
	mov eax, [edx].DDOBJ.dwVideoTotal
	mov [ecx], eax
@@:
	mov ecx, lpdwFree
	jecxz @F
	mov eax, [edx].DDOBJ.dwVideoFree
	mov [ecx], eax
@@:
	mov eax, DD_OK
	@strace <"DirectDraw2::GetAvailableVidMem(", pThis, ", ", pDDCaps, ", ", lpdwTotal, ", ", lpdwFree, ")=", eax>
	ret
	align 4
_GetAvailableVidMem endp

if ?DD4

;--- IDirectDraw4 methods
GetSurfaceFromDC:
	sub dword ptr [esp+4], DDOBJ.vft2

_GetSurfaceFromDC proc pThis:ptr DDOBJ, hdc:HDC, lpDDSF4:ptr LPDIRECTDRAWSURFACE4
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw4::GetSurfaceFromDC(", pThis, ", ", hdc, ", ", lpDDSF4, ")=", eax>
	ret
	align 4
_GetSurfaceFromDC endp

RestoreAllSurfaces:
	sub dword ptr [esp+4], DDOBJ.vft2

_RestoreAllSurfaces proc pThis:ptr DDOBJ
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw4::RestoreAllSurfaces(", pThis, ")=", eax>
	ret
	align 4
_RestoreAllSurfaces endp

TestCooperativeLevel:
	sub dword ptr [esp+4], DDOBJ.vft2

_TestCooperativeLevel proc pThis:ptr DDOBJ
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw4::TestCooperativeLevel(", pThis, ")=", eax>
	ret
	align 4
_TestCooperativeLevel endp

GetDeviceIdentifier:
	sub dword ptr [esp+4], DDOBJ.vft2

_GetDeviceIdentifier proc pThis:ptr DDOBJ, lpDDID:LPDDDEVICEIDENTIFIER, dwFlags:DWORD
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw4::GetDeviceIdentifier(", pThis, ", ", lpDDID, ", ", dwFlags, ")=", eax>
	ret
	align 4
_GetDeviceIdentifier endp

endif

if ?DD7
StartModeTest:
	sub dword ptr [esp+4], DDOBJ.vft2
        
_StartModeTest proc pThis:ptr DDOBJ, lpModesToTest:ptr SIZE_, dwNumEntries:DWORD, dwFlags:DWORD
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw7::StartModeTest(", pThis, ", ", lpModesToTest, ", ", dwNumEntries, ", ", dwFlags, ")=", eax>
	ret
	align 4
_StartModeTest endp

EvaluateMode:
	sub dword ptr [esp+4], DDOBJ.vft2

_EvaluateMode proc pThis:ptr DDOBJ, dwFlags:DWORD, pSecondsUntilTimeout:ptr DWORD
	mov eax, DDERR_UNSUPPORTED
	@strace <"DirectDraw7::EvaluateMode(", pThis, ", ", dwFlags, ", ", pSecondsUntilTimeout, ")=", eax>
	ret
	align 4
_EvaluateMode endp

endif

	END

