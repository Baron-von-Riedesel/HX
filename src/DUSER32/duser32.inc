
?AUTOINIT		equ 1	;try to auto initialize gfx mode 
?THREADQUEUE	equ 0	;1=use a thread message queue

USER_TYPE_HWND	equ "HWND"
USER_TYPE_HMENU equ "MENU"

WNDOBJ struct
pNext		dd ?	;must be first!
dwType  	dd ?	;type to identify a WNDOBJ
WndProc 	WNDPROC ?
dwStyle		dd ?
pWndClass   dd ?	;wnd class of this window
dwUserData	dd ?	;user data
hInstance	dd ?
rc			RECT <>
dwFlags		dd ?
pszText		dd ?
dwThreadId  dd ?
hbmSaveBits	dd ?	;bitmap if window class has CS_SAVEBITS style
hwndParent	dd ?	;parent/owner
hwndChilds	dd ?	;start of child windows
hwndSibling dd ?	;next sibling
hRgn		dd ?	;window region
hMenu		dd ?
hSysMenu	dd ?
bUpdate		db ?
bErase		db ?
			db 2 dup (?)
WNDOBJ ends

FWO_XDEF	equ 1
FWO_YDEF	equ 2
FWO_CXDEF	equ 4
FWO_CYDEF	equ 8


MENUOBJ struc
dwType	dd ?
pItems	dd ?
MENUOBJ ends

ICONOBJ struct
hBitmap dd ?
ICONOBJ	ends

protoTimerProc typedef proto :DWORD, :DWORD, :DWORD, :DWORD
LPTIMERPROC typedef ptr protoTimerProc

UTIMER  struct
pNext	dd ?
hwnd	dd ?
dwID	dd ?
hTimer	dd ?
time	FILETIME <>
pProc	LPTIMERPROC ?
UTIMER	ends

externdef g_hInstance:HINSTANCE
externdef g_hwndFocus:DWORD
externdef g_hwndActive:DWORD
externdef g_bMouse:BYTE

_GetVesaProcs		proto stdcall
atexit				proto c :DWORD
doatexit			proto c
malloc				proto stdcall :DWORD
malloc2				proto stdcall :DWORD
free				proto stdcall :DWORD
_FindClass			proto stdcall :DWORD
_CreateBitmapFromMemory proto stdcall :ptr BITMAPINFOHEADER
_ClearDCCache		proto stdcall
ConvertWStr			proto
ConvertAStrN		proto stdcall :ptr BYTE, :ptr WORD, :dword

@GetGDIProc macro x
if ?FLAT
;_GetGDIProcs proto
;	invoke _GetGDIProcs
;	mov eax, g_lpfn&x
else
;	mov eax, offset x
endif
	endm


if 0
;--- GDI32 procs

protoBitBlt typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
LPFNBITBLT typedef ptr protoBitBlt

protoCreateCompatibleBitmap typedef proto :DWORD, :DWORD, :DWORD
LPFNCREATECOMPATIBLEBITMAP typedef ptr protoCreateCompatibleBitmap

protoCreateCompatibleDC typedef proto :DWORD
LPFNCREATECOMPATIBLEDC typedef ptr protoCreateCompatibleDC

protoCreateDIBitmap typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
LPFNCREATEDIBITMAP typedef ptr protoCreateDIBitmap

protoCreateDCA typedef proto :DWORD, :DWORD, :DWORD, :DWORD
LPFNCREATEDCA typedef ptr protoCreateDCA

;protoCreateRectRgnIndirect typedef proto :ptr RECT
;LPFNCREATERECTRGNINDIRECT typedef ptr protoCreateRectRgnIndirect

protoCreateSolidBrush typedef proto :DWORD
LPFNCREATESOLIDBRUSH typedef ptr protoCreateSolidBrush

protoDeleteDC typedef proto :DWORD
LPFNDELETEDC typedef ptr protoDeleteDC

protoDeleteObject typedef proto :DWORD
LPFNDELETEOBJECT typedef ptr protoDeleteObject

protoGetDeviceCaps typedef proto :DWORD, :DWORD
LPFNGETDEVICECAPS typedef ptr protoGetDeviceCaps

protoPatBlt typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
LPFNPATBLT typedef ptr protoPatBlt

protoSelectObject typedef proto :DWORD, :DWORD
LPFNSELECTOBJECT typedef ptr protoSelectObject

protoGetStockObject typedef proto :DWORD
LPFNGETSTOCKOBJECT typedef ptr protoGetStockObject

protoSetDCOrgEx typedef proto :DWORD, :DWORD, :DWORD
LPFNSETDCORGEX typedef ptr protoSetDCOrgEx

protoGetDCOrgEx typedef proto :DWORD, :ptr POINT
LPFNGETDCORGEX typedef ptr protoGetDCOrgEx

protoSetBkMode typedef proto :DWORD, :DWORD
LPFNSETBKMODE typedef ptr protoSetBkMode

protoGetRegionData typedef proto :DWORD, :DWORD, :DWORD
LPFNGETREGIONDATA typedef ptr protoGetRegionData

protoSetRectRgn typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
LPFNSETRECTRGN typedef ptr protoSetRectRgn

protoTextOutA typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
LPFNTEXTOUTA  typedef ptr protoTextOutA 

protoExtTextOutA typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :ptr RECT, :LPSTR, :DWORD, :ptr DWORD
LPFNEXTTEXTOUTA  typedef ptr protoExtTextOutA 


ife ?FLAT
g_lpfnBitBlt        	textequ <BitBlt>
g_lpfnCreateCompatibleBitmap textequ <CreateCompatibleBitmap>
g_lpfnCreateCompatibleDC textequ <CreateCompatibleDC>
g_lpfnCreateDIBitmap	textequ <CreateDIBitmap>
g_lpfnCreateDCA         textequ <CreateDCA>
;g_lpfnCreateRectRgnIndirect textequ <CreateRectRegionIndirect>
g_lpfnCreateSolidBrush  textequ <CreateSolidBrush>
g_lpfnDeleteDC          textequ <DeleteDC>
g_lpfnDeleteObject      textequ <DeleteObject>
g_lpfnGetDCOrgEx        textequ <GetDCOrgEx>
g_lpfnGetDeviceCaps     textequ <GetDeviceCaps>
g_lpfnGetStockObject    textequ <GetStockObject>
g_lpfnPatBlt            textequ <PatBlt>
g_lpfnSelectObject      textequ <SelectObject>
g_lpfnSetBkMode         textequ <SetBkMode>
g_lpfnSetDCOrgEx        textequ <SetDCOrgEx>
g_lpfnGetRegionData     textequ <GetRegionData>
g_lpfnSetRectRgn        textequ <SetRectRgn>
g_lpfnTextOutA          textequ <TextOutA>
g_lpfnExtTextOutA       textequ <ExtTextOutA>
endif

externdef g_lpfnBitBlt:			LPFNBITBLT
externdef g_lpfnCreateCompatibleBitmap: LPFNCREATECOMPATIBLEBITMAP
externdef g_lpfnCreateCompatibleDC: LPFNCREATECOMPATIBLEDC
externdef g_lpfnCreateDIBitmap: LPFNCREATEDIBITMAP
externdef g_lpfnCreateDCA:		LPFNCREATEDCA
;externdef g_lpfnCreateRectRgnIndirect: LPFNCREATERECTRGNINDIRECT
externdef g_lpfnCreateSolidBrush:LPFNCREATESOLIDBRUSH
externdef g_lpfnDeleteDC:		LPFNDELETEDC
externdef g_lpfnDeleteObject:	LPFNDELETEOBJECT
externdef g_lpfnGetDeviceCaps:	LPFNGETDEVICECAPS
externdef g_lpfnPatBlt:			LPFNPATBLT
externdef g_lpfnSelectObject:	LPFNSELECTOBJECT
externdef g_lpfnGetStockObject:	LPFNGETSTOCKOBJECT
externdef g_lpfnSetDCOrgEx:		LPFNSETDCORGEX
externdef g_lpfnGetDCOrgEx:		LPFNGETDCORGEX
externdef g_lpfnSetBkMode:  	LPFNSETBKMODE
externdef g_lpfnGetRegionData:  LPFNGETREGIONDATA
externdef g_lpfnSetRectRgn:  	LPFNSETRECTRGN
externdef g_lpfnTextOutA:		LPFNTEXTOUTA
externdef g_lpfnExtTextOutA:	LPFNEXTTEXTOUTA

endif

externdef g_pTimer:DWORD

;--- VESA32 procs

protoEnumVesaModes				typedef proto :DWORD, :DWORD
LPFNENUMVESAMODES          		typedef ptr protoEnumVesaModes
protoGetVesaMemoryBufferSize	typedef proto :DWORD
LPFNGETVESAMEMORYBUFFERSIZE		typedef ptr protoGetVesaMemoryBufferSize
protoGetVesaMode				typedef proto
LPFNGETVESAMODE					typedef ptr protoGetVesaMode
protoGetVesaModeInfo			typedef proto :dword, :DWORD
LPFNGETVESAMODEINFO				typedef ptr protoGetVesaModeInfo
protoGetVesaStateBufferSize		typedef proto
LPFNGETVESASTATEBUFFERSIZE		typedef ptr protoGetVesaStateBufferSize
protoRestoreVesaVideoMemory		typedef proto :DWORD
LPFNRESTOREVESAVIDEOMEMORY 		typedef ptr protoRestoreVesaVideoMemory
protoRestoreVesaVideoState		typedef proto :DWORD
LPFNRESTOREVESAVIDEOSTATE		typedef ptr protoRestoreVesaVideoState
protoSaveVesaVideoMemory		typedef proto :DWORD, :DWORD
LPFNSAVEVESAVIDEOMEMORY 		typedef ptr protoSaveVesaVideoMemory
protoSaveVesaVideoState			typedef proto :DWORD, :DWORD
LPFNSAVEVESAVIDEOSTATE			typedef ptr protoSaveVesaVideoState
protoSearchVesaMode				typedef proto :DWORD, :DWORD, :DWORD
LPFNSEARCHVESAMODE				typedef ptr protoSearchVesaMode
protoSetVesaMode				typedef proto :DWORD
LPFNSETVESAMODE					typedef ptr protoSetVesaMode
protoVesaMouseInit				typedef proto
LPFNVESAMOUSEINIT				typedef ptr protoVesaMouseInit
protoVesaMouseExit				typedef proto
LPFNVESAMOUSEEXIT				typedef ptr protoVesaMouseExit

externdef g_lpfnEnumVesaModes:			LPFNENUMVESAMODES
externdef g_lpfnGetVesaMemoryBufferSize:LPFNGETVESAMEMORYBUFFERSIZE
externdef g_lpfnGetVesaMode:			LPFNGETVESAMODE			
externdef g_lpfnGetVesaModeInfo:		LPFNGETVESAMODEINFO
externdef g_lpfnGetVesaStateBufferSize:	LPFNGETVESASTATEBUFFERSIZE
externdef g_lpfnRestoreVesaVideoMemory:	LPFNRESTOREVESAVIDEOMEMORY
externdef g_lpfnRestoreVesaVideoState:	LPFNRESTOREVESAVIDEOSTATE
externdef g_lpfnSaveVesaVideoMemory:	LPFNSAVEVESAVIDEOMEMORY
externdef g_lpfnSaveVesaVideoState:		LPFNSAVEVESAVIDEOSTATE
externdef g_lpfnSearchVesaMode:			LPFNSEARCHVESAMODE 
externdef g_lpfnSetVesaMode:			LPFNSETVESAMODE
externdef g_lpfnVesaMouseInit:			LPFNVESAMOUSEINIT
externdef g_lpfnVesaMouseExit:			LPFNVESAMOUSEEXIT

externdef g_csUser:CRITICAL_SECTION

;--- macros

@serialize_enter macro
	push eax
	invoke EnterCriticalSection, addr g_csUser
    pop eax
;;	@noints
	endm

@serialize_exit macro
	push eax
	invoke LeaveCriticalSection, addr g_csUser
    pop eax
;;	@restoreints
    endm


