
;--- implements IDirectDrawPalette

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

QueryInterface proto stdcall pThis:dword,refiid:dword,pObj:dword
AddRef         proto stdcall pThis:dword
Release        proto stdcall pThis:dword

DDPALETTEVFT struct
pQueryInterface 		dd ?
pAddRef 				dd ?
pRelease				dd ?
pGetCaps				dd ?	;:ptr DWORD
pGetEntries 			dd ?	;:DWORD, :DWORD, :DWORD, :LPPALETTEENTRY
pInitialize 			dd ?	;:LPDIRECTDRAW, :DWORD, :LPPALETTEENTRY
pSetEntries 			dd ?	;:DWORD, :DWORD, :DWORD, :LPPALETTEENTRY
DDPALETTEVFT ends


DDPALETTE struct
vft 		dd ?
dwCnt		dd ?
dwCaps		dd ?
numEntries	dd ?
hPalette	dd ?
hdc			dd ?
lpDD		dd ?
DDPALETTE ends

		.CONST

IID_IDirectDrawPalette	GUID <06c14db84H, 0a733H, 011ceH, <0a5H, 021H, 000H, 020H, 0afH, 00bH, 0e5H, 060H>>

vtable label DDPALETTEVFT
		dd QueryInterface,AddRef,Release
		dd GetCaps, GetEntries, Initialize, SetEntries

		.CODE

QueryInterface proc uses esi edi pThis:dword,pIID:dword,pObj:dword

		@strace <"DirectDrawPalette::QueryInterface(", pThis, ")">
		mov edi,offset IID_IDirectDrawPalette
		mov esi,pIID
		mov ecx,4
		repz cmpsd
		jz found
		mov ecx,pObj
		mov dword ptr [ecx],0
		mov eax,DDERR_INVALIDOBJECT
		ret
found:
		mov eax, pThis
		mov ecx, pObj
		mov [ecx],eax
		invoke AddRef, eax
		mov eax,DD_OK
		ret
		align 4
QueryInterface endp

AddRef proc pThis:dword
		mov ecx, pThis
		mov eax, [ecx].DDPALETTE.dwCnt
		inc [ecx].DDPALETTE.dwCnt
		@strace <"DirectDrawPalette::AddRef(", pThis, ")=", eax>
		ret
		align 4
AddRef endp

Release proc uses ebx pThis:dword
		mov ebx, pThis
		mov eax, [ebx].DDPALETTE.dwCnt
		dec [ebx].DDPALETTE.dwCnt
		.if (ZERO?)
			invoke DeleteObject, [ebx].DDPALETTE.hPalette
			invoke LocalFree, ebx
			xor eax, eax
		.endif
		@strace <"DirectDrawPalette::Release(", pThis, ")=", eax>
		ret
		align 4
Release endp

_GethPal proc public pThis:dword, lphPal:ptr DWORD
		mov ecx, pThis
		mov edx, [ecx].DDPALETTE.hPalette
		mov ecx, lphPal
		mov [ecx], edx
		mov eax, DD_OK
		ret
		align 4
_GethPal endp

;--- one the palette is attached to a primary surface,
;--- this flag should be set

_SetPrimarySF proc public pThis:dword, hdc:dword
		mov ecx, pThis
		or [ecx].DDPALETTE.dwCaps, DDPCAPS_PRIMARYSURFACE
		mov edx, hdc
		mov [ecx].DDPALETTE.hdc, edx
		mov eax, DD_OK
		ret
		align 4
_SetPrimarySF endp

GetCaps proc pThis:dword, lpdwCaps:ptr DWORD
		mov ecx, lpdwCaps
		mov edx, pThis
		mov eax, [edx].DDPALETTE.dwCaps
		mov [ecx], eax
		mov eax, DD_OK
		@strace <"DirectDrawPalette::GetCaps(", pThis, ", ", lpdwCaps, ")=", eax>
		ret
		align 4
GetCaps endp

GetEntries proc uses ebx esi edi pThis:dword, dwFlags:DWORD, dwBase:DWORD, dwNumEntries:DWORD, lpEntries:LPPALETTEENTRY

local	dwEsp:dword

		mov ebx, pThis
		mov esi, [ebx].DDPALETTE.hPalette
		mov ecx, dwNumEntries
		mov edi, lpEntries
		mov eax, dwBase
		.if ([ebx].DDPALETTE.dwCaps & DDPCAPS_8BITENTRIES)
			@strace <"DirectDrawPalette::GetEntries() 8 bit entries">
			.while (ecx)
				stosb
				inc eax
				dec ecx
			.endw
		.else
			invoke GetPaletteEntries, esi, dwBase, dwNumEntries, lpEntries
		.endif
		mov eax, DD_OK
		@strace <"DirectDrawPalette::GetEntries(", pThis, ", ", dwFlags, ", ", dwBase, ", ", dwNumEntries, ", ", lpEntries, ")=", eax>
		ret
		align 4

GetEntries endp

Initialize proc pThis:dword, lpDD:LPDIRECTDRAW, dwFlags:DWORD, lpDDColorTable:LPPALETTEENTRY
		mov eax, DDERR_ALREADYINITIALIZED
		@strace <"DirectDrawPalette::Initialize(", pThis, ")=", eax>
		ret
		align 4
Initialize endp

;--- peFlags:
;--- 01: PE_RESERVED: reserved for palette animation (ignored in hx)
;--- 02: PE_EXPLICIT: is a hardware palette index
;--- 04: PE_NOCOLLAPSE: do not try to match to system palette

SetEntries proc uses ebx esi edi pThis:dword, dwFlags:DWORD, dwStartingEntry:DWORD, dwCount:DWORD, lpEntries:LPPALETTEENTRY

local	dwEsp:dword

		@strace	<"DDPalette::SetEntries(", pThis, ", ", dwFlags, ", ", dwStartingEntry, ", ", dwCount, ", ", lpEntries, ") enter">
		cld
		mov ebx, pThis
		mov edi, [ebx].DDPALETTE.hPalette
		mov esi, lpEntries
		mov eax, dwStartingEntry
		mov ecx, dwCount
		lea edx, [ecx+eax]
		.if (edx > [ebx].DDPALETTE.numEntries)
			mov eax, E_FAIL
			jmp exit
		.endif
		mov dwEsp, esp
		.if ([ebx].DDPALETTE.dwCaps & DDPCAPS_8BITENTRIES)
			@strace <"DDPalette::SetEntries() 8 bit entries">
			sub esp, 256*4
			mov edi, esp
			.while (ecx)
				lodsb
				movzx eax, al
				or eax, PC_EXPLICIT shl 24
				stosd
				dec ecx
			.endw
			mov edi, esp
		.else
			mov edi, lpEntries
		.endif
		@strace <"DDPalette::SetEntries [0]: ",dword ptr [edi+0*4], " ",dword ptr [edi+1*4], " ",\
				dword ptr [edi+2*4], " ", dword ptr [edi+3*4]>
		@strace <"DDPalette::SetEntries [8]: ",dword ptr [edi+8*4], " ",dword ptr [edi+9*4], " ",\
				dword ptr [edi+10*4], " ", dword ptr [edi+11*4]>
		invoke SetPaletteEntries, [ebx].DDPALETTE.hPalette, dwStartingEntry, dwCount, edi
		.if ([ebx].DDPALETTE.dwCaps & DDPCAPS_PRIMARYSURFACE)
			.if ([ebx].DDPALETTE.hdc)
				@strace <"DDPalette::SetEntries: calling RealizePalette">
				invoke RealizePalette, [ebx].DDPALETTE.hdc
;				invoke _SendMessage, [ebx].DDPALETTE.lpDD, WM_PALETTECHANGED, 0, 0
			.endif
		.endif
		mov esp, dwEsp
		mov eax, DD_OK
exit:
		@strace <"DirectDrawPalette::SetEntries(", pThis, ", ", dwFlags, ", ", dwStartingEntry, ", ", dwCount, ", ", lpEntries, ")=", eax>
		ret
		align 4

SetEntries endp

;--- the GDI CreatePalette() uses a LOGPALETTE ptr (with PALETTEENTRY items)
;--- all the flags PC_RESERVED, PC_EXPLICITE, PC_NOCOLLAPSE are possible here

Create@DDPalette proc public uses ebx esi edi lpDD:LPDIRECTDRAW, dwFlags:DWORD, lpDDColorArray:LPPALETTEENTRY, ppObj:ptr DWORD

local	pe[255]:PALETTEENTRY
local	lp:LOGPALETTE

		xor ebx, ebx
		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, sizeof DDPALETTE
		and eax,eax
		jz error_nomem
		mov ebx,eax
		mov [ebx].DDPALETTE.vft, offset vtable
		mov [ebx].DDPALETTE.dwCnt, 1
		mov ecx, dwFlags
		mov [ebx].DDPALETTE.dwCaps, ecx
		mov edx, lpDD
		mov [ebx].DDPALETTE.lpDD, edx
		.if (ecx & DDPCAPS_8BIT)
			mov eax, 256
		.elseif (ecx & DDPCAPS_4BIT)
			mov eax, 16
		.elseif (ecx & DDPCAPS_2BIT)
			mov eax, 4
		.else
			mov eax, 2
		.endif
		mov [ebx].DDPALETTE.numEntries, eax
		mov lp.palVersion, 0300h
		mov lp.palNumEntries, ax
		mov ecx, eax
		lea edi, lp.palPalEntry
		mov esi, lpDDColorArray
		and esi, esi
		mov eax, DDERR_INVALIDPARAMS
		jz error
		.if ([ebx].DDPALETTE.dwCaps & DDPCAPS_8BITENTRIES)
			.while (ecx)
				lodsb
				movzx eax, al
				or eax, PC_EXPLICIT shl 24
				stosd
				dec ecx
			.endw
		.else
			@strace <"Create@DDPalette, first 6 entries: ",dword ptr [esi], " ",dword ptr [esi+4], " ",\
				dword ptr [esi+8], " ", dword ptr [esi+12], " ", dword ptr [esi+16], " ", dword ptr [esi+20]>
			rep movsd
		.endif
;--- entries 0 and 255 are	modified at least for DD7
		.if (!(dwFlags & DDPCAPS_ALLOW256))
			and lp.palPalEntry[0*4],0FF000000h
			 or lp.palPalEntry[255*4],0FFFFFFh
		.endif
		invoke CreatePalette, addr lp
		and eax, eax
		jz error_nomem
		mov [ebx].DDPALETTE.hPalette, eax
		mov ecx, ppObj
		mov [ecx], ebx
		mov eax, DD_OK
exit:
		@strace <"Create@DirectDrawPalette(", lpDD, ", ", dwFlags, ", ", lpDDColorArray, ", ", ppObj, ")=", eax, " [", ebx, "]">
		ret
error_nomem:
		mov eax, DDERR_OUTOFMEMORY
error:
		.if (ebx)
			push eax
			invoke LocalFree, ebx
			pop eax
		.endif
		jmp exit
		align 4

Create@DDPalette endp

		END

