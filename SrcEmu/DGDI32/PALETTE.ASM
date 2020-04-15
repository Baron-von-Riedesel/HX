
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private
		option dotname

		include winbase.inc
		include wingdi.inc
		include dgdi32.inc
		include macros.inc

?MAXPALDISP = 0
ifdef _DEBUG
?MAXPALDISP	= 0		;set this to 1 to get verbose palette displays
endif

;--- winxp returns 256 entries for 8bpp,
;--- but win9x returns 20 only

GetSystemPaletteEntries proto :DWORD, :DWORD, :DWORD, :ptr

		.DATA

		public pfnRealizePalette
		public pfnSelectPalette

pfnRealizePalette  dd _RealizePalette
pfnSelectPalette   dd SelectPalette

	public g_syspal

g_syspal	PALETTEOBJ <<GDI_TYPE_PALETTE>, 0, 2, 0, <0, 0FFFFFFh>>        

		.CODE

CreatePalette proc public uses ebx lplgPal:ptr LOGPALETTE

		invoke _GDImalloc2, sizeof PALETTEOBJ
		.if (eax)
			mov ebx, eax
			mov [ebx].PALETTEOBJ.dwType, GDI_TYPE_PALETTE
			mov edx, lplgPal
			movzx ecx, [edx].LOGPALETTE.palNumEntries
			mov [ebx].PALETTEOBJ.cntEntries, ecx
			invoke SetPaletteEntries, ebx, 0, ecx, addr [edx].LOGPALETTE.palPalEntry
			mov eax, ebx
		.endif
		@strace <"CreatePalette(", lplgPal, ")=", eax>
		ret
		align 4

CreatePalette endp

CreateHalftonePalette proc public hdc:DWORD
		xor eax, eax
		@strace <"CreateHalftonePalette(", hdc, ")=", eax>
		ret
		align 4
CreateHalftonePalette endp

ResizePalette proc public hPal:ptr PALETTEOBJ, nEntries:DWORD
		mov edx, hPal
		mov ecx, nEntries
		.if ((ecx <= 256) && ([edx].GDIOBJ.dwType == GDI_TYPE_PALETTE))
			mov eax, [edx].PALETTEOBJ.cntEntries
			mov [edx].PALETTEOBJ.cntEntries, ecx
			lea edx, [edx].PALETTEOBJ.ColorTab
			.while (eax < ecx)
				mov dword ptr [edx+eax*4],0
				inc eax
			.endw
			mov eax, 1
		.else
			xor eax, eax
		.endif
		@strace <"ResizePalette(", hPal, ", ", nEntries, ")=", eax>
		ret
		align 4
ResizePalette endp

_initreservedentries proc
		@strace <"_initreservedentries called">
		pushad
		invoke GetStockObject, DEFAULT_PALETTE
		.if (eax)
			lea esi, [eax].PALETTEOBJ.ColorTab
			mov edi, offset g_syspal.ColorTab
			mov ecx, 10
			rep movsd
			mov cl, 10
			mov edi, offset g_syspal.ColorTab + 246 * 4
			rep movsd
			mov g_syspal.cntEntries, 256
		.endif
		popad
		ret
		align 4
_initreservedentries endp

;--- this is called if there has no DC been created yet
;--- then RealizePalette was never called

_initsyspal proc public
		@strace <"_initsyspal called">
		pushad
		invoke GetVesaProcs
		.if (g_lpfnGetVesaPaletteEntries)
			invoke g_lpfnGetVesaPaletteEntries, 0, 256, addr g_syspal.ColorTab
		.endif
		.if (g_lpfnSetVesaPaletteEntries)
			invoke _initreservedentries
			invoke g_lpfnSetVesaPaletteEntries, 0, 256, addr g_syspal.ColorTab
		.endif
		popad
		ret
		align 4
_initsyspal endp

;--- map logical palette into system palette
;--- returns number of entries mapped into system palette

?GETSYSPAL	equ 0

@swapclr macro
		mov edx,eax
		shr eax, 8
		mov dh,ah
		mov ah,dl
		shl eax, 8
		mov al,dh
		endm

		public RealizePalette@4

RealizePalette@4:
		jmp [pfnRealizePalette]
		align 4

_RealizePalette proc uses ebx esi edi hdc:DWORD

local	dwEntries:dword
local	dwRes:DWORD
local	pMax:DWORD
local	dwChanged:DWORD

		mov dwChanged, 0
		mov eax, GDI_ERROR
		mov ecx, hdc
		mov ebx, [ecx].DCOBJ.hPalette
		.if (ebx)
			mov edx,[ecx].DCOBJ.hBitmap
			.if (edx)		;is it a memory context?
				@strace <"RealizePalette(", hdc, ") for a memory DC">
				mov edx, [edx].BITMAPOBJ.pBitmap
				movzx eax, [edx].BITMAPINFOHEADER.biBitCount
				.if (eax <= 8)
					mov edi, [edx].BITMAPINFOHEADER.biSize
					add edi, edx
					.if (eax == 8)
						mov ecx, 256
					.elseif (eax == 4)
						mov ecx, 16
					.else
						mov ecx, 2
					.endif
if ?GETSYSPAL
;--- get the system colors, the DC's color palette
;--- might not be correct (if it is a newly created DC)
					mov esi, offset g_syspal.ColorTab
else
					lea esi, [ebx].PALETTEOBJ.ColorTab
endif
;--- transform PALETTEOBJ items to RGBQUAD items
if 1
@@:
					lodsd
					@swapclr
					stosd
					loop @B
else
					rep movsd
endif
					mov eax, [ebx].PALETTEOBJ.cntEntries
				.else
					xor eax, eax
				.endif
			.else
				@strace <"RealizePalette(", hdc, ") for a physical DC, bpp=", [ecx].DCOBJ.dwBpp>
				.if ([ecx].DCOBJ.bSysPalUse != SYSPAL_ERROR)
					.if (g_syspal.cntEntries == 2)
						call _initsyspal
					.endif
					lea esi, [ebx].PALETTEOBJ.ColorTab
					mov edi, offset g_syspal.ColorTab
					mov edx, hdc
					mov al, [edx].DCOBJ.bSysPalUse
					.if (al == SYSPAL_STATIC)
						invoke _initreservedentries
						mov ecx,10
					.elseif (al == SYSPAL_NOSTATIC)
						mov g_syspal.ColorTab[0*4],0
						mov g_syspal.ColorTab[255*4],0FFFFFFh
						mov ecx,1
					.else
						xor ecx, ecx
					.endif
					mov dwRes, ecx
					lea eax, [edi+256*4]
					lea edi, [edi+ecx*4]
					shl ecx, 2
					sub eax, ecx
					mov pMax, eax
					mov ecx, [ebx].PALETTEOBJ.cntEntries
					xor ebx, ebx
					mov dwEntries, ecx
					and ecx, ecx
					jz done
					sub esp, 100h
					xor edx, edx
					.repeat
						lodsd
						test eax, PC_EXPLICIT shl 24
						jnz isExplicit
;						test eax, PC_NOCOLLAPSE shl 24
						test eax, (PC_NOCOLLAPSE or PC_RESERVED) shl 24
						jnz colorset
						cmp dwRes,0
						jz colorset
						push edi
						mov ecx, edi
						mov edi, offset g_syspal.ColorTab
						sub ecx, edi
						shr ecx, 2
;;						jz colorsetX
						repnz scasd
						jz colormatchedX
						mov ecx, dwRes
						mov edi, pMax
						repnz scasd
						jz colormatchedX
colorsetX:
						pop edi
colorset:
						and eax, 0FFFFFFh
						.if (edi < pMax)
if 1
							mov ecx, eax
							scasd
							mov eax, edi
							jz colormatchedY
							mov [edi-4],ecx
else
							stosd
							mov eax, edi
endif
							inc dwChanged
							jmp colormatchedY
						.endif
						push edx
						invoke GetNearestPaletteIndex, offset g_syspal, eax
						pop edx
						jmp colornotmatched
isExplicit:
;						movzx eax, al
;						mov eax, [eax*4 + offset g_syspal.ColorTab]
;						and eax, 0FFFFFFh
;						stosd
						mov al,dl
						jmp colormatched
colormatchedX:
						mov eax, edi
						pop edi
colormatchedY:
						sub eax, offset g_syspal.ColorTab + 4
						shr eax, 2
colormatched:
						inc ebx
colornotmatched:
						mov [esp+edx],al
						inc edx
						dec dwEntries
					.until (ZERO?)
					mov edi, esp
					mov esi, hdc
					mov ecx, [esi].DCOBJ.hPalette
					mov ecx, [ecx].PALETTEOBJ.cntEntries
					mov al, 00h
@@:
					scasb
					jnz @F
					inc al
					dec cl
					jnz @B
					mov [esi].DCOBJ.bColMap, 0
					@strace <"identity palette">
					jmp identity
@@:
					.if (![esi].DCOBJ.pColMap)
						invoke _GDImalloc, 100h
						mov [esi].DCOBJ.pColMap, eax
					.endif
					mov edi, [esi].DCOBJ.pColMap
					@strace <"no identity palette, mapping table=", edi>
					.if (edi)
						mov [esi].DCOBJ.bColMap, 1
						mov esi, esp
						mov ecx, 100h/4
						rep movsd
					.endif
identity:
					add esp,100h
done:
if 1
					mov esi, hdc
					invoke _GetNearestColor, esi, [esi].DCOBJ.dwTextColor
					mov [esi].DCOBJ._TextColor, eax
					invoke _GetNearestColor, esi, [esi].DCOBJ.dwBkColor
					mov [esi].DCOBJ._BkColor, eax
					mov edx, [esi].DCOBJ.hBrush
					.if (edx && ([edx].BRUSHOBJ.dwStyle & BS_SOLID))
						invoke _GetNearestColor, esi, [edx].BRUSHOBJ.dwColor
						mov [esi].DCOBJ._BrushColor, eax
					.endif
endif
					@strace <"system palette: ", ebx, " entries mapped, ", dwChanged, " entries changed">
					.if (dwChanged && g_lpfnSetVesaPaletteEntries)
						invoke g_lpfnSetVesaPaletteEntries, 0, 100h, offset g_syspal.ColorTab
					.endif
if 1
					.if ([esi].DCOBJ.bSysPalUse == SYSPAL_NOSTATIC256)
						mov dwChanged, 0	;dont send WM_PALETTECHANGED
					.endif
endif
					mov eax, ebx
				.else
error:
					xor eax, eax
				.endif
			.endif
		.endif
exit:
		mov edx, dwChanged
		@strace <"RealizePalette(", hdc, ")=", eax>
		ret
		align 4

_RealizePalette endp

SelectPalette proc public hdc:DWORD, hpal:DWORD, bForceBackground:DWORD

		mov ecx, hdc
		mov eax, hpal
		lea edx, [eax].PALETTEOBJ.ColorTab
		.if (eax && (![eax].PALETTEOBJ.hdc))
			mov [eax].PALETTEOBJ.hdc, ecx
		.endif
		xchg eax, [ecx].DCOBJ.hPalette
		.if (eax && (ecx == [eax].PALETTEOBJ.hdc) && (eax != hpal))
			mov [eax].PALETTEOBJ.hdc, 0
		.endif
		mov [ecx].DCOBJ.pColorTab, edx
		@strace <"SelectPalette(", hdc, ", ", hpal, ", ", bForceBackground, ")=", eax>
		ret
		align 4

SelectPalette endp

;--- the entries are of type PALETTEENTRY,
;--- which means there are flags in the highest byte

SetPaletteEntries proc public uses esi edi hpal:DWORD, iStart:DWORD, cEntries:DWORD, lppe:ptr PALETTEENTRY

		xor eax, eax
		mov edi, hpal
		.if ([edi].PALETTEOBJ.dwType == GDI_TYPE_PALETTE)
			mov esi, lppe
			mov edx, iStart
			mov eax, edi
			lea edi, [edi+4*edx+PALETTEOBJ.ColorTab]
			mov ecx, cEntries
			.while (ecx && (!dh))
				movsd
				dec ecx
				inc edx
			.endw
			mov edi, eax
			.if (edx > [edi].PALETTEOBJ.cntEntries)
				mov [edi].PALETTEOBJ.cntEntries, edx
			.endif
			mov eax, cEntries
			sub eax, ecx
		.endif
ifdef _DEBUG
		xor ecx, ecx
		mov edi, hpal
		mov edx, iStart
		lea edi, [edi+PALETTEOBJ.ColorTab+edx*4]
		.while (ecx < 10h)
			@strace <[edi+ecx*4+0], " ", [edi+ecx*4+4], " ", [edi+ecx*4+8], " ", [edi+ecx*4+12]>
			add ecx,4
		.endw
endif
		@strace <"SetPaletteEntries(", hpal, ", ", iStart, ", ", cEntries, ", ", lppe, ")=", eax>
		ret
		align 4

SetPaletteEntries endp

;--- AnimatePalette changes "reserved" entries in a logical palette

AnimatePalette proc public uses ebx esi edi hPal:dword, iStart:DWORD, cEntries:DWORD, lppe:ptr PALETTEENTRY

ifdef _DEBUG
local	dwChanged:dword
endif

		xor eax, eax
		mov ebx, hPal
		.if ([ebx].PALETTEOBJ.dwType == GDI_TYPE_PALETTE)
			mov esi, lppe
			lea edi, [ebx].PALETTEOBJ.ColorTab
			mov edx, iStart
			mov ecx, cEntries
ifdef _DEBUG
			mov dwChanged, 0
endif
			.while (ecx && (edx < [ebx].PALETTEOBJ.cntEntries))
				lodsd
				.if (byte ptr [edi+edx*4+3] & PC_RESERVED)
ifdef _DEBUG
					inc dwChanged
endif
					or eax, PC_RESERVED shl 24
					mov [edi+edx*4], eax
				.endif
				inc edx
				dec ecx
			.endw
ifdef _DEBUG
			@strace <"AnimatePalette: ", dwChanged, " entries set">
endif
			mov ecx, hPal
			mov edx, [ecx].PALETTEOBJ.hdc
			.if (edx && (![edx].DCOBJ.hBitmap))
				xor ebx, ebx
				.if ([edx].DCOBJ.bColMap)
					mov ebx, [edx].DCOBJ.pColMap
				.endif
				lea esi, [ecx].PALETTEOBJ.ColorTab
				mov edx, iStart
				lea esi, [esi+edx*4]
				add ebx, edx
				mov ecx, cEntries
				mov edi, offset g_syspal.ColorTab
				.while (ecx)
					lodsd
					test eax, PC_RESERVED shl 24
					.if (!ZERO?)
						.if (ebx)
							movzx edx, byte ptr [ebx]
							inc ebx
						.endif
						mov [edi+edx*4], eax
					.endif
					inc edx
					dec ecx
				.endw
				.if (g_lpfnSetVesaPaletteEntries)
					invoke g_lpfnSetVesaPaletteEntries, 0, 256, addr g_syspal.ColorTab
				.endif
			.endif
			@mov eax, 1
		.endif
		@strace <"AnimatePalette(", hPal, ", ", iStart, ", ", cEntries, ", ", lppe, ")=", eax>
		ret
		align 4

AnimatePalette endp

GetPaletteEntries proc public uses ebx esi edi hpal:DWORD, iStart:DWORD, cEntries:DWORD, lppe:ptr PALETTEENTRY

		mov ebx, hpal
		.if (!lppe)
			mov eax, [ebx].PALETTEOBJ.cntEntries
		.else
			mov ecx, cEntries
			mov edi, lppe
			mov edx, iStart
			lea esi, [ebx].PALETTEOBJ.ColorTab
			.while (ecx)
				.break .if (edx >= [ebx].PALETTEOBJ.cntEntries)
				mov eax,[esi+edx*4]
				mov [edi+edx*4],eax
				inc edx
				dec ecx
			.endw
			mov eax, cEntries
			sub eax, ecx
		.endif
		@strace <"GetPaletteEntries(", hpal, ", ", iStart, ", ", cEntries, ", ", lppe, ")=", eax>
		ret
		align 4

GetPaletteEntries endp

GetSystemPaletteEntries proc public uses ebx esi edi hdc:DWORD, iStart:DWORD, cEntries:DWORD, lppe:ptr

		mov ebx, offset g_syspal
if 1
		.if (g_syspal.cntEntries == 2)
			call _initsyspal
		.endif
endif
		.if (!lppe)
			mov eax, [ebx].PALETTEOBJ.cntEntries
		.else
			lea esi, [ebx].PALETTEOBJ.ColorTab
			mov ecx, cEntries
			mov edi, lppe
			mov edx, iStart
			xor eax, eax
			.while (ecx)
;				.break .if (edx >= [ebx].PALETTEOBJ.cntEntries)
				.break .if (dh)
				mov eax,[esi+edx*4]
				mov [edi+edx*4],eax
				inc edx
				dec ecx
			.endw
			mov eax, cEntries
			sub eax, ecx
		.endif
		@strace <"GetSystemPaletteEntries(", hdc, ", ", iStart, ", ", cEntries, ", ", lppe, ")=", eax>
		ret
		align 4

GetSystemPaletteEntries endp

;--- get a palette index for a color
;--- GetNearestPaletteIndex( hdc, PALETTEINDEX(x)) should return x

GetNearestPaletteIndex proc public uses ebx esi edi hpal:dword, colorref:COLORREF

local	dwColor:DWORD
ifdef _DEBUG
local	dwCol:DWORD
endif

		mov ebx, hpal
		xor eax, eax
		cmp [ebx].GDIOBJ.dwType, GDI_TYPE_PALETTE
		jnz exit
		mov eax, colorref		;format 00BBGGRR
		test eax, 01000000h		;is is a color created with PALETTEINDEX()?
		jz @F
		movzx eax, al
		jmp exit
@@:
		lea esi, [ebx].PALETTEOBJ.ColorTab
		mov dwColor,0
		mov edi, 0FFFFFFh
		xor ecx, ecx
		.while (ecx < [ebx].PALETTEOBJ.cntEntries)
			lodsd
			mov ebx, colorref
			xor edx, edx
			sub al,bl
			jnc @F
			neg al
@@:
			sub ah,bh
			jnc @F
			neg ah
@@:
			mov dl,al
			add dl,ah
			adc dh,00
			shr eax, 16
			shr ebx, 16
			sub al, bl
			jnc @F
			neg al
@@:
			add dl, al
			adc dh, 00
			mov ebx, hpal
if ?MAXPALDISP
			@tracedw ecx
			@trace ':'
			@tracedw [esi-4]
			@trace ' '
			@tracedw edx
			@trace ' '
endif
			cmp edx, edi
			jnc @F
			mov edi, edx
			mov dwColor, ecx
ifdef _DEBUG
			mov eax, [esi-4]
			mov dwCol, eax
endif
			and edi, edi
			jz found
@@:
			inc ecx
if ?MAXPALDISP
			test cl,3
			jnz  @F
			@trace <13,10>
@@:
endif
		.endw
found:
		mov eax, dwColor
exit:
		@strace <"GetNearestPaletteIndex(", hpal, ", ", colorref, ")=", eax, " ", dwCol>
		ret
		align 4

GetNearestPaletteIndex endp

SetSystemPaletteUse proc public hdc:dword, bUse:dword

		mov eax, SYSPAL_ERROR
		mov ecx, hdc
		jecxz @F
		.if (([ecx].GDIOBJ.dwType == GDI_TYPE_DC) && ([ecx].DCOBJ.bSysPalUse != al))
			mov eax, bUse
			xchg al, [ecx].DCOBJ.bSysPalUse
			movzx eax, al
		.endif
@@:
		@strace <"SetSystemPaletteUse(", hdc, ", ", bUse, ")=", eax>
		ret
		align 4

SetSystemPaletteUse endp

GetSystemPaletteUse proc public hdc:dword
		mov eax, SYSPAL_ERROR
		mov ecx, hdc
		jecxz @F
		.if ([ecx].GDIOBJ.dwType == GDI_TYPE_DC)
			movzx eax, [ecx].DCOBJ.bSysPalUse
		.endif
@@:
		@strace <"GetSystemPaletteUse(", hdc, ")=", eax>
		ret
		align 4

GetSystemPaletteUse endp

;--- returns a color value (COLORREF)
;--- often used this way: GetNearestColor( hdc, PALETTEINDEX(1))

GetNearestColor proc public hdc:dword, colorref:COLORREF

		.if (g_syspal.cntEntries == 2)
			call _initsyspal
		.endif
		mov eax, colorref		;format 00BBGGRR
		mov ecx, hdc
		mov edx, [ecx].DCOBJ.dwBpp
		.if (edx <= 8)
			test eax, 01000000h		;is is a color created with PALETTEINDEX()?
			jz @F
			movzx eax,al
			jmp colfnd
@@:
			invoke GetNearestPaletteIndex, addr g_syspal, eax
colfnd:
			mov eax, [offset g_syspal.ColorTab+eax*4]
		.elseif (edx == 15)
			and eax, 0F8F8F8h
		.elseif (edx == 16)
			and eax, 0F8FCF8h
		.endif
		@strace <"GetNearestColor(", hdc, ", ", colorref, ")=", eax>
		ret
		align 4
GetNearestColor endp


UpdateColors proc public hdc:dword
		mov eax, 1
		@strace <"UpdateColors(", hdc, ")=", eax, " *** unsupp ***">
		ret
		align 4
UpdateColors endp

_GetDCColorMap proc public hdc:dword

		mov ecx, hdc
		xor eax, eax
		.if ([ecx].DCOBJ.bColMap)
			mov eax, [ecx].DCOBJ.pColMap
		.endif
		ret
		align 4
_GetDCColorMap endp

		end
