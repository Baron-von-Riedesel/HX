
;********** global equates **********

?MULTPSP		= 1	;1, create a PSP for every task

?LFNNT			= 0
ifndef ?LFN
?LFN            = 1     ;1, 1=support LFN
  if ?32BIT
?LFNNT          = 0
  endif
endif

ifndef ?STUB
?STUB			= 0		;0, 1=dpmildr is a stub
endif
ifndef _FILEHANDLES_
_FILEHANDLES_	= 20	;20 initial no of file handles for a task
endif

?INT24RES		= 1	;1, restore int 24 when task exits
?INT23RES		= 1	;1, restore int 23
?INT41SUPPORT	= 1	;1, support Int 41h debugging messages
?SUPAPPTITLE	= 1	;1, support for "application title" (win9x only, in rm!)
?DISABLESERVER	= 0	;0, 1=disable DPMI server for next task if DPMILDR=8;
					;   since HDPMI=32 exists, this is now obsolete
?SETDTA			= 1	;1, 1=for ?MULTPSP: init DTA to PSP:80 on start
?ZEROHIWORDEBP  = 1	;1, 1=if ?32BIT clear hiword(ebp) before 16-bit proc is called.
					;   this is essentially for ENTER/LEAVE instructions!
?32RTMBUG		= 0	;0, 1=repair 32RTM.exe bugs (doesn't work since
					;   32RTM doesn't know int 21h, ah=00
?MEMFORKERNEL   = 0	;0, 1=alloc extra memory for KERNEL

if ?32BIT                        
?DOS4G			= 1	;1, 1=support DOS4G                        
?DOS4GMEM		= 0	;0, 1=support DOS4G data segment in GS
?LOCALHEAP		= 0	;0, 1=implement local heap as in windows
_PROFSTRING_	= 0	;0, 1=support Get-/WritePrivateProfileString
else
?DOS4G			= 0
?LOCALHEAP		= 1	;1, 1=implement local heap as in windows
_PROFSTRING_	= 1	;1, 1=support Get-/WritePrivateProfileString
endif


if ?LFN
?MAXPATH	equ 260
?MAXNAME	equ 255
else
?MAXPATH	equ 65
?MAXNAME	equ 13		;8+3 + dot + terminating 0
endif

if ?DEBUG
_TRACE_		equ 1
else
_TRACE_		equ 0
endif


HBSEM_NOOPENFILEBOX	equ 80h	;high byte of wErrMode (=SEM_NOOPENFILEBOX)

;*** flags from environment variable DPMILDR
;--- 16-bit loader knows 2,8,64,256 only

;--- v3.11 break flag removed - debugger is detected via int 41h now. 
;ENVFL_BREAKATENTRY  equ 01h	;debug break at program entry
ENVFL_DONTLOADHIGH  equ 02h	;dont move in extended memory
if ?32BIT
ENVFL_DISABLENE32   equ 04h	;disable support for loading NE32 apps
endif
ENVFL_LOAD1APPONLY  equ 08h	;disable loader after first pm app has started
if ?32BIT
ENVFL_DONTPROTECT   equ 10h	;16   dont protect r/o sections (PE only)
ENVFL_DONTUSEDPMI1  equ 20h	;32   dont use any DPMI 1.0 functions
endif
ENVFL_IGNNOOPENERR	equ 40h	;64   ignore SEM_NOOPENFILEERRORBOX flag
if ?32BIT
ENVFL_IGNUNRESIMP	equ 80h	;128  ignore unresolved imports (PE only)
endif
ENVFL2_LOADDBGOUT	equ 01h	;256  try to load debugout.dll /debugo32.dll
;ENVFL2_IGN214B92	equ 02h	;512  ignore int 21h, ax=4b92h requests (module list)
if ?32BIT
ENVFL2_USEPREFADDR  equ 04h	;1024 load PE dlls at their prefered load address
ENVFL2_EXPANDDOWN   equ 08h	;2048 alloc flat DS as expand down
ENVFL2_128KBSTACK	equ 10h	;4096 restrict stack of PE add to 128 kB
ENVFL2_ALLOWGUI  	equ 20h	;8192 allow GUI apps to be loaded in win dos boxes
ENVFL2_EARLYGUIHLP  equ 40h	;16384 load hxguihlp before dll initialisation
endif

;--- fMode flags

FMODE_DISABLED	equ 01h	;bit 0: 1=loader is disabled
FMODE_OVERLAY	equ 02h	;bit 1: 1=loader loaded as overlay
FMODE_DOSEMU	equ 04h	;bit 2: 1=running on DOSEMU
FMODE_ISNT		equ 08h	;bit 3: 1=running on NT/2K/XP
FMODE_ISWIN9X	equ 10h	;bit 4: 1=running on WIN9X
FMODE_NOERRDISP	equ 20h	;bit 5: 1=temporarily suppress dpmi error messages
if ?LFN
FMODE_LFN       equ 40h ;bit 6: 1=LFN supported
endif
FMODE_DEBUGGER	equ 80h	;bit 7: 1=debugger is present

;--- fCmdLOpt flags

FO_GUI    		equ 1	;-g cmdline switch

;*** exits:
;*** 4CFB: error in loader Init (real mode)
;*** 4CFC: error in loader init (prot mode)
;*** 4CFD: error in exception 0B (segment load)
;*** 4CFE: error in app Init (prot mode)
;*** 4CFF: fatal exit
;***

RC_INITRM  equ 0FBh	;init loader real mode
RC_INITPM  equ 0FCh	;init loader protected mode
RC_EXC0B   equ 0FDh	;error in exc 0b handler (usually 16bit only)
RC_INITAPP equ 0FEh	;error in init application
RC_FATAL   equ 0FFh	;FatalExit/FatalAppExit called (16bit only)

;********** publics/externals **********

_DATA segment
externdef	wLdrDS:word
externdef	wTDStk:word
externdef	starttaskstk:byte
externdef	wMDSta:word
externdef	wLastRC:word
externdef	bEnvFlgs:byte
externdef	bEnvFlgs2:byte
externdef	fCmdLOpt:byte
externdef	wEnvFlgs:word
externdef	wErrMode:word
externdef	szPath:byte
externdef	segtable:byte
externdef	fMode:byte
externdef	wLdrPSP:word
;externdef	wCurPSP:word
externdef	fLoadMod:byte
externdef	wEquip:word
externdef	printproc:word
if _TRACE_
externdef	tprintproc:word
endif
if ?32BIT
externdef	dStktop:dword
else
externdef	wStktop:word
endif
_DATA ends

_TEXT segment
;SearchNEExport	proto near
checkne			proto near
strlen			proto near
Segment2Module	proto near
SearchModule16	proto near
;GetModuleHandle proto far pascal :far ptr byte
GetModuleHandle16 proto near
SetAppTitle		proto near
_SetErrorMode	proto near
SetCmdLine		proto near
cr_out			proto near
CreatePsp		proto near
openfile        proto near
saveint2x		proto near
string_out		proto near stdcall :ptr
string_out_prefix proto near stdcall :ptr
doscall			proto near
externdef Segment2ModuleFirst:near
externdef GetProcAddress16:near
CallAllLibEntries proto near
FreeLib16       proto near
CreateAlias     proto near
CopyDescriptor  proto near
stroutBX        proto near
InitDlls        proto near
if ?32BIT
externdef dw_2_str:near
endif
externdef w_2_str:near

_TEXT ends

;********** constants and structures ***********

;*** module database (MD)
;*** bytes 0x00-0x3F are copied from file NE-Header

NEHDR   struct
ne_magic	dw	?		;+00: contains "NE"
ne_count	dw	?		;+02: module count
ne_enttab	dw	?		;+04: ^ Entries
ne_cbenttab dw	?		;+06: length entry table (will be overwritten)
DGROFS		dw	?		;+08: offset in segment table for DGROUP
FINFO		dw	?		;+0A: FileInfo (not used)
PGMFLGS		db	?		;+0C: program flags
APPFLGS		db	?		;+0D: application flags
ne_autodata	dw	?		;+0E: no of DGROUP segment (needn't exist!)
ne_heap		dw	?		;+10: heap space (bytes/pages)
ne_stack	dw	?		;+12: extra stack space (bytes/pages)
ne_csip		dd	?		;+14: CS:IP
ne_sssp		dd	?		;+18: SS:SP
ne_cseg 	dw	?		;+1C: number of segments
ne_cmod 	dw	?		;+1E: number of referenced modules
NRESLEN		dw	?		;+20: length of table nonres names
ne_segtab	dw	?		;+22: ^ segment table
ne_rsrctab	dw	?		;+24: ^ resource table
ne_restab   dw	?		;+26: ^ resident names table
ne_modtab	dw	?		;+28: ^ module table (=module references)
ne_imptab	dw	?		;+2A: ^ imported names table
NRESADR		dd	?		;+2C: address nonresident names (DWORD)
ne_cmovent	dw	?		;+30: moveable entry points in entry table
SEGSHFT		dw	?		;+32: shift faktor
ne_cres		dw	?		;+34: number of resource table entries
ne_exetyp	db	?		;+36: operating system
ne_flagsothers	db	?	;+37: exe flags (long filenames, prop font)
ne_pretthunks	dw	?	;+38: start of gangload area?
ne_psegrefbytes	dw	?	;+3A: length of gangload area?
ne_swaparea	dw	?		;+3C: codeswap
ne_expver	dw	?		;+3E: expected windows version
NXTFREE		dw	?		;+40: offset free space in this MD
NRESNAM		dw	?		;+42: ^ nonresident names
ne_hFile	dw	?		;+44: file handle of .EXE image
MEMHDL		dd	?		;+46: dpmi memory handle of MD (DWORD)
szModPath   db	?		;+4A: offset to binary full path
NEHDR   ends

NXTMOD  equ <ne_cbenttab>
MDCONST equ <szModPath> ;size of MD without binary full path

;--- program flags

;PF_NONE	equ 00h		;bits 0+1: 00 no DGROUP
;PF_SINGLE	equ 01h		;bits 0+1: 01 single DGROUP
PF_MULTIPLE	equ 02h		;bits 0+1: 10 multiple DGROUPs
;PF_GLOBALINIT equ 04h	;bit 2: global initialization
;PF_PROTMODE equ 08h	;bit 3: protected mode only
;PF_8086				;bit 4: 8086 instructions
;PF_80286				;bit 5: 80286 instructions
;PF_80386				;bit 6: 80386 instructions
;PF_80X87				;bit 7: 80x87 instructions

;--- application flags

;--- bits 0-2:
;--- 000=fullscreen
;--- 001=windows aware
;--- 010=uses windows API

;AF_WINAPI	equ 02h

;AF_FAMILY	equ 08h		;bit 3: OS2: family app; Win16: self-loading
AF_BIT4		equ 10h		;bit 4: for code segments, alloc another descriptor if this bit is set
;AF_ERROR	equ 20h		;bit 5: error in image
AF_INIT		equ 40h		;bit 6: dlls: LibEntry done
AF_DLL		equ 80h		;bit 7: module is dll

;--- ne_exetyp

ET_UNKNOWN  equ 0   
ET_OS2		equ 1	
ET_WINDOWS	equ 2
ET_DOS4 	equ 3	
ET_WIN386	equ 4
ET_DPMI16	equ 5
ET_DPMI32	equ 6		;this is known by HX only

;----------------------------------------------------

;*** segment table entry ***
;*** first 4 words are in segment table of file as well

SEGITEM struct
filepos dw  ?       ;segment position in file (without shift factor)
filesiz dw  ?       ;segment size in file
flags   dw  ?       ;segment flags (see below)
memsiz  dw  ?       ;size in memory
wSel    dw  ?       ;standard selector
dwHdl   dd  ?       ;DPMI memory handle (0x0501)
wDosSel dw  ?       ;selector for DOS memory alloc (0x0100)
SEGITEM ends

SGTSIZE equ SIZE SEGITEM

;--- segment flags

SF_DATA   equ 0001h		;1=DATA, 0=CODE
SF_LOADED equ 0002h		;1=segment is loaded in memory
SF_RES1   equ 0004h
SF_ITERED equ 0008h		;1=ITERATED (OS/2 only)
SF_MOVABL equ 0010h		;1=MOVEABLE, 0=FIXED
SF_SHARED equ 0020h		;1=SHARED, 0=NONSHARED
SF_PRELOD equ 0040h		;1=PRELOAD, 0=LOADONCALL
SF_RDONLY equ 0080h		;1=READONLY, 0=R/W
SF_RELOCS equ 0100h		;1=relocations exist for this segment
SF_CONFRM equ 0200h		;1=conforming segment (OS/2 only)
SF_RES2   equ 0C00h		;00,01,02,03=priviledge level (OS/2 only)
SF_DISCRD equ 1000h		;1=DISCARDABLE, 0=NONDISCARDABLE
SF_32BIT  equ 2000h		;1=MIXED3216
SF_RES4   equ 4000h		;1=huge segment (OS/2 only)
SF_RES5   equ 8000h
SF_ALIAS  equ 8000h

;*** task structure ***
;--- missing: wErrorMode ***

TASK struct

if ?32BIT
dwESP   dd ?        ;SS:ESP of previous task
else
wSP     dw ?        ;SS:SP of previous task
endif
wSS     dw ?

if ?32BIT
union
dwModul dd ?        ;module selector/linear address
struct
wModul	dw ?
		dw ?
ends
ends
else
wModul  dw ?        ;module selector
endif

if ?MULTPSP
wPSP    dw ?        ;PSP (selector or segment?)
if ?SETDTA
if ?32BIT
dta	df ?		;dos disk transfer area
else
dta	dd ?
endif
endif
endif

if ?INT23RES
if ?32BIT
dfI23   df ?        ;previous int 23 vector
else
dwI23   dd ?        ;previous int 23 vector
endif
endif

if ?INT24RES
if ?32BIT
dfI24   df ?        ;previous int 24 vector
else
dwI24   dd ?        ;previous int 24 vector
endif
endif

if ?32BIT
wFlags	dw ?
endif

TASK ends

;********** Macros **********

;-- define a string

CStr macro string:vararg
local NewStr
CCONST   segment
NewStr  db string
        db 00
CCONST   ends
	exitm <offset NewStr>
endm

@swap macro x,y
	push x
	push y
	pop x
	pop y
	endm

;--- @saveregs, @restoreregs

@saveregs_exec macro
if ?32BIT
	push gs
	push es
	push ds
	pushad
?SIZE_SAVEREGS equ 8*4+3*2
else
	push es
	push ds
	pusha
?SIZE_SAVEREGS equ 8*2+2*2
endif
	endm

@restoreregs_exec macro
if ?32BIT
	popad	;get register from application stack
	pop ds
	pop es
	pop gs
else
	popa
	pop ds
	pop es
endif
	endm

;--- @iret, @retf, @pusha, @popa

@iret macro
if ?32BIT
	iretd
else
	iret
endif
	endm

@retf macro
if ?32BIT
	db 66h
endif
	retf
	endm

@pusha macro
if ?32BIT
	pushad
else
	pusha
endif
	endm

@popa macro
if ?32BIT
	popad
else
	popa
endif
	endm

@condbrk macro what
ifndef what
what equ 0
endif
endm

	@condbrk _INT03PGMEXIT_		;0 1=int 03 on program termination
	@condbrk _INT03RETEXEC_		;0 1=int 03 after int 21h, ax=4B00h
	@condbrk _INT03NAMEIMP_		;0 1=int 03 on a "reference by name"
	@condbrk _INT03JMPPM_		;0 1=int 03 after initial switch to protected mode
	@condbrk _INT03REALLOC_		;0 1=int 03 on realloc memory block
	@condbrk _TESTIMPORT_		;0 1=display debug msg on relocation fixups

@int3 macro x	;conditional break
if x
	int 3
endif
endm

;-------------------------

