
?CLIPPING	equ 1
?MAPPING	equ 1

GDI_TYPE_DC			equ "DCOB"
GDI_TYPE_BITMAP		equ "BITM"
GDI_TYPE_BRUSH		equ "BRUS"
GDI_TYPE_FONT 		equ "FONT"
GDI_TYPE_PALETTE	equ "PALE"
GDI_TYPE_PEN  		equ "PEN "
GDI_TYPE_RGN  		equ "RGN "

GDIOBJ	struct
dwType	dd ?
GDIOBJ	ends

DCOBJ	struct
		GDIOBJ <>
pBMBits 	DWORD ?		;pointer to bits
pOrigin 	DWORD ?		;pointer to 0,0
pColorTab	DWORD ?		;
lPitch		DWORD ?		;bytes per scan line
dwBpp 		DWORD ?		;bits per pixel
dwHeight	DWORD ?
dwWidth		DWORD ?
hBrush		DWORD ?		;current brush
hPen		DWORD ?		;current pen
hBitmap		DWORD ?		;currentbitmap (for memory contexts)
hFont       DWORD ?		;current font
hPalette	DWORD ?		;current palette
dwBkColor   DWORD ?		;type COLORREF
dwTextColor DWORD ?		;type COLORREF
_BrushColor	DWORD ?		;color palette/value
_BkColor	DWORD ?		;color palette/value
_TextColor	DWORD ?		;color palette/value
dwTextAlign DWORD ?		;these are flags (WORD)
dwFlags  	DWORD ?
pStack		DWORD ?		;DC stack (for SaveDC/RestoreDC)
pColMap		DWORD ?		;for palettes a color map
ptPos		POINT <>	;current X,Y position (for LineTo)
rcClipping	RECT <>
ptWindowOrg POINT <>	;used by Get/SetWindowOrgEx
sWindowExt	SIZE_ <>	;used by Get/SetWindowExtEx
ptViewportOrg POINT <>	;used by Get/SetViewportOrgEx
sViewportExt SIZE_ <>	;used by Get/SetViewportExtEx
bBkMode     BYTE ?		;background mode
bMapMode	BYTE ?		;mapping mode
bROP2		BYTE ?		;rop2 mode
bSysPalUse	BYTE ?		;system palette usage
bStretch	BYTE ?		;stretch blt mode
bGraphicsMode BYTE ?	;???
bColMap		BYTE ?		;pColMap must be used (palette translation required)
			BYTE ?		;alignment
DCOBJ	ends

DCF_BOTTOM_UP	equ 1
DCF_SCREEN		equ 2	;device is screen

LPDCOBJ typedef ptr DCOBJ

BITMAPOBJ	struct
		GDIOBJ <>
pBitmap 	DWORD ?
BITMAPOBJ	ends

;--- if BRUSHOBJ, PENOBJ, FONTOBJ, PALETTEOBJ are modified
;--- check stock object definitions in STOCKOBJ.ASM!

BRUSHOBJ	struct
		GDIOBJ <>
dwStyle		DWORD ?
union
dwColor 	DWORD ?
hBitmap		DWORD ?
ends
BRUSHOBJ	ends

PENOBJ	struct
		GDIOBJ <>
dwStyle		DWORD ?
dwColor 	DWORD ?
dwWidth		DWORD ?
PENOBJ	ends

FONTOBJ		struct
		GDIOBJ <>
pFontRes	DWORD ?
;dwHeight	DWORD ?
FONTOBJ		ends

PALETTEOBJ	struct
			GDIOBJ <>
hdc			DWORD ?		;hdc this palette is selected into            
cntEntries	DWORD ?            
dwIndex		DWORD ?
ColorTab 	DWORD 256 dup (?)
PALETTEOBJ	ends

ifndef RECT
RECT struct
left	SDWORD	?
top		SDWORD	?
right	SDWORD	?
bottom	SDWORD	?
RECT ends
endif

RGNOBJ	struct
		GDIOBJ <>
dwRgnType DWORD ?
union
rc		RECT <>
ends
RGNOBJ	ends

RGNTYPE_RECT	equ 0	;rectangular region

FONTDIRENTRY struct
dfVersion	dw ?			;+0
dfSize		dd ?			;+2
dfCopyright	db 60 dup (?)	;+6
dfType		dw ?			;+66
dfPoints	dw ?			;+68
dfVertRes	dw ?			;+70
dfHorzRes	dw ?			;+72
dfAscent	dw ?			;+74
dfInternalLeading dw ?		;+76
dfExternalLeading dw ?		;+78
dfItalic	db ?			;+80
dfUnderline	db ?			;+81
dfStrikeOut	db ?			;+82
dfWeight	dw ?			;+83  400=190h/700=2BCh
dfCharSet	db ?			;+85
dfPixWidth	dw ?			;+86
dfPixHeight	dw ?			;+88
dfPitchAndFamily db ?		;+90
dfAvgWidth	dw ?			;+91
dfMaxWidth	dw ?			;+93
dfFirstChar	db ?			;+95
dfLastChar	db ?			;+96
dfDefaultChar db ?			;+97
dfBreakChar	db ?			;+98
dfWidthBytes dw ?			;+99
dfDevice	dd ?			;+101
dfFace		dd ?			;+105
dfReserved	dd ?			;+109
;szDeviceName db 1 dup (?)	;+113 = 71h
;szFaceName db 1 dup (?)	
FONTDIRENTRY ends

protoSetVesaPaletteEntries typedef proto nStart:DWORD, nEntries:DWORD, pPal:DWORD
LPFNSETVESAPALETTEENTRIES typedef ptr protoSetVesaPaletteEntries
protoGetVesaPaletteEntries typedef proto nStart:DWORD, nEntries:DWORD, pPal:DWORD
LPFNGETVESAPALETTEENTRIES typedef ptr protoGetVesaPaletteEntries

getdisplaydc proto
_col16to8    proto
_col24to8    proto
_col8to24    proto
_col24to15   proto
_col15to24   proto
_col24to16   proto
_col16to24   proto
_FindFontResource proto :ptr LOGFONTA
atexit       proto c :DWORD
doatexit    proto c
_GDImalloc	proto stdcall :DWORD
_GDImalloc2	proto stdcall :DWORD
_GDIfree	proto stdcall :DWORD
ShowMouse	proto
HideMouse	proto
ConvertWStr	proto
GetVesaProcs proto

externdef g_hdc: LPDCOBJ
externdef g_bMouse:BYTE
externdef g_bCharHeight:BYTE
externdef g_lpfnGetVesaPaletteEntries:LPFNGETVESAPALETTEENTRIES
externdef g_lpfnSetVesaPaletteEntries:LPFNSETVESAPALETTEENTRIES

protoRealizePalette typedef proto :DWORD
LPFNREALIZEPALETTE typedef ptr protoRealizePalette
externdef _imp__RealizePalette@4:LPFNREALIZEPALETTE

protoSelectPalette typedef proto :DWORD
LPFNSELECTPALETTE typedef ptr protoSelectPalette
externdef _imp__SelectPalette@12:LPFNSELECTPALETTE

_GetNearestColor proto :DWORD, :COLORREF

