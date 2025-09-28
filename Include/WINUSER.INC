
HWND       typedef HANDLE
HMENU      typedef HANDLE
LPSTR      typedef ptr BYTE

RT_CURSOR                            equ 1
RT_BITMAP                            equ 2
RT_ICON                              equ 3
RT_MENU                              equ 4
RT_DIALOG                            equ 5
RT_STRING                            equ 6
RT_FONTDIR                           equ 7
RT_FONT                              equ 8
RT_ACCELERATOR                       equ 9
RT_RCDATA                            equ 10
RT_MESSAGETABLE                      equ 11

DIFFERENCE equ 11

RT_GROUP_CURSOR	equ RT_CURSOR + DIFFERENCE
RT_GROUP_ICON	equ RT_ICON + DIFFERENCE

RT_VERSION		EQU 16
RT_DLGINCLUDE	EQU 17
RT_PLUGPLAY		EQU 19
RT_VXD			EQU 20
RT_ANICURSOR	EQU 21
RT_ANIICON		EQU 22
RT_HTML			EQU 23

;--- menu constants

MF_BYCOMMAND	EQU	00000000h
MF_BYPOSITION	EQU	00000400h
MF_SEPARATOR	EQU	00000800h
MF_ENABLED		EQU	00000000h
MF_GRAYED		EQU	00000001h
MF_DISABLED		EQU	00000002h
MF_UNCHECKED	EQU	00000000h
MF_CHECKED		EQU	00000008h
MF_USECHECKBITMAPS	EQU	00000200h
MF_STRING		EQU	00000000h
MF_BITMAP		EQU	00000004h
MF_OWNERDRAW	EQU	00000100h
MF_POPUP		EQU	00000010h

GCL_HBRBACKGROUND	EQU	-10
GCL_HCURSOR			EQU	-12
GCL_HMODULE			EQU	-16
GCL_CBWNDEXTRA		EQU	-18
GCL_CBCLSEXTRA		EQU	-20
GCL_WNDPROC			EQU	-24
GCL_STYLE			EQU	-26

GWL_WNDPROC		EQU -4
GWL_HINSTANCE   EQU -6
GWL_HWNDPARENT	EQU	-8
GWL_STYLE		EQU	-16
GWL_USERDATA	EQU	-21

ENUM_CURRENT_SETTINGS EQU -1
ENUM_REGISTRY_SETTINGS EQU -2

POINT struct
x       DWORD ?
y       DWORD ?
POINT ends

HTERROR			EQU	- 2
HTTRANSPARENT	EQU	- 1
HTNOWHERE		EQU	0
HTCLIENT		EQU	1
HTCAPTION		EQU	2
HTSYSMENU		EQU	3
HTGROWBOX		EQU	4
HTSIZE			EQU	<HTGROWBOX>
HTMENU			EQU	5
HTHSCROLL		EQU	6
HTVSCROLL		EQU	7
HTMINBUTTON		EQU	8
HTMAXBUTTON		EQU	9
HTLEFT			EQU	10
HTRIGHT			EQU	11
HTTOP			EQU	12
HTTOPLEFT		EQU	13
HTTOPRIGHT		EQU	14
HTBOTTOM		EQU	15
HTBOTTOMLEFT	EQU	16
HTBOTTOMRIGHT	EQU	17
HTBORDER		EQU	18
HTREDUCE		EQU	<HTMINBUTTON>
HTZOOM			EQU	<HTMAXBUTTON>
HTSIZEFIRST		EQU	<HTLEFT>
HTSIZELAST		EQU	<HTBOTTOMRIGHT>
HTOBJECT		EQU	19
HTCLOSE			EQU	20
HTHELP			EQU	21

RECT	struct
left	SDWORD	?
top		SDWORD	?
right	SDWORD	?
bottom	SDWORD	?
RECT	ends

LPRECT	typedef ptr RECT

PAINTSTRUCT	struct 
hdc			HDC		?
fErase		DWORD	?
rcPaint		RECT	<>
fRestore	DWORD	?
fIncUpdate	DWORD	?
rgbReserved	BYTE 32 dup (?)
PAINTSTRUCT	ends

;--- LoadImageA constants

IMAGE_BITMAP		EQU	0
IMAGE_ICON			EQU	1
IMAGE_CURSOR		EQU	2
IMAGE_ENHMETAFILE	EQU	3

LR_DEFAULTCOLOR		EQU	0000h
LR_MONOCHROME		EQU	0001h
LR_COLOR			EQU	0002h
LR_COPYRETURNORG	EQU	0004h
LR_COPYDELETEORG	EQU	0008h
LR_LOADFROMFILE		EQU	0010h
LR_LOADTRANSPARENT	EQU	0020h
LR_DEFAULTSIZE		EQU	0040h
LR_VGACOLOR			EQU	0080h
LR_LOADMAP3DCOLORS	EQU	1000h
LR_CREATEDIBSECTION	EQU	2000h
LR_COPYFROMRESOURCE	EQU	4000h
LR_SHARED			EQU	8000h

SM_CXSCREEN		EQU	0
SM_CYSCREEN		EQU	1
SM_CXVSCROLL	EQU	2
SM_CYHSCROLL	EQU	3
SM_CYCAPTION	EQU	4
SM_CXBORDER		EQU	5
SM_CYBORDER		EQU	6
SM_CXDLGFRAME	EQU	7
SM_CYDLGFRAME	EQU	8
SM_CYVTHUMB		EQU	9
SM_CXHTHUMB		EQU	10
SM_CXICON		EQU	11
SM_CYICON		EQU	12
SM_CXCURSOR		EQU	13
SM_CYCURSOR		EQU	14
SM_CYMENU		EQU	15
SM_CXFULLSCREEN	EQU	16
SM_CYFULLSCREEN	EQU	17
SM_CYKANJIWINDOW	EQU	18
SM_MOUSEPRESENT	EQU	19
SM_CYVSCROLL	EQU	20
SM_CXHSCROLL	EQU	21
SM_DEBUG		EQU	22
SM_SWAPBUTTON	EQU	23
SM_CXMIN		EQU	28
SM_CYMIN		EQU	29
SM_CXSIZE		EQU	30
SM_CYSIZE		EQU	31
SM_CXFRAME		EQU	32
SM_CYFRAME		EQU	33
SM_CXMINTRACK	EQU	34
SM_CYMINTRACK	EQU	35
SM_CXDOUBLECLK	EQU	36
SM_CYDOUBLECLK	EQU	37
SM_CXICONSPACING		EQU	38
SM_CYICONSPACING		EQU	39
SM_MENUDROPALIGNMENT	EQU	40
SM_PENWINDOWS			EQU	41
SM_DBCSENABLED			EQU	42
SM_CMOUSEBUTTONS		EQU	43
SM_CXMAXIMIZED	EQU	61
SM_CYMAXIMIZED	EQU	62

SIZE_RESTORED	EQU	0
SIZE_MINIMIZED	EQU	1
SIZE_MAXIMIZED	EQU	2
SIZE_MAXSHOW	EQU	3
SIZE_MAXHIDE	EQU	4

SWP_NOSIZE			EQU	0001h
SWP_NOMOVE			EQU	0002h
SWP_NOZORDER		EQU	0004h
SWP_NOREDRAW		EQU	0008h
SWP_NOACTIVATE		EQU	0010h
SWP_FRAMECHANGED	EQU	0020h
SWP_SHOWWINDOW		EQU	0040h
SWP_HIDEWINDOW		EQU	0080h
SWP_NOCOPYBITS		EQU	0100h
SWP_NOOWNERZORDER	EQU	0200h
SWP_NOSENDCHANGING	EQU	0400h
SWP_DRAWFRAME		EQU	<SWP_FRAMECHANGED>
SWP_NOREPOSITION	EQU	<SWP_NOOWNERZORDER>

HWND_TOP		EQU	0
HWND_BOTTOM		EQU	1
HWND_TOPMOST	EQU	-1
HWND_NOTOPMOST	EQU	-2


HWND_BROADCAST	EQU	0ffffh

DISP_CHANGE_SUCCESSFUL	EQU	0
DISP_CHANGE_FAILED		EQU	-1
DISP_CHANGE_BADMODE		EQU	-2

QS_KEY			EQU	0001h
QS_MOUSEMOVE	EQU	0002h
QS_MOUSEBUTTON	EQU	0004h
QS_POSTMESSAGE	EQU	0008h
QS_TIMER		EQU	0010h
QS_PAINT		EQU	0020h
QS_SENDMESSAGE	EQU	0040h
QS_HOTKEY		EQU	0080h
QS_ALLPOSTMESSAGE	EQU	0100h
QS_MOUSE		EQU	( QS_MOUSEMOVE  or  QS_MOUSEBUTTON )
QS_INPUT		EQU	( QS_MOUSE  or  QS_KEY )
QS_ALLEVENTS	EQU	( QS_INPUT  or  QS_POSTMESSAGE  or  QS_TIMER  or  QS_PAINT  or  QS_HOTKEY )
QS_ALLINPUT		EQU	( QS_INPUT  or  QS_POSTMESSAGE  or  QS_TIMER  or  QS_PAINT  or  QS_HOTKEY  or  QS_SENDMESSAGE )

MB_OK				EQU 00000000h
MB_OKCANCEL			EQU	00000001h
MB_ABORTRETRYIGNORE	EQU	00000002h
MB_YESNOCANCEL		EQU	00000003h
MB_YESNO			EQU	00000004h
MB_RETRYCANCEL		EQU	00000005h

HELPINFO	struct 
cbSize		DWORD	?
iContextType	DWORD	?
iCtrlId		DWORD	?
hItemHandle	HANDLE	?
dwContextId	DWORD	?
MousePos	POINT	<>
HELPINFO	ends

LPHELPINFO typedef ptr HELPINFO

proto_MSGBOXCALLBACK typedef proto stdcall :LPHELPINFO
MSGBOXCALLBACK typedef ptr proto_MSGBOXCALLBACK

MSGBOXPARAMSA	struct 
cbSize		DWORD	?
hwndOwner	HWND	?
hInstance	HINSTANCE	?
lpszText	LPSTR	?
lpszCaption	LPSTR	?
dwStyle		DWORD	?
lpszIcon	LPSTR	?
dwContextHelpId		DWORD	?
lpfnMsgBoxCallback	MSGBOXCALLBACK	?
dwLanguageId	DWORD	?
MSGBOXPARAMSA	ends

IDOK		EQU	1
IDCANCEL	EQU	2
IDABORT		EQU	3
IDRETRY		EQU	4
IDIGNORE	EQU	5
IDYES		EQU	6
IDNO		EQU	7
IDCLOSE		EQU	8
IDHELP		EQU	9

SW_HIDE            = 0
SW_SHOWNORMAL      = 1
SW_NORMAL          = 1
SW_SHOWMINIMIZED   = 2
SW_SHOWMAXIMIZED   = 3
SW_MAXIMIZE        = 3
SW_SHOWNOACTIVATE  = 4
SW_SHOW            = 5
SW_MINIMIZE        = 6
SW_SHOWMINNOACTIVE = 7
SW_SHOWNA          = 8
SW_RESTORE         = 9

;*** Messages ***

WM_NULL          equ 0000h
WM_CREATE        equ 0001h
WM_DESTROY       equ 0002h
WM_MOVE          EQU 0003h
WM_SIZE          EQU 0005h
WM_ACTIVATE      EQU 0006h
WM_SETFOCUS      equ 0007h
WM_KILLFOCUS     equ 0008h
WM_ENABLE        equ 000Ah
WM_SETTEXT       equ 000Ch
WM_GETTEXT       equ 000Dh
WM_GETTEXTLENGTH equ 000Eh
WM_PAINT         equ 000Fh
WM_CLOSE         equ 0010h
WM_QUIT          equ 0012h
WM_ERASEBKGND    equ 0014h
WM_SHOWWINDOW    EQU 0018h
WM_ACTIVATEAPP   EQU 001Ch
WM_CANCELMODE    EQU 001Fh
WM_SETCURSOR     equ 0020h
WM_WINDOWPOSCHANGED	EQU	0047h
WM_DISPLAYCHANGE EQU 007Eh
WM_NCPAINT       equ 0085h

WM_KEYDOWN       equ 0100h
WM_KEYUP         equ 0101h
WM_CHAR          EQU 0102h
WM_SYSKEYDOWN    equ 0104h
WM_SYSKEYUP      equ 0105h
WM_INITDIALOG    equ 0110h
WM_COMMAND       equ 0111h
WM_SYSCOMMAND    equ 0112h
WM_TIMER         equ 0113h
WM_MENUSELECT    equ 011Fh

WM_MOUSEMOVE     equ 0200h
WM_LBUTTONDOWN   equ 0201h
WM_LBUTTONUP     equ 0202h
WM_LBUTTONDBLCLK equ 0203h
WM_RBUTTONDOWN   equ 0204h
WM_RBUTTONUP     equ 0205h
WM_RBUTTONDBLCLK equ 0206h
WM_MBUTTONDOWN   EQU 0207h
WM_MBUTTONUP     EQU 0208h
WM_MBUTTONDBLCLK EQU 0209h
WM_MOUSEWHEEL    EQU 020Ah

WM_ENTERMENULOOP equ 0211h
WM_EXITMENULOOP  equ 0212h

WM_QUERYNEWPALETTE	EQU	030Fh
WM_PALETTECHANGED	EQU	0311h
WM_HOTKEY			EQU	0312h


WA_INACTIVE		EQU	0
WA_ACTIVE		EQU	1
WA_CLICKACTIVE	EQU	2

SC_SIZE			EQU	0F000h
SC_MOVE			EQU	0F010h
SC_MINIMIZE		EQU	0F020h
SC_MAXIMIZE		EQU	0F030h
SC_NEXTWINDOW	EQU	0F040h
SC_PREVWINDOW	EQU	0F050h
SC_CLOSE		EQU	0F060h

PM_REMOVE       equ 0001h

KEYEVENTF_EXTENDEDKEY	EQU	0001h
KEYEVENTF_KEYUP			EQU	0002h

CS_VREDRAW			EQU	0001h
CS_HREDRAW			EQU	0002h
CS_DBLCLKS			EQU	0008h
CS_OWNDC			EQU	0020h
CS_CLASSDC			EQU	0040h
CS_PARENTDC			EQU	0080h
CS_NOCLOSE			EQU	0200h
CS_SAVEBITS			EQU	0800h
CS_BYTEALIGNCLIENT	EQU	1000h
CS_BYTEALIGNWINDOW	EQU	2000h
CS_GLOBALCLASS		EQU	4000h
CS_IME				EQU	00010000h
CS_DROPSHADOW		EQU	00020000h

proto_WNDPROC typedef proto stdcall :HWND,:DWORD,:WPARAM,:LPARAM
WNDPROC typedef ptr proto_WNDPROC
proto_HOOKPROC typedef proto stdcall :DWORD,:WPARAM,:LPARAM
HOOKPROC typedef ptr proto_HOOKPROC

WNDCLASS struct
style         dd ?
lpfnWndProc   WNDPROC ?
cbClsExtra    dd ?
cbWndExtra    dd ?
hInstance     dd ?
hIcon         dd ?
hCursor       dd ?
hbrBackground dd ?
lpszMenuName  dd ?
lpszClassName dd ?
WNDCLASS ends

WNDCLASSEX struct
cbSize        dd ?
              WNDCLASS <>
hIconSM       dd ?
WNDCLASSEX ends

MSG     struct
hwnd    dd     ?
message dd     ?
wParam  dd     ?
lParam  dd     ?
time    dd     ?
pt      POINT  <?,?>
MSG     ends

WINDOWPOS	struct 
hwnd	HWND	?
hwndInsertAfter	HWND	?
x		DWORD	?
y		DWORD	?
cx_		DWORD	?
cy		DWORD	?
flags	DWORD	?
WINDOWPOS	ends

MK_LBUTTON	EQU	0001h
MK_RBUTTON	EQU	0002h
MK_SHIFT	EQU	0004h
MK_CONTROL	EQU	0008h
MK_MBUTTON	EQU	0010h

WINDOWPLACEMENT	struct 
length_				DWORD	?
flags				DWORD	?
showCmd				DWORD	?
ptMinPosition		POINT	<>
ptMaxPosition		POINT	<>
rcNormalPosition	RECT	<>
WINDOWPLACEMENT	ends

WINDOWINFO	struct 
cbSize	DWORD	?
rcWindow	RECT	<>
rcClient	RECT	<>
dwStyle	DWORD	?
dwExStyle	DWORD	?
dwWindowStatus	DWORD	?
cxWindowBorders	DWORD	?
cyWindowBorders	DWORD	?
atomWindowType	ATOM	?
wCreatorVersion	WORD	?
WINDOWINFO	ends

; * Window Styles

WS_OVERLAPPED     equ  00000000h
WS_POPUP          equ  80000000h
WS_CHILD          equ  40000000h
WS_MINIMIZE       equ  20000000h
WS_VISIBLE        equ  10000000h
WS_DISABLED       equ  08000000h
WS_CLIPSIBLINGS   equ  04000000h
WS_CLIPCHILDREN   equ  02000000h
WS_MAXIMIZE       equ  01000000h
WS_CAPTION        equ  00C00000h     ;/* WS_BORDER | WS_DLGFRAME  *
WS_BORDER         equ  00800000h
WS_DLGFRAME       equ  00400000h
WS_VSCROLL        equ  00200000h
WS_HSCROLL        equ  00100000h
WS_SYSMENU        equ  00080000h
WS_THICKFRAME     equ  00040000h
WS_GROUP          equ  00020000h
WS_TABSTOP        equ  00010000h

WS_MINIMIZEBOX    equ  00020000h
WS_MAXIMIZEBOX    equ  00010000h

WS_TILED          equ  WS_OVERLAPPED
WS_ICONIC         equ  WS_MINIMIZE
WS_SIZEBOX        equ  WS_THICKFRAME
WS_TILEDWINDOW    equ  WS_OVERLAPPEDWINDOW

WS_OVERLAPPEDWINDOW equ (WS_OVERLAPPED or \
                     WS_CAPTION       or \
                     WS_SYSMENU       or \
                     WS_THICKFRAME    or \
                     WS_MINIMIZEBOX   or \
                     WS_MAXIMIZEBOX)

WS_POPUPWINDOW  equ (WS_POPUP         or \
                     WS_BORDER        or \
                     WS_SYSMENU)

WS_CHILDWINDOW  equ (WS_CHILD)

WS_EX_DLGMODALFRAME   equ  00000001h
WS_EX_NOPARENTNOTIFY  equ  00000004h
WS_EX_TOPMOST         equ  00000008h
WS_EX_ACCEPTFILES     equ  00000010h
WS_EX_TRANSPARENT     equ  00000020h
WS_EX_MDICHILD        equ  00000040h
WS_EX_TOOLWINDOW      equ  00000080h
WS_EX_WINDOWEDGE      equ  00000100h
WS_EX_CLIENTEDGE      equ  00000200h
WS_EX_CONTEXTHELP     equ  00000400h

WS_EX_RIGHT           equ  00001000h
WS_EX_LEFT            equ  00000000h
WS_EX_RTLREADING      equ  00002000h
WS_EX_LTRREADING      equ  00000000h
WS_EX_LEFTSCROLLBAR   equ  00004000h
WS_EX_RIGHTSCROLLBAR  equ  00000000h

WS_EX_CONTROLPARENT   equ  00010000h
WS_EX_STATICEDGE      equ  00020000h
WS_EX_APPWINDOW       equ  00040000h


WS_EX_OVERLAPPEDWINDOW equ (WS_EX_WINDOWEDGE or WS_EX_CLIENTEDGE)
WS_EX_PALETTEWINDOW    equ (WS_EX_WINDOWEDGE or WS_EX_TOOLWINDOW or WS_EX_TOPMOST)

COLOR_SCROLLBAR        = 0
COLOR_BACKGROUND       = 1
COLOR_ACTIVECAPTION    = 2
COLOR_INACTIVECAPTION  = 3
COLOR_MENU             = 4
COLOR_WINDOW           = 5
COLOR_WINDOWFRAME      = 6
COLOR_MENUTEXT         = 7
COLOR_WINDOWTEXT       = 8
COLOR_CAPTIONTEXT      = 9
COLOR_ACTIVEBORDER     = 10
COLOR_INACTIVEBORDER   = 11
COLOR_APPWORKSPACE     = 12
COLOR_HIGHLIGHT        = 13
COLOR_HIGHLIGHTTEXT    = 14
COLOR_BTNFACE          = 15
COLOR_BTNSHADOW        = 16
COLOR_GRAYTEXT         = 17
COLOR_BTNTEXT          = 18

;  Predefined cursor & icon IDs
;
IDC_ARROW       = 32512
IDC_IBEAM       = 32513
IDC_WAIT        = 32514
IDC_CROSS       = 32515
IDC_UPARROW     = 32516
IDC_SIZE        = 32640
IDC_ICON        = 32641
IDC_SIZENWSE    = 32642
IDC_SIZENESW    = 32643
IDC_SIZEWE      = 32644
IDC_SIZENS      = 32645

IDI_APPLICATION = 32512
IDI_HAND        = 32513
IDI_QUESTION    = 32514
IDI_EXCLAMATION = 32515
IDI_ASTERISK    = 32516

;--- icon/cursor resources

;--- icon/cursor groups start with NEWHEADER, then 1..n RESDIR
;--- that are 6 + 14 = 20 bytes
;--- then comes a BITMAPINFOHEADER

NEWHEADER struct
Reserved	dw ?
ResType		dw ?	;RES_ICON/RES_CURSOR
ResCount	dw ?	;number of RESDIRs following
NEWHEADER ends

ICONRESDIR struct
Width_	db ?
Height	db ?
ColorCount db ?
reserved db ?
ICONRESDIR ends

CURSORRESDIR struct
Width_	dw ?
Height	dw ?
CURSORRESDIR ends

RESDIR	struct
union
Icon	ICONRESDIR <>
Cursor	CURSORRESDIR <>
ends
Planes			dw ?
BitCount		dw ?
BytesInRes		dd ?
IconCursorId	dw ?
RESDIR	ends

LOCALHEADER struct
xHotSpot	dw ?
yHotSpot	dw ?
LOCALHEADER ends

ifndef HBITMAP
HBITMAP typedef HANDLE
endif

ICONINFO	struct 
fIcon		DWORD   ?
xHotspot	DWORD	?
yHotspot	DWORD	?
hbmMask		HBITMAP	?
hbmColor	HBITMAP	?
ICONINFO	ends

HICON typedef HANDLE

CW_USEDEFAULT equ 80000000h

CREATESTRUCTA	struct 
lpCreateParams	LPVOID	?
hInstance		HINSTANCE	?
hMenu			HMENU	?
hwndParent		HWND	?
cy				DWORD	?
cx_				DWORD	?
y				DWORD	?
x				DWORD	?
style			SDWORD	?
lpszName		LPSTR	?
lpszClass		LPSTR	?
dwExStyle		DWORD	?
CREATESTRUCTA	ends

;--- keyboard

MOD_ALT		EQU	0001h
MOD_CONTROL	EQU	0002h
MOD_SHIFT	EQU	0004h
MOD_WIN		EQU	0008h

;--- clipboard

CF_TEXT		EQU	1
CF_BITMAP	EQU	2
CF_METAFILEPICT	EQU	3
CF_SYLK		EQU	4
CF_DIF		EQU	5
CF_TIFF		EQU	6
CF_OEMTEXT	EQU	7
CF_DIB		EQU	8
CF_PALETTE	EQU	9
CF_PENDATA	EQU	10
CF_RIFF		EQU	11
CF_WAVE		EQU	12
CF_UNICODETEXT	EQU	13
CF_ENHMETAFILE	EQU	14
CF_HDROP	EQU	15
CF_LOCALE	EQU	16
CF_DIBV5	EQU	17
CF_MAX		EQU	18

;--- DrawText flags

DT_TOP			EQU	00000000h
DT_LEFT			EQU	00000000h
DT_CENTER		EQU	00000001h
DT_RIGHT		EQU	00000002h
DT_VCENTER		EQU	00000004h
DT_BOTTOM		EQU	00000008h
DT_WORDBREAK	EQU	00000010h
DT_SINGLELINE	EQU	00000020h
DT_EXPANDTABS	EQU	00000040h
DT_TABSTOP		EQU	00000080h
DT_NOCLIP		EQU	00000100h
DT_EXTERNALLEADING	EQU	00000200h
DT_CALCRECT			EQU	00000400h
DT_NOPREFIX			EQU	00000800h
DT_INTERNAL			EQU	00001000h
DT_EDITCONTROL		EQU	00002000h
DT_PATH_ELLIPSIS	EQU	00004000h
DT_END_ELLIPSIS		EQU	00008000h
DT_MODIFYSTRING		EQU	00010000h
DT_RTLREADING		EQU	00020000h
DT_WORD_ELLIPSIS	EQU	00040000h
DT_NOFULLWIDTHCHARBREAK	EQU	00080000h
DT_HIDEPREFIX		EQU	00100000h
DT_PREFIXONLY		EQU	00200000h


SPI_GETSCREENSAVEACTIVE	EQU	0010h
SPI_GETWORKAREA			EQU	0030h

ifdef _USER32_
?INDCALL_ = 0
elseif ?INDCALL eq 0
?INDCALL_ = 0
else
?INDCALL_ = 1
endif

if ?INDCALL_ eq 0

;	.CODE
;_TEXT segment

BeginPaint       proto stdcall :HWND, :ptr PAINTSTRUCT
CharToOemBuffA   proto stdcall a1:dword,a2:dword,a3:dword
ClipCursor       proto stdcall :ptr RECT
CopyRect         proto stdcall :ptr RECT, :ptr RECT
CreateWindowExA  proto stdcall xstyle:dword,lpszClass:dword,lpszName:dword,style:dword,x:dword,y:dword,_cx:dword,cy:dword,parent:dword,menu:dword,hInst:dword,lParam:dword
DefWindowProcA   proto stdcall a1:dword,a2:dword,a3:dword,a4:dword
DestroyCursor    proto stdcall :HANDLE
DestroyWindow    proto stdcall :dword
DispatchMessageA proto stdcall :ptr MSG
EndPaint         proto stdcall :HWND, :ptr PAINTSTRUCT
FillRect         proto stdcall :dword, :ptr RECT, :dword
FindWindowA      proto stdcall :ptr BYTE, :ptr BYTE
FindWindowExA    proto stdcall :dword, :dword, :ptr BYTE, :ptr BYTE
GetActiveWindow  proto stdcall
GetAsyncKeyState proto stdcall a1:dword
GetClassInfoA    proto stdcall :dword, :ptr BYTE, :ptr WNDCLASS
GetClassInfoExA  proto stdcall :dword, :ptr BYTE, :ptr WNDCLASSEX
GetClassLongA    proto stdcall :dword, :dword
GetClassNameA    proto stdcall :dword, :ptr BYTE, :dword
GetClientRect    proto stdcall :dword, :ptr RECT
GetCursorPos     proto stdcall :ptr POINT
GetDC            proto stdcall :DWORD
GetFocus         proto stdcall
GetKeyState      proto stdcall a1:dword
GetMessageA      proto stdcall a1:dword,a2:dword,a3:dword,a4:dword
GetSysColorBrush proto stdcall :dword
GetSystemMetrics proto stdcall :dword
GetWindowLongA   proto stdcall :HWND, :DWORD
GetWindowRect    proto stdcall :dword, :ptr RECT
GetWindowTextA   proto stdcall :dword, :ptr BYTE, :dword
GetWindowTextLengthA   proto stdcall :dword
InvalidateRect   proto stdcall :dword, :ptr RECT, :dword
IsChild          proto stdcall :dword, :dword
KillTimer        proto stdcall :dword, :dword
LoadBitmapA      proto stdcall :HINSTANCE, :ptr BYTE
LoadCursorA      proto stdcall :HINSTANCE, :ptr BYTE
MessageBoxA      proto stdcall a1:dword,a2:dword,a3:dword,a4:dword
PeekMessageA     proto stdcall :dword, :dword, :dword, :dword, :dword
PostMessageA     proto stdcall a1:dword,a2:dword,a3:dword,a4:dword
PostQuitMessage  proto stdcall a1:dword
PostThreadMessageA proto stdcall :dword, :dword, :dword, :dword
RegisterClassA   proto stdcall :ptr WNDCLASS
RegisterClassExA   proto stdcall :ptr WNDCLASSEX
RegisterWindowMessageA   proto stdcall :ptr BYTE
ReleaseDC        proto stdcall :DWORD, :DWORD
ScreenToClient   proto stdcall :DWORD, :ptr POINT
SendMessageA     proto stdcall a1:dword,a2:dword,a3:dword,a4:dword
SetActiveWindow  proto stdcall :DWORD
SetCapture       proto stdcall :HANDLE
SetClassLongA    proto stdcall :dword, :dword, :dword
SetCursor        proto stdcall :HANDLE
SetFocus         proto stdcall :HWND
SetRect          proto stdcall :ptr RECT, :dword, :dword, :dword, :dword 
SetRectEmpty     proto stdcall :ptr RECT
SetWindowLongA   proto stdcall :HWND, :DWORD, :DWORD
SetWindowPos     proto stdcall :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
SetWindowTextA   proto stdcall :HWND, :ptr BYTE
ShowCursor       proto stdcall :DWORD
ShowWindow       proto stdcall a1:dword,a2:dword
TabbedTextOutA   proto stdcall :dword, :dword, :dword, :ptr BYTE, :dword, :dword, :ptr DWORD, :dword
ToAscii          proto stdcall :DWORD, :DWORD, :ptr BYTE, :ptr WORD, :DWORD
UnregisterClassA proto stdcall :ptr BYTE, :DWORD
WindowFromDC     proto stdcall :DWORD
WindowFromPoint  proto stdcall :POINT
wsprintfA        proto c       a1:ptr byte,a2:ptr byte,a3:vararg
wvsprintfA       proto stdcall a1:ptr byte,a2:ptr byte,a3:ptr

;_TEXT ends

else

;	.DATA
_DATA segment

externdef stdcall _imp__CharToOemBuffA@12:pfunc@12
externdef stdcall _imp__ClipCursor@4:pfunc@4
externdef stdcall _imp__CloseClipboard@0:pfunc@0
externdef stdcall _imp__CreateWindowExA@48:pfunc@48
externdef stdcall _imp__DefWindowProcA@16:pfunc@16
externdef stdcall _imp__DestroyCursor@4:pfunc@4
externdef stdcall _imp__DestroyWindow@4:pfunc@4
externdef stdcall _imp__DispatchMessageA@4:pfunc@4
externdef stdcall _imp__EmptyClipboard@0:pfunc@0
externdef stdcall _imp__EnumClipboardFormats@4:pfunc@4
externdef stdcall _imp__FillRect@12:pfunc@12
externdef stdcall _imp__GetActiveWindow@0:pfunc@0
externdef stdcall _imp__GetAsyncKeyState@4:pfunc@4
externdef stdcall _imp__GetClientRect@8:pfunc@8
externdef stdcall _imp__GetClipboardData@4:pfunc@4
externdef stdcall _imp__GetCursorPos@4:pfunc@4
externdef stdcall _imp__GetDC@4:pfunc@4
externdef stdcall _imp__GetFocus@0:pfunc@0
externdef stdcall _imp__GetKeyState@4:pfunc@4
externdef stdcall _imp__GetMessageA@16:pfunc@16
externdef stdcall _imp__GetSystemMetrics@4:pfunc@4
externdef stdcall _imp__GetWindowRect@8:pfunc@8
externdef stdcall _imp__InvalidateRect@12:pfunc@12
externdef stdcall _imp__IsClipboardFormatAvailable@4:pfunc@4
externdef stdcall _imp__KillTimer@8:pfunc@8
externdef stdcall _imp__LoadCursorA@8:pfunc@8
externdef stdcall _imp__LoadMenuA@8:pfunc@8
externdef stdcall _imp__MessageBoxA@16:pfunc@16
externdef stdcall _imp__OpenClipboard@4:pfunc@4
externdef stdcall _imp__PostMessageA@16:pfunc@16
externdef stdcall _imp__PostQuitMessage@4:pfunc@4
externdef stdcall _imp__PostThreadMessageA@16:pfunc@16
externdef stdcall _imp__RegisterClassA@4:pfunc@4
externdef stdcall _imp__RegisterHotKey@16:pfunc@16
externdef stdcall _imp__ReleaseDC@8:pfunc@8
externdef stdcall _imp__SendMessageA@16:pfunc@16
externdef stdcall _imp__SetActiveWindow@4:pfunc@4
externdef stdcall _imp__SetClipboardData@8:pfunc@8
externdef stdcall _imp__SetCursor@4:pfunc@4
externdef stdcall _imp__SetFocus@4:pfunc@4
externdef stdcall _imp__SetWindowPos@28:pfunc@28
externdef stdcall _imp__ShowCursor@4:pfunc@4
externdef stdcall _imp__ShowWindow@8:pfunc@8
externdef stdcall _imp__WindowFromPoint@8:pfunc@8
externdef stdcall _imp__wsprintfA:cpfunc@8v
externdef stdcall _imp__wvsprintfA@12:pfunc@12

_DATA ends

CharToOemBuffA      equ <_imp__CharToOemBuffA@12>
ClipCursor          equ <_imp__ClipCursor@4>
CloseClipboard      equ <_imp__CloseClipboard@0>
CreateWindowExA     equ <_imp__CreateWindowExA@48>
DefWindowProcA      equ <_imp__DefWindowProcA@16>
DestroyCursor       equ <_imp__DestroyCursor@4>
DestroyWindow       equ <_imp__DestroyWindow@4>
DispatchMessageA    equ <_imp__DispatchMessageA@4>
EmptyClipboard      equ <_imp__EmptyClipboard@0>
EnumClipboardFormats equ <_imp__EnumClipboardFormats@4>
FillRect            equ <_imp__FillRect@12>
GetActiveWindow     equ <_imp__GetActiveWindow@0>
GetAsyncKeyState    equ <_imp__GetAsyncKeyState@4>
GetClientRect       equ <_imp__GetClientRect@8>
GetClipboardData    equ <_imp__GetClipboardData@4>
GetCursorPos        equ <_imp__GetCursorPos@4>
GetDC               equ <_imp__GetDC@4>
GetFocus            equ <_imp__GetFocus@0>
GetKeyState         equ <_imp__GetKeyState@4>
GetMessageA         equ <_imp__GetMessageA@16>
GetSystemMetrics    equ <_imp__GetSystemMetrics@4>
GetWindowRect       equ <_imp__GetWindowRect@8>
InvalidateRect      equ <_imp__InvalidateRect@12>
IsClipboardFormatAvailable equ <_imp__IsClipboardFormatAvailable@4>
KillTimer           equ <_imp__KillTimer@8>
LoadCursorA         equ <_imp__LoadCursorA@8>
LoadMenuA           equ <_imp__LoadMenuA@8>
MessageBoxA         equ <_imp__MessageBoxA@16>
OpenClipboard       equ <_imp__OpenClipboard@4>
PostMessageA        equ <_imp__PostMessageA@16>
PostQuitMessage     equ <_imp__PostQuitMessage@4>
PostThreadMessageA  equ <_imp__PostThreadMessageA@16>
RegisterClassA      equ <_imp__RegisterClassA@4>
RegisterHotKey      equ <_imp__RegisterHotKey@16>
ReleaseDC           equ <_imp__ReleaseDC@8>
SendMessageA        equ <_imp__SendMessageA@16>
SetActiveWindow     equ <_imp__SetActiveWindow@4>
SetClipboardData    equ <_imp__SetClipboardData@8>
SetCursor           equ <_imp__SetCursor@4>
SetFocus            equ <_imp__SetFocus@4>
SetWindowPos        equ <_imp__SetWindowPos@28>
ShowCursor          equ <_imp__ShowCursor@4>
ShowWindow          equ <_imp__ShowWindow@8>
WindowFromPoint     equ <_imp__WindowFromPoint@8>
wsprintfA           equ <_imp__wsprintfA>
wvsprintfA          equ <_imp__wvsprintfA@12>

endif

CreateWindowEx	textequ <CreateWindowExA>
DefWindowProc	textequ <DefWindowProcA>
DispatchMessage	textequ <DispatchMessageA>
GetMessage		textequ <GetMessageA>
LoadCursor		textequ <LoadCursorA>
MessageBox		textequ <MessageBoxA>
PostMessage		textequ <PostMessageA>
PostThreadMessage textequ <PostThreadMessageA>
RegisterClass	textequ <RegisterClassA>
SendMessage		textequ <SendMessageA>
wsprintf		textequ <wsprintfA>
wvsprintf		textequ <wvsprintfA>

