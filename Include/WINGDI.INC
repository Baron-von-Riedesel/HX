
WHITE_BRUSH		EQU	0
LTGRAY_BRUSH	EQU	1
GRAY_BRUSH		EQU	2
DKGRAY_BRUSH	EQU	3
BLACK_BRUSH		EQU	4
NULL_BRUSH		EQU	5
WHITE_PEN		EQU	6
BLACK_PEN		EQU	7
NULL_PEN		EQU	8

OEM_FIXED_FONT	EQU	10
ANSI_FIXED_FONT	EQU	11
ANSI_VAR_FONT	EQU	12
SYSTEM_FONT		EQU	13
DEFAULT_PALETTE	EQU	15

TRANSPARENT		EQU	1
OPAQUE			EQU	2

GM_COMPATIBLE	EQU	1
GM_ADVANCED		EQU	2
GM_LAST			EQU	2

MM_TEXT			EQU	1
MM_LOMETRIC		EQU	2
MM_HIMETRIC		EQU	3
MM_LOENGLISH	EQU	4
MM_HIENGLISH	EQU	5
MM_TWIPS		EQU	6
MM_ISOTROPIC	EQU	7
MM_ANISOTROPIC	EQU	8


XFORM	struct 
eM11	REAL4	?
eM12	REAL4	?
eM21	REAL4	?
eM22	REAL4	?
eDx_	REAL4	?
eDy		REAL4	?
XFORM	ends

GDI_ERROR	EQU	0FFFFFFFFh

SIZE_	struct
cx_		sdword ?
cy		sdword ?
SIZE_	ends

ifndef RECT
RECT	struct
left	SDWORD	?
top		SDWORD	?
right	SDWORD	?
bottom	SDWORD	?
RECT	ends
endif

;--- Regions

;--- SelectClipRgn return codes

ERROR			EQU	0
NULLREGION		EQU	1
SIMPLEREGION	EQU	2
COMPLEXREGION	EQU	3

RDH_RECTANGLES	EQU	1

RGNDATAHEADER	struct 
dwSize		DWORD	?
iType		DWORD	?
nCount		DWORD	?
nRgnSize	DWORD	?
rcBound		RECT	<>
RGNDATAHEADER	ends

RGNDATA	struct 
rdh		RGNDATAHEADER	<>
Buffer	SBYTE 1 dup (?)
RGNDATA	ends

RGN_ERROR	EQU	<ERROR>
RGN_AND		EQU	1
RGN_OR		EQU	2
RGN_XOR		EQU	3
RGN_DIFF	EQU	4
RGN_COPY	EQU	5

PATCOPY	EQU	00F00021h

CBM_INIT	equ 4

COLORREF typedef DWORD	;colorref is 0x00BBGGRR

CLR_INVALID	EQU	0FFFFFFFFh

BS_SOLID		EQU	0
BS_NULL			EQU	1
BS_HOLLOW		EQU	<BS_NULL>
BS_HATCHED		EQU	2
BS_PATTERN		EQU	3
BS_INDEXED		EQU	4
BS_DIBPATTERN	EQU	5
BS_DIBPATTERNPT	EQU	6
BS_PATTERN8X8	EQU	7
BS_DIBPATTERN8X8	EQU	8
BS_MONOPATTERN	EQU	9

PS_SOLID		EQU	0
PS_DASH			EQU	1
PS_DOT			EQU	2
PS_DASHDOT		EQU	3
PS_DASHDOTDOT	EQU	4
PS_NULL			EQU	5
PS_INSIDEFRAME	EQU	6
PS_USERSTYLE	EQU	7
PS_ALTERNATE	EQU	8

R2_BLACK		EQU	1
R2_NOTMERGEPEN	EQU	2
R2_MASKNOTPEN	EQU	3
R2_NOTCOPYPEN	EQU	4
R2_MASKPENNOT	EQU	5
R2_NOT			EQU	6
R2_XORPEN		EQU	7
R2_NOTMASKPEN	EQU	8
R2_MASKPEN		EQU	9
R2_NOTXORPEN	EQU	10
R2_NOP			EQU	11
R2_MERGENOTPEN	EQU	12
R2_COPYPEN		EQU	13
R2_MERGEPENNOT	EQU	14
R2_MERGEPEN		EQU	15
R2_WHITE		EQU	16
R2_LAST			EQU	16

;--- palette definitions

SYSPAL_ERROR		EQU	0
SYSPAL_STATIC		EQU	1
SYSPAL_NOSTATIC		EQU	2
SYSPAL_NOSTATIC256	EQU	3

RGB macro r,g,b
	exitm <( r or ( g shl 8 ) or ( b shl 16 ) )>
	endm
PALETTERGB macro r,g,b
	exitm <(02000000h or RGB(r , g , b ))>
	endm
PALETTEINDEX macro i
	exitm <(01000000h or (i))>
	endm

PC_RESERVED		EQU	01h		;palette entry is reserved for animation
PC_EXPLICIT		EQU	02h		;is a palette index
PC_NOCOLLAPSE	EQU	04h		;dont try to match this entry

PALETTEENTRY	struct 
peRed	BYTE	?
peGreen	BYTE	?
peBlue	BYTE	?
peFlags	BYTE	?
PALETTEENTRY	ends

LOGPALETTE	struct 
palVersion		WORD	?
palNumEntries	WORD	?
palPalEntry		PALETTEENTRY 1 dup (<>)
LOGPALETTE	ends

RGBQUAD	struct 
rgbBlue		BYTE	?
rgbGreen	BYTE	?
rgbRed		BYTE	?
rgbReserved	BYTE	?
RGBQUAD	ends

;--- bitmaps

BITMAPFILEHEADER	struct 
bfType		WORD	?
bfSize		DWORD	?
bfReserved1	WORD	?
bfReserved2	WORD	?
bfOffBits	DWORD	?
BITMAPFILEHEADER	ends

BI_RGB			EQU	0
BI_RLE8			EQU	1
BI_RLE4			EQU	2
BI_BITFIELDS	EQU	3
BI_JPEG			EQU 4
BI_PNG			EQU 5

DIB_RGB_COLORS	EQU	0
DIB_PAL_COLORS	EQU	1

BITMAP	struct 
bmType			SDWORD	?
bmWidth			SDWORD	?
bmHeight		SDWORD	?
bmWidthBytes	SDWORD	?
bmPlanes		WORD	?
bmBitsPixel		WORD	?
bmBits			LPVOID	?
BITMAP	ends

BITMAPINFOHEADER	struct 
biSize			DWORD	?
biWidth			SDWORD	?
biHeight		SDWORD	?
biPlanes		WORD	?
biBitCount		WORD	?
biCompression	DWORD	?
biSizeImage		DWORD	?
biXPelsPerMeter	SDWORD	?
biYPelsPerMeter	SDWORD	?
biClrUsed		DWORD	?
biClrImportant	DWORD	?
BITMAPINFOHEADER	ends

BITMAPINFO	struct 
bmiHeader	BITMAPINFOHEADER <>
bmiColors	RGBQUAD 1 dup (<>)
BITMAPINFO	ends

DIBSECTION	struct 
dsBm		BITMAP	<>
dsBmih		BITMAPINFOHEADER	<>
dsBitfields	DWORD 3 dup (?)
dshSection	HANDLE	?
dsOffset	DWORD	?
DIBSECTION	ends

FXPT2DOT30 typedef SDWORD

CIEXYZ	struct 
ciexyzX	FXPT2DOT30	?
ciexyzY	FXPT2DOT30	?
ciexyzZ	FXPT2DOT30	?
CIEXYZ	ends

CIEXYZTRIPLE	struct 
ciexyzRed	CIEXYZ	<>
ciexyzGreen	CIEXYZ	<>
ciexyzBlue	CIEXYZ	<>
CIEXYZTRIPLE	ends


BITMAPV4HEADER	struct 
bV4Size				DWORD	?
bV4Width			SDWORD	?
bV4Height			SDWORD	?
bV4Planes			WORD	?
bV4BitCount			WORD	?
bV4Compression		DWORD	?
bV4SizeImage		DWORD	?
bV4XPelsPerMeter	SDWORD	?
bV4YPelsPerMeter	SDWORD	?
bV4ClrUsed			DWORD	?
bV4ClrImportant		DWORD	?
bV4RedMask			DWORD	?
bV4GreenMask		DWORD	?
bV4BlueMask			DWORD	?
bV4AlphaMask		DWORD	?
bV4CSType			DWORD	?
bV4Endpoints		CIEXYZTRIPLE	<>
bV4GammaRed			DWORD	?
bV4GammaGreen		DWORD	?
bV4GammaBlue		DWORD	?
BITMAPV4HEADER	ends

SRCCOPY	EQU	00CC0020h

;--- brush

LOGBRUSH	struct 
lbStyle	DWORD	?
lbColor	COLORREF	?
lbHatch	SDWORD	?
LOGBRUSH	ends

;--- fonts

LF_FACESIZE	EQU	32

LOGFONTA	struct 
lfHeight		SDWORD	?
lfWidth			SDWORD	?
lfEscapement	SDWORD	?
lfOrientation	SDWORD	?
lfWeight		SDWORD	?
lfItalic		BYTE	?
lfUnderline		BYTE	?
lfStrikeOut		BYTE	?
lfCharSet		BYTE	?
lfOutPrecision	BYTE	?
lfClipPrecision	BYTE	?
lfQuality		BYTE	?
lfPitchAndFamily	BYTE	?
lfFaceName		SBYTE LF_FACESIZE dup (?)
LOGFONTA	ends

LOGFONTW	struct 
lfHeight		SDWORD	?
lfWidth			SDWORD	?
lfEscapement	SDWORD	?
lfOrientation	SDWORD	?
lfWeight		SDWORD	?
lfItalic		BYTE	?
lfUnderline		BYTE	?
lfStrikeOut		BYTE	?
lfCharSet		BYTE	?
lfOutPrecision	BYTE	?
lfClipPrecision	BYTE	?
lfQuality		BYTE	?
lfPitchAndFamily	BYTE	?
lfFaceName		SWORD LF_FACESIZE dup (?)
LOGFONTW	ends

LF_FULLFACESIZE	EQU	64

ENUMLOGFONTA	struct 
elfLogFont	LOGFONTA	<>
elfFullName	BYTE LF_FULLFACESIZE dup (?)
elfStyle	BYTE LF_FACESIZE dup (?)
ENUMLOGFONTA	ends

LPENUMLOGFONTA typedef ptr ENUMLOGFONTA

ENUMLOGFONTEXA	struct 
elfLogFont	LOGFONTA	<>
elfFullName	BYTE LF_FULLFACESIZE dup (?)
elfStyle	BYTE LF_FACESIZE dup (?)
elfScript	BYTE LF_FACESIZE dup (?)
ENUMLOGFONTEXA	ends

RASTER_FONTTYPE		EQU	0001h
DEVICE_FONTTYPE		EQU	0002h
TRUETYPE_FONTTYPE	EQU	0004h

ANSI_CHARSET	EQU	0
DEFAULT_CHARSET	EQU	1
OEM_CHARSET		EQU	255

DEFAULT_PITCH	EQU	0
FIXED_PITCH		EQU	1
VARIABLE_PITCH	EQU	2

CCHDEVICENAME	EQU	32
CCHFORMNAME		EQU	32

DEFAULT_QUALITY	EQU	0
DRAFT_QUALITY	EQU	1
PROOF_QUALITY	EQU	2

ifndef POINTL
POINTL struct
x	SDWORD ?
y	SDWORD ?
POINTL ends
endif

FONTSIGNATURE	struct 
fsUsb	DWORD 4 dup (?)
fsCsb	DWORD 2 dup (?)
FONTSIGNATURE	ends

;---

DM_BITSPERPEL	EQU	00040000h
DM_PELSWIDTH	EQU	00080000h
DM_PELSHEIGHT	EQU	00100000h
DM_DISPLAYFLAGS	EQU	00200000h
DM_DISPLAYFREQUENCY	EQU	00400000h

DEVMODEA	struct 
dmDeviceName	BYTE CCHDEVICENAME dup (?)
dmSpecVersion	WORD	?
dmDriverVersion	WORD	?
dmSize			WORD	?
dmDriverExtra	WORD	?
dmFields		DWORD	?
union
struct
dmOrientation	SWORD	?
dmPaperSize		SWORD	?
dmPaperLength	SWORD	?
dmPaperWidth	SWORD	?
ends
dmPosition		POINTL	<>
ends
dmScale			SWORD	?
dmCopies		SWORD	?
dmDefaultSource	SWORD	?
dmPrintQuality	SWORD	?
dmColor			SWORD	?
dmDuplex		SWORD	?
dmYResolution	SWORD	?
dmTTOption		SWORD	?
dmCollate		SWORD	?
dmFormName		BYTE CCHFORMNAME dup (?)
dmLogPixels		WORD	?
dmBitsPerPel	DWORD	?
dmPelsWidth		DWORD	?
dmPelsHeight	DWORD	?
dmDisplayFlags	DWORD	?
dmDisplayFrequency	DWORD	?
dmICMMethod		DWORD	?
dmICMIntent		DWORD	?
dmMediaType		DWORD	?
dmDitherType	DWORD	?
dmReserved1		DWORD	?
dmReserved2		DWORD	?
if 0;(WINVER ge 0500h) OR (_WIN32_WINNT ge 0400h)
dmPanningWidth	DWORD	?
dmPanningHeight	DWORD	?
endif 
DEVMODEA	ends

;--- GetDeviceCaps parameters

DRIVERVERSION	EQU	0
TECHNOLOGY		EQU	2
HORZRES			EQU	8
VERTRES			EQU	10
BITSPIXEL		EQU	12
PLANES			EQU	14
NUMCOLORS		EQU	24		;colors in default palette
TEXTCAPS		EQU	34
RASTERCAPS		EQU	38
LOGPIXELSX		EQU	88
LOGPIXELSY		EQU	90
SIZEPALETTE		EQU	104		;???
NUMRESERVED		EQU	106		;???
COLORRES		EQU	108		;color resolution (fix 24)

;--- TECHNOLOGY return values

DT_PLOTTER		EQU	0
DT_RASDISPLAY	EQU	1
DT_RASPRINTER	EQU	2
DT_RASCAMERA	EQU	3
DT_CHARSTREAM	EQU	4
DT_METAFILE		EQU	5
DT_DISPFILE		EQU	6

;--- GetCurrentObject types

OBJ_PEN			EQU	1
OBJ_BRUSH		EQU	2
OBJ_DC			EQU	3
OBJ_METADC		EQU	4
OBJ_PAL			EQU	5
OBJ_FONT		EQU	6
OBJ_BITMAP		EQU	7
OBJ_REGION		EQU	8
OBJ_METAFILE	EQU	9
OBJ_MEMDC		EQU	10
OBJ_EXTPEN		EQU	11
OBJ_ENHMETADC	EQU	12
OBJ_ENHMETAFILE	EQU	13


RC_NONE			EQU	<>
RC_BITBLT		EQU	0001h
RC_BANDING		EQU	0002h
RC_SCALING		EQU	0004h
RC_BITMAP64		EQU	0008h
RC_GDI20_OUTPUT	EQU	0010h
RC_GDI20_STATE	EQU	0020h
RC_SAVEBITMAP	EQU	0040h
RC_DI_BITMAP	EQU	0080h
RC_PALETTE		EQU	0100h
RC_DIBTODEV		EQU	0200h
RC_BIGFONT		EQU	0400h
RC_STRETCHBLT	EQU	0800h
RC_FLOODFILL	EQU	1000h
RC_STRETCHDIB	EQU	2000h
RC_OP_DX_OUTPUT	EQU	4000h
RC_DEVBITS		EQU	8000h

DISPLAY_DEVICEA struct
cb            DWORD ?
DeviceName    BYTE  32 dup (?)
DeviceString  BYTE  128 dup (?)
StateFlags    DWORD ?
DeviceID      BYTE  128 dup (?)
DeviceKey     BYTE  128 dup (?)
DISPLAY_DEVICEA ends

DISPLAY_DEVICE_ATTACHED_TO_DESKTOP equ 01h
DISPLAY_DEVICE_PRIMARY_DEVICE      equ 04h
DISPLAY_DEVICE_VGA_COMPATIBLE      equ 10h

TEXTMETRICA	struct DWORD
tmHeight			SDWORD	?
tmAscent			SDWORD	?
tmDescent			SDWORD	?
tmInternalLeading	SDWORD	?
tmExternalLeading	SDWORD	?
tmAveCharWidth		SDWORD	?
tmMaxCharWidth		SDWORD	?
tmWeight			SDWORD	?
tmOverhang			SDWORD	?
tmDigitizedAspectX	SDWORD	?
tmDigitizedAspectY	SDWORD	?
tmFirstChar			BYTE	?
tmLastChar			BYTE	?
tmDefaultChar		BYTE	?
tmBreakChar			BYTE	?
tmItalic			BYTE	?
tmUnderlined		BYTE	?
tmStruckOut			BYTE	?
tmPitchAndFamily	BYTE	?
tmCharSet			BYTE	?
TEXTMETRICA	ends

PANOSE	struct 
bFamilyType	BYTE	?
bSerifStyle	BYTE	?
bWeight		BYTE	?
bProportion	BYTE	?
bContrast	BYTE	?
bStrokeVariation	BYTE	?
bArmStyle	BYTE	?
bLetterform	BYTE	?
bMidline	BYTE	?
bXHeight	BYTE	?
PANOSE	ends

ifndef POINT
POINT struct
x       DWORD ?
y       DWORD ?
POINT ends
endif

ifndef LPSTR
LPSTR typedef ptr BYTE
endif

OUTLINETEXTMETRICA	struct 
otmSize				DWORD	?
otmTextMetrics		TEXTMETRICA	<>
otmFiller			BYTE	?
otmPanoseNumber		PANOSE	<>
otmfsSelection		DWORD	?
otmfsType			DWORD	?
otmsCharSlopeRise	DWORD	?
otmsCharSlopeRun	DWORD	?
otmItalicAngle		DWORD	?
otmEMSquare			DWORD	?
otmAscent			DWORD	?
otmDescent			DWORD	?
otmLineGap			DWORD	?
otmsCapEmHeight		DWORD	?
otmsXHeight			DWORD	?
otmrcFontBox		RECT	<>
otmMacAscent		DWORD	?
otmMacDescent		DWORD	?
otmMacLineGap		DWORD	?
otmusMinimumPPEM	DWORD	?
otmptSubscriptSize		POINT	<>
otmptSubscriptOffset	POINT	<>
otmptSuperscriptSize	POINT	<>
otmptSuperscriptOffset	POINT	<>
otmsStrikeoutSize		DWORD	?
otmsStrikeoutPosition	DWORD	?
otmsUnderscoreSize		DWORD	?
otmsUnderscorePosition	DWORD	?
otmpFamilyName			DWORD	?
otmpFaceName			DWORD	?
otmpStyleName			DWORD	?
otmpFullName			DWORD	?
OUTLINETEXTMETRICA	ends

PIXELFORMATDESCRIPTOR	struct 
nSize			WORD	?
nVersion		WORD	?
dwFlags			DWORD	?
iPixelType		BYTE	?
cColorBits		BYTE	?
cRedBits		BYTE	?
cRedShift		BYTE	?
cGreenBits		BYTE	?
cGreenShift		BYTE	?
cBlueBits		BYTE	?
cBlueShift		BYTE	?
cAlphaBits		BYTE	?
cAlphaShift		BYTE	?
cAccumBits		BYTE	?
cAccumRedBits	BYTE	?
cAccumGreenBits	BYTE	?
cAccumBlueBits	BYTE	?
cAccumAlphaBits	BYTE	?
cDepthBits		BYTE	?
cStencilBits	BYTE	?
cAuxBuffers		BYTE	?
iLayerType		BYTE	?
bReserved		BYTE	?
dwLayerMask		DWORD	?
dwVisibleMask	DWORD	?
dwDamageMask	DWORD	?
PIXELFORMATDESCRIPTOR	ends

PFD_TYPE_RGBA		EQU	0
PFD_TYPE_COLORINDEX	EQU	1
PFD_MAIN_PLANE		EQU	0
PFD_OVERLAY_PLANE	EQU	1
PFD_UNDERLAY_PLANE	EQU	-1
PFD_DOUBLEBUFFER	EQU	00000001h
PFD_STEREO			EQU	00000002h
PFD_DRAW_TO_WINDOW	EQU	00000004h
PFD_DRAW_TO_BITMAP	EQU	00000008h
PFD_SUPPORT_GDI		EQU	00000010h
PFD_SUPPORT_OPENGL	EQU	00000020h
PFD_GENERIC_FORMAT	EQU	00000040h
PFD_NEED_PALETTE	EQU	00000080h
PFD_NEED_SYSTEM_PALETTE		EQU	00000100h
PFD_SWAP_EXCHANGE			EQU	00000200h
PFD_SWAP_COPY				EQU	00000400h
PFD_SWAP_LAYER_BUFFERS		EQU	00000800h
PFD_GENERIC_ACCELERATED		EQU	00001000h
PFD_SUPPORT_DIRECTDRAW		EQU	00002000h
PFD_DEPTH_DONTCARE			EQU	20000000h
PFD_DOUBLEBUFFER_DONTCARE	EQU	40000000h
PFD_STEREO_DONTCARE			EQU	80000000h

;--- escape codes

QUERYESCSUPPORT             equ 8


ifdef _GDI32_
?INDCALL_ = 0
elseif ?INDCALL eq 0
?INDCALL_ = 0
else
?INDCALL_ = 1
endif

if ?INDCALL_ eq 0

;_TEXT segment

BitBlt                 proto near stdcall :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword
CreateCompatibleBitmap proto near stdcall :dword, :dword, :dword
CreateCompatibleDC     proto near stdcall :dword
CreateDCA              proto near stdcall :ptr BYTE, :ptr BYTE, :ptr BYTE, :ptr
CreateDIBitmap         proto near stdcall :dword, :ptr BITMAPINFOHEADER, :dword, :ptr, :ptr BITMAPINFO, :sdword
CreateFontIndirectA    proto near stdcall :ptr LOGFONTA
CreatePalette          proto near stdcall :ptr LOGPALETTE
CreatePen              proto near stdcall :dword, :dword, :dword
CreateSolidBrush       proto near stdcall :COLORREF
DeleteDC               proto near stdcall :dword
DeleteObject           proto near stdcall :dword
ExtTextOutA            proto near stdcall :dword, :dword, :dword, :dword, :ptr RECT, :ptr BYTE, :dword, :ptr dword
GetDCBrushColor        proto near stdcall :dword
GetDeviceCaps          proto near stdcall :dword, :dword
GetDIBits              proto near stdcall :dword, :dword, :dword, :dword, :ptr BYTE, :ptr BITMAPINFO, :dword
GetNearestColor        proto near stdcall :dword, :COLORREF
GetNearestPaletteIndex proto near stdcall :dword, :COLORREF
GetPaletteEntries      proto near stdcall :dword, :dword, :dword, :ptr PALETTEENTRY
GetRegionData          proto near stdcall :HRGN, :dword, :ptr RGNDATA
GetStockObject         proto near stdcall :dword
GetTextExtentPoint32A  proto near stdcall :dword, :ptr BYTE, :dword, :ptr SIZE_
GetTextFaceA           proto near stdcall :DWORD, :DWORD, :ptr BYTE
GetTextMetricsA        proto near stdcall :dword, :ptr TEXTMETRICA
LineTo                 proto near stdcall :dword, :dword, :dword 
MaskBlt                proto near stdcall :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword
MoveToEx               proto near stdcall :dword, :dword, :dword, :ptr POINT
PatBlt                 proto near stdcall :dword, :dword, :dword, :dword, :dword, :dword
RealizePalette         proto near stdcall :dword
SelectObject           proto near stdcall :dword, :dword
SelectPalette          proto near stdcall :dword, :dword, :dword
SetBkColor             proto near stdcall :dword, :COLORREF
SetBkMode              proto near stdcall :dword, :dword
SetDIBits              proto near stdcall :dword, :dword, :dword, :dword, :ptr, :ptr BITMAPINFO, :dword
SetPaletteEntries      proto near stdcall :dword, :dword, :dword, :ptr PALETTEENTRY
SetPixel               proto near stdcall :dword, :dword, :dword, :COLORREF
SetRectRgn             proto near stdcall :HRGN, :sdword, :sdword, :sdword, :sdword
SetSystemPaletteUse    proto near stdcall :dword, :dword
SetTextColor           proto near stdcall :dword, :COLORREF
SetViewportOrgEx       proto near stdcall :dword, :dword, :dword, :ptr POINT
SetWindowOrgEx         proto near stdcall :dword, :dword, :dword, :ptr POINT
TextOutA               proto near stdcall :dword, :dword, :dword, :ptr BYTE, :dword

;_TEXT ends

else

_DATA segment

externdef stdcall _imp__AddFontResourceA@4:pfunc@4
externdef stdcall _imp__AnimatePalette@16:pfunc@16
externdef stdcall _imp__BitBlt@36:pfunc@36
externdef stdcall _imp__CreateCompatibleBitmap@12:pfunc@12
externdef stdcall _imp__CreateCompatibleDC@4:pfunc@4
externdef stdcall _imp__CreateDIBitmap@24:pfunc@24
externdef stdcall _imp__CreateDCA@16:pfunc@16
externdef stdcall _imp__CreatePalette@4:pfunc@4
externdef stdcall _imp__CreateSolidBrush@4:pfunc@4
externdef stdcall _imp__DeleteDC@4:pfunc@4
externdef stdcall _imp__DeleteObject@4:pfunc@4
externdef stdcall _imp__ExtTextOutA@32:pfunc@32
externdef stdcall _imp__GetCurrentObject@8:pfunc@8
externdef stdcall _imp__GetDeviceCaps@8:pfunc@8
externdef stdcall _imp__GetDIBits@28:pfunc@28
externdef stdcall _imp__GetPaletteEntries@16:pfunc@16
externdef stdcall _imp__GetRegionData@12:pfunc@12
externdef stdcall _imp__GetStockObject@4:pfunc@4
externdef stdcall _imp__GetSystemPaletteEntries@16:pfunc@16
externdef stdcall _imp__GetTextExtentPoint32A@16:pfunc@16
externdef stdcall _imp__GetTextMetricsA@8:pfunc@8
externdef stdcall _imp__PatBlt@24:pfunc@24
externdef stdcall _imp__RealizePalette@4:pfunc@4
externdef stdcall _imp__SelectObject@8:pfunc@8
externdef stdcall _imp__SelectPalette@12:pfunc@12
externdef stdcall _imp__SetBkColor@8:pfunc@8
externdef stdcall _imp__SetBkMode@8:pfunc@8
externdef stdcall _imp__SetPaletteEntries@16:pfunc@16
externdef stdcall _imp__SetRectRgn@20:pfunc@20
externdef stdcall _imp__SetSystemPaletteUse@8:pfunc@8
externdef stdcall _imp__SetViewportOrgEx@16:pfunc@16
externdef stdcall _imp__SetWindowOrgEx@16:pfunc@16
externdef stdcall _imp__TextOutA@20:pfunc@20

_DATA ends

AddFontResourceA        equ <_imp__AddFontResourceA@4>
AnimatePalette          equ <_imp__AnimatePalette@16>
BitBlt                  equ <_imp__BitBlt@36>
CreateCompatibleBitmap  equ <_imp__CreateCompatibleBitmap@12>
CreateCompatibleDC      equ <_imp__CreateCompatibleDC@4>
CreateDCA               equ <_imp__CreateDCA@16>
CreateDIBitmap          equ <_imp__CreateDIBitmap@24>
CreatePalette           equ <_imp__CreatePalette@4>
CreateSolidBrush        equ <_imp__CreateSolidBrush@4>
DeleteDC                equ <_imp__DeleteDC@4>
DeleteObject            equ <_imp__DeleteObject@4>
ExtTextOutA             equ <_imp__ExtTextOutA@32>
GetCurrentObject        equ <_imp__GetCurrentObject@8>
GetDeviceCaps           equ <_imp__GetDeviceCaps@8>
GetDIBits               equ <_imp__GetDIBits@28>
GetPaletteEntries       equ <_imp__GetPaletteEntries@16>
GetRegionData           equ <_imp__GetRegionData@12>
GetStockObject          equ <_imp__GetStockObject@4>
GetSystemPaletteEntries equ <_imp__GetSystemPaletteEntries@16>
GetTextExtentPoint32A   equ <_imp__GetTextExtentPoint32A@16>
GetTextMetricsA         equ <_imp__GetTextMetricsA@8>
PatBlt                  equ <_imp__PatBlt@24>
RealizePalette          equ <_imp__RealizePalette@4>
SelectObject            equ <_imp__SelectObject@8>
SelectPalette           equ <_imp__SelectPalette@12>
SetBkColor              equ <_imp__SetBkColor@8>
SetBkMode               equ <_imp__SetBkMode@8>
SetPaletteEntries       equ <_imp__SetPaletteEntries@16>
SetRectRgn              equ <_imp__SetRectRgn@20>
SetSystemPaletteUse     equ <_imp__SetSystemPaletteUse@8>
SetViewportOrgEx        equ <_imp__SetViewportOrgEx@16>
SetWindowOrgEx          equ <_imp__SetWindowOrgEx@16>
TextOutA                equ <_imp__TextOutA@20>

endif

