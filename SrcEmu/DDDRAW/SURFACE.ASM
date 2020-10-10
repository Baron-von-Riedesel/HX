
;--- implements
;--- IDirectDrawSurface
;--- IDirectDrawSurface2
;--- IDirectDrawSurface3
;--- IDirectDrawSurface4
;--- IDirectDrawSurface7

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include winbase.inc
		include wingdi.inc
		include winuser.inc
		include ddraw.inc
		include vesa32.inc
		include dddraw.inc
		include macros.inc

?STOREHDC	equ 1
CPUF_XMM_SUPPORTED equ 2000000h	;cpuid feature flag
?FILLOPTIMIZE equ 1
?VESA2		equ 1
?GAMMA		equ 1				;support IDirectDrawGammaControl
?PALMAP		equ 0				;support non-identity palettes
?NOVIDMEMSF	equ 1				;1=no surfaces in video memory
								;  except primary + flips
?MOUSEOPT	equ 1

GetHwnd proto :dword

protoSetDCOrgEx typedef proto :DWORD, :DWORD, :DWORD
LPFNSETDCORGEX typedef ptr protoSetDCOrgEx

;--- for non-video surfaces, we need a special GDI entry

protoSetDCBitPtr typedef proto :DWORD, :DWORD
LPFNSETDCBITPTR typedef ptr protoSetDCBitPtr

@vmementer macro
		endm
		
@vmemexit macro
		endm

QueryInterface proto stdcall pThis:dword,refiid:dword,pObj:dword
AddRef		   proto stdcall pThis:dword
Release 	   proto stdcall pThis:dword


DDSF	struct
vft 		dd ?
;vft1		dd ?
;vft2		dd ?
;vft3		dd ?
if ?GAMMA
vftgc		dd ?
endif
dwCnt		dd ?
dwFlags 	dd ?	;flags from ???
dwVesaMode	dd ?
lpSurface	dd ?	;screen/surface pointer
lpVidStart	dd ?	;start of video memory
if ?STOREHDC
hdc			dd ?
endif
hBitmap		dd ?
lPitch		dd ?
dwWidth		dd ?
dwHeight	dd ?
lpDD		dd ?
pFlipChain	dd ?
pAttachedSF dd ?
lpPalette	dd ?	;DDPALETTE
lpClipper	dd ?
if ?OVERLAYEMU
ptOLPos		POINT <>
endif
ddsCaps		DDSCAPS <>
ddpfPixelFormat	DDPIXELFORMAT <>
ddColorKey	DDCOLORKEY <>
DDSF	ends

;--- dwFlags values

FDDSF_ALLOCATED	equ 1
FDDSF_VIRTALLOC	equ 2
FDDSF_FLIPSCHED	equ 4

		.DATA

g_hGDI			dd 0
g_lpfnSetDCOrgEx			LPFNSETDCORGEX 0
g_lpfnSetDCBitPtr			LPFNSETDCBITPTR 0

externdef g_bMouse:BYTE
externdef g_dwCpuFeature:dword

		.CONST

IID_IDirectDrawSurface	GUID <06c14db81H, 0a733H, 011ceH, <0a5H, 021H, 000H, 020H, 0afH, 00bH, 0e5H, 060H>>
IID_IDirectDrawSurface2 GUID <057805885H, 06eecH, 011cfH, <094H, 041H, 0a8H, 023H, 003H, 0c1H, 00eH, 027H>>
IID_IDirectDrawSurface3 GUID <0DA044E00h,  69B2h,  11D0h, <0A1h, 0D5h,	00h, 0AAh,	00h, 0B8h, 0DFh, 0BBh>>
if ?DDS4
IID_IDirectDrawSurface4 GUID <00B2B8630h, 0AD35h,  11D0h, < 8Eh, 0A6h,	00h,  60h,	97h,  97h, 0EAh,  5Bh>>
endif
if ?DDS7
IID_IDirectDrawSurface7 GUID <006675a80h,  3b9bh,  11d2h, <0b9h,  2fh,	00h,  60h,	97h,  97h, 0eah,  5bh>>
endif
IID_IDirectDrawGammaControl GUID <69C11C3Eh,0B46Bh,11D1h, <0ADh,  7Ah,	00h, 0C0h,	4Fh, 0C2h,	9Bh,  4Eh>>

ddsvf label IDirectDrawSurfaceVtbl
		dd QueryInterface, AddRef, Release
		dd AddAttachedSurface, AddOverlayDirtyRect, Blt, BltBatch, BltFast
		dd DeleteAttachedSurface, EnumAttachedSurfaces, EnumOverlayZOrders
		dd Flip,GetAttachedSurface, GetBltStatus, GetCaps, GetClipper
		dd GetColorKey, GetDC_, GetFlipStatus, GetOverlayPosition
		dd GetPalette, GetPixelFormat, GetSurfaceDesc
		dd Initialize, IsLost, Lock_, ReleaseDC_, Restore
		dd SetClipper, SetColorKey, SetOverlayPosition, SetPalette
		dd Unlock, UpdateOverlay, UpdateOverlayDisplay, UpdateOverlayZOrder
		dd GetDDInterface, PageLock, PageUnlock
		dd SetSurfaceDesc
if ?DDS4
		dd SetPrivateData
		dd GetPrivateData
		dd FreePrivateData
		dd GetUniquenessValue
		dd ChangeUniquenessValue 
endif
if ?DDS7
		dd SetPriority
		dd GetPriority
		dd SetLOD
		dd GetLOD
endif

if 0
dds2vf label IDirectDrawSurface2Vtbl
		 dd QueryInterface2, AddRef2, Release2
		 dd AddAttachedSurface2, AddOverlayDirtyRect2, Blt2, BltBatch2, BltFast2
		 dd DeleteAttachedSurface2, EnumAttachedSurfaces2, EnumOverlayZOrders2
		 dd Flip2, GetAttachedSurface2, GetBltStatus2, GetCaps2, GetClipper2
		 dd GetColorKey2, GetDC_2, GetFlipStatus2, GetOverlayPosition2
		 dd GetPalette2, GetPixelFormat2, GetSurfaceDesc2
		 dd Initialize2, IsLost2, Lock_2, ReleaseDC_2, Restore2
		 dd SetClipper2, SetColorKey2, SetOverlayPosition2, SetPalette2
		 dd Unlock2, UpdateOverlay2, UpdateOverlayDisplay2, UpdateOverlayZOrder2
		 dd GetDDInterface, PageLock, PageUnlock

dds3vf label IDirectDrawSurface3Vtbl
		 dd QueryInterface3, AddRef3, Release3
		 dd AddAttachedSurface3, AddOverlayDirtyRect3, Blt3, BltBatch3, BltFast3
		 dd DeleteAttachedSurface3, EnumAttachedSurfaces3, EnumOverlayZOrders3
		 dd Flip3, GetAttachedSurface3, GetBltStatus3, GetCaps3, GetClipper3
		 dd GetColorKey3, GetDC_3, GetFlipStatus3, GetOverlayPosition3
		 dd GetPalette3, GetPixelFormat3, GetSurfaceDesc3
		 dd Initialize3, IsLost3, Lock_3, ReleaseDC_3, Restore3
		 dd SetClipper3, SetColorKey3, SetOverlayPosition3, SetPalette3
		 dd Unlock3, UpdateOverlay3, UpdateOverlayDisplay3, UpdateOverlayZOrder3
		 dd GetDDInterface3, PageLock3, PageUnlock3
		 dd SetSurfaceDesc
endif

if ?GAMMA
ddgcvf label IDirectDrawGammaControlVtbl
		dd QueryInterfaceGC, AddRefGC, ReleaseGC
		dd GetGammaRamp, SetGammaRamp
endif

		.CODE

@MakeStub macro name, suffix, offs
if 0
name&suffix:
		sub dword ptr [esp+4], offs
		jmp name
endif
		endm

ShowMouse proc
		.if (g_bMouse)
			mov	ax,1
			int 33h
		.endif
		ret
		align 4
ShowMouse endp

HideMouse proc
		.if (g_bMouse)
			mov	ax,2
			int 33h
		.endif
		ret
		align 4
HideMouse endp

if ?GAMMA

QueryInterfaceGC proc pThis:dword, pIID:dword, pObj:dword

		mov edx, pThis
		sub edx, DDSF.vftgc
		invoke QueryInterface, edx, pIID, pObj
		@strace <"DirectDrawGammaControl::QueryInterface(", pThis, ", ", pIID, ", ", pObj, ")=", eax>
		ret
		align 4
QueryInterfaceGC endp

AddRefGC proc pThis:dword
		mov edx, pThis
		sub edx, DDSF.vftgc
		invoke AddRef, edx
		@strace <"DirectDrawGammaControl::AddRef(", pThis, ")=", eax>
		ret
		align 4
AddRefGC endp

ReleaseGC proc uses ebx pThis:dword

		mov edx, pThis
		sub edx, DDSF.vftgc
		invoke Release, edx
		@strace <"DirectDrawGammaRamp::Release(", pThis, ")=", eax>
		ret
		align 4
ReleaseGC endp

GetGammaRamp proc uses ebx pThis:dword, dwFlags:dword, lpRampData:ptr

		xor ecx, ecx
		mov ebx, lpRampData
		xor edx, edx
		.repeat
			mov [ebx+ecx*2+256*0],dx
			mov [ebx+ecx*2+256*2],dx
			mov [ebx+ecx*2+256*4],dx
			inc dh
			inc ecx
		.until (ecx==100h)
		mov eax, DD_OK
		@strace	<"DirectDrawGammaRamp::GetGammaRamp(", pThis, ", ", dwFlags, ", ", lpRampData, ")=", eax>
		ret
		align 4
	
GetGammaRamp endp

SetGammaRamp proc uses ebx pThis:dword, dwFlags:dword, lpRampData:ptr
		mov eax, DD_OK
		@strace	<"DirectDrawGammaRamp::SetGammaRamp(", pThis, ", ", dwFlags, ", ", lpRampData, ")=", eax>
		ret
		align 4
SetGammaRamp endp

endif

if 0
		@MakeStub QueryInterface, 3, DDSF.vft3
		@MakeStub QueryInterface, 2, DDSF.vft2
endif

QueryInterface proc uses esi edi pThis:dword, pIID:dword, pObj:dword

		mov		edx, pThis
		mov 	edi,offset IID_IDirectDrawSurface
		mov 	esi,pIID
		mov		eax, esi
		mov 	ecx,4
		repz	cmpsd
		jz		found1
		mov 	edi,offset IID_IDirectDrawSurface2
		mov 	esi, eax
		mov 	cl,4
		repz	cmpsd
		jz		found2
		mov 	edi,offset IID_IDirectDrawSurface3
		mov 	esi, eax
		mov 	cl,4
		repz	cmpsd
		jz		found3
if ?DDS4
		mov 	edi,offset IID_IDirectDrawSurface4
		mov 	esi, eax
		mov 	cl,4
		repz	cmpsd
		jz		found4
endif
if ?DDS7
		mov 	edi,offset IID_IDirectDrawSurface7
		mov 	esi, eax
		mov 	cl,4
		repz	cmpsd
		jz		found7
endif
if ?GAMMA
		mov 	edi,offset IID_IDirectDrawGammaControl
		mov 	esi, eax
		mov 	cl,4
		repz	cmpsd
		jz		foundgc
endif
		mov 	ecx,pObj
		mov		dword ptr [ecx],0
ifdef _DEBUG
		mov		ecx, pIID
		@strace <"iid=", dword ptr [ecx], "-", dword ptr [ecx+4], "-", dword ptr [ecx+8], "-", dword ptr [ecx+12]>
endif
		mov 	eax,DDERR_INVALIDOBJECT
		jmp		exit
if ?GAMMA
foundgc:
		mov		[edx].DDSF.vftgc, offset ddgcvf
		add		edx, DDSF.vftgc
endif
found1:
found2:
found3:
found4:
found7:
		mov		eax, edx
		mov 	ecx,pObj
		mov 	[ecx],eax
		invoke	vf(eax, IUnknown, AddRef)
		mov 	eax,DD_OK
exit:		 
		@strace	<"DirectDrawSurface::QueryInterface(", pThis, ", ", pIID, ", ", pObj, ")=", eax>
		ret
		align 4
QueryInterface endp

if 0
		@MakeStub AddRef, 3, DDSF.vft3
		@MakeStub AddRef, 2, DDSF.vft2
endif

AddRef proc pThis:dword
		mov ecx, pThis
		mov eax, [ecx].DDSF.dwCnt
		inc [ecx].DDSF.dwCnt
		@strace	<"DirectDrawSurface::AddRef(", pThis, ")=", eax>
		ret
		align 4
AddRef endp

DeleteAttachedSurface proto :dword, :dword, :LPDIRECTDRAWSURFACE

if 0
		@MakeStub Release, 3, DDSF.vft3
		@MakeStub Release, 2, DDSF.vft2
endif

Release proc uses ebx pThis:dword

		mov ebx, pThis
		mov eax, [ebx].DDSF.dwCnt
		dec [ebx].DDSF.dwCnt
		.if (ZERO?)
			.if ([ebx].DDSF.dwFlags & FDDSF_ALLOCATED)
				.if ([ebx].DDSF.dwFlags & FDDSF_VIRTALLOC)
					invoke VirtualFree, [ebx].DDSF.lpSurface, 0, MEM_RELEASE
				.else
					invoke LocalFree, [ebx].DDSF.lpSurface
				.endif
			.endif
			xor ecx, ecx
			xchg ecx, [ebx].DDSF.lpClipper
			.if (ecx)
				invoke vf(ecx, , Release)
			.endif
			xor ecx, ecx
			xchg ecx, [ebx].DDSF.lpPalette
			.if (ecx)
				invoke vf(ecx, , Release)
			.endif
			.if ([ebx].DDSF.pFlipChain)
				invoke vf([ebx].DDSF.pFlipChain, , Release)
			.endif
if 0
			.if ([ebx].DDSF.hBitmap)
				invoke g_lpfnDeleteObject, [ebx].DDSF.hBitmap
			.endif
endif
if ?STOREHDC
			xor ecx, ecx
			xchg ecx, [ebx].DDSF.hdc
			.if (ecx)
				push ecx
				invoke GetHwnd, [ebx].DDSF.lpDD
				pop ecx
				.if (eax)
					invoke g_lpfnReleaseDC, eax, ecx
				.else
					invoke DeleteDC, ecx
				.endif
			.endif
endif			 
			invoke LocalFree, ebx
			xor eax, eax
		.endif
		@strace	<"DirectDrawSurface::Release(", pThis, ")=", eax>
		ret
		align 4
Release endp

		@MakeStub AddAttachedSurface, 3, DDSF.vft3
		@MakeStub AddAttachedSurface, 2, DDSF.vft2

AddAttachedSurface proc pThis:dword,lpDDSAttachedSurface:LPDIRECTDRAWSURFACE

		mov edx, pThis
		mov ecx, lpDDSAttachedSurface
if 1
		.while ([edx.DDSF.pAttachedSF])
			mov edx, [edx].DDSF.pAttachedSF
		.endw
		mov [edx].DDSF.pAttachedSF, ecx
else
		mov eax, [edx].DDSF.pAttachedSF
		mov [ecx].DDSF.pAttachedSF, eax
		mov [edx].DDSF.pAttachedSF, ecx
endif
		invoke vf(ecx, , AddRef)
		mov eax, S_OK
		jmp exit
error:
		mov eax, E_FAIL
exit:
		@strace	<"DirectDrawSurface::AddAttachedSurface(", pThis, ")=", eax>
		ret
		align 4
AddAttachedSurface endp

		@MakeStub AddOverlayDirtyRect, 3, DDSF.vft3
		@MakeStub AddOverlayDirtyRect, 2, DDSF.vft2

AddOverlayDirtyRect proc pThis:dword,  pRECT:dword

		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawSurface::AddOverlayDirtyRect(", pThis, ")=", eax>
		ret
		align 4
AddOverlayDirtyRect endp


if ?USEXMM

		pushcontext cpu
		.686
		.xmm

;--- faster replacement for movsd

xmmcopy proc

xmmcopy_d::
		shl ecx, 1
xmmcopy_w::
		shl ecx, 1
xmmcopy_b::
		push ebp
		push ebx
		mov edx, ecx			;Keep a copy of count
		mov ecx, 8				;A trick that's faster than rep movsb...
		sub ecx, edi			;Align destination to qword
		and ecx, 111b			;Get the low bits
		sub edx, ecx			;Update copy count
		neg ecx					;Set up to jump into the array
		add ecx, offset @@AlignDone
		jmp ecx					;Jump to array of movsb's

		align @WordSize
		repeat 8				;1 + 7, first used for alignment
			movsb				;Opcode A4
		endm
@@AlignDone:					;Destination is dword aligned
		mov ecx, edx			;Number of bytes left to copy
		shr ecx, 6				;Get 64-byte block count
		jz done
		mov eax, ecx
		and ecx, 0127
		shr eax, 7				;get number of 8 kB blocks
		mov ebp, ecx			;save this value in a register
		jz lastcacheblock
		align 4
nextcacheblock:
		mov cx, 128*8-8 		;preload cache (127 reads for 64 byte lines)
@@:
		mov ebx, [esi + ecx * 8 + 00*8]
		sub cx, 1*8
		jnz @B
@@: 	
		mov cl, 128			;128*64 = 8 kb block
		align 4
nextblock:
		movq mm0, [esi + 00]
		movq mm1, [esi + 08]
		movq mm2, [esi + 16]
		movq mm3, [esi + 24]
		movq mm4, [esi + 32]
		movq mm5, [esi + 40]
		movq mm6, [esi + 48]
		movq mm7, [esi + 56]
		movntq [edi + 00], mm0
		movntq [edi + 08], mm1
		movntq [edi + 16], mm2
		movntq [edi + 24], mm3
		movntq [edi + 32], mm4
		movntq [edi + 40], mm5
		movntq [edi + 48], mm6
		movntq [edi + 56], mm7 
		add esi, 64
		add edi, 64
		dec cl
		jnz nextblock
		sub eax, 1
		jc blocksdone
		jnz nextcacheblock
		mov ecx, ebp
lastcacheblock:
		and cl,cl
		jnz nextblock
blocksdone:
		sfence
		emms					;Set all FPU tags to empty
done:

		mov ecx, edx			;Has valid low 6 bits of the byte count
;a P4s "rep movsb" is optimised and not slower than movsd
if 1
		shr ecx, 2				;dword count
		and ecx, 0Fh			;Only look at the "remainder" bits
		rep movsd
		mov cl, dl				;Has valid low 2 bits of the byte count
		and cl,3				;The last few cows must come home...
else
		and ecx, 3Fh
endif
		rep movsb				;The last 0 to 3 bytes
		pop ebx
		pop ebp
		ret
		align 4
xmmcopy endp

		popcontext cpu

endif

;--- the blit is done asynchronously by default!
;--- unless DDBLT_WAIT is set
;--- flag: DDBLT_COLORFILL: source ignored/NULL

		@MakeStub Blt, 3, DDSF.vft3
		@MakeStub Blt, 2, DDSF.vft2

Blt 	proc uses ebx esi edi pThis:dword,lpDestRect:ptr RECT,
			lpDDSrcSurface:LPDIRECTDRAWSURFACE, lpSrcRect:ptr RECT,
			dwFlags:DWORD, lpDDBltFx:ptr DDBLTFX

local	dwWidth:dword
local	dwHeight:dword
local	lPitch:dword
local	lpfnCopyProc:dword
if ?MOUSEOPT
local	bOnScreen:dword
endif

		mov ebx, pThis
		mov esi, lpDestRect
		mov edi, [ebx].DDSF.lpSurface
if ?MOUSEOPT
		mov eax,[ebx].DDSF.ddsCaps.dwCaps
		mov bOnScreen, eax
endif
		.if (esi)
			@strace <"DirectDrawSurface::Blt, Dst=", ebx, " pSF=", [ebx].DDSF.lpSurface, " Rect=", [esi].RECT.left, " ", [esi].RECT.top, " ", [esi].RECT.right, " ", [esi].RECT.bottom, " bpp=", [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount, " pitch=", [ebx].DDSF.lPitch>
			mov eax, [esi].RECT.top
			mul [ebx].DDSF.lPitch
			add edi, eax
			mov eax, [esi].RECT.left
			mul [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount
			shr eax, 3
			add edi, eax
			mov eax, [esi].RECT.right
			mov edx, [esi].RECT.bottom
			sub eax, [esi].RECT.left
			sub edx, [esi].RECT.top
		.else
			@strace	<"DirectDrawSurface::Blt, Dst=", ebx, " pSF=", [ebx].DDSF.lpSurface, " lpDstRect=0, bpp=", [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount, " pitch=", [ebx].DDSF.lPitch>
			mov eax, [ebx].DDSF.dwWidth 
			mov edx, [ebx].DDSF.dwHeight
		.endif
		mov dwWidth, eax
		mov dwHeight, edx
		mov eax, [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount
		shr eax, 3
		cmp eax, 5
		jnc error
		test dwFlags, DDBLT_COLORFILL
		.if (!ZERO?)
			add eax, 5
			mov edx, [eax*4 + offset bltprocs]
			mov ecx, lpDDBltFx
			mov lpfnCopyProc, edx
			mov lPitch, 0
			mov esi, [ecx].DDBLTFX.dwFillColor
		.else
			mov edx, [eax*4 + offset bltprocs]
			mov esi, lpDDSrcSurface
if ?MOUSEOPT
			mov eax,[esi].DDSF.ddsCaps.dwCaps
			or [bOnScreen], eax
endif
			mov ecx, lpSrcRect
			mov lpfnCopyProc, edx
			xor eax, eax
			.if (ecx)
				@strace	<"DirectDrawSurface::Blt, Src=", esi, " pSF=", [esi].DDSF.lpSurface, " Rect=", [ecx].RECT.left, " ", [ecx].RECT.top, " ", [ecx].RECT.right, " ", [ecx].RECT.bottom, " bpp=", [esi].DDSF.ddpfPixelFormat.dwRGBBitCount, " pitch=", [esi].DDSF.lPitch>
				mov eax, [ecx].RECT.top
				mul [esi].DDSF.lPitch
				push eax
				mov eax, [ecx].RECT.left
				mul [esi].DDSF.ddpfPixelFormat.dwRGBBitCount
				shr eax, 3
				pop edx
				add eax, edx
				mov edx, [ecx].RECT.bottom
				sub edx, [ecx].RECT.top
				cmp edx, dwHeight
				jnc @F
				mov dwHeight, edx
@@:
			.endif
			mov edx, [esi].DDSF.lPitch
			mov esi, [esi].DDSF.lpSurface
			mov lPitch, edx
			add esi, eax

		.endif

		cmp dwHeight,0
		jz done
		@vmementer
if ?MOUSEOPT
		test [bOnScreen],DDSCAPS_PRIMARYSURFACE
		jz @F
endif
		invoke HideMouse
@@:
		mov eax, esi
		sub esp,2*4
@@:
		mov [esp+4],edi
		mov [esp+0],esi
		mov ecx, dwWidth
		call lpfnCopyProc
		mov esi,[esp+0]
		mov edi,[esp+4]
		add esi, lPitch
		add edi, [ebx].DDSF.lPitch
		dec dwHeight
		jnz @B
		add esp,2*4
if ?MOUSEOPT
		test [bOnScreen],DDSCAPS_PRIMARYSURFACE
		jz @F
endif
		invoke ShowMouse
@@:
		@vmemexit
done:
		mov eax, S_OK
exit:
		@strace	<"DirectDrawSurface::Blt(", pThis, ", ", lpDestRect, ", ", lpDDSrcSurface, ", ", lpSrcRect, ", ", dwFlags, ", ", lpDDBltFx, ")=", eax>
		ret
error:
		mov eax, E_FAIL
		jmp exit

_GetDCColorMap proto :dword

		align 4
blt08:
if ?PALMAP
		mov eax, [ebx].DDSF.hdc
		and eax, eax
		jz @F
		push ecx
		invoke _GetDCColorMap, eax
		pop ecx
		and eax, eax
		jnz blt08_2
@@: 
endif
		cmp ecx, lPitch
		jnz @F
		cmp ecx, [ebx].DDSF.lPitch
		jnz @F
		mov eax, ecx		;optimization possible: just do one movsd
		mul dwHeight
		mov dwHeight,1
		mov ecx, eax
if ?USEXMM
		test g_dwCpuFeature, CPUF_XMM_SUPPORTED
		jnz xmmcopy_b
endif
@@:
		mov  lpfnCopyProc, offset blt08_1
		align 4
blt08_1:
		mov dl,cl
		shr ecx, 2
		rep movsd
		mov cl,dl
		and cl,3
		rep movsb
		retn
		align 4
if ?PALMAP
blt08_2:
		mov lpfnCopyProc, offset blt08_2x
		mov edx, eax
		xor eax, eax
blt08_2x:
@@:
		lodsb
		mov al,[edx+eax]
		stosb
		dec ecx
		jnz @B
		retn
		align 4
endif
blt24:
		mov eax, ecx
		shr ecx, 1
		add ecx, eax
blt16:
		test di,2
		jnz @F
		mov lpfnCopyProc, offset proc16to16_1
		test cl,1
		jnz proc16to16_1
		mov eax, ecx
		shl eax, 1
		mov lpfnCopyProc, offset proc16to16_11
		cmp eax, lPitch
		jnz proc16to16_11
		cmp eax, [ebx].DDSF.lPitch
		jnz proc16to16_11
		mov eax, ecx		;optimization possible: just do one movsd
		mul dwHeight
		mov dwHeight,1
		mov ecx, eax
if ?USEXMM
		test g_dwCpuFeature, CPUF_XMM_SUPPORTED
		jnz xmmcopy_w
endif
		jmp proc16to16_11
@@:
		mov lpfnCopyProc, offset proc16to16_2
		test cl,1
		jz proc16to16_2
		mov lpfnCopyProc, offset proc16to16_21
proc16to16_21:
		dec ecx
		movsw
proc16to16_11:
		shr ecx,1
		rep movsd
		retn
		align 4
proc16to16_2:
		dec ecx
		movsw
proc16to16_1:
		shr ecx,1
		rep movsd
		adc ecx,ecx
		rep movsw
		retn
		align 4 	   
blt32:
		mov eax, ecx
		shl eax, 2
		cmp eax, lPitch
		jnz @F
		cmp eax, [ebx].DDSF.lPitch
		jnz @F
		mov eax, ecx		;optimization possible: just do one movsd
		mul dwHeight
		mov dwHeight,1
		mov ecx, eax
if ?USEXMM
		test g_dwCpuFeature, CPUF_XMM_SUPPORTED
		jnz xmmcopy_d
endif
@@:
		mov  lpfnCopyProc, offset blt32_1
		align 4
blt32_1:
		rep movsd
blt00:
		retn
		align 4

fill08:
if ?PALMAP
		mov eax, [ebx].DDSF.hdc
		and eax, eax
		jz @F
		push ecx
		invoke _GetDCColorMap, eax
		pop ecx
		and eax, eax
		jz @F
		movzx esi, byte ptr [eax+esi]
@@: 
endif
if ?FILLOPTIMIZE
		cmp ecx, [ebx].DDSF.lPitch
		jnz @F
		mov eax, ecx		;optimization possible: just do one stos
		mul dwHeight
		mov dwHeight,1
		mov ecx, eax
		mov eax, esi
@@:
		mov  lpfnCopyProc, offset fill08_1
endif
		mov ah,al
		mov edx,eax
		shl eax,16
		mov ax,dx
fill08_1:
		mov dl,cl
		shr ecx, 2
		rep stosd
		mov cl,dl
		and cl,3
		rep stosb
fill00:
		retn
		align 4
fill16:
if ?FILLOPTIMIZE
		mov edx, ecx
		shl edx, 1
		cmp edx, [ebx].DDSF.lPitch
		jnz @F
		mov eax, ecx		;optimization possible: just do one stos
		mul dwHeight
		mov dwHeight,1
		mov ecx, eax
		mov eax, esi
@@:
		mov  lpfnCopyProc, offset fill16_1
endif
		mov edx, eax
		shl eax, 16
		mov ax, dx
fill16_1:
		shr ecx, 1
		rep stosd
		adc cl,cl
		rep stosw
		retn
fill24:
		mov edx, eax
		shr edx, 16
@@:
		mov [edi+0],ax
		mov [edi+2],dl
		add edi,3
		dec ecx
		jnz @B
		retn
		align 4
fill32:
if ?FILLOPTIMIZE
		mov edx, ecx
		shl edx, 2
		cmp edx, [ebx].DDSF.lPitch
		jnz @F
		mov eax, ecx		;optimization possible: just do one stos
		mul dwHeight
		mov dwHeight,1
		mov ecx, eax
		mov eax, esi
@@:
		mov  lpfnCopyProc, offset fill32_1
		align 4
fill32_1:
endif
		rep stosd
		retn
		align 4

bltprocs label dword
		dd offset blt00
		dd offset blt08
		dd offset blt16
		dd offset blt24
		dd offset blt32

		dd offset fill00	;dummy
		dd offset fill08	
		dd offset fill16
		dd offset fill24
		dd offset fill32
		align 4


Blt 	endp

		@MakeStub BltBatch, 3, DDSF.vft3
		@MakeStub BltBatch, 2, DDSF.vft2

BltBatch proc pThis:dword, pDDBLTBATCH:dword, dw1:DWORD, dw2:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawSurface::BltBatch(", pThis, ")=", eax>
		ret
		align 4
BltBatch endp

		@MakeStub BltFast, 3, DDSF.vft3
		@MakeStub BltFast, 2, DDSF.vft2

BltFast proc pThis:dword, dwX:DWORD, dwY:DWORD, lpDDSrcSurface:LPDIRECTDRAWSURFACE,
			lpSrcRect:ptr RECT, dwTrans:DWORD

local	rcDst:RECT

		mov ecx, dwX
		mov edx, dwY
		mov eax, ecx
		or	eax, edx
		jz simple
		mov rcDst.left, ecx
		mov rcDst.top, edx
		mov eax, pThis
		mov ecx, [eax].DDSF.dwWidth 
		mov edx, [eax].DDSF.dwHeight
		sub ecx, dwX
		sub edx, dwY
		mov rcDst.right, ecx
		mov rcDst.bottom, edx
		lea edx, rcDst
simple:
		invoke Blt, pThis, edx, lpDDSrcSurface, lpSrcRect, 0, 0
exit:
		@strace	<"DirectDrawSurface::BltFast(", pThis, ", ", dwX, ", ", dwY, ", ", lpDDSrcSurface, ", ", lpSrcRect, ", ", dwTrans, ")=", eax>
		ret
		align 4
BltFast endp

		@MakeStub DeleteAttachedSurface, 3, DDSF.vft3
		@MakeStub DeleteAttachedSurface, 2, DDSF.vft2

DeleteAttachedSurface proc uses ebx pThis:dword, dwFlags:DWORD, lpDDSurface: LPDIRECTDRAWSURFACE
		mov ecx, pThis
		mov eax, lpDDSurface
		mov edx, [ecx].DDSF.pAttachedSF
		.while (edx)
			.if ((!eax) || (eax == edx))
				pushad
				mov eax, [edx].DDSF.pAttachedSF
				mov [ecx].DDSF.pAttachedSF, eax
				mov [ecx].DDSF.pAttachedSF, 0
				mov eax, edx
				invoke vf(eax, , Release)
				popad
				.if (eax)
					mov eax, DD_OK
					jmp exit
				.endif
				jmp nextitem
			.endif
			mov ecx, edx
nextitem:
			mov edx, [ecx].DDSF.pAttachedSF
		.endw
		mov eax, DD_OK
		.if (lpDDSurface)
			mov eax, DDERR_SURFACENOTATTACHED
		.endif
exit:
		@strace	<"DirectDrawSurface::DeleteAttachedSurface(", pThis, ", ", dwFlags, ", ", lpDDSurface, ")=", eax>
		ret
		align 4
DeleteAttachedSurface  endp

protoDDENUMSURFACESCALLBACK typedef proto :LPDIRECTDRAWSURFACE, :ptr DDSURFACEDESC, :DWORD
LPFNDDENUMSURFACESCALLBACK typedef ptr protoDDENUMSURFACESCALLBACK

GetSurfaceDesc proto :dword, lpDDSURFACEDESC:ptr DDSURFACEDESC

		@MakeStub EnumAttachedSurfaces, 3, DDSF.vft3
		@MakeStub EnumAttachedSurfaces, 2, DDSF.vft2

EnumAttachedSurfaces proc uses esi pThis:dword, lpContext:dword, lpDDEnumSurfacesCallback:LPFNDDENUMSURFACESCALLBACK

local	ddsd:DDSURFACEDESC

		mov esi, pThis
		.while ([esi].DDSF.pAttachedSF)
			mov esi,[esi].DDSF.pAttachedSF
			mov ddsd.dwSize, sizeof DDSURFACEDESC
			invoke GetSurfaceDesc, esi, addr ddsd
			invoke lpDDEnumSurfacesCallback, esi, addr ddsd, lpContext
			.break .if (eax == DDENUMRET_CANCEL)
		.endw
		mov eax, DD_OK
		@strace	<"DirectDrawSurface::EnumAttachedSurfaces(", pThis, ", ", lpContext, ", ", lpDDEnumSurfacesCallback, ")=", eax>
		ret
		align 4
EnumAttachedSurfaces endp

		@MakeStub EnumOverlayZOrders, 3, DDSF.vft3
		@MakeStub EnumOverlayZOrders, 2, DDSF.vft2

EnumOverlayZOrders proc pThis:dword, dw1:DWORD, pVOID:dword, pDDENUMSURFACESCALLBACK:dword
		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawSurface::EnumOverlayZOrders(", pThis, ")=", eax>
		ret
		align 4

EnumOverlayZOrders endp

		@MakeStub Flip, 3, DDSF.vft3
		@MakeStub Flip, 2, DDSF.vft2

;--- the first surface is always the frontbuffer,
;--- the second surface is always the backbuffer

Flip proc uses ebx pThis:dword, lpDDSurface:LPDIRECTDRAWSURFACE, dwFlags:DWORD

		mov ebx, pThis

if 1
		test byte ptr [ebx].DDSF.dwFlags, FDDSF_FLIPSCHED
		jz flipok
@@:
		invoke GetVesaFlipStatus
		and eax, eax
		jnz flipok
		test dwFlags, DDFLIP_WAIT
		jnz @B
		mov eax, DDERR_WASSTILLDRAWING
		jmp exit
flipok:
		and byte ptr [ebx].DDSF.dwFlags, not FDDSF_FLIPSCHED
endif

		.if (lpDDSurface)
			mov eax, [ebx].DDSF.pFlipChain
;--- if lpDDSurface is != null, it must be found in flip chain
			.while (eax && (eax != lpDDSurface))
				mov eax, [eax].DDSF.pFlipChain
			.endw
		.else
			mov eax, [ebx].DDSF.pAttachedSF	;get the backbuffer surface
		.endif
		and eax, eax
		jz error

;--- ecx = current FRONTBUFFER, eax = current BACKBUFFER		

if 0
		mov edx, [ebx].DDSF.lpSurface
  if ?STOREHDC
		mov ecx, [ebx].DDSF.hdc
  endif
		.while (eax)
			xchg edx,[eax].DDSF.lpSurface
  if ?STOREHDC
			xchg ecx,[eax].DDSF.hdc
  endif
			mov eax, [eax].DDSF.pFlipChain
		.endw
		mov [ebx].DDSF.lpSurface, edx
  if ?STOREHDC
		mov [ebx].DDSF.hdc, ecx
  endif
else
		push [ebx].DDSF.lpSurface
		push [ebx].DDSF.hdc
		.while (eax)
			mov edx, [eax].DDSF.lpSurface
			mov ecx, [eax].DDSF.hdc
			mov [ebx].DDSF.lpSurface, edx
			mov [ebx].DDSF.hdc, ecx
			mov ebx, eax
			mov eax, [eax].DDSF.pFlipChain
		.endw
		pop [ebx].DDSF.hdc
		pop [ebx].DDSF.lpSurface
		mov ebx, pThis
endif
		mov eax, [ebx].DDSF.lpSurface
		sub eax, [ebx].DDSF.lpVidStart
		invoke SetVesaDisplayStart, eax, [ebx].DDSF.lPitch, dwFlags
		or byte ptr [ebx].DDSF.dwFlags, FDDSF_FLIPSCHED
		mov eax, DD_OK
exit:
		@strace	<"DirectDrawSurface::Flip(", pThis, ", ", lpDDSurface, ", ", dwFlags, ")=", eax>
		ret
error:
		mov eax, DDERR_NOTFLIPPABLE
		jmp exit
		align 4

Flip	endp

		@MakeStub GetAttachedSurface, 3, DDSF.vft3
		@MakeStub GetAttachedSurface, 2, DDSF.vft2

GetAttachedSurface proc uses esi pThis:dword, lpDDSCaps:ptr DDSCAPS, lplpDDSurface:ptr LPDIRECTDRAWSURFACE

		mov esi, pThis
		mov esi, [esi].DDSF.pAttachedSF
		mov ecx, lpDDSCaps
		mov eax, [ecx].DDSCAPS.dwCaps
		.while (esi)
			mov edx, [esi].DDSF.ddsCaps.dwCaps
			and edx, eax
			.if (eax == edx)
				inc [esi].DDSF.dwCnt
				invoke vf(esi, , AddRef)
				mov eax, DD_OK
				jmp exit
			.endif
			mov esi, [esi].DDSF.pAttachedSF
		.endw
		mov eax, DDERR_NOTFOUND
exit:
		mov edx, lplpDDSurface
		mov [edx], esi
		@strace	<"DirectDrawSurface::GetAttachedSurface(", pThis, ", ", lpDDSCaps, ", ", lplpDDSurface, ")=", eax, " pSF=", esi>
		ret
		align 4
GetAttachedSurface endp

		@MakeStub GetBltStatus, 3, DDSF.vft3
		@MakeStub GetBltStatus, 2, DDSF.vft2

GetBltStatus proc pThis:dword, dwFlags:DWORD
		mov eax, DDERR_NOBLTHW
		@strace	<"DirectDrawSurface::GetBltStatus(", pThis, ")=", eax>
		ret
		align 4
GetBltStatus endp

		@MakeStub GetCaps, 3, DDSF.vft3
		@MakeStub GetCaps, 2, DDSF.vft2

GetCaps proc pThis:dword, pDDSCAPS:ptr DDSCAPS
		mov ecx, pThis
		mov edx, pDDSCAPS
		push [ecx].DDSF.ddsCaps.dwCaps
		pop [edx].DDSCAPS.dwCaps
		mov eax, S_OK
		@strace	<"DirectDrawSurface::GetCaps(", pThis, ")=", eax>
		ret
		align 4
GetCaps endp

		@MakeStub GetClipper, 3, DDSF.vft3
		@MakeStub GetClipper, 2, DDSF.vft2

GetClipper proc pThis:dword, lplpDDClipper:ptr dword
		mov ecx, pThis
		mov edx, [ecx].DDSF.lpClipper
		.if (edx)
			mov eax, lplpDDClipper
			mov [eax], edx
			invoke vf([ecx].DDSF.lpClipper, , AddRef)
			mov eax, DD_OK
		.else
			mov eax, DDERR_NOCLIPPERATTACHED
		.endif
		@strace	<"DirectDrawSurface::GetClipper(", pThis, ")=", eax>
		ret
		align 4
GetClipper endp

		@MakeStub GetColorKey, 3, DDSF.vft3
		@MakeStub GetColorKey, 2, DDSF.vft2

GetColorKey proc pThis:dword, dwFlags:DWORD, lpDDColorKey:ptr DDCOLORKEY
		mov ecx, pThis
		mov edx, lpDDColorKey
		mov eax, [ecx].DDSF.ddColorKey.dwColorSpaceLowValue
		mov [edx].DDCOLORKEY.dwColorSpaceLowValue, eax
		mov eax, [ecx].DDSF.ddColorKey.dwColorSpaceHighValue
		mov [edx].DDCOLORKEY.dwColorSpaceHighValue, eax
		mov eax, DD_OK
		@strace	<"DirectDrawSurface::GetColorKey(", pThis, ", ", dwFlags, ", ", lpDDColorKey, ")=", eax>
		ret
		align 4
GetColorKey endp

		@MakeStub GetDC_, 3, DDSF.vft3
		@MakeStub GetDC_, 2, DDSF.vft2

GetDC_	 proc uses ebx pThis:dword,pHDC:dword

local	hdc:dword
local	ddpcaps:dword

		mov ebx, pThis
if ?STOREHDC
		mov eax, [ebx].DDSF.hdc
		and eax, eax
		jnz gothdc
endif
		invoke GetHwnd, [ebx].DDSF.lpDD
		.if (eax)
			invoke g_lpfnGetDC, eax
		.else
			invoke CreateDCA, CStr("DISPLAY"), NULL, NULL, NULL
		.endif
if ?STOREHDC
		mov [ebx].DDSF.hdc, eax
endif
;--- is surface in video memory?
		.if (eax && g_lpfnSetDCBitPtr && ([ebx].DDSF.dwFlags & FDDSF_ALLOCATED))
			push eax
			invoke g_lpfnSetDCBitPtr, eax, [ebx].DDSF.lpSurface
			pop eax
		.endif
gothdc:
		mov ecx, pHDC
		mov [ecx], eax
		.if (eax)
;			.if (g_lpfnSetDCOrgEx && (!([ebx].DDSF.dwFlags & FDDSF_ALLOCATED)))
			.if (g_lpfnSetDCBitPtr && (!([ebx].DDSF.dwFlags & FDDSF_ALLOCATED)))
				mov ecx, eax
if 0
				mov eax, [ebx].DDSF.lpSurface
				sub eax, [ebx].DDSF.lpVidStart
				cdq
				div [ebx].DDSF.lPitch
				invoke g_lpfnSetDCOrgEx, ecx, 0, eax
else
				invoke g_lpfnSetDCBitPtr, ecx, [ebx].DDSF.lpSurface
endif
			.endif

;--- if the surface is "real" and mode is exclusive
;--- set system palette usage to 254/256

			.if ([ebx].DDSF.ddsCaps.dwCaps & DDSCAPS_PRIMARYSURFACE)
				invoke GetCoopLevel, [ebx].DDSF.lpDD
				.if (eax & DDSCL_EXCLUSIVE)
					.if ([ebx].DDSF.lpPalette)
						invoke vf([ebx].DDSF.lpPalette, IDirectDrawPalette, pGetCaps), addr ddpcaps
						.if (ddpcaps & DDPCAPS_ALLOW256)
							mov ecx, SYSPAL_NOSTATIC256
						.else
							mov ecx, SYSPAL_NOSTATIC
						.endif
						invoke SetSystemPaletteUse, [ebx].DDSF.hdc, ecx
					.endif
				.endif
			.endif
			mov eax, S_OK
		.else
error:
			mov eax, E_FAIL
		.endif
		@strace	<"DirectDrawSurface::GetDC(", pThis, ")=", eax>
		ret
		align 4
GetDC_	 endp

		@MakeStub GetFlipStatus, 3, DDSF.vft3
		@MakeStub GetFlipStatus, 2, DDSF.vft2

GetFlipStatus proc pThis:dword, dwFlags:DWORD

		mov ecx, dwFlags
		.if (ecx == DDGFS_CANFLIP)
			mov eax, DD_OK
		.elseif (ecx == DDGFS_ISFLIPDONE)
			invoke GetVesaFlipStatus
			.if (!eax)
				mov eax, DDERR_WASSTILLDRAWING
			.else
				mov eax, DD_OK
			.endif
		.endif
		@strace	<"DirectDrawSurface::GetFlipStatus(", pThis, ", ", dwFlags, ")=", eax>
		ret
		align 4
GetFlipStatus endp

		@MakeStub GetOverlayPosition, 3, DDSF.vft3
		@MakeStub GetOverlayPosition, 2, DDSF.vft2

GetOverlayPosition proc pThis:dword,lplX:ptr dword, lpLY:ptr dword
		mov eax, DDERR_NOTAOVERLAYSURFACE
		@strace	<"DirectDrawSurface::GetOverlayPosition(", pThis, ")=", eax>
		ret
		align 4
GetOverlayPosition endp

		@MakeStub GetPalette, 3, DDSF.vft3
		@MakeStub GetPalette, 2, DDSF.vft2

GetPalette proc pThis:dword, lplpDDPalette:ptr dword
		mov ecx, pThis
		mov edx, [ecx].DDSF.lpPalette
		.if (edx)
			mov eax, lplpDDPalette
			mov [eax], edx
			invoke vf([ecx].DDSF.lpPalette, , AddRef)
			mov eax, DD_OK
		.else
			mov eax, DDERR_NOPALETTEATTACHED
		.endif
		@strace	<"DirectDrawSurface::GetPalette(", pThis, ", ", lplpDDPalette, ")=", eax>
		ret
		align 4
GetPalette endp

copypixelformat proc
		mov		eax, [ecx].DDSF.ddpfPixelFormat.dwFlags
		mov		[edx].DDPIXELFORMAT.dwFlags, eax
		mov		eax, [ecx].DDSF.ddpfPixelFormat.dwFourCC
		mov 	[edx].DDPIXELFORMAT.dwFourCC, eax
		mov 	eax, [ecx].DDSF.ddpfPixelFormat.dwRGBBitCount
		mov		[edx].DDPIXELFORMAT.dwRGBBitCount, eax
		mov 	eax, [ecx].DDSF.ddpfPixelFormat.dwRBitMask
		mov		[edx].DDPIXELFORMAT.dwRBitMask, eax
		mov 	eax, [ecx].DDSF.ddpfPixelFormat.dwGBitMask
		mov		[edx].DDPIXELFORMAT.dwGBitMask, eax
		mov 	eax, [ecx].DDSF.ddpfPixelFormat.dwBBitMask
		mov		[edx].DDPIXELFORMAT.dwBBitMask, eax
		mov 	[edx].DDPIXELFORMAT.dwRGBAlphaBitMask, 0
		ret
		align 4
copypixelformat endp

		@MakeStub GetPixelFormat, 3, DDSF.vft3
		@MakeStub GetPixelFormat, 2, DDSF.vft2

GetPixelFormat proc pThis:dword, lpDDPixelFormat:ptr DDPIXELFORMAT
		mov ecx, pThis
		mov edx, lpDDPixelFormat
		call	copypixelformat
		mov eax, DD_OK
		@strace	<"DirectDrawSurface::GetPixelFormat(", pThis, ", ", lpDDPixelFormat, ")=", eax>
		ret
		align 4
GetPixelFormat endp

		@MakeStub GetSurfaceDesc, 3, DDSF.vft3
		@MakeStub GetSurfaceDesc, 2, DDSF.vft2

GetSurfaceDesc proc uses ebx pThis:dword,lpDDSurfaceDesc:ptr DDSURFACEDESC
		mov ebx, pThis
		mov edx, lpDDSurfaceDesc

		mov [edx].DDSURFACEDESC.dwFlags, DDSD_CAPS or DDSD_PITCH or DDSD_WIDTH or DDSD_HEIGHT or DDSD_PIXELFORMAT

		mov eax, [ebx].DDSF.dwWidth
		mov [edx].DDSURFACEDESC.dwWidth, eax

		mov eax, [ebx].DDSF.dwHeight
		mov [edx].DDSURFACEDESC.dwHeight, eax

		mov eax, [ebx].DDSF.ddsCaps.dwCaps
		mov [edx].DDSURFACEDESC.ddsCaps.dwCaps,eax

		mov eax, [ebx].DDSF.lPitch
		mov [edx].DDSURFACEDESC.lPitch,eax

		mov eax, [ebx].DDSF.lpSurface
		mov [edx].DDSURFACEDESC.lpSurface,eax

		lea edx, [edx].DDSURFACEDESC.ddpfPixelFormat
		mov ecx, ebx
		call copypixelformat

		mov eax, S_OK
		@strace	<"GetSurfaceDesc SurfaceDesc: width=", [ebx].DDSF.dwWidth, " height=", [ebx].DDSF.dwHeight, " caps=", [ebx].DDSF.ddsCaps.dwCaps>
		@strace	<"GetSurfaceDesc SurfaceDesc: bpp=", [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount, " RGB=", [ebx].DDSF.ddpfPixelFormat.dwRBitMask, " ", [ebx].DDSF.ddpfPixelFormat.dwGBitMask, " ", [ebx].DDSF.ddpfPixelFormat.dwBBitMask>
		@strace	<"DirectDrawSurface::GetSurfaceDesc(", pThis, ", ", lpDDSurfaceDesc, ")=", eax>
		ret
		align 4
GetSurfaceDesc endp

		@MakeStub Initialize, 3, DDSF.vft3
		@MakeStub Initialize, 2, DDSF.vft2

Initialize proc pThis:dword, lpDirectDraw:ptr, lpDDSurfaceDesc:ptr

		mov eax, DDERR_ALREADYINITIALIZED
		@strace	<"DirectDrawSurface::Initialize(", pThis, ", ", lpDirectDraw, ", ", lpDDSurfaceDesc, ")=", eax>
		ret
		align 4

Initialize endp

		@MakeStub IsLost, 3, DDSF.vft3
		@MakeStub IsLost, 2, DDSF.vft2

IsLost	proc pThis:dword
		mov eax, DD_OK
		@strace	<"DirectDrawSurface::IsLost(", pThis, ")=", eax>
		ret
		align 4
IsLost	endp

		@MakeStub Lock_, 3, DDSF.vft3
		@MakeStub Lock_, 2, DDSF.vft2

;--- fills a DDSURFACEDESC

Lock_ proc pThis:dword, pRect:dword, pDDSurfaceDesc:ptr DDSURFACEDESC, dwFlags:DWORD, handle:dword

;		invoke HideMouse

		mov edx,pDDSurfaceDesc
		mov ecx,pThis

		mov eax, [ecx].DDSF.dwWidth
		mov [edx].DDSURFACEDESC.dwWidth, eax
		mov eax, [ecx].DDSF.dwHeight
		mov [edx].DDSURFACEDESC.dwHeight, eax

		mov eax, [ecx].DDSF.ddsCaps.dwCaps
		mov [edx].DDSURFACEDESC.ddsCaps.dwCaps, eax

		mov eax, [ecx].DDSF.lpSurface
		mov [edx].DDSURFACEDESC.lpSurface,eax

		mov eax, [ecx].DDSF.lPitch
		mov [edx].DDSURFACEDESC.lPitch,eax

		lea edx, [edx].DDSURFACEDESC.ddpfPixelFormat
		call copypixelformat

		mov eax,DD_OK
exit:
		@strace <"Lock SurfaceDesc: pSF=", [ecx].DDSF.lpSurface, " width=", [ecx].DDSF.dwWidth, " height=", [ecx].DDSF.dwHeight>
		@strace <"Lock SurfaceDesc: bpp=", [ecx].DDSF.ddpfPixelFormat.dwRGBBitCount, " RGB=", [ecx].DDSF.ddpfPixelFormat.dwRBitMask, " ", [ecx].DDSF.ddpfPixelFormat.dwGBitMask, " ", [ecx].DDSF.ddpfPixelFormat.dwBBitMask>
		@strace <"DirectDrawSurface::Lock(", pThis, ", ", pRect, ", ", pDDSurfaceDesc, ", ", dwFlags, ", ", handle, ")=", eax>
		ret
		align 4
Lock_ endp

		@MakeStub ReleaseDC_, 3, DDSF.vft3
		@MakeStub ReleaseDC_, 2, DDSF.vft2

ReleaseDC_ proc uses ebx pThis:dword, hdc:dword
		mov ebx, pThis
		mov ecx, hdc
if ?STOREHDC
		.if (ecx == [ebx].DDSF.hdc)
			mov eax, S_OK
		.else
			mov eax, E_FAIL
		.endif
else
		invoke GetHwnd, [ebx].DDSF.lpDD
		.if (eax)
			invoke g_lpfnReleaseDC, eax, hdc
		.else
			invoke DeleteDC, hdc
		.endif
		mov eax, S_OK
endif
		@strace	<"DirectDrawSurface::ReleaseDC(", pThis, ")=", eax>
		ret
		align 4
ReleaseDC_ endp

		@MakeStub Restore, 3, DDSF.vft3
		@MakeStub Restore, 2, DDSF.vft2

Restore proc pThis:dword
		mov eax, DDERR_UNSUPPORTED
		@strace	<"DirectDrawSurface::Restore(", pThis, ")=", eax>
		ret
		align 4
Restore endp

		@MakeStub SetClipper, 3, DDSF.vft3
		@MakeStub SetClipper, 2, DDSF.vft2

SetClipper proc uses ebx pThis:dword, lpDDClipper:LPDIRECTDRAWCLIPPER
		mov ebx, pThis
		mov edx, lpDDClipper
		.if (edx != [ebx].DDSF.lpClipper)
			@strace	<"DirectDrawSurface::SetClipper() old=", [ebx].DDSF.lpClipper, " new=", edx>
			.if ([ebx].DDSF.lpClipper)
				push edx
				invoke vf([ebx].DDSF.lpClipper, , Release)
				pop edx
			.endif
			mov [ebx].DDSF.lpClipper, edx
			.if (edx)
				invoke vf([ebx].DDSF.lpClipper, , AddRef)
			.endif
		.endif
ifdef _DEBUG
		lea edx, [esp+5*4]
endif
		mov eax, DD_OK
		@strace	<"DirectDrawSurface::SetClipper(", pThis, ", ", lpDDClipper, ")=", eax, " esp=", edx>
		ret
		align 4
SetClipper endp

		@MakeStub SetColorKey, 3, DDSF.vft3
		@MakeStub SetColorKey, 2, DDSF.vft2
		
SetColorKey proc pThis:dword, dwFlags:DWORD, lpDDColorKey:ptr DDCOLORKEY
		mov ecx, pThis
		mov edx, lpDDColorKey
		mov eax, [edx].DDCOLORKEY.dwColorSpaceLowValue
		mov [ecx].DDSF.ddColorKey.dwColorSpaceLowValue, eax
		mov eax, [edx].DDCOLORKEY.dwColorSpaceHighValue
		mov [ecx].DDSF.ddColorKey.dwColorSpaceHighValue, eax
		mov eax, DD_OK
		@strace	<"DirectDrawSurface::SetColorKey(", pThis, ", ", lpDDColorKey, ")=", eax>
		ret
		align 4
SetColorKey endp

		@MakeStub SetOverlayPosition, 3, DDSF.vft3
		@MakeStub SetOverlayPosition, 2, DDSF.vft2

SetOverlayPosition proc pThis:dword, lX:DWORD, lY:DWORD

if ?OVERLAYEMU
		mov ecx, pThis
		mov edx, lX
		mov eax, lY
		mov [ecx].DDSF.ptOLPos.x, edx
		mov [ecx].DDSF.ptOLPos.y, eax
else
		mov eax, DDERR_UNSUPPORTED
endif
		@strace	<"DirectDrawSurface::SetOverlayPosition(", pThis, ", ", lX, ", ", lY, ")=", eax>
		ret
		align 4

SetOverlayPosition endp

_GethPal proto stdcall :dword, :ptr DWORD
_SetPrimarySF proto stdcall :dword, :dword

		@MakeStub SetPalette, 3, DDSF.vft3
		@MakeStub SetPalette, 2, DDSF.vft2

;--- in cooperative mode, the 20 reserved entries in
;--- the system palette remain untouched!
;--- in non-cooperative mode, 254 or 256 colors are used
;--- depending on DDPCAPS_ALLOW256
		
SetPalette proc uses ebx pThis:dword, lpDDPalette:ptr DIRECTDRAWPALETTE

local	hPal:dword
local	hdc:dword

		mov ebx, pThis
		mov ecx, lpDDPalette
		.if (ecx != [ebx].DDSF.lpPalette)
			.if ([ebx].DDSF.lpPalette)
				invoke vf([ebx].DDSF.lpPalette, , Release)
			.endif
			mov ecx, lpDDPalette
			mov [ebx].DDSF.lpPalette, ecx
			.if (ecx)
				invoke vf([ebx].DDSF.lpPalette, , AddRef)
			.endif
		.endif
		.if ([ebx].DDSF.lpPalette && ([ebx].DDSF.ddsCaps.dwCaps & DDSCAPS_PRIMARYSURFACE))
			invoke GetDC_, ebx, addr hdc
			.if (eax == DD_OK)
				invoke _GethPal, lpDDPalette, addr hPal
				.if (eax == DD_OK)
					@strace	<"DirectDrawSurface::SetPalette: calling SelectPalette/RealizePalette">
					invoke SelectPalette, hdc, hPal, 0
					invoke RealizePalette, hdc
					invoke _SetPrimarySF, lpDDPalette, hdc
				.endif
				invoke ReleaseDC_, ebx, hdc
			.endif
ifdef _DEBUG
		.else
			@strace	<"DirectDrawSurface::SetPalette: not a primary surface/no pal ", [ebx].DDSF.lpPalette>
endif
		.endif
		mov eax, DD_OK
		@strace	<"DirectDrawSurface::SetPalette(", pThis, ", ", lpDDPalette, ")=", eax>
		ret
		align 4
SetPalette endp

		@MakeStub Unlock, 3, DDSF.vft3
		@MakeStub Unlock, 2, DDSF.vft2
		
Unlock	proc pThis:dword, pVoid:dword

;		invoke ShowMouse
		mov 	eax,DD_OK
		@strace	<"DirectDrawSurface::Unlock(", pThis, ", ", pVoid, ")=", eax>
		ret
		align 4
Unlock	endp

;--- this is the main method for overlay support

		@MakeStub UpdateOverlay, 3, DDSF.vft3
		@MakeStub UpdateOverlay, 2, DDSF.vft2

UpdateOverlay proc pThis:dword,lpSrcRect:ptr RECT, lpDDDestSurface:dword, 
			lpDestRect:ptr RECT, dwFlags:DWORD, lpDDOverlayFx:ptr DDOVERLAYFX
if ?OVERLAYEMU
		invoke Blt, lpDDDestSurface, lpDestRect, pThis, lpSrcRect, 0, lpDDOverlayFx
else
		mov eax, DDERR_UNSUPPORTED
endif
		@strace	<"DirectDrawSurface::UpdateOverlay(", pThis, ", ", lpSrcRect, ", ", lpDDDestSurface, ", ", lpDestRect, ", ", dwFlags, ", ", lpDDOverlayFx, ")=", eax>
		ret
		align 4
UpdateOverlay endp

		@MakeStub UpdateOverlayDisplay, 3, DDSF.vft3
		@MakeStub UpdateOverlayDisplay, 2, DDSF.vft2

UpdateOverlayDisplay proc pThis:dword,dwFlags:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface::UpdateOverlayDisplay(", pThis, ", ", dwFlags, ")=", eax>
		ret
		align 4
UpdateOverlayDisplay endp

		@MakeStub UpdateOverlayZOrder, 3, DDSF.vft3
		@MakeStub UpdateOverlayZOrder, 2, DDSF.vft2

UpdateOverlayZOrder proc pThis:dword, dwFlags:DWORD, lpDDSReference:dword
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface::UpdateOverlayZOrder(", pThis, ", ", dwFlags, ", ", lpDDSReference, ")=", eax>
		ret
		align 4
UpdateOverlayZOrder endp

;--- IDirectDrawSurface2 methods

		@MakeStub GetDDInterface, 3, DDSF.vft3

GetDDInterface proc pThis:dword, lplpDD:ptr ptr
		mov ecx, pThis
		mov edx, [ecx].DDSF.lpDD
		push edx
		invoke vf([ecx].DDSF.lpDD,,AddRef)
		pop edx
		mov ecx,lplpDD
		mov [ecx],edx
		mov eax, DD_OK
		@strace <"DirectDrawSurface2::GetDDInterface(", pThis, ", ", lplpDD, ")=", eax>
		ret
		align 4
GetDDInterface endp

		@MakeStub PageLock, 3, DDSF.vft3

PageLock proc pThis:dword, dw1:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface2::PageLock(", pThis, ")=", eax>
		ret
		align 4
PageLock endp

		@MakeStub PageUnlock, 3, DDSF.vft3

PageUnlock proc pThis:dword, dw1:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface2::PageUnlock(", pThis, ")=", eax>
		ret
		align 4
PageUnlock endp

;--- IDirectDrawSurface3 methods

SetSurfaceDesc proc uses ebx pThis:dword, lpddsd:ptr DDSURFACEDESC, dwFlags:DWORD

		mov ebx, pThis
		mov edx, lpddsd
ifdef _DEBUG
		@strace <"SurfaceDesc: size=", [edx].DDSURFACEDESC.dwSize, " flags=", [edx].DDSURFACEDESC.dwFlags, " height=", [edx].DDSURFACEDESC.dwHeight, " width=", [edx].DDSURFACEDESC.dwWidth>
		@strace <"SurfaceDesc: lPitch/linSize=", [edx].DDSURFACEDESC.lPitch, " backbuffcnt=", [edx].DDSURFACEDESC.dwBackBufferCount, " lpSurface=", [edx].DDSURFACEDESC.lpSurface>
endif
		mov ecx, [edx].DDSURFACEDESC.dwFlags

;--- currently implemented (and allowed) is to set the surface		  

		and ecx, DDSD_LPSURFACE

		.if (ecx != [edx].DDSURFACEDESC.dwFlags)
			mov eax, DDERR_UNSUPPORTED
		.else
			.if (ecx & DDSD_LPSURFACE)
				push [edx].DDSURFACEDESC.lpSurface
				.if ([ebx].DDSF.dwFlags & FDDSF_ALLOCATED)
					.if ([ebx].DDSF.dwFlags & FDDSF_VIRTALLOC)
						invoke VirtualFree, [ebx].DDSF.lpSurface, 0, MEM_RELEASE
					.else
						invoke LocalFree, [ebx].DDSF.lpSurface
					.endif
				.endif
				pop [ebx].DDSF.lpSurface
				and [ebx].DDSF.dwFlags, not (FDDSF_ALLOCATED or FDDSF_VIRTALLOC)
			.endif
			mov eax, DD_OK
		.endif

		@strace <"DirectDrawSurface3::SetSurfaceDesc(", pThis, ", ", lpddsd, ", ", dwFlags, ")=", eax>
		ret
		align 4
SetSurfaceDesc endp

;--- IDirectDrawSurface4 methods

if ?DDS4

SetPrivateData proc pThis:dword, guidTag:REFGUID, lpData:LPVOID, cbSize:DWORD, dwFlags:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface4::SetPrivateData(", pThis, ", ", guidTag, ", ", lpData, ", ", cbSize, ", ", dwFlags, ")=", eax>
		ret
		align 4
SetPrivateData endp

GetPrivateData proc pThis:dword, guidTag:REFGUID, lpBuffer:LPVOID, lpcbBufferSize:ptr DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface4::GetPrivateData(", pThis, ", ", guidTag, ", ", lpBuffer, ", ", lpcbBufferSize, ")=", eax>
		ret
		align 4
GetPrivateData endp

FreePrivateData proc pThis:dword, guidTag:REFGUID
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface4::FreePrivateData(", pThis, ", ", guidTag, ")=", eax>
		ret
		align 4
FreePrivateData endp

GetUniquenessValue proc pThis:dword, lpValue:ptr DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface4::GetUniquenessValue(", pThis, ", ", lpValue, ")=", eax>
		ret
		align 4
GetUniquenessValue endp

ChangeUniquenessValue proc pThis:dword
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface4::ChangeUniquenessValue(", pThis, ")=", eax>
		ret
		align 4
ChangeUniquenessValue endp

endif

;--- IDirectDrawSurface7 methods

if ?DDS7

SetPriority proc pThis:dword, dwPriority:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface7::SetPriority(", pThis, ", ", dwPriority, ")=", eax>
		ret
		align 4
SetPriority endp

GetPriority proc pThis:dword, lpdwPriority:ptr DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface7::GetPriority(", pThis, ", ", lpdwPriority, ")=", eax>
		ret
		align 4
GetPriority endp

SetLOD proc pThis:dword, dwMaxLOD:DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface7::SetLOD(", pThis, ", ", dwMaxLOD, ")=", eax>
		ret
		align 4
SetLOD endp

GetLOD proc pThis:dword, lpdwMaxLOD:ptr DWORD
		mov eax, DDERR_UNSUPPORTED
		@strace <"DirectDrawSurface7::GetLOD(", pThis, ", ", lpdwMaxLOD, ")=", eax>
		ret
		align 4
GetLOD endp

endif

;--------------------------------------------------------

if ?FLAT
gdiprocs label dword
	dd offset g_lpfnSetDCOrgEx, CStr("SetDCOrgEx")
	dd offset g_lpfnSetDCBitPtr, CStr("_SetDCBitPtr")
	dd 0
endif

GetGDIProcs proc uses esi
		mov eax, g_hGDI
if ?FLAT
		.if (!eax)
			invoke GetModuleHandle, CStr("GDI32")
			mov	g_hGDI, eax
		.endif
		.if (eax)
			mov esi, offset gdiprocs
			.while (dword ptr [esi])
				lodsd
				push eax
				lodsd
				invoke GetProcAddress, g_hGDI, eax
				pop ecx
				mov [ecx],eax
			.endw
		.endif
else
externdef stdcall SetDCOrgEx:near
externdef stdcall SetDCBitPtr:near
		mov g_lpfnSetDCOrgEx, offset SetDCOrgEx
		mov g_lpfnSetDCBitPtr, offset SetDCBitPtr
endif
		ret
		align 4
GetGDIProcs endp

;--- set pixel format from SVGAINFO structure in EDX

SetPixelFormat proc
		movzx eax, [edx].SVGAINFO.BitsPerPixel
		mov [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount, eax
		.if (eax <= 8)
			mov [ebx].DDSF.ddpfPixelFormat.dwFlags, DDPF_PALETTEINDEXED8 or DDPF_RGB
		.else
			mov [ebx].DDSF.ddpfPixelFormat.dwFlags, DDPF_RGB
		.endif
		mov cl,[edx].SVGAINFO.RedMaskSize
		add cl,[edx].SVGAINFO.GreenMaskSize
		add cl,[edx].SVGAINFO.BlueMaskSize
		.if (!cl)
			.if (eax == 15)
				mov [ebx].DDSF.ddpfPixelFormat.dwRBitMask, 001Fh
				mov [ebx].DDSF.ddpfPixelFormat.dwGBitMask, 03E0h
				mov [ebx].DDSF.ddpfPixelFormat.dwBBitMask, 07C00h
			.elseif (eax == 16)
				mov [ebx].DDSF.ddpfPixelFormat.dwRBitMask, 001Fh
				mov [ebx].DDSF.ddpfPixelFormat.dwGBitMask, 07E0h
				mov [ebx].DDSF.ddpfPixelFormat.dwBBitMask, 0F800h
			.elseif ((eax == 24) || (eax == 32))
				mov [ebx].DDSF.ddpfPixelFormat.dwRBitMask, 0FFh
				mov [ebx].DDSF.ddpfPixelFormat.dwGBitMask, 0FF00h
				mov [ebx].DDSF.ddpfPixelFormat.dwBBitMask, 0FF0000h
if 0
			.else
				or [ebx].DDSF.ddsCaps, DDSCAPS_PALETTE
endif
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
		mov [ebx].DDSF.ddpfPixelFormat.dwRBitMask, eax

		mov cl, [edx].SVGAINFO.GreenMaskSize
		xor eax, eax
		.while (cl)
			shl eax,1
			or al,1
			dec cl
		.endw
		mov cl, [edx].SVGAINFO.GreenFieldPosition
		shl eax, cl
		mov [ebx].DDSF.ddpfPixelFormat.dwGBitMask, eax

		mov cl, [edx].SVGAINFO.BlueMaskSize
		xor eax, eax
		.while (cl)
			shl eax,1
			or al,1
			dec cl
		.endw
		mov cl, [edx].SVGAINFO.BlueFieldPosition
		shl eax, cl
		mov [ebx].DDSF.ddpfPixelFormat.dwBBitMask, eax
exit:
		ret
		align 4
SetPixelFormat endp

;--- what constellations are supported
;--- 1. a primary surface
;--- 2. a surface in video/system-memory
;--- 3. complex surface with 1 backbuffers
;--- 4. complex surface with 2 backbuffers


Create@DDSurface proc public uses ebx esi edi lpDD: LPDIRECTDRAW, pSurfaceDesc:ptr DDSURFACEDESC, dwMode:dword

local	svi:SVGAINFO
local	dwBBCnt:dword

		@strace <"Create@DDSurface(", lpDD, ", ", pSurfaceDesc, ") enter">

		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DDSF
		and eax,eax
		jz error
		mov ebx,eax
		mov [ebx].DDSF.vft, offset ddsvf
;		mov [ebx].DDSF.vft1, offset dds1vf
;		mov [ebx].DDSF.vft2, offset dds2vf
;		mov [ebx].DDSF.vft3, offset dds3vf
		mov [ebx].DDSF.dwCnt, 1

;--- try to set some addresses from GDI32

		invoke GetGDIProcs

		mov eax, lpDD
		mov [ebx].DDSF.lpDD, eax

		mov esi, pSurfaceDesc
		mov ecx, [esi].DDSURFACEDESC.dwFlags

		.if (ecx & DDSD_PITCH)
			mov eax, [esi].DDSURFACEDESC.lPitch
			mov [ebx].DDSF.lPitch, eax
		.endif
		mov dwBBCnt, 0
		.if (ecx & DDSD_BACKBUFFERCOUNT)
			mov eax, [esi].DDSURFACEDESC.dwBackBufferCount
			mov dwBBCnt, eax
		.endif

		@strace <"Create@DDSurface: this=", ebx, " DDSURFACEDESC.dwFlags=", ecx, " caps=", [esi].DDSURFACEDESC.ddsCaps.dwCaps, " width=", [esi].DDSURFACEDESC.dwWidth, " height=", [esi].DDSURFACEDESC.dwHeight, " bpp=", [esi].DDSURFACEDESC.ddpfPixelFormat.dwRGBBitCount>

		test ecx, DDSD_CAPS
		jz error2
		.if ([esi].DDSURFACEDESC.ddsCaps.dwCaps & DDSCAPS_PRIMARYSURFACE)

			@strace <"Create@DDSurface: primary surface">

;--- for a primary surface width and height must not be set
;--- (what about pixelformat (=bpp)?

			test ecx, DDSD_WIDTH or DDSD_HEIGHT
			jnz error2

			invoke GetVesaMode
			mov [ebx].DDSF.dwVesaMode, eax
			invoke GetVesaModeInfo, [ebx].DDSF.dwVesaMode, addr svi


;--- set values for width, height and bpp from current vesa mode info
		
			movzx eax, svi.XResolution
			mov [ebx].DDSF.dwWidth, eax
			movzx eax, svi.YResolution
			mov [ebx].DDSF.dwHeight, eax
			lea edx, svi
			invoke SetPixelFormat

			movzx eax, svi.BytesPerScanLine
			mov [ebx].DDSF.lPitch, eax

			@strace <"svgainfo: mode=", [ebx].DDSF.dwVesaMode, " width=", [ebx].DDSF.dwWidth, " height=", [ebx].DDSF.dwHeight>
			@strace <"svgainfo: bpp=", [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount, " RGB=", [ebx].DDSF.ddpfPixelFormat.dwRBitMask, " ", [ebx].DDSF.ddpfPixelFormat.dwGBitMask, " ", [ebx].DDSF.ddpfPixelFormat.dwBBitMask>

		.else

;--- for non-primary surfaces width and height *must* be set

			and ecx, DDSD_WIDTH or DDSD_HEIGHT
			cmp ecx, DDSD_WIDTH or DDSD_HEIGHT
			jnz error2
			mov eax, [esi].DDSURFACEDESC.dwHeight
			mov [ebx].DDSF.dwHeight, eax
			mov eax, [esi].DDSURFACEDESC.dwWidth
			mov [ebx].DDSF.dwWidth, eax
;--- is it valid to set the pixel format for back surfaces?
			.if ([esi].DDSURFACEDESC.dwFlags & DDSD_PIXELFORMAT)
				mov eax, [esi].DDSURFACEDESC.ddpfPixelFormat.dwRGBBitCount
				mov [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount, eax
				mov eax, [esi].DDSURFACEDESC.ddpfPixelFormat.dwRBitMask
				mov [ebx].DDSF.ddpfPixelFormat.dwRBitMask, eax
				mov eax, [esi].DDSURFACEDESC.ddpfPixelFormat.dwGBitMask
				mov [ebx].DDSF.ddpfPixelFormat.dwGBitMask, eax
				mov eax, [esi].DDSURFACEDESC.ddpfPixelFormat.dwBBitMask
				mov [ebx].DDSF.ddpfPixelFormat.dwBBitMask, eax
			.else
				invoke GetVesaMode
				mov ecx, eax
				invoke GetVesaModeInfo, ecx, addr svi
				.if (eax)
					lea edx, svi
					invoke SetPixelFormat
				.endif
			.endif
			.if (![ebx].DDSF.lPitch)
				mov eax, [ebx].DDSF.dwWidth
				mul [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount
				shr eax, 3
				mov	[ebx].DDSF.lPitch, eax
			.endif
		.endif

;--- init surface pointer 

		mov edx, [esi].DDSURFACEDESC.ddsCaps
		mov [ebx].DDSF.ddsCaps.dwCaps, edx
		
		.if (edx & DDSCAPS_PRIMARYSURFACE)
			or [ebx].DDSF.ddsCaps.dwCaps, DDSCAPS_VISIBLE or DDSCAPS_VIDEOMEMORY or DDSCAPS_LOCALVIDMEM
			mov	eax, svi.PhysBasePtr
;		 .elseif (edx & (DDSCAPS_VIDEOMEMORY or DDSCAPS_OFFSCREENPLAIN)) 
		.elseif (edx & DDSCAPS_VIDEOMEMORY) 
if ?NOVIDMEMSF
			test dwMode,1
			jz @F
endif
			mov eax, [ebx].DDSF.dwHeight
			mul [ebx].DDSF.dwWidth
			mul [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount
			shr eax, 3
			invoke AllocVideoMemory, lpDD, eax
			and eax, eax
			jz error2
			@strace <"Create@DDSurface: surface in video memory!!!">
		.else
			test [ebx].DDSF.ddsCaps.dwCaps, DDSCAPS_VIDEOMEMORY
			jnz error
@@:
			mov eax, [ebx].DDSF.dwHeight
			mul [ebx].DDSF.dwWidth
			mul [ebx].DDSF.ddpfPixelFormat.dwRGBBitCount
			shr eax, 3
			.if (eax >= 10000h)
				invoke VirtualAlloc, 0, eax, MEM_COMMIT, PAGE_READWRITE
				.if (eax)
					or [ebx].DDSF.dwFlags, FDDSF_ALLOCATED or FDDSF_VIRTALLOC
				.endif
			.else
				invoke LocalAlloc, LMEM_FIXED, eax
				.if (eax)
					or [ebx].DDSF.dwFlags, FDDSF_ALLOCATED
				.endif
			.endif
		.endif
		mov [ebx].DDSF.lpSurface, eax
		invoke GetVideoMemoryStart, [ebx].DDSF.lpDD
		mov [ebx].DDSF.lpVidStart, eax


		.if ([ebx].DDSF.ddsCaps.dwCaps & DDSCAPS_COMPLEX)
			@strace	<"Create@DDSurface: complex surface, creating attached surfaces">
			.if ([ebx].DDSF.ddsCaps.dwCaps & DDSCAPS_FLIP)
				.if (!dwBBCnt)
					jmp error2
				.endif
				or [ebx].DDSF.ddsCaps.dwCaps, DDSCAPS_FRONTBUFFER
			.endif
			mov ecx, ebx
			.while (dwBBCnt)
				push ecx
				mov ecx, sizeof DDSURFACEDESC
				sub esp, ecx
				mov edi, esp
				push esi
				rep movsb
				pop esi
				mov ecx, esp
				and [ecx].DDSURFACEDESC.ddsCaps.dwCaps, \
					not (DDSCAPS_FLIP or DDSCAPS_COMPLEX or DDSCAPS_PRIMARYSURFACE or DDSCAPS_FRONTBUFFER or DDSCAPS_BACKBUFFER or DDSCAPS_VIDEOMEMORY) 
;--- usually flipping surfaces are created in video memory
;--- unless it is explicitely requested to be in SYSTEM_MEMORY
;--- dont know if this may make sense here
				.if ([ebx].DDSF.ddsCaps.dwCaps & DDSCAPS_FLIP)
					.if (!([ecx].DDSURFACEDESC.ddsCaps.dwCaps & DDSCAPS_SYSTEMMEMORY))
						or [ecx].DDSURFACEDESC.ddsCaps.dwCaps, DDSCAPS_VIDEOMEMORY or DDSCAPS_LOCALVIDMEM
					.endif
				.endif
				mov [ecx].DDSURFACEDESC.dwFlags, DDSD_CAPS or DDSD_WIDTH or DDSD_HEIGHT
				push [ebx].DDSF.dwWidth
				pop [ecx].DDSURFACEDESC.dwWidth
				push [ebx].DDSF.dwHeight
				pop [ecx].DDSURFACEDESC.dwHeight
				invoke Create@DDSurface, lpDD, ecx, 1
				add esp, sizeof DDSURFACEDESC
				pop ecx
				and eax, eax
				jz error2
				mov edx, [ebx].DDSF.ddsCaps.dwCaps
				and edx, DDSCAPS_COMPLEX or DDSCAPS_FLIP
				.if (ecx == ebx)
					or edx, DDSCAPS_BACKBUFFER
				.endif
				or [eax].DDSF.ddsCaps.dwCaps, edx
				mov [ecx].DDSF.pFlipChain, eax
				push eax
				.if (edx & DDSCAPS_BACKBUFFER)
					invoke AddAttachedSurface, ebx, eax
				.endif
				pop ecx
				dec dwBBCnt
			.endw
		.endif

		mov eax, ebx
		ret
error:
		xor eax,eax
		ret
error2:
		invoke LocalFree, ebx
		jmp error
		align 4

Create@DDSurface endp


		END

