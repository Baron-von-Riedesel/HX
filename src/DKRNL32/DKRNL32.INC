
;*** DKRNL32 internal structures, constants, prototypes, globals, macros

?NT				equ 0	;std=0, 1=NT platform, 0=win9x platform
?NONULLHDL		equ 1	;std=1, 1=dont use 0 as valid handle        
?USECLISTI		equ 1	;std=1, 1=use CLI/STI, 0=use PIC or int 31h, ax=90xh
?USERTC			equ 1	;std=1, 1=use RTC timer for dispatcher, 20 ms slice
						;       0=use PIT timer with 55 ms timeslice
?MICROSECS		equ 0	;std=0, 1=count microsecs in RTC irq handler

?USEINDOS   = 1         ;std=1, 1=use indosflag as mutex
                        ;       0=use separate flag as mutex (g_bDosUsed)
if ?FLAT                        
?HOOKINT21		equ	1	;std=?, hook optionally
else
?HOOKINT21		equ	1	;std=1, hook in any case
endif
?GBLCURRENT		equ 1	;std=1, 1=global g_hCurThread exists

?EVENTOPT		equ 1	;std=?, 1=do a thread switch in SetEvent?

?LOWLEVEL_CTRLBRK	equ 1	;std=1, 1=check for ctrl-break in IRQ 1 routine

?COMMSUPP		equ 0	;std=0, 1=support low-level COMM API
?PROCFEAT		equ 1	;std=1, 1=support IsProcessorFeaturePresent

;--- offset in THREAD_INFORMATION_BLOCK
;--- to store last error

if ?NT
?LERROROFS		equ 34h
else
?LERROROFS		equ 60h
endif

;--- start of async IO list

?ASYNCSTART		equ 5Ch	;offset in THREAD_INFORMATION_BLOCK

if ?USERTC
?TIMESLICE		equ 20
else
?TIMESLICE		equ 55
endif

HANDLE_DUMMY	equ -29	;a handle CloseHandle is ignoring
CURRENT_THREAD	equ -2	;value returned by GetCurrentThread in Win32
?TLSSLOTS		equ 64	;entries in TLS array

protoDeviceCmpProc typedef proto :dword
LPFNDEVICECMPPROC typedef ptr protoDeviceCmpProc
protoDeviceIoHandler typedef proto :dword, :dword, :dword, :dword, :dword, :dword, :dword, :dword
LPFNDEVICEIOHANDLER typedef ptr protoDeviceIoHandler

;--- help structure for DeviceIoControl to call VxD services
;--- currently only vwin32+apix support is implemented

VXDENTRY struct
pCmpProc	LPFNDEVICECMPPROC ?
VXDENTRY ends

DPMIEXC struct
if ?CLEARHIGHEBP
dpmiip  dw ?
dpmics  dw ?
errc    dw ?
rEip    dw ?
rCS     dw ?
rEflags dw ?
union
struct
rEsp    dw ?
rSS     dw ?
ends
rSSSP	dd ?
ends
else
dpmiip  dd ?	;+0
dpmics  dd ?	;+4
errc    dd ?	;+8
rEip    dd ?	;+12
rCS     dd ?	;+16
rEflags dd ?	;+20
union
struct
rEsp    dd ?	;+24
rSS     dd ?	;+28
ends
struct
rSSESP  df ?	;+24
        dw ?
ends
ends
endif
DPMIEXC ends

PF16	typedef far16 ptr
PF32	typedef far32 ptr

IRETDS struct
if ?CLEARHIGHEBP
rEip    dw ?
rCS     dw ?
rEflags dw ?
else
rEip    dd ?
rCS     dd ?
rEflags dd ?
endif
IRETDS ends

KEYEVNT struct	;KEYEVNT is also used by DirectInput!!!
bScan	db ?
bAscii	db ?
bStat17	db ?
bStat18	db ?
bStat96	db ?
KEYEVNT ends

_GetKbdEvent			proto
_PeekKbdEvent			proto :DWORD
_GetNumberOfKbdEvents	proto

MOUEVNT struct
wPosX	dw ?
wPosY	dw ?
wPosZ	dw ?
wState	dw ?
wMask	dw ?
MOUEVNT ends

_GetMouEvent			proto
_PeekMouEvent			proto :DWORD
_GetNumberOfMouEvents	proto

;------------------------------------ kernel heap objects

ifndef CONSOLE_CURSOR_INFO
CONSOLE_CURSOR_INFO struct
dwSize   dd ?
bVisible dd ?
CONSOLE_CURSOR_INFO ends
endif

SCREENBUF struct
dwType		dd ?	;must be first
dwFlags		dd ?	;if the order of the fields is changed, 
pMem		dd ?	;g_sb must be changed as well!
dwAccess	dd ?
dwShareMode dd ?
dwAttributes dd ?
dwSize		COORD <>
dwCursorPos COORD <>
cci			CONSOLE_CURSOR_INFO <>
SCREENBUF ends

;--- SCREENBUF dwFlags values

SBF_ISACTIVE	equ 1
SBF_ATTRSET		equ 2	;text attribute has been set

;------------------- memory/heap

;--- MDESC holds up to 255 MBLOCKs

MDESC struct
pNext	dd ?	;next MDESC item
dwCnt	dd ?	;number of MBLOCK items
dwHdl	dd ?	;DPMI handle of this descriptor block
		dd ?	;not used
MDESC ends

;--- MBLOCK describes an address space region (VirtualAlloc/VirtualFree)

MBLOCK struct
dwSize	dd ?	;virtual block size in bytes
dwAddr	dd ?	;virtual block linear base address
dwBase	dd ?	;DPMI linear base address of block
dwHandle dd ?	;DPMI handle
MBLOCK ends

;------------------- Heap definitions 

?FREELIST	equ 1	;maintain a list of free heap items

;--- HBLOCK used by HeapAlloc/HeapDestroy
;--- this structure is used for multiple heap regions

HBLOCK struct
pNext    dd ?
dwAddr   dd ?	;linear address of block
HBLOCK ends

;--- heap item  (+ freelist item)
;--- used by HeapAlloc, HeapFree

FLITEM	struct
dwSize	DWORD ?
pNext	DWORD ?
FLITEM	ends

;*** heap item flags (bits 0+1 of dwSize)

FHEAPITEM_FREE		equ 1
FHEAPITEM_INTERNAL	equ 2

;------------------- kernel sync objects 

SYNCOBJECT struct
dwType		dd ?
SYNCOBJECT ends

SYNCTYPE_FILE		textequ <"FILE">
SYNCTYPE_SEMAPHOR	textequ <"SEMA">
SYNCTYPE_MUTEX		textequ <"MUTE">
SYNCTYPE_EVENT		textequ <"EVEN">
SYNCTYPE_TIMER		textequ <"TIME">
SYNCTYPE_PROCESS	textequ <"PROC">
SYNCTYPE_THREAD		textequ <"THRD">
SYNCTYPE_FILEMAPP	textequ <"FMAP">
SYNCTYPE_CHANGENOT	textequ <"CHNT">
SYNCTYPE_SOCKET		textequ <"SCKT">
SYNCTYPE_PIPE		textequ <"PIPE">

;--- other non-sync types:

TYPE_SCREENBUF	textequ <"SCBF">

NAMEDOBJECT struct
	SYNCOBJECT <>
NextObj	dd ?
lpName	dd ?
NAMEDOBJECT ends


FILE struct
		SYNCOBJECT <>
flags	db ?
union
bDrive	db ?			;drive/disk
bDevice db ?			;COM device 
ends
wDOSFH	dw ?			;DOS file handle
union
pHandler  LPFNDEVICEIOHANDLER ?
pVxdHandler LPFNDEVICEIOHANDLER ?
ends
union
dqPos	dq ?			;current position
pParams dd ?			;additional parameters
ends
FILE ends

;--- FILE.flags values

FF_DISK		equ 1		;is a physical disk (0, 80h, ...)
FF_DRIVE	equ 2		;is a drive (a:, c:, ...) 
FF_FILE		equ 4		;is a "true" file (position can be set)
FF_CDROM	equ 8		;drive is a cdrom (not FAT32)
FF_VXD		equ 16		;is a vxd
FF_DEVICE	equ 32		;is a device (COM:, AUX:, PRT:, LPT:, ...)
FF_CHS		equ 64		;for FF_DISK: is CHS device

THREAD struct
		SYNCOBJECT <>
pNext      dd ?			;next thread
pContext   dd ?
dwExitCode dd ?			;thread exit code
dwTibSel   dd ?
flags      db ?
           db 3 dup (?)
hStack     dd ?			;stack allocated for this thread (also TIB)
if 0
pAPC       dd ?
endif
bBoosted   db ?			;boost count
bSuspended db ?			;suspended count
bPriority  SBYTE ?
           db ?
THREAD ends

;--- THREAD.flags values

TF_TERMINATED	equ 01h ;thread has terminated
TF_CLOSED		equ 02h ;CloseHandle has been called for this thread
TF_WAITING		equ 04h ;thread is blocked (Sleep(0) called)
TF_LINKED		equ 08h ;thread is in linked list
TF_ALERTABLE	equ 10h ;thread is in an alertable wait state

;--- internal structure for ReadFileEx/WriteFileEx

ASYNCFILE struct
pNext		dd ?
dwFlags		dd ?
handle		dd ?
pBuffer		dd ?
numBytes	dd ?
lpOverlapped dd ?
lpCompletionRoutine dd ?
ASYNCFILE ends

;--- part of CONTEXT structure

CONTEXT_CTRL struct
rEbp   dd ?
rEip   dd ?
SegCs  dd ?
EFlags dd ?
rEsp   dd ?
SegSs  dd ?
CONTEXT_CTRL ends

FILEMAPOBJ struct
			NAMEDOBJECT <>
hFile		DWORD ?		;file handle
dwSize		DWORD ?		;total size
pView		DWORD ?		;linear address of view
dwProtect	DWORD ?		;PAGE_READONLY or PAGE_READWRITE
dwOffset	DWORD ?		;file offset
dwSizeReal	DWORD ?		;real size to read/write
dwFlags		DWORD ?
dwRefCnt	DWORD ?		;workaround: use a reference counter
FILEMAPOBJ ends

;--- FILEMAPOBJ dwFlags values

FMO_MAPPED	equ 1
FMO_CLOSED	equ 2

SEMAPHORE struct
			NAMEDOBJECT <>
dwCurCnt	DD ?
dwMaxCnt	DD ?
dwRefCnt	DD ?
SEMAPHORE ends

MUTEX struct
			NAMEDOBJECT <>
wRefCnt		DW ?
wCnt		DW ?
dwOwner		DD ?	;thread who owns the mutex
MUTEX ends

protoTimerAPCProc typedef proto :DWORD, :DWORD, :DWORD
LPFNTIMERAPCPROC typedef ptr protoTimerAPCProc

TIMER struct
			NAMEDOBJECT <>
pNext		dd ?	;active timers are in a linked list
filetime	FILETIME <>
if ?MICROSECS
lCnt		DQ ?
lPeriod		DQ ?
else
lCnt		DD ?
lPeriod		DD ?
endif
hThread		DD ?	;
lpfnCompRoutine LPFNTIMERAPCPROC ?
lpArgCompRoutine DD ?
bManReset	DB ?	;
bSignaled	DB ?	;
bDispatch   DB ?	;dispatch to the thread waiting for the timer
bRefCnt		DB ?
TIMER ends

EVENT struct
			NAMEDOBJECT <>
bFlags		db ?
bRefCnt 	db ?
			dw ?
if ?EVENTOPT
hThread		dd ?	;thread waiting for event
endif
EVENT ends

EVNT_SIGNALED	equ 1
EVNT_MANRESET	equ 2

EVNT_SIGNALED_BIT equ 0	;for BT, BTS, BTR, BTC functions

PROCESS struct
			SYNCOBJECT <>
hThread		dd ?	;process main thread
hModule		dd ?	;main module handle
pHeap		dd ?	;process heap handle
pVirtual	dd ?	;process virtual memory
pModuleList	dd ?	;list of loaded modules
wErrMode	dw ?
wFlags		dw ?
pCmdLine	dd ?	;process command line
if ?HOOKINT21
wPSP		dw ?	;process's PSP
endif
PROCESS ends

PF_TERMINATING	equ 0001h
PF_LOCKED		equ 0002h	;1=no thread switches allowed
PF_TERMINATED	equ 0004h
PF_CON_ATTACHED	equ 0008h	;1=console is attached

SOCKET struct
			SYNCOBJECT <>
dwRefCnt	dd ?
hSocket		dd ?        ;WatTCP socket handle
			dd ?		;reserve another DWORD for WSOCK32
SOCKET ends

;--- a pipe is mapped by a DOS file, but
;--- the DOS file handle cannot be used directly

PIPE struct
			SYNCOBJECT <>
dwfh		dd ?
dwPos		dd ?
bWrite		db ?
PIPE ends

;--- dispatcher

ifndef ?DIRECTDISP
?DIRECTDISP = 0			;std=0, 0=use exc 01 to dispatch, 1=dispatch in IRQ0
endif

FTI_INIT 	equ 1	;1=dispatcher is initialized
if ?DIRECTDISP
FTI_DIRDISP	equ 2	;0=use exception 01
					;1=dispatch directly in IRQ 0 routine
endif                

;------------------- internal functions

KernelHeapAlloc		proto stdcall :DWORD
KernelHeapAllocObject proto stdcall :DWORD, :ptr BYTE
KernelHeapFree		proto stdcall :DWORD
KernelHeapFindObject proto stdcall :ptr BYTE, :DWORD
KernelHeapUnlinkObject proto stdcall :ptr NAMEDOBJECT
KernelHeapWalk		proto stdcall :ptr PROCESS_HEAP_ENTRY, :DWORD
_growseg			proto c
_searchseg			proto c
HeapAllocRegion		proto stdcall :dword, :dword, :dword, :dword, :dword
GetKernelHeap		proto stdcall
IsKernelHeapLocked	proto stdcall
VirtualGetFileMapObject proto stdcall
VirtualGetPageAttr	proto stdcall :dword, :ptr WORD, :DWORD
VirtualSetPageAttr	proto stdcall :dword, :DWORD, :DWORD, :DWORD
VirtualFindBlock	proto stdcall :DWORD
HeapFreeMemBlocks	proto stdcall :DWORD
GetProcessHeapEx	proto stdcall :DWORD
_GetEnvironmentVariableInt proto stdcall :ptr BYTE
__dw2a				proto stdcall
__dw2aD				proto stdcall
__dw2aDX    		proto stdcall
__dw2aDY    		proto stdcall
__dw2aX				proto stdcall
__kernel32init		proto stdcall
__kernel32exit		proto stdcall
_SearchRegion		proto stdcall :ptr MBLOCK
_RegionStart		proto stdcall
ife ?FLAT
__lin2based 		proto stdcall
__based2lin			proto stdcall
endif
if ?FLAT
initstaticTLS		proto stdcall
endif
_allocdosmem		proto stdcall
_freedosmem			proto stdcall
KernelShowMouse		proto stdcall
KernelHideMouse		proto stdcall
EnterSerialization  proto stdcall
LeaveSerialization	proto stdcall
Display_szString	proto stdcall :ptr byte
ConvertWStr			proto stdcall
ConvertWStrN		proto stdcall
ConvertAStr			proto stdcall :ptr byte
ConvertAStrN		proto stdcall :ptr byte, :ptr WORD, :DWORD
getscreenptr		proto stdcall handle:DWORD
tzset				proto stdcall
systemtolocal   	proto stdcall
localtosystem   	proto stdcall
gethelperstack		proto stdcall
freehelperstack		proto stdcall
SetIntensityBackground proto stdcall
_DosDateTimeToFileTime proto stdcall :DWORD, :DWORD, :ptr FILETIME
_FileTimeToDosDateTime proto stdcall :ptr FILETIME, :ptr WORD, :ptr WORD
_FlushLogFile		proto stdcall
_GetCurrentThread	proto stdcall
_SetRTCTimer		proto stdcall
_RestoreRTCTimer	proto stdcall
_SaveContext		proto stdcall :DWORD, :CONTEXT_CTRL
_LoadContext		proto stdcall :DWORD
_sprintf			proto c :ptr BYTE, :ptr BYTE, :VARARG
_AddMemoryRegion	proto stdcall :DWORD, :DWORD, :DWORD, :DWORD
_GetScreenBuffer	proto stdcall
_WriteConsole		proto stdcall :ptr SCREENBUF, :ptr BYTE, :DWORD, :ptr DWORD
_mul64				proto stdcall :qword, :dword
_div64				proto stdcall :qword, :qword, :dword

;------------------- global vars

;.data
_DATA segment

externdef g_bProcessed:DWORD
externdef g_bIsConsole:DWORD
externdef g_csalias:DWORD
ife ?FLAT
externdef g_flatsel:DWORD
endif
externdef g_indosaddr:DWORD		;is a linear address!
externdef g_dwFlags:DWORD		;global DKRNL32 flags (environment var)
externdef g_bIsActive:BYTE		;is this kernel instance active?
externdef g_bIntFl:BYTE			;global internal DKRNL32 flags
externdef g_bHost:BYTE			;DPMI host
externdef g_bDPMICap:BYTE		;page get/set attr supported
externdef g_wPics:WORD			;current master/slave PIC mappings

externdef g_dwIdleProc:DWORD
externdef g_bDispatchFlags:BYTE	;dispatcher flags
if ?GBLCURRENT
externdef g_hCurThread:dword	;current thread or 0
endif
externdef g_dwActiveScreenBuffer:DWORD
externdef g_consoleflags:DWORD
;externdef g_wAttributes:WORD
externdef g_dwRTCTicks:DWORD
externdef g_dwGetTimerValue:dword
externdef g_dwGetTimerValuems:dword
externdef g_dwBoostProc:dword
externdef g_bDispReq:BYTE
externdef g_dwDebugFlags:dword

_DATA ends

;--- g_bHost values

HF_UNKNOWN	equ 0
HF_WIN9X	equ 1
HF_WINNT	equ 2
HF_HDPMI   	equ 3
HF_DPMIONE	equ 4
HF_DOSEMU	equ 5

;--- g_dwFlags values

DKF_NODISABLE	equ 1	;dkrnl32 remains active if a new process is launched
DKF_NODBGHOOK	equ 2	;dont hook exceptions 1 and 3 (for debuggers)
DKF_FULLSTACK	equ 4	;full stack for threads
;DKF_DISABLEKBD  equ 8	;1=disable kbd before reading port 60h
DKF_USERTC      equ 16	;1=always use RTC to get GetTickCount value
DKF_NOEXCHOOK	equ 32	;dont hook any exceptions (for debuggers)

;--- g_bIntFl values

IKF_PELDR		equ 1	;dpmild32 API is present
IKF_CALLTERM	equ 2	;call terminators in int 21h, ah=4Ch handler

;------------------- macros

if ?FLAT
@flat	equ <ds>
@bios	equ <ds>
else
@flat	equ <gs>
@bios	equ <gs>
endif

;--- ?CLEARHIGHEBP is 1 for 16 bit DPMI client

@iret   macro
if ?CLEARHIGHEBP
	iret
else
	iretd
endif
	endm

@pushf  macro
if ?CLEARHIGHEBP
	pushf
else
	pushfd
endif
	endm

@traceF macro x,y
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & x)
		@trace <y>
	.endif
endif
	endm

@straceF macro x,y
ifdef _DEBUG
	.if (cs:g_dwDebugFlags & x)
		@strace <y>
	.endif
endif
	endm

if 1;def _DEBUG
;--- flags read from DKRNLDBG environment variable
DBGF_FLUSH		equ 01h	;flush dos file buffers after each write
DBGF_CIN		equ 02h	;verbose log console input
DBGF_COUT		equ 04h	;verbose log console output
DBGF_SCRNFL		equ 08h	;show activity on text screen, line 25
DBGF_WAIT		equ 10h	;verbose wait functions
DBGF_TEXTMODE	equ 20h	;switch to text mode when an exception occurs
endif

if 1

VIOCOLS		equ <@bios:044Ah>	;word, number of text screen columns
VIOPAGESIZ	equ <@bios:044Ch>	;word, screen size in bytes
VIOPAGEOFS	equ <@bios:044Eh>	;word, offset of current page
VIOCSRPOS	equ <@bios:0450h>	;word[8], cursor pos for pages 0-7
VIOCSRSHAPE	equ <@bios:0460h>	;word, text cursor shape
VIOPAGE		equ <@bios:0462h>	;byte, video text page
VIOCRTPORT	equ <@bios:0463h>	;word, CRT port (3b4/3d4)
VIOROWS		equ <@bios:0484h>	;byte, number of text screen rows - 1
VIOCHARSIZE equ <@bios:0485h>	;byte, text char scan lines

else

_SEG0 segment byte use16
_PAGE0 struct
             db 400h dup (?)
             db 4ah dup (?)
_VIOCOLS     dw ?            ;+4Ah
_VIOPAGESIZ  dw ?            ;+4Ch
_VIOPAGEOFS  dw ?            ;+4Eh
_VIOCSRPOS   dw 8 dup (?)    ;+50h
_VIOCSRSHAPE dw ?            ;+60h
_VIOPAGE     db ?            ;+62h
_VIOCRTPORT  dw ?            ;+63h
             db 1Fh dup (?)  ;+65h
_VIOROWS     db ?            ;+84h
_VIOCHARSIZE db ?            ;+85h
_PAGE0 ends
_SEG0 ends

VIOCOLS     equ <@bios:_PAGE0._VIOCOLS>
VIOPAGESIZ  equ <@bios:_PAGE0._VIOPAGESIZ>
VIOPAGEOFS  equ <@bios:_PAGE0._VIOPAGEOFS>
VIOCSRPOS   equ <@bios:_PAGE0._VIOCSRPOS>
VIOCSRSHAPE equ <@bios:_PAGE0._VIOCSRSHAPE>
VIOPAGE     equ <@bios:_PAGE0._VIOPAGE>
VIOCRTPORT  equ <@bios:_PAGE0._VIOCRTPORT>
VIOROWS     equ <@bios:_PAGE0._VIOROWS>
VIOCHARSIZE equ <@bios:_PAGE0._VIOCHARSIZE>

endif

;--- dkrnl32 specific flags in PE OptionalHeader
;--- field DllCharacteristic

FKF_DISTHREADLIBCALLS	equ 1

