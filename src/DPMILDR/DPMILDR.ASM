
	page ,132

;*** HX loader for 16/32-Bit DPMI Apps
;*** names:
;*** 32Bit loader: DPMILD32.EXE
;*** 16Bit loader: DPMILD16.EXE

;--- best viewed with TABSIZE 4

if ?DEBUG
?EXTLOAD		 = 0	;0 dont move loader in extended memory
else
?EXTLOAD		 = 1	;1 move loader in extended memory
endif

ifndef ?HDPMI
?HDPMI			= 0		;0 1=assume HDPMI is included (stand-alone MZ stub)
endif

?RMSEGMENTS		 = 0	;0 1=support realmode segments (doesn't work!)
?DOSAPI			 = 1	;1 1=activate DOS API translation, required for OS/2
ifndef ?LOADDBGDLL
?LOADDBGDLL		 = 1	;1 load DEBUGOUT.DLL on startup if DPMILDR=256
endif
ifndef ?SERVER
?SERVER			 = 1	;1 1=load DPMI host HDPMIXX.EXE if no DPMI installed
endif
?CLOSEALLFILES	 = 0	;0 1=close all files before fatal exit
_CLEARENV_		 = 0	;0 if ?MULTPSP=1: clear PSP:[002C] on exit task
_LOADERPARENT_	 = 1	;1 if ?MULTPSP=1: set PSP:[0016] to ldr PSP on exit task
_SETPSP_		 = 1	;1 if ?MULTPSP=1: set owner in MCB to current PSP
?USELOADERPSP	 = 0	;1 1=switch to ldr PSP for segment loads.
						;  0=for DOS MCB's, set PSP manually to the loader's	
_SUPRESDOSERR_	 = 1	;1 bei _RESIZEPSP_: suppress error msg
_WIN87EMWAIT_	 = 0	;0 1=for WIN87EM.DLL always resolve fixup 6
_LINKWORKAROUND_ = 1	;1 1=fix bug in old linkers (caps/small)
_UNDEFDYNLINK_	 = 0	;0 1=resolve missing imports with UndefDynLink()
_SETCSLIM_		 = 0	;0 1=adjust CS limit of loader (if ?EXTLOAD=0)
_SETDSLIM_		 = 0	;0 1=adjust DS limit of loader (if ?EXTLOAD=0)
?MAXSEG			 = 255	;255 max number of segments for a module (8 Bit!)
_ACCDATA_		 = 12h	;12h value for accessrights data segments (memory,r/w)
_ACCCODE_		 = 1Ah	;1Ah value for accessrights code segments (memory,e/r)
_MAXTASK_		 = 8	;8 max. number of task recursion 
_SFLAGS_		 = 20h	;share flags to use for file open (20h=deny write)
_ONLY4B00_		 = 1	;1 1=catch int 21,4B00h+4B01, ignore 4B02-4B7F
_LASTRC_		 = 1	;1 1=catch int 21h, AH=4D
_TRAPEXC0D_ 	 = 0	;0 1=watch exception 0D (GPFs)
?EXC01RESET 	 = 0	;0 1=restore exc 01 when terminating
_CHKLIBENTRYRC_  = 1	;1 1=error if LibEntry returns ax=0
_CHECKSEGSIZE_	 = 1	;1 1=check segment size (security check for relocs)
_SUPTSR_		 = 1	;1 1=support and watch int 21,AH=31h 
_WINNT40BUG_	 = 1	;1 1=workaround for bug in nt 4.0 for 32bit clients:
						;  NP exceptions didn't work
_RESIZEPSP_ 	 = 1	;1 1=resize loader psp to 120h after moved in ext. memory
?FASTCSCHANGE	 = 0	;0 1=modify CS attributes directly (critical)
?GSFLAT			 = 1	;1 1=GS has zero based flat selector for 32bit apps
?CHECKTOP		 = 0	;0 1=check if this instance of the loader is the
						;  current one if an app is terminating. (doesnt work
						;  yet!)
?COPYENV		= 1		;1 1=copy environment ptr at PSP:[2Ch] to child psp.
						;  required for FreeDOS
?DOSEMUSUPP		= 1		;1 1=support DOSEMU
?PHARLABTNT		= 1		;1 1=support PharLab TNT executables (PL) (32bit only)
?HIDENEASWELL	= 1		;1 1=hide loader and server for NE exes if DPMILDR=8
?CHECKCALLER	= 0		;0 1=??? (had this ever worked?)
?SETINIT		= 1		;1 1=set init flag for Dlls
?SLOADERR		= 1		;1 1=display exact error why HDPMI cannot be loaded
?MAKENEWENV		= 1		;1 1=make new environment if task > 0
?LOWENV			= 1 	;1 1=alloc new env in dos memory (0 not finished!)
?FREECHILDSELS	= 1		;1 1=free selectors for psp+env
?USE1PSP		= 1		;1 1=use just 1 psp if DPMILDR=8
ifndef ?STDERR
?STDERR	equ 2
endif

ifndef ?KERNEL16
?KERNEL16		= 1		;1
endif

?RESETDEFPATH	= 0		;0 1= reset szPath? No, currently this is done
						;  every time a .EXE is loaded
?PSPSAVEI2FADDR	= 007Ch	;address in PSP to save int vector 2Fh

if ?HDPMI
_COPY2PSP_		 = 0
else
_COPY2PSP_		 = 1	;1 1=copy termination code to psp at the end
endif

if ?32BIT
_DISCARD_		= 0		;0 1=remove discardable segments if out of memory
?OS2COMPAT		= 0		;0 1=OS/2 compatible app entry call
?AUTOCSALIAS	= 0		;0 1=alloc a CS alias for each code segment
  ifndef ?NEAPPS
?NEAPPS			= 1		;1 0=dont support NE apps
  endif
else
_DISCARD_		= 1		;1 1=remove discardable segments if out of memory
?OS2COMPAT		= 1		;1 1=OS/2 compatible app entry call
?AUTOCSALIAS	= 1		;1 1=optionally alloc a CS alias for code segments
?NEAPPS			= 1		;1 0=dont support NE apps
endif

ENVIRON equ 2Ch
PARPSP	equ 16h

;*** define segments ***

if ?32BIT
		.386
?PESUPP = 1
;;?use16	= 1		;obsolete
@use16	textequ <use16>

else
		.286
		
?PESUPP = 0
@use16	textequ <>
endif
		option casemap:none
		option proc:private

if ?HDPMI
HDPMI	segment para @use16 public 'CODE'
HDPMI	ends
endif
_TEXT	segment dword @use16 public 'CODE'
_TEXT	ends
CCONST	segment word @use16 public 'CODE'
CCONST	ends
_DATA	segment word @use16 public 'DATA'
_DATA	ends

		include ascii.inc
		include dpmi.inc
		include fixups.inc
		include dpmildr.inc
		include debug.inc
		include debugsys.inc
		include version.inc
if ?KERNEL16
		include kernel16.inc
endif
if ?PESUPP
		include peload.inc
		include winnt.inc
		include mzhdr32.inc
endif

_ITEXT	segment word @use16 public 'DATA'	;use 'DATA' (OPTLINK bug)
_ITEXT	ends
if ?STUB
ENDSTUB segment para @use16 public 'DATA'
		db 16 dup (0)
ENDSTUB ends
endif
_BSS	segment word @use16 public 'BSS'
_BSS	ends
STACK	segment para @use16 stack  'STACK'
STACK	ends

if ?HDPMI
HDPMI	segment
  if ?32BIT
		include ..\hdpmi\stub32\hdpmi32.inc
  else
		include ..\hdpmi\stub16\hdpmi16.inc
  endif
  		align 16
endhdpmi label byte        
HDPMI	ends
endif

if ?STUB
DGROUP	group _TEXT,CCONST,_DATA,_ITEXT,ENDSTUB,_BSS,STACK
else
DGROUP	group _TEXT,CCONST,_DATA,_ITEXT,_BSS,STACK
endif

ife ?EXTLOAD
_COPY2PSP_		 = 0
_RESIZEPSP_ 	 = 0
endif

		assume CS:DGROUP
		assume DS:DGROUP
		assume SS:NOTHING
		assume ES:DGROUP

;*** Stack ***

STACK segment
if ?32BIT
if _TRACE_
		db 480h dup (?)
else
		db 280h dup (?)
endif
endif
		db 180h dup (?)

stacktop label byte
STACK ends

;*** constants ***

;*** variables ***

_DATA segment

;*** global constants, initialized during start

aliassel dw 0			;selector for data alias code segments
if ?32BIT
dStktop  dd 0			;top stack pointer
else
wStktop  dw 0			;top stack pointer
endif

;*** global variables

wMDSta	 dw 0			;segment of 1. element of 16bit MD table
wTDStk	 dw offset starttaskstk ;LIFO stack for tasks
if ?LOADDBGDLL
hModDbg  dw 0			;handle for DEBUGOUT.DLL
endif
if ?HDPMI
wResHDPMI dw 0
endif
fLoadMod db 0			;flag: LoadModule() called int 21h, ax=4B00h
if ?EXTLOAD
fHighLoad db 0			;1 if loader has been moved in extended memory
endif

fMode	 db 0			;FMODE flags
wEnvFlgs  label word
bEnvFlgs  db 0
bEnvFlgs2 db 0

ife ?STUB
fCmdLOpt  db 0			;additional option from cmdline ("-g")
endif

;*** variables used temporarily

callcs	 dw 0			;current CS for NP exceptions
wLastRC  dw 0			;RC of last app
if ?32BIT
if ?DOSEMUSUPP
execpm	dw 0,offset segtable,0,0,0,0,0	;exec parameter block
endif
endif

;*** task specific variables

_start_of_instancedata label byte
wErrMode dw 0			 ;ErrorMode
_end_of_instancedata label byte

_DATA ends

_BSS segment

;*** global constants, initialized during start

wDPMIFlg	dw ?			;DPMI init call CX flags (CL=CPU[2,3,4],CH=??)
wDPMIVer	dw ?			;DPMI init call DX Flags (DPMI version)
wEquip		dw ?			;Int 11h Equipment flags (only bit 1 used)
wCSlim		dw ?			;limit CS (=CSSIZE-1), size of loader segment incl. stack
wVersion	dw ?			;DOS version major+minor
if ?EXTLOAD
dwMemHdl	dd ?			;DPMI memory handle for loader segment
endif
wlError		dw ?			;error code (for function 4B00h)

;*** std variables, initialization ensured/not required
ife ?MULTPSP
wCurPSP	label word
endif
wLdrPSP		dw ?			;PSP selector of loader
wRMPSP	 	dw ?			;PSP segment of loader
if ?MULTPSP
wCurPSP  	dw ?			;PSP selector of current app
endif

starttaskstk db size TASK * _MAXTASK_ dup (?)
endtaskstk label byte

szName		db ?MAXNAME dup (?)	;moved from behind szPath because of a bug
								;in DPMIONE (int 21h, ah=47h)
szPgmName	db ?MAXPATH dup (?)	;program name from command line
szModName	db ?MAXPATH dup (?)	;module name (absolute path)
szPath		db ?MAXPATH dup (?)	;path of current .EXE (is default for DLLs)
NE_Hdr		label NEHDR			;NE header buffer
MZ_Hdr		db 40h dup (?)		;MZ header buffer (same memory as NE header
relbuf		label byte			;relocation buffer
segtable	db ?MAXSEG * 8 dup (?);segment table (temporarily MZ-Header)
RELSIZE		equ ?MAXSEG * 8		;size relocations buffer
ParmBlk		dd 6 dup (?)		;parameter block for "exec prog"

;*** temp variables
blksize		dd ?			;limit for memory allocs
blkaddr		dd ?			;address for memory allocs
wCnReloc	dw ?			;number of relocations for a segment
NEHdrOfs	dw ?			;offset NE-Header
wMDSize		dw ?			;size MD
wRelTmp		dw ?			;buffer pointer for relocations

_BSS ends

_ITEXT segment

if ?SERVER
if ?32BIT
HostName db "HDPMI32.EXE",00
else
HostName db "HDPMI16.EXE",00
endif
SIZE_HOSTNAME equ $-HostName
endif

if ?LOADDBGDLL
if ?32BIT
szDbgout   db '.\DEBUGO32.DLL',0
else
szDbgout   db '.\DEBUGOUT.DLL',0
endif
endif

ife ?STUB        
versionstring textequ @CatStr(!",%?VERMAJOR,.,%?VERMINOR,.,%?VERMINOR2,!")
szHello    db lf
		   db 'DPMI loader version ',versionstring,lf
		   db 'Copyright (C) 1993-2010 Japheth',lf,lf,00
endif           
szInitErr  db 'Error in initialization, loading aborted',lf,00
szShrkErr  db 'memory shrink Error',lf,00
szNoDPMI   db 'No DPMI server available',lf,00
if ?32BIT
szNo32Bit  db "DPMI server doesn't support 32-bit apps",lf,00
endif
errstr2    db 'Error allocating memory for DPMI server',lf,00
errstr3    db 'Error switching to protected mode',lf,00
ife ?STUB
errstr8    db 'Filename missing or invalid',lf,00
endif
if ?DOSAPI
;szAPIerr	db "DOS API translation not supported",lf,00
szDOSstr	db "MS-DOS",00
endif
szLoader	db 'DPMILDR=',0
if ?DOSEMUSUPP
szDosEmuDate db "02/25/93"
endif

_ITEXT ends

CCONST segment

defdgrp  dw 0,0,SF_DATA or SF_MOVABL,0	;default segment flags for dgroup

fpOSFixups label byte			 ;Floating Point OS-fixups
	  dw FIARQQ,FJARQQ
	  dw FISRQQ,FJSRQQ
	  dw FICRQQ,FJCRQQ
	  dw FIERQQ,0
	  dw FIDRQQ,0
	  dw FIWRQQ,0

szTerm	   db 'Application will be terminated',lf,00
szErr31    db 'memory allocation (DPMI) for segment load failed',lf,00
szErr311   db 'memory realloc failed',lf,00
szErr32    db 'Freeing memory failed. ',0
szErr33    db 'DPMI 0000: Allocate descriptor',lf,00
szErr34    db 'DPMI 0007: Set segment base address',lf,00
szErr35    db 'DPMI 0008: Set segment limit',lf,00
szErr36    db 'DPMI 0009: Set descriptor access rights',lf,00
szErr37    db 'DPMI 000B: Get descriptor',lf,00
szErr23    db "Invalid module handle "
es23hdl    db "    ",lf,00
szErr22    db "file is corrupt",lf,00
szErr21    db "stack segment of parent destroyed",lf,00
errstr19   db "Can't create PSP (insufficient DOS memory)",lf,00
if ?NEAPPS
errstr20   db "Can't load a 2. instance of an app",lf,00
errstr17   db 'Stack segment is readonly',lf,00
errstr16   db 'Module has no stack',lf,00
endif
errstr15   db 'DLL initialization error',lf,00
errstr14   db 'Relocatable code has zero relocations',lf,00
errstr13   db 'Invalid FixUp Type in relocation table',lf,00
if ?32BIT
szNotaNE	label byte
  if ?NEAPPS
           db 'File is no 32-bit NE application',lf
  endif
           db 00
else
szNotaNE   db 'File is no 16-bit NE application',lf,00
endif
errstr11   db 'Too many segments in EXE',lf,00
if ?NEAPPS
errstr10   db 'Program has no valid start address',lf,00
endif
errstr9    db 'Cannot allocate required memory',lf,00
errstr7    db 'Error while loading segment',lf,00
errstr6    db 'File read error',lf,00
errstr5    db 'Inconsistent module table size',lf,00
int0Berr1  db 'Invalid not present exception',lf,00
if _TRAPEXC0D_
exc0derr   db lf,'protection exception occured',lf,0
endif
if ?SLOADERR
errstr26   db "can't load ",00
endif
szNotFnd   db 'File not found error',lf,00
nohandles  db 'Out of file handles error',lf,00
szLoadErr  db "Load error. ",0

szModule    db "Module ",0
szSegment   db ", segment "
SegNo   	db "00.",0

errstr24	db 'Entry 0x'
LENTERR		db 0,0,0,0,' not found in module ',00
errstr25	db ' not found in name tables of module ',00

modtext		db 'Module: ',00


szExtErr	db 'Last DOS Error:'
			db lf,9,'Extended Error Code '
szExtErrCod	db 4 dup (0)
			db ', Error Class '
szExtErrCls	db 2 dup (0)
			db lf,9,'Suggested Action '
szExtErrAct	db 2 dup (0)
			db ', Locus '
szExtErrLoc	db 2 dup (0)
			db lf,0

szDpmiErr	db 'DPMI function 0x'
dpmifunc	db 0,0,0,0
			db ' failed at 0x'
dpmicaller	db 0,0,0,0
szLF		db lf,0

szEntryErr	db 'Error code 0x'
szEntryCode	db 4 dup (0)
			db ' from LibEntry '
szLibName	db 40h dup (0)

szPathConst db 'PATH=',0
if 0;e ?32BIT
szCmdline	db 'CMDLINE=',0
endif
szWEP		db 'WEP'
szDotDLL	db '.DLL'
nullstr		db 00

if ?RMSEGMENTS
errstr41   db 'PMtoRMCallTHUNK: Cannot convert Selector',lf,00
errstr42   db 'PMtoRMCallTHUNK: Cannot call real mode procedure',lf,00
errstr43   db 'PMtoRMCallTHUNK: Invalid THUNK instruction',lf,00
endif

CCONST ends

_TEXT segment

;*** if the loader is loaded as overlay (by DPMIST32.BIN)
;*** DS:DX will point to full path of DPMILDXX.EXE
;*** and DS:BX will have path of program to load
;*** (bad design, but cannot be changed anymore)

;*** the dpmi host will only be searched in directory of the loader!

wLdrDS label word
	jmp overlayentry

if ?DISABLESERVER

int2frm:
  if ?HIDENEASWELL
	cmp ah, 16h
  else
	cmp ax, 1687h
  endif
	jz @F
	jmp dword ptr cs:[?PSPSAVEI2FADDR]
@@:
	iret
endif

if _COPY2PSP_
psp_rou:
	int 31h		;free extended memory
	mov ax,1
	int 31h
	pop ax
	mov ah,4Ch
	int 21h
endif

endoflowcode label byte


if ?CHECKCALLER
ctxt	db "DPMILDR"
lctxt	equ $ - ctxt
endif

overlayentry:
ife ?STUB
	push es
if ?KERNEL16
	mov di,offset KernelNE.szModPath
else
	mov di,offset segtable
endif
	push cs
	pop es
	mov si,dx
@@:
	lodsb
	stosb
	and al,al
	jnz @B
	mov di,offset szPgmName
	mov si,bx
@@:
	lodsb
	stosb
	and al,al
	jnz @B
	pop es
	or byte ptr cs:[fMode],FMODE_OVERLAY
	jmp step2
endif

;--- entry for .EXE

main:
	cld
	push es
	mov es,ds:[ENVIRON] ;get environment
	xor di,di
	or  cx,-1
	xor ax,ax
@@:
	repnz scasb			;search end of environment
	scasb				;found?
	jnz @B				;no, continue
	inc di				;skip 0001
	inc di				;now comes current file name
if ?KERNEL16
	mov si,offset KernelNE.szModPath
else
	mov si,offset segtable
endif
@@:
	mov al,es:[di]
	mov cs:[si],al
	inc si
	inc di
	and al,al
	jnz @B
	pop es
step2:
	push cs
	pop ds
	mov wLdrDS,ds
	push ds
	pop ss
	mov sp,offset stacktop
	mov [wRMPSP],es
	mov [wLdrPSP],es		;this will be changed to a selector
if ?STUB
	mov [wCurPSP],es		;this also
endif
	mov ah,30h
	int 21h
	mov [wVersion],ax

	mov ax,sp
	dec ax
	mov [wCSlim],ax
	sub ax,001Fh	;important: make 32 bytes room on stack
if ?32BIT
;	movzx eax,ax
	mov word ptr [dStktop],ax
else
	mov [wStktop],ax
endif
	mov bx,sp
	shr bx,4
if ?HDPMI
	mov ax,cs		;it's not a TINY model if HDPMI is included!
	mov cx,es
	sub ax,cx
	add bx,ax
else
	add bx,10h		;+ PSP
endif
	mov ah,4Ah		;now shrink memory (Real Mode)
	int 21h
	mov bx,offset szShrkErr
	jc main_err1	;shrink error (can this happen?)
if ?DOSEMUSUPP
	push 0F000h
	pop es
	mov di,0FFF5h
	mov si,offset szDosEmuDate
	mov cx,8
	repz cmpsb
	jnz @F
	or byte ptr [fMode], FMODE_DOSEMU
@@:
endif

if ?LFN
						;detect if lfn is installed
	mov ax,7147h
	mov si,offset szPath
	mov dl,0
	stc
	int 21h
	jc @F
	or fMode, FMODE_LFN
@@:
endif
	int 11h 			;get equipment flags (MPC)
	mov [wEquip],ax
	call JumpToPM		;initial switch to protected mode
	jnc @F
main_err1:
	call strout_err
	mov ax,4C00h + RC_INITRM
	int 21h
@@:
if ?DOSAPI
	mov si,offset szDOSstr
	mov ax,168Ah
	int 2Fh
	cmp al,0
	jz @F
	@trace_s <"fatal: no DOS API translation",lf>
	mov ax,4C00h + RC_INITPM	;just exit, dont display anything
	int 21h
@@:
	@trace_s <"DOS API translation initiated",lf>
endif
	mov dx,offset szLoader	;find env variable "DPMILDR="
	call GetLdrEnvironmentVariable
	jc @F
	call getnum
	mov wEnvFlgs,ax
@@:
	mov ax,3306h
	int 21h
	cmp bx,3205h				;NT, 2k, XP?
	jnz @F
	or fMode, FMODE_ISNT
if ?LFN
ife ?LFNNT
	and fMode, not FMODE_LFN
endif
endif
	or bEnvFlgs, ENVFL_DONTUSEDPMI1
@@:
	mov ax,1600h
	int 2Fh
	and al,al
	jz @F
	or fMode, FMODE_ISWIN9X
@@:
if ?32BIT
	test fMode, FMODE_ISNT or FMODE_ISWIN9X
	jnz @F
	or bEnvFlgs2, ENVFL2_ALLOWGUI
@@:
endif
if 0	;not needed currently
	mov ax,004Fh
	int 41h
	cmp ax,0F386h
	jnz @F
	or fMode, FMODE_DEBUGGER
@@:
endif
	call InitProtMode	;init vectors, alloc internal selectors
	jc main_err6		;--->
ife ?STUB
	test [fMode],FMODE_OVERLAY
	jnz main_1
	@strout szHello,1
main_1:
endif
	mov szPath,0
if ?KERNEL16
	call InitKernel	   ;init MD for KERNEL
endif
	call GetPgmParms	   ;program name -> szPgmName, exec parm init
	jc main_err3	   ;---> error: no program name given
	call setvec21	   ;now set int 21h vector
if ?LOADDBGDLL
	call loaddbg
endif
	mov dx,offset szPgmName ;ptr module name
	mov bx,offset ParmBlk	;ptr exec parameter block
if ?32BIT
	movzx edx,dx
endif
	push ds
	pop es
	mov ax,4B00h	;launch program
	int 21h
	jc @F
	mov ah,4Dh
	int 21h
@@:
fatalerror:
	push ax
	@trace_s <"*** last task terminated (RC=">
	@trace_w ax
	@trace_s <"), will exit now ***",lf>
	call freemodulerest ;free modules not unloaded yet
if ?CHECKTOP
	call areweontop
	jz @F
	pop ax
	mov ah,4Ch
	int 21h
@@:
endif
	call resetvecs
	@trace_s <"*** bye from DPMILDXX ***",lf>
	pop ax
if _COPY2PSP_		;free all memory (problem: we are running in
					;it!)
	call copy_to_psp_and_exit
endif
	mov ah,4Ch
	int 21h 		;and exit loader
main_err6:			;protected mode init error
	mov ax,offset szInitErr
main_err3:
	mov bx,ax		;AX might have "missing filename"
	@strout_err		;DOS API is ensured to be available!
	mov al,RC_INITPM
	jmp fatalerror
if 0
main_err4:
	mov ds,cs:[wLdrDS]
	call stroutax
	@strout szTerm,1
if ?CLOSEALLFILES
	call CloseAllFiles
endif
	mov al,RC_INITPM
	jmp fatalerror
endif

;-------------------------------------------------------
if _TRAPEXC0D_
LEXC0D:
	push cs:[wLdrDS]
	mov ax,offset exc0derr
	push ax
	push cs
	call near ptr FatalAppExit
endif

if ?USELOADERPSP

;--- this was called to ensure
;--- 1. DOS memory blocks get the loader's PSP
;--- 2. the file handle for the file to be opened is owned by the loader
;--- now this code is no longer called. The PSP of the DOS memory blocks is
;--- set manually to the loader's.

setldrpsp proc
	push ax
	mov ah,51h
	int 21h
	push bx
	mov bx,[wLdrPSP]
	mov ah,50h
	int 21h
	pop bx
	pop ax
	ret
setldrpsp endp
resetldrpsp proc
	pushf			;preserve carry flag!
	push ax
	mov ah,50h
	int 21h
	pop ax
	popf
	ret
resetldrpsp endp
endif

;*** exception 0Bh handler
;--- called if segments marked "not present" are accessed

Exc0BProc proc

DPMIEXC struct
if ?32BIT
		dd ?
		dd ?
errcode	dd ?
_eip	dd ?
_cs		dw ?
		dw ?
_eflags	dd ?
_esp	dd ?
_ss		dw ?
		dw ?
EXCERRC	equ [ebp+20h].DPMIEXC.errcode
EXCIP	equ [ebp+20h].DPMIEXC._eip
EXCCS	equ [ebp+20h].DPMIEXC._cs
EXCFL	equ [ebp+20h].DPMIEXC._eflags
EXCSP	equ [ebp+20h].DPMIEXC._esp
EXCSS	equ [ebp+20h].DPMIEXC._ss
EXCAX	equ [ebp+1Ch]
EXCCX	equ [ebp+18h]
EXCSI	equ [ebp+04h]
else
		dw ?
		dw ?
errcode	dw ?
_ip		dw ?
_cs		dw ?
_flags	dw ?
_sp		dw ?
_ss		dw ?
EXCERRC	equ [bp+10h].DPMIEXC.errcode
EXCIP	equ [bp+10h].DPMIEXC._ip
EXCCS	equ [bp+10h].DPMIEXC._cs
EXCFL	equ [bp+10h].DPMIEXC._flags
EXCSP	equ [bp+10h].DPMIEXC._sp
EXCSS	equ [bp+10h].DPMIEXC._ss
EXCAX	equ [bp+0Eh]
EXCCX	equ [bp+0Ch]
EXCSI	equ [bp+02h]
endif
DPMIEXC ends

	test cs:[fMode], FMODE_DISABLED
	jnz calloldexc0b
if ?32BIT
	pushad
	mov ebp,esp
	movzx edx,dx
	movzx ecx,cx
	mov ebx,EXCERRC
else
	pusha
	mov bp,sp
	mov bx,EXCERRC
endif
	push ds
	push es
	mov ds,cs:[wLdrDS]
	@trace_s <"*** exc 0B handler, ErrCode=">
if ?32BIT
	@trace_d ebx
else
	@trace_w bx
endif
	@trace_s <",cs:ip=">
	@trace_w EXCCS
	@trace_s <":">
if ?32BIT
	@trace_d EXCIP
else
	@trace_w EXCIP
endif
	@trace_s <",ss:sp=">
	@trace_w EXCSS
	@trace_s <":">
if ?32BIT
	@trace_d EXCSP
else
	@trace_w EXCSP
endif
	@trace_s <" ***",lf>
	push 0
	pop es
	mov ax,cs
	and al,03
	or bl,al
	call GetNPBase				;segm-desc -> ES:SI
	jc error
	mov ax,EXCCS
if ?RMSEGMENTS
	test byte ptr es:[si.SEGITEM.flags],SF_RES1
	jz @F
	call ExecRMProc				;Call Real Mode Proc
	jc error					;error exit (AX->ErrText)
	jmp done
@@:
endif
if ?USELOADERPSP
	call setldrpsp
	push bx
endif
	call Load_Segm				;load segment
if ?USELOADERPSP
	pop bx
	call resetldrpsp
endif
	jnc done
error:							;error in exc 0B will terminate task
	mov EXCIP, offset exc0berrorexit
	mov EXCCS, cs
	mov EXCAX, ax
	mov EXCCX, es				;will hold NE module (or NULL)
	mov EXCSI, si
done:
	@trace_s <"*** exception 0B handler exit ***",lf>
	pop es
	pop ds
	@popa
	@retf
calloldexc0b:
if ?32BIT
	db 66h
	db 0eah			   ;jmp ssss:oooooooo
oldexc0b df 0
else
	db 0eah			   ;jmp ssss:oooo
oldexc0b dd 0
endif
Exc0BProc endp

;--- an invalid exception 0Bh occured

exc0berrorexit proc
	mov ds,cs:[wLdrDS]
if 0
	push ds
	pop ss
  if ?32BIT
	mov esp,[dStktop]
  else
	mov sp,[wStktop]
  endif
endif
	push cx
	call stroutax			;display text ^AX
	pop cx
	jcxz @F					;no valid NE hdr!
	mov es, cx
	push offset szLoadErr
	call stroutstk_err
	call displaymodandseg

;--- display <Modulename>.<Segment#> in ES:SI

@@:
	@strout_err szTerm,1
if ?CLOSEALLFILES
	call CloseAllFiles
endif
;	int 3
	mov ax,4C00h + RC_EXC0B
	int 21h

exc0berrorexit endp

displaymodandseg proc        
	push offset szModule
	call stroutstk
	call modnameout			;expects ES=NE hdr
	mov ax, si
	sub ax, es:[NEHDR.ne_segtab]
	shr ax, 3+1				;size of segment table in ES is 16!!!
	inc ax
	mov di, offset SegNo
	call BYTEOUT
	push offset szSegment
	call stroutstk
	@cr_out
	ret
displaymodandseg endp

if _TRAPEXC0D_
if ?32BIT
oldexc0D df 0
else
oldexc0D dd 0
endif
endif

if ?EXC01RESET
if ?32BIT
oldexc01 df 0
else
oldexc01 dd 0
endif
endif

if ?TRAPINT41
myint41 proc
	cmp ax,0
	jz ischarout
if ?32BIT
	cmp ax,2
	jz isstrout
else
	cmp ax,12h
	jz isstrout
endif
	jmp cs:[oldint41]
isstrout:
	cld
	push dx
if ?32BIT
	push esi
nextitem:
	lods byte ptr [esi]
else
	push si
nextitem:
	lods byte ptr [si]
endif
	and al,al
	jz done
	mov dl,al
	mov ah,2
	int 21h
	jmp nextitem
done:
if ?32BIT
	pop esi
else
	pop si
endif
	pop dx
	@iret
ischarout:
	mov ah,2
	int 21h
	@iret
myint41 endp
endif

if ?DOS4G
is4g proc
	cmp dx,0078h
	jnz jmpprevint21
	call checkpsp
	jc jmpprevint21
	push bx
	mov ah,51h
	int 21h
	mov es,bx
	pop bx
if ?DOS4GMEM
	cmp cs:[w4GSel],0
	jnz @F
	call Init4G
	jc error
@@:
	mov gs,cs:[w4GSel]
endif
	mov eax, "G4"*10000h+0FFFFh
error:
	jmp retf2ex
is4g endp
endif

if _SUPTSR_
do2131 proc
	cmp [wTDStk],offset starttaskstk + sizeof TASK	   ;last app?
	jz @F
	ret
@@:
	push ax
	mov bx,[wLdrPSP]			;set psp of loader
	mov es,bx
	mov ah,50h
	int 21h
	mov ax,0306h				;get real mode entry point
	int 31h
	pop ax
if ?32BIT
	push esi
	push edi 					;push real mode entry point
else
	push si
	push di						;push real mode entry point
endif
	mov di,80h
	push di
	cld
								;BA 10 00  mov dx,0010h
								;B8 xx 31  mov ax,31xxh
								;CD 21	  int 21h
	mov cl,al
	mov ax,10BAh
	stosw
	mov ax,0B800h
	stosw
	mov al,cl
	mov ah,31h
	stosw
	mov ax,21CDh
	stosw
	pop di						   ;IP
	mov ax,cs:[wRMPSP]			   ;DS
	mov cx,ax					   ;ES
	mov dx,ax					   ;SS
	mov si,ax					   ;CS
	mov bx,100h 				   ;SP
	@retf
do2131 endp
endif

if _LASTRC_
do214d:
	push ds
	mov ds,cs:[wLdrDS]
	xor ax,ax
	xchg ax,[wLastRC]
	pop ds
	jmp retf2ex
endif

is214b91:
	push ds
	mov ds,cs:[wLdrDS]
	and fMode, not FMODE_DISABLED
	cmp bl,0
	jnz @F
	or fMode, FMODE_DISABLED
@@:
	pop ds
	jmp retf2ex

	align 4
;-------------------------------------------------------
;*** int 21 handler ***

int21proc proc

	cmp ax,4b91h		;enable/disable loader?
	jz is214b91
	test cs:[fMode], FMODE_DISABLED
	jnz jmpprevint21
if _LASTRC_
	cmp ah,4Dh
	jz do214d
endif
	cmp ah,4Ch
	jz int214c
if _SUPTSR_
	cmp ah,31h
	jz int2131
endif
	cmp ah,4bh
	jz is4b
if ?DOS4G
	cmp ax,0FF00h
	jz is4g
endif
jmpprevint21::
if ?32BIT
	db 66h
	db 0eah			   ;jmp ssss:oooooooo
oldint21 df 0
else
	db 0eah			   ;jmp ssss:oooo
oldint21 dd 0
endif
	align 4

if ?32BIT
oldint31 df 0
else
oldint31 dd 0
endif
	align 4

if ?TRAPINT41
  if ?32BIT
oldint41 df 0
  else
oldint41 dd 0
  endif
endif
	align 4
is4b:
if _ONLY4B00_
	cmp al,01h
	jbe int214b
else
	cmp al,3
	jbe int214b
endif
	cmp al, 80h
	jnz @F
if ?32BIT
	test edx, 0FFFF0000h
	jnz @F
endif
	mov ax, dx
	call FreeLib16		;may change ES
	jmp retf2ex
@@:
	cmp al,85h
	jnz @F
	call GetProcAddress16
	jmp retf2ex
@@:
ife ?32BIT
	cmp al,86h
	jnz @F
	call GetModuleFileName16
	jmp retf2ex
@@:
endif
	cmp al,88h
	jnz @F
	call GetModuleHandle16
	jmp retf2ex
@@:
	cmp al,93h			;set error mode?
	jnz @F
	call _SetErrorMode
	jmp retf2ex
@@:
	cmp al,94h			;set wEnvFlgs?
	jnz @F
	push ds
	mov ds,cs:[wLdrDS]
	mov ax,[wEnvFlgs]
	and dx,cx
	not cx
	and ax,cx
	or ax,dx
	xchg ax,[wEnvFlgs]
	pop ds
	jmp retf2ex
@@:
if ?32BIT
	call CheckInt214B	;might directly return to caller!
endif
	jmp jmpprevint21

int21proc endp

;--- if CL=1, DX is number of export
;--- if CL=0, DS:E/DX -> name of export
;--- module handle in BX
;--- return address in dx:ax

if ?32BIT
GetProcAddress16 proc public uses es ebx esi
	mov esi, edx
else
GetProcAddress16 proc public uses es bx si
	mov si, dx
endif

	mov ax, bx
	xor dx, dx
	call checkne	;check if AX is a NE (modifies ES)
	mov ax,dx
	jc error
	cmp cl,1
	mov cx,ax
	jz @F
	mov ax,ds
	call strlen		;get length of name into CX
@@:
	call SearchNEExport
	mov dx,ax
	mov ax,bx
	clc
error:
	ret

GetProcAddress16 endp

ife ?32BIT

GetModuleFileName16 proc uses es

	mov ax,dx
	call checkne
	jc error
	mov ax,offset NEHDR.szModPath
	ret
error:
	xor ax,ax
	cwd
	ret

GetModuleFileName16 endp

endif

if ?32BIT
GetModuleHandle16 proc public uses es ds esi ebx
else
GetModuleHandle16 proc uses es ds si bx
endif

	mov bx,cs:[wMDSta]
	push bx
if ?32BIT
	mov esi, edx
else
	mov si, dx
endif
	cmp cl, 0		; is it a handle in DX?
	jz @F
	call Segment2Module	;get module handle for SI segment
	jmp exit
@@:
	call strlen		; get string length of DS:E/SI into CX
	call SearchModule16	; will work with DS:ESI in ?32BIT!
exit:
	pop dx			; return first module in DX	
	ret
GetModuleHandle16 endp


;*******************************************
;*** int 21, AH=4Ch (terminate programm) ***
;*******************************************

int214c:
int2131:
	@int3 _INT03PGMEXIT_
;---------------------------------- check if the terminating app
;---------------------------------- is one started by the loader
;if ?MULTPSP
;if _LOADERPARENT_
	@trace_s <"dpmildr: int 21, ah=4Ch; checking psp",lf>
	call checkpsp			;wont change registers
	jc jmpprevint21			;jmp to previous handler
	@trace_s <"dpmildr: check psp ok",lf>
;endif
;endif
	mov ds,cs:[wLdrDS]
	@trace_s <"dpmildr: int 21h ah=4C entry, task ptr(si)=">
	mov si,[wTDStk]
	sub si,size TASK
	@trace_w si
	@trace_s <", ldr sp=">
	@trace_w sp
	@trace_s lf
	@trace_s <"dpmildr: task-modul=">
if ?32BIT
	@trace_d [si.TASK.dwModul]
else
	@trace_w [si.TASK.wModul]
endif
if ?MULTPSP
	@trace_s <" psp=">
	@trace_w [si.TASK.wPSP]
	@trace_s <", parent ss:sp=">
	@trace_w [si.TASK.wSS]
	@trace_s <":">
if ?32BIT
	@trace_d [si.TASK.dwESP]
else
	@trace_w [si.TASK.wSP]
endif
	@trace_s lf
endif
if _SUPTSR_
	cmp ah,31h					;go resident?
	jnz @F
	call do2131
	jmp i214c_1
@@:
endif
	mov ah,00
	mov [wLastRC],ax
if 0;?INT24RES or ?INT23RES
	call restoreint2x		;restore int 23h/24h,DTA
endif
if ?32BIT
	@trace_s <"dpmildr: free modules/libs, handle=">
	mov eax,[si].TASK.dwModul
	@trace_d eax
	@trace_s <lf>
  if ?PESUPP
	test eax,0FFFF0000h
	jz @F
	call FreeModule32
	push ds					;FreeLibrary may free the stack mem block
	pop ss					;so set the loader stack here
	mov esp,[dStktop]
	push si
	push eax
	pop di
	pop si
	mov ax,0502h				;free stack handle
	int 31h
	pop si
	jmp i214c_2
@@:
  endif
else
	mov ax,[si.TASK.wModul]
endif
	push ds					;FreeLibrary may free the stack mem block
	pop ss					;so set the loader stack here
if ?32BIT
	mov esp,[dStktop]
else
	mov sp,[wStktop]
endif
	call FreeLib16
i214c_2:
if ?INT24RES or ?INT23RES
	call restoreint2x			;restore int 23h/24h,DTA
endif
	mov [wTDStk],si
if ?MULTPSP
if ?USE1PSP
	test bEnvFlgs, ENVFL_LOAD1APPONLY
	jz @F
;--- since we didn't create a PSP if DPMILDR=8,
;--- there is no need to "kill" one now.
if ?DEBUG
	mov ah,51h
	call doscall
	mov ax,bx
	call sel2segm
	@trace_s <"dpmildr: DPMILDR=8, current PSP segm is=">
	@trace_w bx
	@trace_s lf
endif
	jmp i214c_1
@@:
endif
	mov bx,[si.TASK.wPSP]			;get PSP of terminating task
	@trace_s <"dpmildr: last task's PSP selector=">
	@trace_w bx
	@trace_s lf
	and bx,bx				;(hopefully it is it!)
	jz i214c_1

	mov es,bx
if 0						;win31, 9x, NT, XP work with selector
	mov ax,[wRMPSP]				;use loader psp segment
	test fMode, FMODE_ISNT
	jz @F
endif
	mov ax,[wLdrPSP]			;use loader psp selector for NT!!!
@@:
	mov es:[PARPSP],ax

if _CLEARENV_
	mov word ptr es:[ENVIRON],0000
endif
if ?32RTMBUG					;32RTM.EXE doesn't know int 21, ah=00 (is 0)
	call KillManually
else
	@trace_s <"dpmildr: task ptr(si) before dos kill=">
	@trace_w si
	@trace_s lf

;--- even if dos kill works it doesn't free selectors for PSP and ENV

	push es:[ENVIRON]
	push 0					;clear es
	pop es
	push bx

if _LOADERPARENT_
	mov ax,[wLdrPSP]
	mov bx,[wTDStk]
	cmp bx,offset starttaskstk
	jz @F
	mov ax,[bx.TASK.wPSP - sizeof TASK]
@@:
	push ax
endif
	@trace_s <"dpmildr: calling dos kill", lf>
	mov ah,00h				;dos "kill" function
	call doscall
	mov di,0				;di=0 if kill didn't work
	jc @F
	inc di
@@:
	pop bx
	@trace_s <"dpmildr: calling dos set PSP, bx=">
	@trace_w bx
	@trace_s lf
	mov ah,50h				;set "new" PSP directly
	call doscall

	pop bx					;selector of killed PSP
	verw bx
	jnz pspfreed
	mov ax,1
	and di,di
	jnz @F
	mov dx,bx
	mov ax,101h				;kill didn't work, free psp dos mem
@@:
	int 31h
pspfreed:
	pop bx
	cmp [wTDStk],offset starttaskstk	;dont free enviroment sel of task 0
	jz childselsdone			;because it is the loader's ENV as well
	@trace_s <"dpmildr: freeing DOS memory block sel=">
	@trace_w bx
	@trace_s lf
	verw bx
	jnz childselsdone
	mov ax,1
	and di,di
	jnz @F
	mov dx,bx
	mov ax,101h				;kill didn't work, free psp dos mem
@@:
	int 31h
childselsdone:

endif							;endif ?32RTMBUG
endif							;endif ?MULTPSP

i214c_1:
	mov ax,[si.TASK.wSS]
	@trace_s <"dpmildr: internal task ptr(si)=">
	@trace_w si
	@trace_s <" parent ss:sp=">
	@trace_w ax
	@trace_s <":">
if ?32BIT
	@trace_d [si.TASK.dwESP]
else
	@trace_w [si.TASK.wSP]
endif
	@trace_s lf
	verw ax
	jnz l214c_3
	mov ss,ax
if ?32BIT
	mov esp,[si.TASK.dwESP]
else
	mov sp,[si.TASK.wSP]
endif
if ?SUPAPPTITLE
	call setapptitle2
endif
	@trace_s <"dpmildr: switched to parent psp and stack",lf>
	@restoreregs_exec
if ?32BIT
	@trace_s <"dpmildr: app terminated, esi=">
	@trace_d esi
	@trace_s <",edi=">
	@trace_d edi
	@trace_s <",ebp=">
	@trace_d ebp
else
if _TRACE_
	@trace_s <"dpmildr: app terminated, [sp]=">
	push bp
	mov bp,sp
	@trace_w <word ptr [bp+2]>
	@trace_s <", ">
	@trace_w <word ptr [bp+4]>
	@trace_s <", ">
	@trace_w <word ptr [bp+6]>
	pop bp
endif
endif
	@trace_s <lf,"dpmildr: ---------------------------------",lf>
;	xor ax,ax
	mov ax,cs:[wLastRC]			;modified 29.11.2004
	jmp retf2ex
l214c_3:
	mov bx,offset szErr21
	@strout_err
	jmp fatalerror

;*** int 21, AH=4Bh (execute programm, DS:(E)DX=Pfad)
;*** ES:(E)BX -> exec parameter block
;*** parameter block (16bit) looks like:
;*** WORD  environment ; environment segment or 0
;*** DWORD cmdline     ; cmdline       (-> PSP:80)
;*** DWORD fcb1        ; FCB 1         (-> PSP:5C)
;*** DWORD fcb2        ; FCB 2         (-> PSP:6C)
;*** parameterblock (32bit) looks like:
;*** QWORD cmdline     ; cmdline       (-> PSP:80)
;*** QWORD fcb1        ; FCB 1         (-> PSP:5C)
;*** QWORD fcb2        ; FCB 2         (-> PSP:6C)

int214b proc
if ?CHECKCALLER
	call checkcaller	;called by loader?
	jnz @F
	jmp jmpprevint21	;jmp to previous int21 handler
@@:
endif
	push ds
	push es
if ?32BIT
	push edx
	push ebx
	push eax
	push esi
	push edi
else
	push dx
	push bx
	push ax
	push si
	push di
endif
	call LoadLibIntern2	   ;load NE module (DS:EDX -> path)
if ?32BIT
	pop edi
	pop esi
	pop ecx
	pop ebx
	pop edx
else
	pop di
	pop si
	pop cx
	pop bx
	pop dx
endif
	pop es
	pop ds
	jc @F					;not found or not a valid NE file 
if ?NEAPPS        
	push ds
	mov ds,ax
	test byte ptr ds:[NEHDR.APPFLGS],AF_DLL ;app or dll?
	pop ds
	jz StartApp16
endif        
	call CallAllLibEntries	;run LibEntries of dlls
if ?32BIT
	@trace_s <"int 21h, ax=4b00h (dll) will exit now to ">
	@trace_w word ptr [esp+4]
	@trace_s <":">
	@trace_d dword ptr [esp+0]
	@trace_s <lf>
endif
	jmp retf2ex				;done
@@:
	cmp ax,offset szNotaNE	;not a "NE" File error?
	stc
if ?32BIT
	movzx eax,cs:[wlError]
else
	mov ax,cs:[wlError]
endif
	jnz retf2ex 		  ;if no, return with error
	mov ax,cx			  ;restore AX
if ?PESUPP
;	cmp byte ptr cs:[bEnabled],0  ;is peloader enabled?
;	jz int214b_1
	cmp word ptr cs:[NE_Hdr],'EP'
	jz @F
if ?PHARLABTNT
	cmp word ptr cs:[NE_Hdr],'LP'
	jz @F
endif
	cmp word ptr cs:[NE_Hdr],'XP'
	jnz int214b_1			;is not a PE executable 
@@:
	@saveregs_exec
	mov ds,cs:[wLdrDS]	  ;call with full path so we dont need
	mov edx,offset szModName  ;to search PATH again
	call LoadModule32
	mov [esp+1Ch],eax
	@restoreregs_exec
	jnc retf2ex 		  ;done
	and ax,ax
	stc
	jnz retf2ex
	mov ax, 4b00h
int214b_1:
endif
	xor cx,cx
if ?DISABLESERVER
	call disableserver
endif
if ?32BIT
if ?DOSEMUSUPP
	test cs:fMode, FMODE_DOSEMU
	jz @F
	call __loadpgm
	jmp loadpgmdone
@@:
endif
endif

;------------------- here there was code to reset int21
;------------------- so the loader does not intercept int 21, ah=4ch
;------------------- of the now launched program (if it is a pm app)
;------------------- but it seems better to check in int21,ah=4ch
;------------------- if the terminating app is one started by the loader
	call doscall 		  ;exec (real mode) program
loadpgmdone:
	pushf
	@trace_s <lf,"-------------------------------------------",lf>
	@trace_s <"dpmildr 21-4bh: back from int 21h, ax=4B00h",lf>
if ?DISABLESERVER
	call enableserver
endif
	popf
	pushf
if _LASTRC_
	jc @F
	mov ah,4Dh
	call doscall
	push ds
	mov ds,cs:[wLdrDS]
	mov [wLastRC],ax
	pop ds
@@:
endif
if ?SUPAPPTITLE
	call setapptitle2	  ;restore app title
endif
	@trace_s <"dpmildr 21-4bh: returning to launching app, ss:esp=">
	@trace_w ss
	@trace_s <":">
	@trace_d esp
	@trace_s lf
	popf
	@int3 _INT03RETEXEC_
retf2ex::
	push ax				   ;copy flags
	lahf				   ;to ensure trace flag isn't touched
if ?32BIT
  if 0
	push ebp
	mov ebp,ss
	lar ebp,ebp
	test ebp,400000h
	mov ebp,esp
	jnz @F
	movzx ebp,bp
@@:
	mov [ebp+4+2+2*4],ah
	pop ebp
  else
	mov [esp+2+2*4],ah
  endif
else
	push bp
	mov bp,sp
	mov [bp+2+2+2*2],ah
	pop bp
endif
	pop ax
	@iret
int214b endp

if ?NEAPPS

;--- start NE application (16/32 bit)

StartApp_Err17:
	mov ax,offset errstr17	;error "stack is readonly"
	jmp StartApp_Err
StartApp_Err10:
	mov ax,offset errstr10	;error "no valid start address"
StartApp_Err11:
StartApp_Err:
	test byte ptr [wErrMode+1],HBSEM_NOOPENFILEBOX
	jnz @F
	mov bx, ax
	@strout_err				;display bx string 
@@:

;--- the new PSP has been created already and is the active one
;--- so best would be to terminate with Ah=4Ch
if 0
	@restoreregs_exec
	stc
	mov ax,cs:[wlError]
	jmp retf2ex 		  ;exit function 4B with Carry set
else
StartApp_ErrExit:
	@trace_s <"StartApp error exit",lf>
	mov ax,4C00h+RC_INITAPP
	int 21h
endif

;*** start new NE application
;*** inp: AX=MD
;---      CL=value of AL (00/01) of ax=4B0x
;***      ES:E/BX-> execute parameter block

StartApp16 proc

	@saveregs_exec

	mov ds,cs:[wLdrDS]
	mov si,[wTDStk]
if ?32BIT
	mov [si.TASK.dwESP],esp
	movzx eax,ax
	mov [si.TASK.dwModul],eax
else
	mov [si.TASK.wSP],sp
	mov [si.TASK.wModul],ax
endif
	mov [si.TASK.wSS],ss
if ?MULTPSP
	push es
	mov es,ax
  if ?32BIT
	mov edi,offset NEHDR.szModPath
  else
	mov di,offset NEHDR.szModPath
  endif
	call CreatePsp			;will set new psp (E/BX not modified)  
	pop es
	jc StartApp_Err
endif
	add [wTDStk],sizeof TASK	;update task stack
if ?INT24RES or ?INT23RES
	call saveint2x
endif
	call SetCmdLine			;copy cmdline into PSP (ES:E/BX->parmb)
	mov es,[si.TASK.wModul]
	cmp word ptr es:[NEHDR.ne_csip+2],0
	jz StartApp_Err10
	call GetSSSP 			;get new SS:E/SP into AX:E/DX
	jc StartApp_Err11		;error "no stack","mult inst"
	@trace_s <"will force NP exception for ">
	@trace_w ax
	@trace_s <" (SS) now",lf>
	push ds
	mov ds,ax				;cause a NP exception
	pop ds					;to ensure stack segment is loaded
	verw ax
	jnz StartApp_Err17
	mov ss,ax
if ?32BIT
	mov esp,edx
else
	mov sp,dx
endif
if ?SUPAPPTITLE
	mov al,00
	call SetAppTitle
endif
	@trace_s "StartApp: launching app now, CS:IP="
	@trace_w <word ptr es:[NEHDR.ne_csip+2]>
	@trace_s ':'
	@trace_w <word ptr es:[NEHDR.ne_csip+0]>
	@trace_s " SS:SP="
	@trace_w ss
	@trace_s ':'
if ?32BIT
	@trace_d esp
else
	@trace_w sp
endif
	@trace_s <" PSP=">
	@trace_w [wCurPSP]
	@trace_s <lf>

	cld
	sti
	mov cx,word ptr es:[NEHDR.ne_csip+2]
if ?32BIT
	movzx ebx,word ptr es:[NEHDR.ne_csip+0]
  if ?GSFLAT
	mov gs,[wFlatDS]
  endif
else
	mov bx,word ptr es:[NEHDR.ne_csip+0]
endif
if ?INT41SUPPORT
	mov ax,DS_StartTask		;CX:BX=CS:IP
	int 41h
	test cs:bEnvFlgs,ENVFL_BREAKATENTRY
	jz @F
	push es
	mov es,cx				;force segment to be loaded
	pop es
	mov ax,DS_ForcedGO16	;force break at cx:bx
	int 41h
@@:
endif
if ?32BIT
	pushfd
	push ecx
	push ebx
else
	pushf
	push cx
	push bx
endif
	mov cx,es:[NEHDR.ne_heap]
	mov bx,es:[NEHDR.ne_stack]	;for win16 binaries
if ?32BIT
	movzx ebx,bx
	movzx ecx,cx
	shl ebx,12				;new: pages instead of bytes for 32bit
	shl ecx,12
endif
	mov di,ss				;DI=hInstance
ife ?32BIT
	xor si,si				;for 16 bit init SI here 
	test es:[NEHDR.APPFLGS],10h	;RTM compatible?
	jz @F
	mov ds,[wCurPSP]
	push ds
	pop es
	jmp notos2
@@:
	cmp es:[NEHDR.ne_exetyp], ET_OS2
endif
	mov es,[wCurPSP]
	mov ds,di
ife ?32BIT
	jnz notos2
endif
ife ?32BIT
	mov si,cx			;si=heap size
	mov dx,bx			;dx=stack size
	call InitDlls		;simple InitTask for OS/2
	jc StartApp_ErrExit
	add cx,3*2			;cx=size of DGROUP (account for IRET stack frame)
	add cx,si
else
	push ebx
	push ecx
	call InitDlls 
	pop ecx
	pop ebx
	jc StartApp_ErrExit
endif
ife ?32BIT
	or bx,-1
	mov es,es:[002Ch]
	xor ax,ax
@@:
	inc bx
	cmp ax,es:[bx]
	jnz @B
	inc bx
@@:
	inc bx
	cmp al,es:[bx]
	jnz @B
	inc bx
	mov ax,es
	push 0
	pop es
notos2:
endif
if _INT01PGMENTRY_
	pushf
	mov bp,sp
	or word ptr [bp+0],100h	;set TF 
endif
if ?32BIT
	xor ebp,ebp
	mov esi,ebp
	mov fs,bp
  ife ?GSFLAT
	mov gs,bp
  endif
else
	xor bp,bp
endif
if _INT01PGMENTRY_
	popf
endif
	@iret
StartApp16 endp

endif ;?NEAPPS

if ?32RTMBUG
KillManually proc
	mov dx,bx
	@trace_s <"freeing psp memory",lf>
	mov ax,0101h
	call dpmicall
	ret
KillManually endp
endif

if ?32BIT
if ?DOSEMUSUPP

;--- EXEC param block in dosemu is wrong

__loadpgm proc
	push es
	push ds
	pushad
	lds esi,es:[ebx+0]
	movzx ecx,byte ptr [esi]
	inc cl
	inc cl
	mov edi,offset segtable
	mov es,cs:[wLdrDS]
	rep movs byte ptr [edi],[esi]
	popad
	pop ds
	push ebx
	mov ebx, offset execpm
	mov es:[bx+4],es		;cmdline selector
	mov ax,4b00h
	call doscall
	pop ebx
	pop es
	ret
__loadpgm endp
endif
endif

if ?DISABLESERVER

disableserver proc uses ds
if 1
	mov ds, cs:[wLdrPSP] 
	mov word ptr ds:[?PSPSAVEI2FADDR+2],0
endif
	test cs:[bEnvFlgs], ENVFL_LOAD1APPONLY
	jz exit
if 0
	cmp cs:[wTasks], 0	;is anything loaded at all?
	jz exit
endif
	pusha
	mov bl, 2fh
	mov ax, 200h
	int 31h
	mov ds:[?PSPSAVEI2FADDR+0],dx
	mov ds:[?PSPSAVEI2FADDR+2],cx
	mov cx, cs:[wRMPSP]
	mov dx, 0100h+offset int2frm
	mov ax, 0201h
	int 31h
	popa
exit:
	ret
disableserver endp

enableserver proc public uses ds
	pusha
	mov ds, cs:[wLdrPSP]
	xor dx,dx
	xor cx,cx
	xchg dx, ds:[?PSPSAVEI2FADDR+0]
	xchg cx, ds:[?PSPSAVEI2FADDR+2]
	jcxz @F
	mov bl, 2fh
	mov ax, 0201h
	int 31h
@@:
	popa
	ret
enableserver endp

endif

if ?SUPAPPTITLE

;*** prepare call of SetAppTitle

setapptitle2 proc uses ds es si ax

	mov ds,cs:[wLdrDS]
	mov si,[wTDStk]
	cmp si, offset starttaskstk
	jz exit
if ?32BIT
	cmp word ptr [si.TASK.dwModul+2 - sizeof TASK],0
	mov al,01
	jnz @F
endif
	mov es,[si.TASK.wModul - sizeof TASK]
	mov al,00
@@:
	call SetAppTitle
exit:
	ret
setapptitle2 endp


;*** int 2f,168e only works for win9x and no translation is supplied!
;*** since a pointer is used, dos memory has to be allocated!
;*** Input: AL=00 + ES=MD or AL=01 + FS=MZHDR
;*** DS=dataseg

SetAppTitle proc public
if ?32BIT
	pushad
	sub esp,sizeof RMCS+2
	mov ebp,esp
else
	pusha
	sub sp,sizeof RMCS+2
	mov bp,sp
endif
	test fMode, FMODE_ISWIN9X
	jz exit
	or fMode, FMODE_NOERRDISP	;dont display dpmi errors
	push es
	push ds
if ?PESUPP
	test al,01
	jz isNE
	mov es,cs:[wFlatDS]
	movzx esi, cs:[wTDStk]
	mov esi, cs:[esi-sizeof TASK].TASK.dwModul
	add esi, es:[esi].MZHDR.pExeNam
	push esi
	mov cl,-1
@@:
	mov al,es:[esi]
	inc esi
	inc cl
	and al,al
	jnz @B
	pop esi
	push es
	pop ds
	jmp sat_2
isNE:
	movzx esi,si
endif
	push es
	pop ds
	mov si,ds:[NEHDR.ne_restab]
	lodsb
	mov cl,al
sat_2:							;copy name to real mode memory
	mov ch,00
	push cx
	mov bx,8
	mov ax,0100h
	call dpmicall
	pop cx
	jc error
if ?32BIT
	xor edi,edi
else
	xor di,di
endif
	mov es,dx
if ?32BIT
	mov [ebp.RMCS.rES],ax
else
	mov [bp.RMCS.rES],ax
endif
	and cl,7Fh
if ?32BIT
	movzx ecx,cx
	rep movs byte ptr [edi], [esi]
	xor al,al
	stos byte ptr [edi]
else
	rep movsb
	xor al,al
	stosb
endif

if ?32BIT
	xor eax,eax
	mov [ebp.RMCS.rDI],ax
	mov [ebp.RMCS.rDX],ax
	mov [ebp.RMCS.rSSSP],eax
	mov [ebp.RMCS.rAX],168Eh
	mov edi,ebp
else
	xor ax,ax
	mov [bp.RMCS.rDI],ax
	mov [bp.RMCS.rDX],ax ;set app title
	mov [bp.RMCS.rSS],ax
	mov [bp.RMCS.rSP],ax
	mov [bp.RMCS.rAX],168Eh
	mov di,bp
endif

;---------------------- call int 2F, AX=168Eh
	push ss
	pop es
	mov bx,002Fh
	xor cx,cx
	mov ax,0300h
	call dpmicall

	mov ax,0101h
	call dpmicall
error:
	pop ds
	pop es
	and fMode, not FMODE_NOERRDISP
exit:
if ?32BIT
	add esp,sizeof RMCS+2
	popad
else
	add sp,sizeof RMCS+2
	popa
endif
	ret
SetAppTitle endp

endif

if ?MULTPSP

;--- inp: DS=new psp with old env
;--- ES:E/DI=program name
;--- out: ES=new env

if ?MAKENEWENV
CopyPgmInEnv proc
	pusha
;### changes for differences in environment block
  if ?OS2COMPAT
	mov bl,ds:[0080h]			;length of cmd tail (used later)
	inc bl						;+1 for terminator
  endif
;### end
	push ds
	mov ds,ds:[002Ch]
	xor si,si
	xor ax,ax
	dec si
@@:
	inc si
	cmp ax,[si]
	jnz @B
;### more changes for environment
  if ?OS2COMPAT
	add si,2		;include 00,00 in copy
	xor bp,bp		;bp==0 means OS/2
	cmp es:[NEHDR.ne_exetyp], ET_OS2
	je @f
	add si,2		;include 01,00 as well
	inc bp
@@:
  else
	add si,4		;skip 00 00 and 01 00
  endif
;### end
  if ?32BIT
	mov edx,edi
;	dec edi
@@:
;	inc edi
	scas byte ptr es:[edi]
	jnz @B
	xchg edx,edi
	sub edx,edi
  else
	mov dx,di
;	dec di
@@:
;	inc di
	scasb
	jnz @B
	xchg dx,di
	sub dx,di
  endif
	mov ax,si		;now calc size of environment block 
	add ax,dx
;### yet more changes for environment
 if ?OS2COMPAT
 	and bp,bp
	jnz @F
	add ax,dx				;allow for  copy of progname
	mov bh,00				;bl has cmd tail count from psp
	add ax,bx
@@:
 endif
;### end
	add ax,15		;paragraph align
	and al,0F0h
	shr ax,4
	mov bx,ax
  if ?LOWENV
	mov ax,100h
	int 31h
  else
	mov ah,48h
	int 21h
  endif
	jc done
	push es
	mov es,dx
	mov cx,si
  if ?32BIT
	push edi
  else
	push di
  endif
	xor di,di
	xor si,si
	rep movsb		;copy old environment to new environment block
  if ?32BIT
	pop esi
	pop ds
@@:
	lods byte ptr [esi]	;copy program name into new environment block
	stosb
	and al,al
	jnz @B
  else
	pop si
	pop ds
    if ?OS2COMPAT
	mov bx,di               ;save ptr within env
    endif
@@:
	lodsb
	stosb
	and al,al
	jnz @B
  endif
	pop ds
	mov ds:[002Ch],es
	push ds
  if ?OS2COMPAT
;### and this is what it's all been about
	and bp,bp				;os/2 exe type?
	jnz done
;	mov ds:[042h],di
@@:
	mov al,es:[bx]		;OS2v1 has 2 copies of progname
	stos byte ptr es:[di]
	inc bx
	or al,al
	jnz @b

	mov si,0080h			;copy from psp (max 127)
	lodsb
	mov cl,al
	mov ch,00
	rep movsb
	mov es:[di],ch			;terminate with 00
  endif
;### end changes for environment
done:
	pop ds
	popa
	ret
CopyPgmInEnv endp
endif

;*** create a new psp of size 100h bytes ***
;--- input:
;--- DS:SI -> new TASK (ds = loader segment)
;--- ES=MD for NE tasks
;--- ES:E/DI -> program name
;--- wTasks has old value (0 for first task)

;*** dos function 55h will set current PSP to the new created PSP!
;--- out: C on error
;--- destroys AX,CX,DX

if ?32BIT
CreatePsp proc public uses ebx
else
CreatePsp proc uses bx
endif

	mov ah,51h
	int 21h
	@trace_s <"createpsp entry DS=">
	@trace_w ds
	@trace_s <" current psp sel=">
	@trace_w bx
	@trace_s <" segm=">
if _TRACE_
	mov ax,bx
	call sel2segm
endif
	@trace_w ax
	@trace_s lf

	mov [wCurPSP],bx

	cld
if ?USE1PSP
	mov dx,bx
	mov [si].TASK.wPSP,0
	test bEnvFlgs, ENVFL_LOAD1APPONLY
	jnz pspdone
endif
	mov bx,10h
	mov ax,0100h			;alloc DOS memory for PSP
	int 31h
	jc error1
	push ax					;DX = selector, AX = segment
	push si
	mov si,ax
	add si,10h				;SI = value placed at offset 2
	mov ah,55h				;create PSP, DX=segment
	int 21h
	pop si
	pop ax
;	jc error1				;RBIL states CF doesnt indicate an error!
	mov [si].TASK.wPSP,dx	;save new PSP
	@trace_s <"new psp is ">
	@trace_w dx
	@trace_s lf
pspdone:
if ?COPYENV
	push ds
	mov ds,dx
	cmp word ptr ds:[2ch],0		;is env of new PSP 0?
	jnz @F
	@trace_s <"environment of PSP is NULL, copy it from previous PSP",lf>
	mov ds, cs:[wCurPSP]		;then copy it from current PSP
	mov cx, ds:[2ch]
	mov ds, dx
	mov ds:[2ch], cx
@@:
  if ?MAKENEWENV
   if ?OS2COMPAT
	cmp es:[NEHDR.ne_exetyp], ET_OS2
	je cpyenv
   endif
	cmp cs:[wTDStk],offset starttaskstk
	jz @F
cpyenv:
	@trace_s <"set new pgm path in environment",lf>
	call CopyPgmInEnv			;preserves AX
@@:
  endif
	pop ds
endif
	mov [wCurPSP],dx
if _SETPSP_
if ?32BIT
	push ds
	push esi
	push edi
	mov di,ax					;segment of new PSP to DI
	dec di
	movzx edi,di
	shl edi,4
	mov es,[wFlatDS]
	mov es:[edi+1],ax			;set new PSP as owner of itself!
	mov byte ptr es:[edi+8],0
if 1
	test word ptr [si.TASK.dwModul+2],0FFFFh
	jnz @F							;is PE-Modul
else
	verr word ptr [si.TASK.dwModul]
	jnz @F							;is PE-Modul
endif
	mov ds,word ptr [si.TASK.dwModul]
	movzx esi,ds:[NEHDR.ne_restab]
	inc si
	add di,8
	movs dword ptr [edi],[esi]		;copy name to PSP header
	movs dword ptr [edi],[esi]
@@:
	pop edi
	pop esi
	pop ds
else
	mov cx,[si.TASK.wModul]
	jcxz createpsp_1
	push ax
	dec ax
	mov bx,ax
	call AllocRMSegment		;create selector in BX for segment BX 
	pop cx
	jc createpsp_1
	push ds
	pusha
	mov ds,[si.TASK.wModul]
	mov es,bx
	mov es:[0001],cx
	mov si,ds:[NEHDR.ne_restab]  ;entries (exported names)
	inc si
	mov di,8
	movsw
	movsw
	movsw
	movsw
	popa
	pop ds
	mov ax,0001
	int 31h
endif
createpsp_1:
endif
if ?SETDTA
	mov ah,2fh
	int 21h
if ?32BIT
	mov dword ptr [si.TASK.dta+0],ebx
	mov word ptr [si.TASK.dta+4],es
else
	mov word ptr [si.TASK.dta+0],bx
	mov word ptr [si.TASK.dta+2],es
endif
	push ds
	mov ds,dx
if ?32BIT
	mov edx,80h
else
	mov dx,0080h
endif
	mov ah,1Ah
	int 21h 				;set DTA
	pop ds
endif
	clc
exit:
	@trace_s <"createpsp exit",lf>
	ret
error1:
	mov ax,offset errstr19	;error "insufficient dos memory"
	jmp exit
CreatePsp endp

endif

;--- set error mode in DX, return old value in DX

_SetErrorMode proc public
	push ds
	mov ds,cs:[wLdrDS]
	test bEnvFlgs, ENVFL_IGNNOOPENERR
	jz dontmoderrmode
	and dh,7Fh			;reset this bit
dontmoderrmode:
	xchg dx,[wErrMode]
	pop ds
	ret
_SetErrorMode endp

;--- get current values for int 23, int 24

saveint2x proc public uses bx
	mov ax,0204h
if ?INT23RES
	mov bl,23h
	call dpmicall
if ?32BIT
	mov dword ptr [si.TASK.dfI23+0],edx
	mov word ptr [si.TASK.dfI23+4],cx
else
	mov word ptr [si.TASK.dwI23+0],dx
	mov word ptr [si.TASK.dwI23+2],cx
endif
endif
if ?INT24RES
	mov bl,24h
	call dpmicall
if ?32BIT
	mov dword ptr [si.TASK.dfI24+0],edx
	mov word ptr [si.TASK.dfI24+4],cx
else
	mov word ptr [si.TASK.dwI24+0],dx
	mov word ptr [si.TASK.dwI24+2],cx
endif
endif
	ret
saveint2x endp

;--- restore values after task end

restoreint2x proc
if ?INT23RES
if ?32BIT
	mov edx,dword ptr [si.TASK.dfI23+0]
	mov cx,word ptr [si.TASK.dfI23+4]
else
	mov dx,word ptr [si.TASK.dwI23+0]
	mov cx,word ptr [si.TASK.dwI23+2]
endif
	mov ax,0205h
	mov bl,23h
	call dpmicall
endif
if ?INT24RES
if ?32BIT
	mov edx,dword ptr [si.TASK.dfI24+0]
	mov cx,word ptr [si.TASK.dfI24+4]
else
	mov dx,word ptr [si.TASK.dwI24+0]
	mov cx,word ptr [si.TASK.dwI24+2]
endif
	mov ax,0205h
	mov bl,24h
	call dpmicall
endif
if ?SETDTA
	push ds
if ?32BIT
	lds edx, [si.TASK.dta]
else
	lds dx, [si.TASK.dta]
endif
	mov ah,1ah
	call doscall	;use doscall in case the app hasn't restored vector 21
	pop ds
endif
	ret
restoreint2x endp

;-------------------------------------------------------

setexc proc
	jcxz @F
	mov ax,0203h
	call dpmicall			;set ext vector
@@:
	ret
setexc endp

;-------------------------------------------------------
;*** prepare loader for termination
;--- restore exc 0Bh, int 21h, int 41h

resetvecs proc

if ?USE1PSP
	test bEnvFlgs, ENVFL_LOAD1APPONLY
	jnz @F
endif
	@trace_s <"restoring loader PSP=">
	mov bx,[wLdrPSP]
	@trace_w bx
	@trace_s <", segm=">
	@trace_w [wRMPSP]
	@trace_s lf
	mov ah,50h
	call doscall
@@:
	@trace_s <"restoring exception vectors",lf>
if ?EXC01RESET
if ?32BIT
	mov cx,word ptr oldexc01+4
	mov edx,dword ptr oldexc01+0
else
	mov cx,word ptr oldexc01+2
	mov dx,word ptr oldexc01+0
endif
	mov bl,01h
	call setexc
endif
if ?32BIT
	mov cx,word ptr oldexc0b+4
	mov edx,dword ptr oldexc0b+0
else
	mov cx,word ptr oldexc0b+2
	mov dx,word ptr oldexc0b+0
endif
	mov bl,0Bh
	call setexc
if _TRAPEXC0D_
if ?32BIT
	mov cx,word ptr oldexc0D+4
	mov edx,dword ptr oldexc0D+0
else
	mov cx,word ptr oldexc0D+2
	mov dx,word ptr oldexc0D+0
endif
	mov bl,0Dh
	call setexc
endif
	mov bx,[aliassel]
	@trace_s <"freeing alias selector ">
	@trace_w bx
	@trace_s lf
	mov ax,0001				;free selector
	call dpmicall
if ?PESUPP
	call DeinitPELoader
endif
	@trace_s <"restoring vector int 0x21",lf>
if ?32BIT
	mov cx,word ptr ds:[oldint21+4]
	mov edx,dword ptr ds:[oldint21+0]
else
	mov cx,word ptr ds:[oldint21+2]
	mov dx,word ptr ds:[oldint21+0]
endif
	mov bl,21h
	mov ax,0205h			;set pm int
	call dpmicall

if ?TRAPINT41
	@trace_s <"restoring vector int 0x41",lf>
  if ?32BIT
	mov cx,word ptr ds:[oldint41+4]
	mov edx,dword ptr ds:[oldint41+0]
  else
	mov cx,word ptr ds:[oldint41+2]
	mov dx,word ptr ds:[oldint41+0]
  endif
	mov bl,41h
	mov ax,0205h
	call dpmicall
endif
	ret

resetvecs endp

if ?CHECKTOP
areweontop proc
	mov bl,21h
	mov ax,0204h
	int 31h
	mov ax, cs
	cmp ax, cx
	ret
areweontop endp
endif

;-------------------------------------------------------

if ?CLOSEALLFILES
CloseAllFiles proc
	mov bx,5				;close open files >= 5 
@@:
	mov ah,3Eh
	int 21h
	inc bx
	cmp bx,_FILEHANDLES_
	jnz @B
	ret
CloseAllFiles endp
endif

;-------------------------------------------------------
;*** insert MD in MD list
;*** ES=current NE module

InsertModule16 proc
	mov ax,es
	mov cx,[wMDSta]
	@trace_s <"InsertModule16 MD=">
	@trace_w es
	@trace_s <", start=">
	@trace_w cx
	@trace_s <lf>
ife ?KERNEL16
	and cx,cx
	jnz @F
	mov wMDSta, ax
	jmp was_first
@@:
endif

@@:
	jcxz @F
	mov es,cx
	mov cx,es:[NEHDR.NXTMOD]
	jmp @B
@@:
	mov es:[NEHDR.NXTMOD],ax	;overwrite length of entry table
	mov es,ax
was_first:
	mov es:[NEHDR.NXTMOD],cx
	ret
InsertModule16 endp

;*** delete NE module from MD list
;*** MD in AX ***

DeleteModule16 proc
	xor bx,bx
	@trace_s <"DeleteModule16 ">
	@trace_w ax
	@trace_s <lf>
	mov cx,[wMDSta]
nextitem:
	jcxz modnotfound
	mov es,cx
	cmp ax,cx
	mov cx,es:[NEHDR.NXTMOD]
	jz modfound
	mov bx,es
	jmp nextitem
modfound:					;ES = current MD, BX=previous, CX=next
	and bx,bx
	jnz @F
	mov [wMDSta],cx
	clc
	ret
@@:
	mov es,bx
	mov es:[NEHDR.NXTMOD],cx
	clc
	ret
modnotfound:				;module not found
	stc
	ret
DeleteModule16 endp

;*** test if AX is referenced
;*** C if yes, NC if no

checkifreferenced proc
	mov bx,ax
	mov cx,[wMDSta]
checkifreferenced1:
	clc
	jcxz checkifreferencedex
	mov es,cx
	cmp bx,cx					  ;no if it is me
	jz checkifreferenced2
	mov cx,es:[NEHDR.ne_cmod]
	jcxz checkifreferenced2
	mov si,es:[NEHDR.ne_modtab]
checkifreferenced4:
	lods word ptr es:[NEHDR.ne_cmod]		;lodsw with ES prefix!
	cmp bx,ax
	stc
	jz checkifreferencedex		;yes, module referenced
	loop checkifreferenced4
checkifreferenced2:
	mov cx,es:[NEHDR.NXTMOD]
	jmp checkifreferenced1
checkifreferencedex:
	mov ax,bx
	ret
checkifreferenced endp

freemodulerest proc
	pusha
if ?LOADDBGDLL
	mov ax,[hModDbg]
	and ax,ax
	jz @F
	@trace_s <"*** delete debugout.dll ***",lf>
	call FreeLib16
@@:
endif
	@trace_s <"*** enter auto delete mode ***",lf>
freemodulerest3:				   ;<----
	mov ax,[wMDSta]
	and ax,ax
	jz freemodulerestex_1
@@:
	verr ax
	jnz freemodulerestex_1	;error in module list
	mov es,ax
	mov ax,es:[NEHDR.NXTMOD]
	and ax,ax
	jnz @B					;go to end of list
freemodulerest21:
	mov ax,es
	@trace_s <"checking references of module ">
	@trace_w ax
	@trace_s lf
	call checkifreferenced  ;only free modules which arent referenced
	jc freemodulerest2
	call FreeLib16
if 1
	jmp freemodulerest3	;now try again
else
	jnc freemodulerest3	;now try again
	jmp freemodulerestex_1
endif
freemodulerest2:
	mov bx,ax			;current module is referenced
	mov ax,[wMDSta] 	;so get previous module
	cmp ax,bx			;if there is none
	jz freemodulerestex_1;immediate exit
@@:
	mov es,ax
	mov ax,es:[NEHDR.NXTMOD]
	cmp ax,bx
	jnz @B
	jmp freemodulerest21
freemodulerestex_1:
if ?PESUPP
	call UnloadPEModules
endif
	@trace_s <"*** exit auto delete mode ***",lf>
freemodulerestex:
	popa
	ret
freemodulerest endp

;*** save path of .EXE as default for DLLs
;*** Input: ES -> MD ***
;*** Output: path in szPath ***

savepathNE proc
	@swap ds,es

	mov di,offset szPath
	mov si,offset NEHDR.szModPath
savepath0:
	mov dx,di
savepath1:
	lodsb
	stosb
	cmp al,'\'
	jz savepath0
	cmp al,'/'
	jz savepath0
	and al,al
	jnz savepath1
	mov di,dx
	stosb
	@swap ds,es
	ret
savepathNE endp

;*** copy cmdline in PSP
;*** Inp: ES:(E)BX -> exec parm blk
;*** regretably there are 2 formats for the parameter string
;*** for windows in asciiz format, for DOS in pascal format

SetCmdLine proc public uses es ds

if ?32BIT
	pushad
else
	pusha
endif
	mov ds,cs:[wLdrDS]
	xor al,al
	xchg [fLoadMod],al
if ?32BIT
	lds esi,es:[ebx+0]	;get dos command tail
	@trace_s <"SetCmdLine enter, es:ebx=">
	@trace_w  es
	@trace_s <':'>
	@trace_d ebx
	@trace_s <" cmdl=">
	@trace_w ds
	@trace_s <':'>
	@trace_d esi
  if ?DEBUG
	@trace_s <" size=">
	movzx cx,byte ptr [esi]
	@trace_w cx
  endif
	@trace_s <lf>
else
	lds si,es:[bx+2]
	@trace_s <"SetCmdLine enter, es:bx=">
	@trace_w  es
	@trace_s <':'>
	@trace_w bx
	@trace_s <" cmdl=">
	@trace_w ds
	@trace_s <':'>
	@trace_w si
	@trace_s <lf>
endif
	mov es,cs:[wCurPSP]
	and al,al
	jz @F
	call strlen	   ;get size of DS:E/SI into CX
	mov al,cl
	jmp scl_2
@@:
if ?32BIT
	lods byte ptr [esi]
else
	lodsb
endif
scl_2:
	mov cl,al			;number of chars
	mov ch,00
	mov di,0080h
	stosb
if ?32BIT
	movzx ecx,cx
	movzx edi,di
	rep movs byte ptr [edi],[esi]
else
	rep movsb
endif
	test di,0FF00h
	jnz @F
	mov al,cr
	stosb
@@:
if ?32BIT
	popad
else
	popa
endif
	@trace_s <"SetCmdLine exit",lf>
	ret

SetCmdLine endp

if ?NEAPPS

;--- get stack parameters for a NE module
;--- inp: ES -> NE-Header
;--- ret: NC: SS:SP in AX:(E)DX
;--- ret: C, AX->error string

GetSSSP proc
	@trace_s <"GetSSSP entered",lf>
	mov ax,word ptr es:[NEHDR.ne_sssp+2]	;SS
	test ax,ax
	jz error1				;no stack for application? -> error
	test byte ptr es:[NEHDR.PGMFLGS],PF_MULTIPLE  ;multiple DGROUPS?
	jz @F
	cmp es:[NEHDR.ne_count],1	;module used more than once?
	jnz MultInst			;error
@@:
	call SegNo2Sel			;get selector in AX
	lar cx,ax
	test ch,08h				;is SS a code selector?
	jz getsssp_1			;(might be true for model tiny)
	mov bx,es:[NEHDR.DGROFS]
	mov ax,es:[bx].SEGITEM.wSel
if _WINNT40BUG_
							;winnt 4.0 might not create a NP exc!
	test es:[bx.SEGITEM.flags],SF_ALIAS
	jz @F
	pusha
	mov si,bx
	call Load_Segm			;this will do a "Realloc"
	popa
@@:
endif
getsssp_1:
if ?32BIT
	push ax					;save selector
	mov cx,0FFFFh
	mov dx,4000h			;set default bit
	call setaccrights
	movzx ebx,bx
	pop ax
endif
	mov bx,word ptr es:[NEHDR.ne_sssp+0]	;SP
	and bx,bx
	jnz @F
	push ax
	mov ax,word ptr es:[NEHDR.ne_sssp+2]
	dec ax
	mov bl,SGTSIZE
	mul bl
	mov bx,ax
	pop ax
	add bx,es:[NEHDR.ne_segtab]	   ;stack needn't be == DGROUP!
	mov bx,es:[bx.SEGITEM.memsiz]	;get mem size of stack segment
if ?32BIT
	movzx edx,word ptr es:[NEHDR.ne_stack] ;+ extra stack space
	shl edx,12							;alloc pages instead of bytes
	add ebx,edx
@@:
	mov edx,ebx
	and dl,0FCh
else
	add bx,es:[NEHDR.ne_stack]	  ;+ extra Stack
@@:
	mov dx,bx
	and dl,0FEh
endif
	@trace_s <"GetSSSP exit",lf>
	clc
	ret
error1:
	mov ax,offset errstr16
	stc
	ret
MultInst:
	mov [wlError],0010h
	mov ax,offset errstr20
	stc
	ret
GetSSSP endp

endif

;*** search var (dx->name) in loader environment
;--- returns NC + offset in DI, else C
;--- modifies DI, AX

GetLdrEnvironmentVariable proc
	mov es,[wLdrPSP]
GetEnvironmentVariable::	;<--- entry with ES=PSP 	   
	mov es,es:[ENVIRON] 	;environment
	SUB DI,DI				;start with es:[0]
	CLD
	mov cx,-1
nextitem:
	push si
	mov SI,dx
	db 2Eh			;CS prefix
	REPZ CMPSB
;	cmp word ptr cs:[si-2],"="
	cmp byte ptr cs:[si-1],0
	pop si
	JZ found
	mov al,00
	repnz scasb
	CMP ES:[DI],al
	JNZ nextitem
	@trace_s <"environment variable not found",lf>
;	mov ah,0
	STC
	RET
found:
	dec di
	@trace_s <"environment variable found",lf>
	CLC
	RET
GetLdrEnvironmentVariable endp

copyfilename proc
	mov SI,offset szName
@@:
	LODSB
	MOV [DI],AL
	INC DI
	CMP AL,00
	JNZ @B
	ret
copyfilename endp

if ?32BIT
openfile proc public uses ebx
else
openfile proc public
endif

;	@trace_s <"try to open: ">
;	@trace_sx dx
;	@trace_s lf
if ?LFN
	test cs:fMode, FMODE_LFN
	jz nolfn
  if ?32BIT
  if ?LFNNT
	test cs:fMode, FMODE_ISNT
	jz nont
	push es
	push esi
	push edi
	push ebp
	sub esp, 32+2
	mov ebp, esp
	mov [ebp].RMCS.rAX,716Ch
	mov [ebp].RMCS.rBX,0
	mov [ebp].RMCS.rCX,0
	mov [ebp].RMCS.rDX,1
	mov cx,80h
	mov [ebp].RMCS.rSI,cx
	mov di, 80h
	mov es, cs:[wLdrPSP]
	mov esi, edx
@@:
if ?32BIT
	lods byte ptr [esi]
else
	lodsb
endif
	stosb
	and al,al
	loopnz @B
	mov ax,cs:[wRMPSP]
	mov [ebp].RMCS.rDS,ax
	mov [ebp].RMCS.rFlags,1
	mov [ebp].RMCS.rSSSP,0
	mov edi, ebp
	push ss
	pop es
	mov bx,0021h
	xor cx,cx
	mov ax,0300h
	int 31h
	mov ax,[ebp].RMCS.rAX
	test [ebp].RMCS.rFlags, 1
	lea esp, [esp+32+2]
	pop ebp
	pop edi
	pop esi
	pop es
	jz done
	cmp ax,7100h
	jz nolfn
	stc
	jmp done
nont:
  endif
  endif
  if ?32BIT
	push esi
	mov esi,edx
  else
	push si
	mov si,dx
  endif
	MOV AX,716Ch
	mov dx,1		;action: fail if not exists
	xor bx,bx		;read only 
	xor cx,cx		;
	stc
	int 21h			;use true DOS int (LFN for XP needs DKRNL32!)
  if ?32BIT
	mov edx,esi
	pop esi
  else
	mov dx,si
	pop si
  endif
	jnc done
	cmp ax,7100h
	stc
	jnz done
nolfn:
endif
	MOV AX,3D00h or _SFLAGS_	;open a file for read
	int 21h
done:
	ret
openfile endp

;*** search file in PATH
;*** inp: es:di behind "PATH=" in environment
;--- inp: szName: file to search
;*** out: file handle in AX if NC
;--- out: full path of file in szModName
;*** modifies szModName, SI

SearchFileInPath proc
	MOV SI,DI
nextitem:							;<----
	mov cl,00
	mov DI,offset szModName
@@:
	MOV AL,ES:[SI]					;get next path from PATH variable
	CMP AL,';'
	JZ @F
	CMP AL,00
	JZ @F
	MOV [DI],AL
	inc cl
	INC SI
	INC DI
	JMP @B
@@:
	mov ah,0
	and cl,cl						;is an empty path?
	jz skipitem
	CMP Byte Ptr [DI-01],'\'		;ends with backslash?
	JZ @F
	CMP Byte Ptr [DI-01],'/'		;or slash?
	JZ @F
	MOV Byte Ptr [DI],'\'			;add one
	INC DI
@@:
	push si
	call copyfilename
	mov DX,offset szModName
	call openfile
	pop si
	jnc found
	cmp ax, 4						;no file handles error?
	jz error
skipitem:
	mov cl,es:[si]
	INC SI
	cmp cl,';'
	jz nextitem
error:
	push ax
	mov DI,offset szModName
	call copyfilename
	@trace_s <"module not found in path",lf>
	pop ax
	STC
	RET
found:
	@trace_s <"module found in path",lf>
	RET

SearchFileInPath endp

;*** file not found in current directory
;*** scan PATH, NC if file was found
;*** then file handle in AX and file full path in ???
;*** inp: ds=loader dataseg
;--- szName= file to search
;*** C if error, then dos error code in AX
;*** modifies SI

ScanPath proc near

	@trace_s <"Searching PATH Variable",lf>
if ?32BIT
	cmp [dwSysDir],0
	jz nosysdir
	push es
	push esi
	push di
	mov esi, [dwSysDir]
	mov es,cs:[wFlatDS]
	mov DI,offset szModName
@@:
	lods byte ptr es:[esi]
	mov [di],al
	inc di
	and al,al
	jnz @B
	mov byte ptr [di-1],'\'
	call copyfilename
	pop di
	pop esi
	pop es
	mov DX,offset szModName
	call openfile
	jnc exit
nosysdir:
endif
	mov dx,offset szPathConst	;variable "PATH="
if 0
	call GetLdrEnvironmentVariable  ;DI=^Path
else
	mov es,cs:[wCurPSP]
	call GetEnvironmentVariable  ;DI=^Path
endif
	jc exit
							;PATH variable found (ES:DI)
	call SearchFileInPath 	;if found, in AX Handle (modifies SI)
exit:
	ret
ScanPath endp

if 1
;--- current drive/directory -> ds:si
;--- highword of esi has been cleared in 32bit version
;--- called by checkpathname
;--- return: size in AX

getcurrentdir proc
	@trace_s <"enter getcurrentdir",lf>
	push dx
	push si
	mov ah,19h
	int 21h
	@trace_s <"int 21,ah=19h called",lf>
	mov dl,al
	inc dl
	add al,'A'
	mov [si],al
	mov ax,"\:"
	mov [si+1],ax
	add si,3
	mov ah,47h
	int 21h
	@trace_s <"int 21,ah=47h called",lf>
	mov ah,-1
@@:
	lodsb
	inc ah
	and al,al
	jnz @B
	and ah,ah
	jz @F
	mov word ptr [si-1],"\"
@@:
	mov ax,si
	pop si
	sub ax,si
	pop dx
	@trace_s <"exit getcurrentdir",lf>
	ret
getcurrentdir endp
endif

;*** Caller: LoadModule16
;*** Input: DX:(E)AX=Path
;*** szPath= path of last EXE or 0
;*** Output:
;*** filename  in szName (8.3)
;*** Pfad	   in szModName
;*** ???	   in szPath
;*** DX=0 -> unqualified angabe

checkpathname proc
	@trace_s <"enter checkpathname",lf>
	push ds
	mov di,offset segtable
	mov bx,offset szName
	push ds
	pop es
	mov ds,dx
	xor dx,dx
if ?32BIT
	mov esi,eax
	mov al,[esi]
else
	mov si,ax
	mov al,[si]
endif
	cmp al,'\'
	jz checkpath0
	cmp al,'/'
	jz checkpath0
if ?32BIT
	mov ax,[esi+1]
else
	mov ax,[si+1]
endif
	cmp al,':'
	jnz checkpath1
	cmp ah,'/'
	jz checkpath0
	cmp ah,'\'
	jnz checkpath1
checkpath0:
	mov di,offset szModName
	inc dh
checkpath1: 					;copy [(E)SI] -> modname
if ?32BIT
	lods byte ptr [esi]
else
	lodsb
endif
	stosb
	mov es:[bx],al		;copy [(E)SI] -> szName
	inc bx
	cmp al,':'
	jz checkpath3
	cmp al,'/'
	jz checkpath3_1
	cmp al,'\'
	jnz @F
checkpath3_1:
	inc dl
checkpath3:
	mov bx,offset szName		;reset szName
@@:
	and al,al
	jnz checkpath1
	pop ds
	mov ax,[bx-3]
	or ax,2020h
	cmp ax,"ex"
	jnz @F
	mov ax,[bx-5]
	or ax,2020h
	cmp ax,"e."
	jnz @F
	mov szPath,0		;reset szPath if it is an .EXE
@@:
	and dh,dh			;absolute path given?
	jnz checkpath2		;then jump
	mov di,offset szModName
	mov si,offset szPath
if ?32BIT
	movzx esi,si			;is required, not only for getcurrentdir!
endif
if 1
	cmp [si],dh			;is szPath set?
	jnz @F
	call getcurrentdir	;current dir -> ds:si
	@trace_s <"relative path given, curdir is ">
	@trace_sx si
	@trace_s <lf>
endif
@@: 					;szPath -> szModName
	lodsb
	stosb
	and al,al
	jnz @B
	dec di
	cmp dl,0
	jz nosubdirs
	mov si,offset segtable
nextitem:
	lodsb
	stosb
	cmp al,'/'
	jz checkpath4
	cmp al,'\'
	jnz @F
checkpath4:
	dec dl
@@:
	or dl,dl
	jnz nextitem
	inc dl					;return dl != 0 to avoid PATH search
nosubdirs:
	mov si,offset szName	;strcat(szModName, szName)
if ?32BIT
	mov ah,00				;switch to dos32 name
	invoke checkandreplace
endif
@@:
	lodsb
	stosb
	and al,al
	jnz @B
checkpath2:
	@trace_s <"szModName: ">
	@trace_sx <offset szModName>
	@trace_s <lf,"szName: ">
	@trace_sx <offset szName>
	@trace_s <lf,"szPath: ">
	@trace_sx <offset szPath>
	@trace_s <lf,"exit checkpathname",lf>
	ret
checkpathname endp


checkoutoffh proc
	cmp ax,4
	jnz exit
	pusha
	push es
	mov ah,62h
	int 21h
	mov es,bx
	mov bx,es:[32h]
	cmp bx,0EFh			;can it be increased?
	jnb @F
	add bx,11h
	mov ah,67h
	int 21h
	@trace_s <"size file handle table increased to ">
	@trace_w bx
	@trace_s <lf>
	pop es
	popa
	stc
	ret
@@:
	@trace_s <"cannot increase file handle table",lf>
	pop es
	popa
exit:
	clc
	ret
checkoutoffh endp

;*** load a NE module
;*** Input: DX:(E)AX -> path
;***		DS=DGROUP ***
;*** RC: C on errors, then in AX=^ErrText
;*** else AX=MD
;--- modifies E/BX, E/SI, E/DI!!!

LoadModule16 proc
	cld
	@trace_s <"LoadModule16: enter; ">
if _TRACE_
	push ds
	push ax
	mov ds,dx
  if ?32BIT
	mov ebx,eax
  else
	mov bx,ax
  endif
	call _trace_s_bx
	@trace_s lf
	pop ax
	pop ds
endif
	call checkpathname	  ;path -> szModName, modulname -> pszName
tryagain:
	push dx
	mov dx,offset szModName
if ?32BIT
	movzx edx,dx
endif
	call openfile
	pop dx
	jnc loadmod_2
	call checkoutoffh
	jc tryagain
	and dx,dx			 ;was an absolute path given?
	jnz loadmod_1		 ;then error
	@trace_s <"open of ">
	@trace_sx <offset szModName>
	@trace_s <" failed, error=">
	@trace_w ax
	@trace_s <lf>
	@trace_s <"will try to open ">
	@trace_sx <offset szName>
	@trace_s <lf>
	push dx
	mov dx,offset szName	;try name without path (current dir)
	call openfile
	pop dx
	jnc loadmod_21
	@trace_s <"will search path now",lf>
	call ScanPath		 	;load without path didn't work, scan PATH
	jnc loadmod_2
	@trace_s <"ScanPath returned error=">
	@trace_w ax
	@trace_s lf
loadmod_1:
	cmp ax, 4
	mov ax,offset szNotFnd
	jnz errorx			;error 'file not found'
	mov ax,offset nohandles
	jmp errorx
loadmod_21:
	push ax
	mov si, offset szModName
	call getcurrentdir
	add si,ax
	mov di,offset szName
@@:
	mov al,[di]
	mov [si],al
	inc si
	inc di
	and al,al
	jnz @B
	pop ax
loadmod_2:
	mov bx,ax
	call ReadHdrs		;load headers (0040h Bytes) (to NE_Hdr)
	jc error3			;error
	test byte ptr NE_Hdr.APPFLGS,AF_DLL ;is app or dll?
	jnz @F
	mov ax,offset szNotaNE
if ?32BIT
	cmp NE_Hdr.ne_exetyp, ET_DPMI32	;only load 32bit NE apps!!!
	jnz error3
else
	cmp NE_Hdr.ne_exetyp, ET_DPMI32	;dont load 32bit NE apps!!!
	jz error3
	cmp NE_Hdr.ne_exetyp, ET_WINDOWS;dont load Win3 NE apps!!!
	jz error3
endif
	cmp [wTDStk],offset starttaskstk
	jz @F
if ?32BIT
	test bEnvFlgs, ENVFL_DISABLENE32
	jnz error3
endif
	test bEnvFlgs, ENVFL_LOAD1APPONLY
	jnz error3
@@:
	call AllocMD 		;alloc module database
	jc error3
	mov es:[NEHDR.ne_hFile],bx
	call LoadSegmTable	;read segment table
	jc error2
	call LoadNETables	;read other tables
	jc error2
							;now NE:0006 may be modified
	call InsertModule16	;save module ES in module list
	call LoadRefMods16	;load modules of external references
	jc error2
	call DoPreloads		;load PRELOAD and HUGE segments
	jc error4
	mov ax,word ptr es:[NEHDR.ne_csip+2]
	and ax,ax
	jz @F
	call SegNo2Sel		;get selector for entry CS
	mov word ptr es:[NEHDR.ne_csip+2],ax
@@:
	mov bx,0FFFFh
	xchg bx,es:[NEHDR.ne_hFile]
	mov ah,3Eh			;close file
	int 21h
	jc error1
	@trace_s <"module ">
	@tracemodule
	@trace_s <" (">
	@trace_w es
	@trace_s <") successfully loaded",lf>
	mov ax,es
	ret
error4:
	push ax
	call UnloadMod16		 ;clear all
	pop ax
error2:
	push ax
	test byte ptr [wErrMode+1],HBSEM_NOOPENFILEBOX
	jnz @F
	@strout_err "Error while loading module "
	call modnameout
	@cr_out
@@:
	mov word ptr es:[NEHDR.ne_cmod],0000
	mov ax,es
	call FreeLib16		;delete module
	pop ax
	stc
	ret
error3:
	push ax
	mov ah,3Eh			;close file
	int 21h
	pop ax
	jmp errorx
error1:
	xor ax,ax			;error on close
errorx:
if _TRACE_
	@trace_s <"can't load module ">
	mov bx,offset szModName
  if ?32BIT
	movzx ebx,bx
  endif
	call _trace_s_bx
	@trace_s lf
	and ax,ax
	jz @F
  if ?32BIT
	movzx ebx,ax
  else
	mov bx,ax
  endif
	call _trace_s_bx
@@:
endif	;_TRACE_
	cmp ax,offset szNotaNE		;dont display "not NE format" 
	jz @F
	test byte ptr [wErrMode+1],HBSEM_NOOPENFILEBOX
	jnz @F
	@strout_err "Module="
	mov bx,offset szModName
	@stroutbx 
	@cr_out
@@:
	stc
	ret
LoadModule16 endp

;*** read MZ-Header + NE-Header
;*** Input: BX=file handle
;---        DS=DGROUP
;*** C + AX=szNotaNE if not NE format

ReadHdrs proc

	@trace_s <"trying to read MZ/NE-Header",lf>
	xor ax,ax
	mov [NEHdrOfs],ax	;init offset NE-Header
	mov cx,0040h
	mov dx,offset MZ_Hdr
	mov ah,3Fh			;read MZ hdr
	int 21h
	jc error1			;DOS read error
	cmp ax,cx			;could read 40h bytes?
	jnz error2
	mov ax,word ptr [MZ_Hdr]
	cmp ax,'ZM'
	jz @F
	cmp ax,'EN'
	jz found			;MZ hdr is missing, is not an error
	jmp error3
@@:
	@trace_s <"trying to locate NE-Header",lf>
	mov cx,word ptr [MZ_Hdr+3Eh]
	mov dx,word ptr [MZ_Hdr+3Ch]
	and dx,dx
	jz error4
	mov [NEHdrOfs],dx	;offset NE-Headers
	mov ax,4200h		;lseek NE hdr
	int 21h
	jc error5			;DOS lseek error, no NE binary
	@trace_s <"trying to read NE-Header",lf>
	mov cx,0040h
	mov dx,offset NE_Hdr
	mov ah,3Fh			;read
	int 21h
	jc error6			;DOS read error
	cmp ax,cx
	jnz error7
	cmp word ptr [NE_Hdr],'EN'	;"NE" signature found?
	jnz error8
found:
	clc
	ret
error4:
	@trace_s <"NE-offset is zero",lf>
	@tracejmp @F
error2:
	@trace_s <"filesize less than 0x0040 Bytes",lf>
	@tracejmp @F
error3:
	@trace_s <"cannot find 'MZ' Header",lf>
	@tracejmp @F
error5:
	@trace_s <"lseek error",lf>
	@tracejmp @F
error7:
	@trace_s <"NE-Header size less than 0x0040 Bytes",lf>
	@tracejmp @F
error8:
	@trace_s <"cannot find 'NE' Header",lf>
	@tracejmp @F
@@:
	mov ax,offset szNotaNE		;File is no NE-EXE
	stc
	ret
error1:
	@trace_s <"read error (MZ)",lf>
	@tracejmp @F
error6:
	@trace_s <"read error (NE)",lf>
	@tracejmp @F
@@:
	mov ax,0000
	ret

ReadHdrs endp

;*** change descriptor from code to data/from data to code 
;*** inp BX = source selector
;*** inp AX = dest selector
;--- out AX = dest selector
;*** called by PrestoChangoSelector()

CreateAlias proc public

	push es
	push bx
if ?32BIT
	push edi
	sub esp,8
	mov edi, esp
else
	push di
	push bp
	mov bp,sp
	sub sp,8
	mov di,sp
endif
if _TRACE_
if ?32BIT
	pushad
	@trace_s <"CreateAlias, src=">
	@trace_w bx
	lar ecx,ebx
	shr ecx,8
	@trace_s <",acc=">
	@trace_w cx
	@trace_s <" dest=">
	@trace_w ax
	lar ecx,eax
	shr ecx,8
	@trace_s <",acc=">
	@trace_w cx
	@trace_s lf
	popad
endif
endif
	push ax
	push ss
	pop es
	mov ax,000Bh			  ;get BX desc -> ES:(E)DI
	int 31h
	jc exit
	@trace_s <"CreateAlias, get descriptor ok",lf>
if ?32BIT
	xor byte ptr es:[edi+5],8
else
	xor byte ptr es:[di+5],8
endif
	pop bx					  ;AX -> BX
	push bx

	mov ax,000Ch			  ;set BX desc <- ES:(E)DI
	int 31h
if _TRACE_
	jc exit
	@trace_s <"CreateAlias, set descriptor ok",lf>
	clc
endif
exit:
	pop ax
if ?32BIT
	lea esp,[esp+8]
	pop edi
else
	mov sp,bp
	pop bp
	pop di
endif
	pop bx
	pop es
	ret
CreateAlias endp

;*** copy descriptor (BX) to desc AX
;*** modifies ES, BX 
;*** C if error

CopyDescriptor proc public
	push es
	push ax
if ?32BIT
	push edi
	sub esp,8
	mov edi,esp
else
	push di
	push bp
	mov bp,sp
	sub sp,8
	mov di,sp
endif
	push ss
	pop es
	push ax
	mov ax,000Bh	 ;get descriptor
	call dpmicall
	pop bx
	jc @F
	mov ax,000Ch	 ;set descriptor
	call dpmicall
@@:
if ?32BIT
	lea esp,[esp+8]
	pop edi
else
	mov sp,bp
	pop bp
	pop di
endif
	pop ax
	pop es
	ret
CopyDescriptor endp

;*** create a writeable ALIAS for a descriptor
;--- in: ES:SI -> segment
;--- out: DX = writeable DATA selector, C on errors
;--- preserves ax,bx,cx

setrwsel proc near

	push es
	push ax
	push bx
	mov bx,es:[si].SEGITEM.wSel
if ?32BIT
	push edi
	sub esp,8
	mov edi,esp
else
	push di
	push bp
	mov bp,sp
	sub sp,8
	mov di,sp
endif
	push ss
	pop es
	mov ax,000Bh	 ;get descriptor
	call dpmicall
	jc @F
if ?32BIT
	and byte ptr es:[edi+5],0F7h ;CODE attribut reset
	or byte ptr es:[edi+5],02h	 ;write attribut set
else
	and byte ptr es:[di+5],0F7h  ;CODE attribut reset
	or byte ptr es:[di+5],02h	 ;write attribut set
endif
	mov bx,[aliassel]
	mov ax,000Ch	 ;set descriptor
	call dpmicall
	mov dx,bx
@@:
if ?32BIT
	lea esp,[esp+8]
	pop edi
else
	mov sp,bp
	pop bp
	pop di
endif
	pop bx
	pop ax
	pop es
exit:
	ret
setrwsel endp


;--- get length of string DS:(E)SI -> CX

if ?32BIT
strlen proc public uses esi
else
strlen proc public uses si
endif
	mov cx,0FFFFh
@@:
	inc cx
if ?32BIT
	lods byte ptr [esi]
else
	lodsb
endif
	and al,al
	jnz @B
	ret
strlen endp

;**************************************************

;--- create a NE header Modul database)
;--- 1. alloc a selector
;--- 2. alloc memory (NE header, segment table, res. names, full path)
;--- 3. copy 64 bytes from NE_Hdr
;--- 4. init some fields
;--- 5. copy full path from szModName
;--- inp: DS=dgroup
;--- out: ES=MD
;--- modifies es, di, si, bx, cx, dx, ax

AllocMD proc uses bx
	mov di,offset szModName
	push ds
	pop es
	mov cx,0FFFFh
	mov al,00
	repnz scasb
	not cx
	mov bx,offset NE_Hdr
	mov ax,cx					;length file name (incl 00)
	mov dx,[NEHdrOfs]			;offset NE-Header
	add dx,[bx.NEHDR.ne_rsrctab];+offset resource table
	mov cx,word ptr [bx.NEHDR.NRESADR]	;abs address nonres names
	sub cx,dx					;gives length of "resident" tables
	add cx,[bx.NEHDR.NRESLEN]	;+ length of table nonres names
	add cx,offset NEHDR.MDCONST	;+ length MD header
	add cx,ax					;+ length file name
	push ax
	mov ax,[bx.NEHDR.ne_cseg]	;number of segments
	inc ax						;add 1 segment !?
	mov bl,SGTSIZE				;for erweiterte segment table
	mul bl
	add cx,ax					;+ length segment table
	mov [wMDSize],cx			;gives size of module database
	push cx
	mov bx,0001 		;set selector to DATA
	call AllocSel		;alloc selector (in AX)
	pop cx
	jc errorx
	mov dx,SF_DATA		;AX=selector
	.if ((bEnvFlgs & ENVFL_DONTLOADHIGH) && (!wMDSta))
		or dl, SF_PRELOD
	.endif
	call AllocMem		;alloc memory (+ Base,Limit der Descipt)
	jc error1			;AX is 0000 or error text

	call Set_AX_Present
	jc errorx

	pop cx
	mov es,ax			 ;now set ES to MD
	mov word ptr es:[NEHDR.MEMHDL+0],si
	mov word ptr es:[NEHDR.MEMHDL+2],di
	mov ax,si
	and ax,di
	cmp ax,-1
	jnz @F
	mov word ptr es:[NEHDR.MEMHDL+0],dx
	mov word ptr es:[NEHDR.MEMHDL+2],-1
@@:
	mov si,offset szModName
	mov di,offset NEHDR.szModPath	;copy module name
	rep movsb
	mov es:[NEHDR.NXTFREE],di	;set next free space
	mov si,offset NE_Hdr		;copy NE header (64 bytes)
	sub di,di
	mov cx,0020h
	rep movsw
	mov es:[NEHDR.ne_count],cx	;clear module count
	and es:[NEHDR.APPFLGS],not AF_INIT
	mov es:[NEHDR.FINFO],NEHDR.szModPath-8	;to be windows compatible
	clc
	ret
error1:
	mov ax,offset errstr9		;error: cannot allocate req. memory
errorx:							;<--- no selector, DPMI error
	pop cx
	stc
	ret
AllocMD endp


;*** read segment table
;*** on errors: C and AX-> error text
;*** the loader can handle a maximum of 255 segments 

LoadSegmTable proc
	sub cx,cx
	cmp cx,es:[NEHDR.ne_cseg]
	jz done
	mov bx,es:[NEHDR.ne_hFile]
	mov dx,[NEHdrOfs]
	add dx,es:[NEHDR.ne_segtab]	;offset segment table
	adc cx,cx
	mov ax,4200h				;lseek
	int 21h
	jc error1
	mov ax,es:[NEHDR.ne_cseg]
	cmp ax,?MAXSEG
	jg error2
	shl ax,3					;8 bytes/segment in file
	mov cx,ax
	mov dx,offset segtable
	mov ah,3Fh					;read table
	int 21h
	jc error1
done:
	ret
error1:
	sub ax,ax
	stc
	ret
error2:
	mov ax,offset errstr11		;too many segments
	stc
	ret
LoadSegmTable endp

;*** segments special (auto data segment)
;*** ES:DI -> end of segment table

segspecial proc
	push di
	mov cx,SGTSIZE/2
	xor ax,ax
	rep stosw
	pop di
	mov bx,ax
	mov ax,es:[NEHDR.ne_autodata]	;does DGROUP exist?
	and ax,ax
	jz segspecial1				;no, then done
	cmp ax,es:[NEHDR.ne_cseg]	;is it an empty segment?
	jna @F
	mov ax,es:[NEHDR.ne_heap]
	or ax,es:[NEHDR.ne_stack]
	jz segspecial1				;no heap or stack?
	inc word ptr es:[NEHDR.ne_cseg]
	mov si,offset defdgrp
	call PrepSegDesc			;selector alloc ES:DI
	jc segspecialex
	mov bx,di
	jmp segspecial1
@@: 							;dgroup exists and not empty
	mov bl,SGTSIZE
	dec ax
	mul bl
	add ax,es:[NEHDR.ne_segtab]
	xchg bx,ax
	mov ax,es:[bx].SEGITEM.wSel
	lar cx,ax
	test ch,8					;is dgroup a code segment?
	jz @F						;no, then done
	and word ptr es:[bx.SEGITEM.flags],NOT SF_DISCRD
	mov si,offset defdgrp
	push bx
	push es:[bx.SEGITEM.memsiz]
	call PrepSegDesc				;selector alloc ES:DI
	pop cx
	pop ax
	jc segspecialex
	mov bx,di
if ?32BIT
;	or word ptr es:[bx.SEGITEM.flags],SF_ALIAS or SF_PRELOD
	or word ptr es:[bx.SEGITEM.flags],SF_ALIAS
else
	or word ptr es:[bx.SEGITEM.flags],SF_ALIAS
endif
	mov word ptr es:[bx].SEGITEM.dwHdl+0,ax
	mov es:[bx.SEGITEM.filesiz],cx
	mov es:[bx.SEGITEM.memsiz],cx
	inc word ptr es:[NEHDR.ne_autodata]
@@:
segspecial1:
	mov es:[NEHDR.DGROFS],bx	;^ Dgroup Segment
	clc
segspecialex:
	ret
segspecial endp

;*** prepare 1 segment (alloc selector)
;*** ES:DI -> segment descriptor in MD
;*** DS:SI -> segment descriptor in NE file to copy from (8 byte size)

PrepSegDesc proc
	xor ax,ax
	mov es:[di].SEGITEM.wDosSel,ax
	dec ax
	mov word ptr es:[di].SEGITEM.dwHdl+0,ax	;handle memory block
	mov word ptr es:[di].SEGITEM.dwHdl+2,ax
	mov bx,[si].SEGITEM.flags
	call AllocSel		;alloc selector in AX
	jc exit			;error?
	push di				;copy first 4 words 1:1
	movsw				;segment file position
	movsw				;segment file size
	movsw				;segment flags
	movsw				;segment memory size
	pop di
	mov es:[di].SEGITEM.wSel,ax	;R/E for code,R/W for data
	and byte ptr es:[di.SEGITEM.flags],not SF_LOADED
exit:
	ret
PrepSegDesc endp

;*** prepare segment table
;*** input: ES=MD, DI-> free space in MD
;*** the segment table has been read into segtable (8 bytes/segment)
;*** now prepare segment table in module header

PrepSegmTable proc
	mov si,offset segtable	;segment table
	mov cx,es:[NEHDR.ne_cseg]
	jcxz done
next:						;<----
	push cx
	call PrepSegDesc		;get selector
	pop cx
	jc error
	add di,SGTSIZE
	loop next				;---->
done:
	call segspecial
	add di,SGTSIZE		 ; in any case 1 segment extra
	inc word ptr es:[NEHDR.ne_cseg]
error:
	ret
PrepSegmTable endp

;*** read all tables of a NE header in module database
;*** on errors: C und AX -> error text

LoadNETables proc
	@trace_s <"load segment table",lf>
	mov di,es:[NEHDR.NXTFREE]
	mov es:[NEHDR.ne_segtab],di
	call PrepSegmTable		;prepare segment table
	jc error1

	@trace_s <"load resource table",lf>
	push di
	call LoadResTable		;read resource tabl
	pop es:[NEHDR.ne_rsrctab]	;address resource table
	jc error1

	@trace_s <"load resident names table",lf>
	push di
	call LoadResNames		;read resident names
	pop es:[NEHDR.ne_restab]	;address resident names
	jc error1

	@trace_s <"load module reference table",lf>
	push di
	call LoadModRefs			;read referenced modules
	pop es:[NEHDR.ne_modtab]	;address module references
	jc error1

	@trace_s <"load imported names table",lf>
	push di
	call LoadImpTable		;read imported names
	pop es:[NEHDR.ne_imptab]	;address imported names
	jc error1

	@trace_s <"load entry table",lf>
	push di
	call LoadEntryTable		;read entries
	pop es:[NEHDR.ne_enttab]	;address entries
	jc error1

	@trace_s <"load nres table",lf>
	push di
	call LoadNResNames		;read nonresident names
	pop es:[NEHDR.NRESNAM]	;address nonresident names
	jc error1

	cmp di,[wMDSize]		;is length correct?
	jnz error2
	@trace_s <"tables ok",lf>
	ret
error2:
	mov ax,offset errstr5
error1:
	@trace_s <"error exit from modul table load",lf>
	stc
	ret
LoadNETables endp

;*** error happened (^error text in AX, if ax==0000 -> DOS error)
;*** if AX=-1, dont display anything
;--- modifies bx, di, cx, ax

stroutax proc
	and ax,ax
	jz @F
	mov bx,ax
	inc ax
	jnz normerr
	ret
@@:
	mov bx,ax
	mov ax,5900h	;get extended error info
	int 21h
	mov di,offset szExtErrCod
	call WORDOUT
	mov di,offset szExtErrCls
	mov al,bh
	call BYTEOUT
	mov di,offset szExtErrAct
	mov al,bl
	call BYTEOUT
	mov di,offset szExtErrLoc
	mov al,ch
	call BYTEOUT
	mov bx,offset szExtErr
normerr:
	@strout_err
	ret
stroutax endp

;*** alloc 1 Selector
;*** Input: segment flags in BX (bit 0)
;*** Output: AX=Selector, C=error

AllocSel proc
	mov cx,0001
if ?AUTOCSALIAS        
	test bl,SF_DATA
	jnz @F
	test es:[NEHDR.APPFLGS],10h
	jz @F
	inc cx
@@:
endif
	xor ax,ax
	call dpmicall			;alloc selector
	jc error1
	push ax
	test bl,01				 ;DATA=1/CODE=0
	jnz @F
	mov cx,_ACCCODE_
	call SetAccBits
	jc error2
	pop ax					;selector in AX
	clc
	ret
@@:
	mov cx,_ACCDATA_		;this should be set already
	call SetAccBits
	jc error2
	pop ax
	clc
	ret
error1:
	mov ax,offset szErr33	;error "out of descriptors"
	stc
	ret
error2:
	pop ax
	mov ax,offset szErr36	;error "set acc rights failed"
	stc
	ret
AllocSel endp

;*** set CODE/DATA accessrights(in CX) for Selector AX
;*** BX = segment flags

SetAccBits proc uses ax bx

	test bh,20h		;32-Bit?
	jz @F
	or ch,40h
@@:
	test bl,80h		;readonly?
	jz @F
	and cl,0FDh
@@:
	test bh,02h		;conforming?
	jz @F
	or cl,04h
@@:
	mov bx,ax
	mov ax,cs
	and ax,0003h
	shl ax,05
	or cx,ax
	mov ax,0009h	;set access rights
	call dpmicall
	ret
SetAccBits endp

;*** alloc memory
;*** for segments + MD
;*** Input: CX=bytes (0000=64k)
;***		DX=flags
;***		AX=selector
;***		ES=MD
;*** Output:
;*** on errors: C, AX=^error text
;*** modifies blksize,blkaddr,SI,DI

AllocMem proc
	push ax
	@trace_s <"AllocMem enter: size=">
	@trace_w cx
	@trace_s <" flags=">
	@trace_w dx
	@trace_s lf
	sub bx,bx
	mov word ptr [blksize+2],bx 	;set limit
	dec cx
	mov word ptr [blksize+0],cx
	add cx,1
	adc bx,bx
	mov dh,00
	mov al,dl
	cmp es:[NEHDR.ne_exetyp],ET_OS2	;ignore DOS alloc for OS/2
	jz @F
	and al,SF_MOVABL or SF_PRELOD
	cmp al,SF_PRELOD	;fixed+preload segment? -> then DOS alloc
	jz AllocDosMem
@@:
if _DISCARD_
	mov dl,2
tryagain:
endif
	mov ax,0501h		;alloc memory (BX:CX bytes)
	int 31h
if _DISCARD_
	jnc @F
	dec dl
	jz error1
	call discardmem
	jmp tryagain
@@:
else
	jc error1
endif
	@trace_s <"AllocMem: memory allocated, handle=">
	@trace_w si
	@trace_w di
	@trace_s <", base=">
	@trace_w bx
	@trace_w cx
	@trace_s <", limit=">
	@trace_w <word ptr [blksize]>
	@trace_s lf

	mov word ptr [blkaddr+2],bx 	;save lineare address
	mov word ptr [blkaddr+0],cx
	pop ax
	call SetBaseLimit			  ;set base and limit of AX
	jc error2
if ?32BIT
	lsl ecx,eax
	test ecx,0FFFF0000h
	jz @F
	pusha
	mov bx,word ptr [blkaddr+2]
	mov cx,word ptr [blkaddr+0]
	inc ecx
	push ecx
	pop di
	pop si
	mov ax,0703h
	int 31h
	popa
@@:
endif
	mov cx,word ptr [blkaddr+2] 	;address in CX:DX
	mov dx,word ptr [blkaddr+0]
	clc
	ret
error1:
	pop ax
	mov ax,offset szErr31	;error: ALLOC memory
	stc
	ret
AllocDosMem:
	shr bx,1
	rcr cx,1
	mov bx,cx			;now in CX number of words
	shr bx,03			;-> paragraphs
	inc bx
	@trace_s <"AllocMem: alloc ">
	@trace_w bx
	@trace_s <" paras conv memory",lf>
	mov ax,0100h		;alloc DOS memory
	call dpmicall
	jc error3
	mov bx,0010h		;segment in AX
ife ?USELOADERPSP
ife ?STUB
	@trace_s <"AllocMem: adjust owner of DOS memblock", lf>
	pusha
	dec ax			;get paragraph address of block's MCB
	mul bx			;convert paragraph in AX to linaddr in DX:AX
	mov cx,dx
	mov dx,ax
	mov bx,[aliassel]	;loader's CS alias
	mov ax,0007		;set base to CX:DX
	call dpmicall
	jc @F			;shouldn't happen
	mov ax, [wRMPSP]	;loader's PSP segment
	push ds
	mov ds,bx
	mov ds:[1],ax		;set MCB's PSP to that of the loader
	pop ds
@@:
	popa
endif
endif
	push dx
	mov cx,ax
	mul bx			;convert paragraph in AX to linaddr in DX:AX
	mov word ptr [blkaddr+2],dx  ;now address in DX:AX
	mov word ptr [blkaddr+0],ax
	pop dx

	pop ax				;selector -> AX

	push cx
	push dx
	call SetBaseLimit	;set base and limit of AX
	pop dx
	pop cx
	jc error2
	@trace_s <"DOS memory allocated, handle=">
	@trace_w dx
	@trace_s lf
	mov si,-1		;Handle = -1
	mov di,si		;return in DX:	DOS memory selector
	clc
	ret
error2:
	@trace_s <"AllocMem, SetBaseLimit() failed",lf>
	ret
error3:
	@trace_s <"AllocMem error exit",lf>
	pop ax
	xor ax,ax
	stc
	ret
AllocMem endp

if _DISCARD_

;*** in BX:CX number of bytes ***

discardmem proc public
	pusha
	push es
	@trace_s <"memory is scarce, try to discard segments",lf>
	mov ax,[wMDSta]
discardmem_2:
	and ax,ax
	jz discardmem_ex
	mov es,ax
	mov cx,es:[NEHDR.ne_cseg]
	jcxz discardmem_1
	mov si,es:[NEHDR.ne_segtab]
discardmem_4:
	mov ax,es:[si.SEGITEM.flags]
	and ax,SF_DISCRD or SF_LOADED
	cmp ax,SF_DISCRD or SF_LOADED ;must be loaded + discardable
	jnz discardmem_3
	mov ax,es:[si].SEGITEM.wSel
	cmp ax,callcs
	jz discardmem_3			;never delete CS of caller

	@trace_s <"discarding segment ">
	@trace_w ax
	@trace_s ",cs="
	@trace_w cs
	@trace_s ",ds="
	@trace_w ds
	@trace_s ",es="
	@trace_w es
	@trace_s ",caller="
	@trace_w callcs
	@trace_s lf

	push cx
	mov cx,0FF7Fh				  ;present bit reset
	xor dx,dx
	call setaccrights			  ;selector in AX
	call SetNPBase				  ;set BX base (not present) to ES:SI
	call freesegmmem 			  ;free segment's memory ES:SI
	pop cx
discardmem_3:
	add si,SGTSIZE
	loop discardmem_4
discardmem_1:
	mov ax,es:[NEHDR.NXTMOD]
	jmp discardmem_2
discardmem_ex:
	pop es
	popa
	ret
discardmem endp

endif

;*** free a segment's memory
;*** Input: DX=segment flags (not used)
;***        AX=DOS memory selector 
;***        SI:DI=DPMI memory handle  (if AX==NULL)
;*** Output: C=error

FreeMemory proc
	and ax,ax
	jnz freedosmem
freeextmem::					;<-entry free dpmi memory
	mov ax,0502h			;free memory
	call dpmicall
	ret
freedosmem:
	mov dx,ax
	mov ax,0101h			;free DOS memory
	call dpmicall
	ret
FreeMemory endp

if ?MULTPSP
if ?32BIT eq 0

;*** inp: BX=Segment   ***
;*** out: BX=Selector  ***

AllocRMSegment proc uses cx dx
	xor ax,ax
	mov cx,0001 			;alloc selector
	int 31h
	jc exit
	xchg ax,bx				;segment in bx
	mov dx,ax				;zu addr in cx:dx
	shr ax,12
	mov cx,ax
	shl dx,4
	mov ax,0007
	int 31h 				;set base
	jc exit
	mov dx,-1
	xor cx,cx
	mov ax,0008 			;set limit to 64k
	int 31h
exit:
	ret
AllocRMSegment endp

endif
endif

;*** set base and limit
;*** inp: AX= selector
;*** inp: ES= MD
;*** blkaddr: address
;*** blksize: limit
;*** out: C=error, then AX=^error text

SetBaseLimit proc uses bx

	mov cx,word ptr [blkaddr+2]
	mov dx,word ptr [blkaddr+0]
	mov bx,ax
	mov ax,0007h			;set segment base address
	call dpmicall
	mov ax,offset szErr34	;error 'set segment base'
	jc error1
	mov cx,word ptr [blksize+2]
	mov dx,word ptr [blksize+0]
	or dl,0Fh				;round up to paragraphs
	test cx,0FFF0h			;> 1MB?
	jz @F
	or dx,0FFFh			;then round up to page
@@:
	mov ax,0008h			;set segment limit
	call dpmicall
	mov ax,offset szErr35	;error 'set segment limit'
	jc error2
if ?AUTOCSALIAS
	lar ax,bx
	test ah,8
	jz @F
	test es:[NEHDR.APPFLGS],10h	;is it RTM app?
	jz @F
	mov ax,bx
	add ax,8
	call SetBaseLimit
	jc error1
@@:
endif
	mov ax,bx
error1:

error2:
	ret
SetBaseLimit endp

;*** set access rights in AX
;*** Input: DX=OR-mask, CX=AND-mask
;*** RC: in CX previous accrights, C on error
;*** out: BX=selector 
;--- modifies AX, BX, CX

setaccrights proc uses es

if ?32BIT
	push edi
	sub esp,8
	mov edi,esp
else
	push di
	push bp
	mov bp,sp
	sub sp,8
	mov di,sp
endif
	push ss
	pop es
	mov bx,ax
	mov ax,000Bh	 ;get descriptor
	call dpmicall
	mov ax,offset szErr37	;error: Cannot get Descriptor
	jc error1
if ?32BIT
	mov ax,word ptr es:[edi+5]
else
	mov ax,word ptr es:[di+5]
endif
	and ax,cx
	or ax,dx
	mov cx,ax
	mov ax,0009h	 ;set access rights
	call dpmicall
	mov ax,offset szErr36	;error: Cannot set Descriptor
	jc error2
if ?32BIT
	mov cx,word ptr es:[edi+5]
else
	mov cx,word ptr es:[di+5]
endif
error1:
error2:
if ?32BIT
	lea esp,[esp+8]
	pop edi
else
	mov sp,bp
	pop bp
	pop di
endif
	ret
setaccrights endp

;*** set descriptor to present
;*** AX=Selestor
;*** RC: C on errors

Set_AX_Present:
	pusha
	mov cx,0FFFFh
	mov dx,0080h	 ;set PRESENT bit
	call setaccrights
	popa
	ret

setexc0b proc uses bx
	mov bl,0Bh
	mov ax,0202h	;get exception 0B
	call dpmicall
	jc @F
if ?32BIT
	mov dword ptr oldexc0b+0,edx
	mov word ptr oldexc0b+4,cx
	mov edx, offset Exc0BProc
else
	mov word ptr oldexc0b+0,dx
	mov word ptr oldexc0b+2,cx
	mov dx, offset Exc0BProc
endif
	mov cx,cs
	call setexc
@@:
	ret
setexc0b endp

;*** set segment BX base to ES:SI
;*** this is initialization for NOT PRESENT segments

SetNPBase proc
if ?32BIT
	cmp word ptr cs:[oldexc0b+4],0	 ;is Exc 0B Handler installed?
else
	cmp word ptr cs:[oldexc0b+2],0
endif
	jnz @F
	call setexc0b
	jc error
@@:
	mov cx,es
	mov dx,si
	mov ax,0007h			;set segment base
	call dpmicall
	jc error
	ret
error:
	mov ax,offset szErr34	;error
	stc
	ret
SetNPBase endp

;*** called from NP-Exception Handler: set ES (^MD)
;*** Input: BX=Selector ***
;*** RC: ES:SI ***

GetNPBase proc
	mov ax,0006h		 ;get segment base -> cx:dx
	call dpmicall
	jc error
	lar ax,cx			 ;in Base there is ^NE.Segment
	jnz error
	mov es,cx
	cmp es:[NEHDR.ne_magic],'EN'
	jnz error
	mov si,dx
	clc
	ret
error:
	mov ax,offset int0Berr1		;invalid not present exception
	stc
	ret
GetNPBase endp

;--- open image: may be called from exception 0B handler!
;--- inp: ES = NE module handle
;--- set C on errors
;--- modifies BX,AX

openimage proc
	mov bx,es:[NEHDR.ne_hFile]
	cmp bx,-1
	clc
	jnz exit
	push ds
	push dx
	push es
	pop ds
	mov dx,offset NEHDR.szModPath
	call openfile
	jc @F
	mov bx,ax
	mov es:[NEHDR.ne_hFile],ax
@@:
	pop dx
	pop ds
exit:
	ret
openimage endp

;--- may be called from exception 0B handler

closefile proc
	cmp word ptr callcs,0
	jz exit
	mov bx,-1
	xchg bx,es:[NEHDR.ne_hFile]
	cmp bx,-1
	jz exit
	mov ah,3Eh					   ;close file
	int 21h
exit:
	ret
closefile endp

;*** load a segment
;*** called by Exc 0B handler and for preload segments
;*** inp: ES:SI = ptr SEGITEM
;***	  AX=CS if EXC 0B, else 0000
;*** tasks:
;*** - alloc memory 
;*** - do relocation fixups
;*** - set descriptor values
;*** out: C=error, then in AX error text or 0000
;*** must preserve E/BP!

Load_Segm proc
	mov [callcs],ax
if ?RMSEGMENTS
	test byte ptr es:[si.SEGITEM.flags],SF_RES1
	jnz ls_1
endif
	@trace_s <"Load_Segm: about to allocate memory for ">
	@trace_w es:[si].SEGITEM.wSel
	@trace_s lf
	call Alloc_Mem_for_Segm			;alloc memory (rc in AX=size) +
	jc error4				;set descriptor to present
	push ax
ls_1:
	mov dx,es:[si.SEGITEM.filepos]
	and dx,dx				;if filepos == 0
	jz ls_3					;then segment isnt external object
	call openimage
	jnc ls_2
	@trace_s <"Load_Segm, open() failed",lf>
	@strout_err "Cannot open file "
	push ds
	push es
	pop ds
	mov bx,offset NEHDR.szModPath
	@stroutbx
	pop ds
	@cr_out
	jmp error2
ls_2:
	sub ax,ax
	mov cx,es:[NEHDR.SEGSHFT]
@@:
	shl dx,1
	rcl ax,1
	loop @B
	mov cx,ax
	mov ax,4200h					;lseek
	int 21h
if _TRACE_
	jnc @F
	@trace_s <"Load_Segm: lseek() failed",lf>
	jmp error2x
@@:
else
	jc error2x						;error (+ adjust stack)
endif
	mov cx,es:[si].SEGITEM.filesiz
	call setrwsel					;get alias in DX
if ?RMSEGMENTS
	test byte ptr es:[si.SEGITEM.flags],SF_RES1
	jz @F
	mov dx,es:[si].SEGITEM.wDosSel	;selector
@@:
endif
	@trace_s <"Load_Segm: trying to read segment",lf>
	push ds
	mov ds,dx
	sub dx,dx
ife ?32BIT
	test byte ptr es:[si.SEGITEM.flags],SF_ITERED
	jz @F
	call Read_Iterated_Segm
	jmp readdone
@@:
endif
	and cx,cx						;is it 64 kB?
	jnz @F
	mov cx,08000h
	mov ah,3Fh
	int 21h							;then do it in 2 reads
	mov dx,8000h
	mov cx,dx
@@:
	mov ah,3Fh						;read segment (CX bytes)
	int 21h
readdone:
	pop ds
if _TRACE_
	jnc @F
	@trace_s <"Load_Segm, read() failed",lf>
	jmp error2x
@@:
else
	jc error2x						;error (mit stackkorrektur)
endif
	@trace_s <"Load_Segm: done file read",lf>
ls_3:
	pop ax							;size -> AX
	@trace_s <"Load_Segm: about to zeroinit rest of segment",lf>
	call ClearSegmentTail			;clear rest with 00
	test word ptr es:[si.SEGITEM.flags],SF_RELOCS ;relocations exist?
	jz ls_4
	@trace_s <"Load_Segm: about to handle relocations",lf>
	push si
	call DoRelocs					;do relocations fixups
	pop si
	jc error1
	@trace_s <"Load_Segm: relocations done",lf>
ls_4:
	call closefile
	jc error3
if ?INT41SUPPORT
	push si
	push di
	mov ax,si
	sub ax,es:[NEHDR.ne_segtab]
	mov bl,SGTSIZE
	div bl
	inc ax
	mov bx,ax						;segment no
	mov cx,es:[si].SEGITEM.wSel	;selector
	mov si,es:[si.SEGITEM.flags]	;segmentflags
	mov di,es:[NEHDR.ne_restab]		;es:di -> module name
	inc di
	mov ax,DS_LoadSeg
	int 41h
	pop di
	pop si
endif
	@trace_s <"Load_Segm: exit",lf>
	clc
;exit:
	ret
error2x:
	call closefile
error2:
	pop dx				;clear stack (selector)
error3:
	sub ax,ax
error4:
	@trace_s <"Load_Segm: error exit",lf>
	stc
	ret
error1:
	push ax
	@trace_s <"Load_Segm: error during relocation",lf>
	call closefile
	pop ax
	stc
	ret
Load_Segm endp

ife ?32BIT

;--- inp: DS=segment to iterate
;--- CX=file size of segment
;--- BX=file handle
;--- out: DX=next free byte in segment

Read_Iterated_Segm proc uses es di si bp 
	push ds
	pop es
	mov di,cx
nextitem:
	mov cx,4
	sub sp,cx
	mov si,dx
	mov dx,sp		;this is 16-bit only
	push ss
	pop ds
	mov ah,3Fh
	int 21h
	pop bp			;number of iterations
	pop cx			;size in bytes
	jc error
	push es
	pop ds
	mov dx,si
	mov ah,3Fh
	int 21h
	jc error
	sub di,ax
	jc error
	sub di,4
	jc error
@@:
	add dx,ax
	dec bp
	jz @F
	mov cx,ax
	push di
	mov di,si
	add di,cx
	rep movsb
	pop di
	jmp @B
@@:
	and di,di
	jnz nextitem
error:
	ret

Read_Iterated_Segm endp

endif

;*** do SF_ALIAS segments
;*** input: dx=flags, (e)cx=req size
;*** out: NC + selector in ax
;---      C + AX= error text or NULL
;--- currently most likely doesnt work for dos memory segments (PRELOAD+FIXED)

ReallocMem proc
	@int3 _INT03REALLOC_
	mov bx,word ptr es:[si].SEGITEM.dwHdl+0  ;here ^segmentdescriptor of alias
	push si
	push ax
	push es
	mov es,es:[bx].SEGITEM.wSel  ;load alias segment
	pop es
	mov di,word ptr es:[bx].SEGITEM.dwHdl+0
	mov si,word ptr es:[bx].SEGITEM.dwHdl+2
	mov ax,word ptr es:[bx].SEGITEM.wDosSel
if ?32BIT
	push ecx
	dec ecx
	mov [blksize],ecx	 ;set limit
	pop cx
	pop bx
else
	xor bx,bx
	dec cx
	mov word ptr [blksize+0],cx
	mov word ptr [blksize+2],bx
	inc cx
endif
	and ax,ax						;is DOS memory used?
	jz isdpmimem
	mov dx,ax
	test bx,0FFF0h					;is limited to 1 MB
	jnz ReallocMem_err
	shr cx,4
	shl bx,12
	or bx,cx
	mov ax,0102h		   ;the address cannot change
	int 31h 			   ;server will do the selector tiling
	jc ReallocMem_err
	mov ax,dx
	jmp reallocmem_exx
isdpmimem:
	@trace_s <"realloc alias, handle=">
	@trace_w si
	@trace_w di
	@trace_s <", size=">
	@trace_w bx
	@trace_w cx
	@trace_s <lf>
	mov ax,0503h		;realloc memory
	call dpmicall
	jc ReallocMem_err
reallocmem_1:
	mov dx,si
	pop ax
	pop si
	push si
	push ax
	mov word ptr [blkaddr+2],bx
	mov word ptr [blkaddr+0],cx
	mov si,word ptr es:[si].SEGITEM.dwHdl+0
	mov word ptr es:[si].SEGITEM.dwHdl+0,di
	mov word ptr es:[si].SEGITEM.dwHdl+2,dx
	call SetBaseLimit
	jc ReallocMem_err1
	mov ax,es:[si].SEGITEM.wSel
	call SetBaseLimit
	jc ReallocMem_err1
reallocmem_exx:
	pop ax
	pop si
ReallocMem_ex:
	ret
ReallocMem_err:
	mov ax,offset szErr311
ReallocMem_err1:
	pop cx
	pop si
	ret
ReallocMem endp

;*** ES:SI -> ext. segment table
;*** alloc memory for segment and set descriptor values
;*** will be called by NP-exception handler as well
;*** RC: if NC size in AX
;--- on error C and AX=error string or NULL

Alloc_Mem_for_Segm proc
	mov dx,es:[si.SEGITEM.flags]	;flags
	mov cx,es:[si.SEGITEM.memsiz]	;size
	mov ax,es:[si].SEGITEM.wSel
	cmp si,es:[NEHDR.DGROFS]		;Dgroup-Segment?
	jnz @F
if ?32BIT
	movzx ecx,cx
	movzx ebx,word ptr es:[NEHDR.ne_stack]
	shl ebx,12					 ;32bit: pages instead of bytes
	add ecx,ebx
	movzx ebx,word ptr es:[NEHDR.ne_heap]
	shl ebx,12					 ;32bit: pages instead of bytes
	add ecx,ebx
else
	add cx,es:[NEHDR.ne_stack]	 ;Stack Extra
	add cx,es:[NEHDR.ne_heap]	 ;Heap Extra
  if 1
	cmp es:[NEHDR.ne_exetyp],ET_OS2
	jnz @F
	xor cx,cx	;alloc 64 kB
  endif
endif
@@:
	push cx
	push di
	test dx,SF_ALIAS
	jz amfs_1
	@trace_s <"Alloc_Mem_for_Segm: segment alias",lf>
	call ReallocMem
	jc error1			;is AX set?
	call Set_AX_Present
	pop di				;dont set "loaded"-flag here
	pop ax				;return: size memory
	ret
amfs_1:
	push si
	push es
	call AllocMem		;memory alloc (AX=Selector, DX=Flags)
	mov bx,si
	pop es
	pop si				;get ^segment
	jc error1			;on errors AX is 0000 or error text	
if ?RMSEGMENTS
	test byte ptr es:[si.SEGITEM.flags],SF_RES1
	jz @F
	mov es:[si+XDOSSEG],cx			;CX=Segment
	mov es:[si].SEGITEM.wDosSel,dx	;DX=Selector
	jmp done
@@:
endif
	mov word ptr es:[si].SEGITEM.dwHdl+2,bx
	mov word ptr es:[si].SEGITEM.dwHdl+0,di
	and bx,di
	cmp bx,0FFFFh
	jnz done
	mov es:[si].SEGITEM.wDosSel,dx	;DOS memory used
done:
	call Set_AX_Present
	or byte ptr es:[si.SEGITEM.flags],SF_LOADED
	@trace_s <"Alloc_Mem_for_Segm normal exit",lf>
	pop di
	pop ax			  ;return: size memory
	ret
error1:				  ;memory error
	@trace_s <"Alloc_Mem_for_Segm failed",lf>
	pop di
	pop cx			  ;preserve ax here (error text)
	ret
Alloc_Mem_for_Segm endp


;*** get position in file

if 0

GetSegmentPos proc
	sub ax,ax
	mov cx,es:[NEHDR.SEGSHFT]
@@:
	shl dx,1
	rcl ax,1
	loop @B
	mov cx,ax
	ret
GetSegmentPos endp

endif

;*** clear rest of a segment
;*** if memsize > filesize
;*** Input: ES:SI-> segment, AX = size of memory block (0=64 kB)
;*** BX,ES,SI must be kept

ClearSegmentTail proc
	push es
	push di
	mov di,es:[si.SEGITEM.filesiz]
	test byte ptr es:[si.SEGITEM.flags],SF_ITERED
	jz @F
	mov di,dx
@@:
	mov cx,ax
	jcxz @F
	cmp cx,di
	jbe exit
@@:
	sub cx,di
	call setrwsel	;get ALIAS in DX
	mov es,dx
	sub ax,ax
	shr cx,1
	rep stosw
	adc cl,al
	rep stosb
exit:
	pop di
	pop es
	ret
ClearSegmentTail endp

;--- DS->loader data segment
;*** load PRELOAD- and HUGE- segments
;--- modifies cx, si, bx
;--- current psp is still the loader's (important for DOS memory alloc)

DoPreloads proc
	@trace_s <"DoPreloads: enter; loading preload & huge segments",lf>
	mov cx,es:[NEHDR.ne_cseg]		;no segments
	jcxz done
	mov si,es:[NEHDR.ne_segtab]
nextitem:							;<----
	push cx
	cmp word ptr es:[si].SEGITEM.wSel,0  ;dummy entry?
	jz doneitem
if ?RMSEGMENTS
	test byte ptr es:[si.SEGITEM.flags],SF_RES1
	jz @F
	test byte ptr es:[si.SEGITEM.flags],SF_DATA
	jnz loadit					   ;DATA always Preload
	mov bx,es:[si+DOSSEL]
	jmp dontloadit2
@@:
endif
	cmp word ptr es:[si.SEGITEM.memsiz],0  ;64k Segment?
	jnz @F
	or byte ptr es:[si.SEGITEM.flags],SF_PRELOD
	and byte ptr es:[si.SEGITEM.flags+1],-10h;change NONDISCARDABLE 
	cmp cx,2						  ;and a possibly succ segment
	jb @F
	or byte ptr es:[si.SEGITEM.flags+SGTSIZE],SF_PRELOD ;as well
	and byte ptr es:[si.SEGITEM.flags+SGTSIZE+1],-10h
@@:
	test byte ptr es:[si.SEGITEM.flags],SF_PRELOD
	jz dontloadit
loadit:
	xor ax,ax
	call Load_Segm				;load segment
	jc error1
	jmp doneitem
dontloadit:
	mov bx,es:[si].SEGITEM.wSel
dontloadit2:
	call SetNPBase				;set base (Not Present)
	jc errorx
doneitem:
	add si,SGTSIZE
	pop cx
	loop nextitem				;--->
done:
	@trace_s <"DoPreloads: exit",lf>
	clc
	ret
error1:
	call stroutax				;display AX if it contains text
	mov ax,offset errstr7		;"error while loading segments"
errorx:
	pop bx						;adjust stack
	stc
	ret
DoPreloads endp

;*** for 1 Module:
;*** free all selectors and memory
;*** ES=MD
;*** will change ES to 0000

CleanUpNE proc
	mov cx,es:[NEHDR.ne_cseg]
	jcxz done
	mov si,es:[NEHDR.ne_segtab]
nextitem:
	push cx
	mov bx,es:[si].SEGITEM.wSel
	and bx,bx
	jz nextseg
	mov ax,cs
	cmp ax,bx					;not for module KERNEL!
	jz nextseg
	@trace_s <"freeing selector ">
	@trace_w bx
	@trace_s lf
if ?32BIT							;make sure fs and gs dont get in the way
	mov ax,fs
	cmp ax,bx
	jnz @F
	push 0
	pop fs
@@:
	mov ax,gs
	cmp ax,bx
	jnz @F
	push 0
	pop gs
@@:
endif
	mov ax,0001					;free selector
	call dpmicall
	jc nextseg
if ?AUTOCSALIAS
	test es:[NEHDR.APPFLGS],10h
	jz @F
	test byte ptr es:[si].SEGITEM.flags, SF_DATA
	jnz @F
	add bx,8
	mov ax,0001					;free alias selector
	call dpmicall
@@:
endif
	call freesegmmem
nextseg:
	pop cx
	add si,SGTSIZE
	loop nextitem
done:
	@trace_s <"freeing MD selector ">
	@trace_w es
	@trace_s <", module ">
	@tracemodule
	@trace_s lf
	mov si,word ptr es:[NEHDR.MEMHDL+0] ;now do MD itself
	mov di,word ptr es:[NEHDR.MEMHDL+2]
	mov bx,es
	push 0
	pop es						  ;clear es before dpmi call
	mov ax,0001
	call dpmicall
	cmp di,-1
	jnz @F
	@trace_s <"freeing memory of MD, Handle=">
	@trace_w si
	@trace_s lf
	mov dx, si
	mov ax,0101h
	call dpmicall
	jmp done2
@@:
ife ?MEMFORKERNEL
	cmp [wMDSta],0
	jz done2
endif
	@trace_s <"freeing memory of MD, Handle=">
	@trace_w si
	@trace_w di
	@trace_s lf
	call freeextmem				  ;free memory
done2:
	@trace_s <"exit proc free_modul",lf>
	ret
CleanUpNE endp

;*** free memory of a loaded segment
;*** input: ES:SI -> segment 
;*** out: carry is error, then errortext in AX

;*** its possibly an error to free dos memory segments here
;*** because this memory will already have been freed by
;*** dos kill (int21, ah=0) call

freesegmmem proc near uses di
	mov dx,es:[si].SEGITEM.flags
	test dl,SF_LOADED
	jz exit
	and dl,not SF_LOADED
	mov es:[si].SEGITEM.flags,dx
	xor ax,ax
	or di,-1
	mov cx,di
	xchg ax,es:[si].SEGITEM.wDosSel			 ;DOS memory block sel
	xchg cx,word ptr es:[si].SEGITEM.dwHdl+2
	xchg di,word ptr es:[si].SEGITEM.dwHdl+0  ;DPMI handle
	@trace_s <"freeing memory of segm=">
	@trace_w es
	@trace_s <":">
	@trace_w si
	@trace_s <", handle ">
	@trace_w cx
	@trace_w di
	@trace_s <", dos sel=">
	@trace_w ax
	@trace_s lf
	push si
	mov si,cx
	call FreeMemory			;free memory (Handle in AX or SI:DI)
	pop si
	jnc exit
	push offset szErr32		;error: deallocate memory
	call stroutstk_err
	call displaymodandseg
	stc
exit:
	ret
freesegmmem endp

;*** input AX (Segment#), ES -> MD
;*** Output AX (Selector)

SegNo2Sel proc uses bx
	dec ax
	mov bl,SGTSIZE
	mul bl
	mov bx,ax
	add bx,es:[NEHDR.ne_segtab]
	mov ax,es:[bx].SEGITEM.wSel		;normal selector (R/E for Code,
if ?RMSEGMENTS						;				 R/W for Data)
	test byte ptr es:[bx.SEGITEM.flags],SF_RES1	;DOS-Block?
	jz exit
	test byte ptr es:[bx.SEGITEM.flags],SF_DATA	;CODE?
	jnz @F
	mov ax,es:[bx+DOSSEL]				 ;Code selector
	jmp exit
@@:
	mov ax,es:[bx+XDOSSEG]
endif
exit:
	ret
SegNo2Sel endp

;*** Input: Seg# in AX ***
;*** Output: size of memory for segment in AX

if 0

GetSegmSize proc uses bx
	dec ax
	mov bl,SGTSIZE
	mul bl
	mov bx,ax
	add bx,es:[NEHDR.ne_segtab]
	mov ax,es:[bx.SEGITEM.memsiz]
	ret
GetSegmSize endp

endif

;*** handle relocations for 1 segment
;*** Input: ES:SI=segment, BX=file handle
;*** Output: C=error, AX -> error text

DoRelocs proc
	mov [wlError],0
	mov cx,sizeof wCnReloc
	mov dx,offset wCnReloc		;read 2 Bytes (# of relocs)
	mov ah,3Fh					;this can be done without lseek
	int 21h 					;since segment was read just before
	jc error3
	mov cx,wCnReloc
	jcxz error2					;this may not be null
	call setrwsel				;get alias in DX (in: ES:SI=segment)
	mov ax,offset relbuf
	add ax,RELSIZE
	mov [wRelTmp],ax			;set buffer to overflow, thus causing
next:
	push cx						;relocs to be read
	call ReadReloc				;set DI to relocation
	jc error3a					;and possibly fill buffer
	call HandleReloc			;do 1 relocation
	pop cx
	jc error1					;on errors: ax-> error text

	loop next
	clc
error1:
	ret
error2:
	mov ax,offset errstr14		;Error: reloc. code has zero rel..
	stc
	ret
error3a:
	pop cx						;error on file access (read)
error3:
	mov ax,offset errstr6
	stc
	ret
DoRelocs endp

;*** for 1 relocation set DI
;*** if needed, refill buffer
;*** input: CX=number of references to fix
;--- ES=module

ReadReloc proc
	mov di,[wRelTmp]
	add di,+08
	mov dx,offset relbuf
	add dx,RELSIZE
	cmp di,dx
	jl rr_1
	mov bx,es:[NEHDR.ne_hFile]	;fill buffer
	cmp cx,RELSIZE/8			;can buffer hold the rest of entries 
	jb @F
	mov cx,RELSIZE/8
@@:
	shl cx,3					;each entry requirest 8 bytes
	mov dx,offset relbuf
	mov ah,3Fh
	int 21h 					;read relocations
	jc exit
	mov di,offset relbuf
rr_1:
	mov [wRelTmp],di
	clc
exit:
	ret

ReadReloc endp

getcssel:
	mov ax,[aliassel]
@@:
if ?RMSEGMENTS
	test byte ptr es:[si.SEGITEM.flags],SF_RES1
	jz @F
	mov ax,es:[si].SEGITEM.wDosSel
@@:
endif
	ret


;------------------------------	 ;Typ 03 (OSFIXUP)

;*** resolve OSFIXUPs

hr_03:
	mov bx,[di+04]
if _WIN87EMWAIT_
	cmp bx,6
	jz @F
endif
;	test [eWinFlags.wOfs],0400h  ;does FPU exist?
	test byte ptr [wEquip],2     ;does FPU exist?
	jz @F
	clc
	ret
@@:
	dec bx
	shl bx,2
	add bx,offset fpOSFixups
	mov dx,[bx+2]
	mov cx,[bx+0]
	call getcssel				 ;cs-alias -> AX
	mov bx,[di+02]				 ;start offset -> BX
	push ds
	mov ds,ax
	add [bx],cx
	add [bx+1],dx
	pop ds
	clc
	ret

;--- DS:DI -> 1 relocation
;--- ES:SI -> segment

;*** BYTE DI+0: rel address type
;*** BYTE DI+1: relocation type
;*** WORD DI+2: offset in segment
;*** WORD DI+4: module no of import
;*** WORD DI+6: entry no of import

;*** relocation address type
;***  0:byte             |  will result in:
;***  2:16 Bit selector  |  bit 3 (08): 1=offset is 32 Bit
;***  3:32 Bit pointer   |  bit 2 (04): 1=no selector exists
;***  5:16 Bit offset    |  bit 1 (02): 1=selector exists
;*** 11:48 Bit pointer   |  bit 0 (01): 1=offset vorhanden
;*** 13:32 Bit offset    |

;*** Output: C on errors, in AX then error text

HandleReloc proc
	mov cl,[di+01]	 ;relocation type
	and cl,03
	cmp cl,00		 ;00 (internal reference)
	jz hr_00
	cmp cl,01		 ;01 (imported ordinal)
	jz hr_01
	cmp cl,02		 ;02 (imported name)
	jz hr_02
	cmp cl,03		 ;03 (OSFIXUP)
	jz hr_03
	mov ax,offset errstr13	;cannot happen
	stc
	ret

;------------------------------  ;Typ 00 (internal reference)
hr_00:	mov ax,[di+04h]
	cmp ax,00FFh				 ;moveable???
	jnz hr_00_1					 ;can be selector or Selector:Offset
	mov ax,[di+06h] 			 ;logical segment no
	call GetProcAddr16			 ;selector:offset of entry -> AX:BX
	mov dx,ax
	mov cx,bx
	jmp hr_continue
hr_00_1:
	call SegNo2Sel				 ;get selector
	mov dx,ax
	mov cx,[di+06h]
	jmp hr_continue

;------------------------------ ;Typ 01 (reference to entry ordinal)
hr_01:	push es
	push si					;reference "by value"
	mov si,[di+04]
	dec si
	shl si,1
	add si,es:[NEHDR.ne_modtab]
	mov es,es:[si]
	mov ax,[di+06]
	call GetProcAddr16		;selector:offset of entry -> AX:BX
if _UNDEFDYNLINK_
	jnc @F
	mov ax,cs
	mov bx,offset UndefDynLink
@@:
else
	jc hr_01_1
endif
	mov dx,ax
	mov cx,bx
	pop si
	pop es
	jmp hr_continue
hr_01_1:
	pusha
	mov ax,[di+6]
	mov di,offset LENTERR
	call WORDOUT
	popa
	mov bx,offset errstr24	;error "entry not found"

notfounderror:				;<--- imported name not found
	@strout_err
	call modnameout
	@cr_out
	pop si
	pop es
ifdef ?CONTONIMPERR
	mov dx,cs
	mov cx,offset UndefDynLink
	jmp hr_continue
endif
	xor ax,ax
	stc
	ret

;------------------------------ Typ 02 (reference to entry in external module)
hr_02:
	@int3 _INT03NAMEIMP_
	push es
	push si			   ;reference "by name"
	push di
	push ds
	mov si,es:[NEHDR.ne_imptab];DS:SI must point to name to import
	add si,[di+06]	   ;this is the offset into name table
	mov di,[di+04]	   ;this is the module which exports this func
	dec di
	add di,di
	add di,es:[NEHDR.ne_modtab]
	push es
	mov es,es:[di]
	pop ds			   ;MD -> DS
	mov cl,[si] 	   ;length of imported name -> CL
	inc si
if ?32BIT
	movzx esi,si
endif
	call SearchNEExport	;search in resident+nonresident names
if _UNDEFDYNLINK_
	jnc @F
	mov ax,cs
	mov bx,offset UndefDynLink
@@:
else
	jc hr_02_1
endif
	mov dx,ax			;selector -> DX, Offset -> CX
	mov cx,bx
	pop ds
	pop di
	pop si
	pop es
	jmp hr_continue
hr_02_1:					;error
	mov bx,si
	mov cl,[si-1]
	call stroutBXn
	pop ds
	pop di
							;imported name not found
	mov bx,offset errstr25
	jmp notfounderror
							;the entry was found
							;now patch (CX:DX)
							;si -> segment descriptor
							;C is set on errors
hr_continue:
	call getcssel		;csalias -> AX
	push bp
	push di
	push ds
	push ax
	mov ax,[di+0]		;flags
	mov bx,[di+2]		;start offset -> BX
	pop ds
	call PatchSegment
	pop ds
	pop di
	pop bp
	ret
HandleReloc endp


;--- DS = segment to patch
;--- ES = module, ES:SI -> segment

PatchSegment proc
	mov di,2		;length offset part
	test al,08		;offset 32 Bit?
	jz @F
	mov di,4		;then length offset is 4
@@:
	and al,03
	test ah,04		;1 time/several times?
	jz isList
	cmp al,02		;is selector here (32 Bit pointer)?
	ja ps_fptr
	jnz @F
	add [bx],dx		;2=just selector
	clc
	ret
@@:
	dec al
	jnz @F
	add [bx],cx		;0/1=word offset
	clc
	ret
@@:
	add [bx],cl		;0=Byte
	clc
	ret
ps_fptr:
	add [bx+di],dx	;3=selector/offset
	add [bx],cx
	clc
	ret

;--- it's a non-additive relocation.
;--- such relocs are a linked list terminated by -1

isList:
if _CHECKSEGSIZE_
	mov bp,ds
	lsl bp,bp
endif
	cmp al,02			;far pointer?
	ja isfar
	jz @F
	mov dx,cx
@@:
nextitem:

if _CHECKSEGSIZE_
	cmp bp,bx
	jbe error1
endif
	mov ax,[bx]
	mov [bx],dx
	mov bx,ax
	inc ax	 			;-1 marks end of list
	jnz nextitem
	ret

isfar:	;might be far16 or far32

nextitem2:

if _CHECKSEGSIZE_
	cmp bp,bx
	jbe error1
endif
	mov ax,[bx]
	mov [bx+di],dx
	mov [bx],cx
	mov bx,ax
	inc ax	 			;-1 marks end of list
	jnz nextitem2
	ret
error1:
	mov ax,offset szErr22
	stc
	ret
PatchSegment endp

;*** read a table into MD
;*** AX=offset in file
;*** ES:DI=address in MD
;*** CX=size of table to read

ReadMD proc
if _TRACE_
	@trace_w cx
	@trace_s <" bytes to read from md-header",lf>
endif
	push cx
	mov bx,es:[NEHDR.ne_hFile]
	sub cx,cx
	mov dx,[NEHdrOfs]
	add dx,ax
	adc cx,cx
	mov ax,4200h		   ;lseek
	int 21h
	pop cx				   ;laenge restore
	jc readmd_er1
;	mov bx,es:[NEHDR.ne_hFile]
	mov dx,di
	push ds
	push es
	pop ds
	mov ah,3Fh			   ;read file
	int 21h
	pop ds
	jc readmd_er2
	add di,cx			   ;new position to di
	ret
readmd_er1:
readmd_er2:
	@trace_s <"error in function ReadMD",lf>
	mov ax,offset errstr6
	ret
ReadMD endp

;*** read resource table (to ES:DI)

LoadResTable proc

	mov cx,es:[NEHDR.ne_restab] ;are there any?
	mov ax,es:[NEHDR.ne_rsrctab]
	sub cx,ax
	jz @F
	jmp ReadMD
@@:
	clc
	ret

LoadResTable endp

;*** read resident names (to ES:DI)

LoadResNames proc

	mov cx,es:[NEHDR.ne_modtab]  ;are there any?
	mov ax,es:[NEHDR.ne_restab]
	sub cx,ax
	jz done
	push di
	call ReadMD
	pop bx
	jc done
if _LINKWORKAROUND_ 		;old linkers may save module names
	mov cl,es:[bx]		;not in caps!
nextitem:
	inc bx
	mov al,es:[bx]
	cmp al,'a'
	jb @F
	cmp al,'z'
	ja @F
	sub byte ptr es:[bx],'a'-'A'
@@:
	dec cl
	jnz nextitem
	clc
endif
done:
	ret

LoadResNames endp

;*** read module references (to ES:DI),C=error

LoadModRefs proc
	mov cx,es:[NEHDR.ne_imptab]	 ;are there any?
	mov ax,es:[NEHDR.ne_modtab]
	sub cx,ax
	jz @F
	jmp ReadMD
@@:
	ret
LoadModRefs endp

;*** read imported names (to ES:DI),C=error

LoadImpTable proc
	mov cx,es:[NEHDR.ne_enttab]		;offset entry table
	mov ax,es:[NEHDR.ne_imptab]
	sub cx,ax
	jz @F
	jmp ReadMD
@@:
	ret
LoadImpTable endp

;*** read nonresident names (to ES:DI),C=error

LoadNResNames proc
	mov cx,es:[NEHDR.NRESLEN]	 ;are there any?
	jcxz exit
	push cx
	mov bx,es:[NEHDR.ne_hFile]
	mov cx,word ptr es:[NEHDR.NRESADR+2]
	mov dx,word ptr es:[NEHDR.NRESADR+0]
	mov ax,4200h
	int 21h
	pop cx
	jc error
;	mov bx,es:[NEHDR.ne_hFile]
	mov dx,di
	push ds
	push es
	pop ds
	mov ah,3Fh
	int 21h
	pop ds
	jc error
	add di,cx
exit:
	clc
	ret
error:
	mov ax,offset errstr6
	stc
	ret
LoadNResNames endp

;*** read entry table (to ES:DI),C=error

LoadEntryTable proc

	mov cx,es:[NEHDR.ne_cbenttab]	;length of entry table
	mov ax,es:[NEHDR.ne_enttab]		;start of entry table
	jcxz @F
	jmp ReadMD
@@: clc
	ret
LoadEntryTable endp

;--- InitDlls, called internally for OS/2 and DPMI32
;--- or by InitTask for DPMI16
;--- in: ES=PSP
;--- out: DI=MD

InitDlls proc public uses es si dx

if ?DEBUG
	nop
	@trace_s <"InitDlls enter",lf>
endif

if _FILEHANDLES_ ne 20
	mov bx,_FILEHANDLES_
	mov ah,67h
	int 21h
endif
	mov si,ss
	call Segment2ModuleFirst		;find module handle for selector in SI into AX/ES
	jc error
	@trace_s <"call CallAllLibEntries",lf>
	call CallAllLibEntries		;call lib entries for new dlls
ife ?32BIT
	cmp es:[NEHDR.ne_exetyp],ET_DPMI16
	jnz @F
	test es:[NEHDR.APPFLGS],10h
	jz nodichange
@@:
	mov di,es	;set DI to hModule for OS/2 and RTM DPMI16
nodichange:
	clc
endif
error:
	ret
InitDlls endp



;*** if module is a dll and not initialized yet: call LibEntry
;*** ES=MD ***
;*** called by CallAllLibEntries

CallLibEntry proc

;	inc es:[NEHDR.ne_count]				;now done in LoadLibIntern
	@trace_s <"CallLibEntry enter",lf>
;	cmp es:[NEHDR.ne_count],1
;	jnz done
	test es:[NEHDR.APPFLGS],AF_DLL			;DLL?
	jz done
	test es:[NEHDR.APPFLGS],AF_INIT			;LibEntry called?
	jnz done
	@trace_s <"calling dll entry of ">
	@tracemodule
	@trace_s <lf>
	mov cx,word ptr es:[NEHDR.ne_csip+2]	;exists CS:IP?
	mov bx,word ptr es:[NEHDR.ne_csip+0]
if ?INT41SUPPORT
	push si
	mov si,es
	mov ax,DS_LOADDLL	;es,si=NE
	int 41h
	pop si
endif
	and cx,cx
	jz nolibentry

	push ds
	push es
	push si
	push di
	mov di,es
if ?32BIT

	push cx
	push bx
	pop edx						;EDX=CS:IP

	xor ax,ax					;if no dgroup found, use 0 as
	mov ds,ax					;hInstance (or better MD?)
;;	mov es:[NEHDR.ne_count],ax
	mov bx,es:[NEHDR.DGROFS]	;offset to dgroup
	and bx,bx
	jz @F
	mov ds,es:[bx].SEGITEM.wSel
@@:
	mov es,ax
	mov si,ax
	xor cx,cx
	call CallProc16
else
	push bp
	mov bp,sp
	push cx						;put CS on stack
	push bx						;put IP on stack
	mov cx,es:[NEHDR.ne_heap]	;if no DGROUP exists,
	xor ax,ax					;use 0 (or better MD?) as
	mov ds,ax					;hInstance
;;	mov es:[NEHDR.ne_count],ax
	mov bx,es:[NEHDR.DGROFS]	;offset to dgroup
	and bx,bx
	jz @F
	mov ds,es:[bx].SEGITEM.wSel
@@:
	mov es,ax
	mov si,ax
	@trace_s <"call with CS:IP=">
	@trace_w [bp-2]
	@trace_s <":">
	@trace_w [bp-4]
	@trace_s <", ES=">
	@trace_w es
	@trace_s <", DS=">
	@trace_w ds
	@trace_s <", CX=">
	@trace_w cx
	@trace_s <", BP=">
	@trace_w bp
	@trace_s <", SP=">
	@trace_w sp
	@trace_s lf
	call dword ptr [bp-04]		;call Libentry
	mov sp,bp
	pop bp
endif
	pop di
	pop si
	pop es
	pop ds
	@trace_s <"returned from init Dll, RC=">
	@trace_w ax
	@trace_s lf
if _CHKLIBENTRYRC_
	and ax,ax					;RC must be <> 0
	jz error1
endif
nolibentry:
;;	mov byte ptr es:[NEHDR.ne_count],01
if ?SETINIT
	or es:[NEHDR.APPFLGS],AF_INIT
endif
done:
	@trace_s <"CallLibEntry exit",lf>
	clc
	ret
error1:									;error in LibEntry
	pusha
	push ds
	mov ds,cs:[wLdrDS]
;;	dec es:[NEHDR.ne_count]
	mov di,offset szEntryCode
	call WORDOUT 				;bin2ascii(errorcode)
	mov si,offset szLibName
	mov di,offset NEHDR.szModPath
nextchar:
	mov al,es:[di]
	mov [si],al
	inc si
	inc di
	cmp al,00
	jnz nextchar
	mov word ptr [si-1],0A0Dh
	mov [si+1],al
	mov ax,offset szEntryErr
	call stroutax
	pop ds
	popa
;	mov ax,offset errstr15		;DLL init error
	@trace_s <"CallLibEntry exit",lf>
	stc
	ret
CallLibEntry endp

;*** call LibEntrys of dlls
;*** Input: AX=MD ***
;--- called by InitTask (apps)
;--- or in int 21h, ax=4B00h (dlls)

CallAllLibEntries proc public uses es

	clc
	mov es,ax
	@trace_s <"CallAllLibEntries enter, ax=">
	@trace_w ax
	@trace_s <lf>
	lsl ax,ax
	@trace_s <"CallAllLibEntries limit of es=">
	@trace_w ax
	@trace_s <lf>
	xor cx,cx
	xchg cx,es:[NEHDR.ne_cmod]
	jcxz done
	push si
	push cx
	mov si,es:[NEHDR.ne_modtab]
@@:
	lods word ptr es:[NEHDR.ne_cmod]
	push cx
	push si
	call CallAllLibEntries	  ;recursion!
	pop si
	pop cx
	jc @F
	loop @B
@@:
	pop word ptr es:[NEHDR.ne_cmod]
	pop si
	jc exit
done:
	call CallLibEntry
exit:
	@trace_s <"CallAllLibEntries exit",lf>
	mov ax,es
	ret
CallAllLibEntries endp

;--- get module handle of a segment
;--- inp: segment selector in SI
;--- out: not found: C + AX=0000
;---      success: NC + module handle in AX
;---      and address of segment descriptor in ES:BX

Segment2ModuleFirst:
	mov bx,cs:[wMDSta]	;search from module list start
	@trace_s "Segment2ModuleFirst, searching sel="
	@trace_w si
	@trace_s ", module start="
	@trace_w bx
	@trace_s lf

Segment2Module proc public

if 0
	@trace_s <"searching module handle, sel=">
	@trace_w si
	@trace_s lf
endif
	and si,0FFFCh
	mov ax,bx
nextmodule:
if 0
	@trace_s <"module: ">
	@trace_w ax
	@trace_s lf
endif
	and ax,ax
	stc
	jz segm2mod2
	mov es,ax
	mov cx,es:[NEHDR.ne_cseg]
	mov bx,es:[NEHDR.ne_segtab]
nextsegment:
	mov ax,es:[bx].SEGITEM.wSel
if 0
	@trace_s <"  segment: ">
	@trace_w ax
	@trace_s lf
endif
	and al,0FCh
	cmp si,ax
	jz found
	add bx,SGTSIZE
	loop nextsegment
	mov ax,es:[NEHDR.NXTMOD]
	jmp nextmodule
found:
	mov ax,es
segm2mod2:
	ret
Segment2Module endp

;*** search handle of a module
;--- inp:
;---   1. DS=0000, SI=selector
;---   2. DS:E/SI -> module name, CL=size of module name
;--- out: C=error, AX=0000
;---     NC=success, AX=module handle

SearchModule16 proc near public

	mov bx,cs:[wMDSta]
	mov ax,ds
	and ax,ax
	jz Segment2Module	;ok, is SI is a selector
if ?32BIT
	push edi
else
	push di
endif
	push es
	mov ah,cl
nextitem:
	and bx,bx
	jz notfound
	push si
	mov es,bx
	mov di,es:[NEHDR.ne_restab]
	mov cl,ah
if ?32BIT
	movzx ecx, cl
else
	mov ch,00
endif
	cmp cl,es:[di]
	jnz @F
	inc di
if ?32BIT
	movzx edi,di
	db 67h
	repz cmpsb
else
	repz cmpsb
endif
@@:
	pop si
	jz found
	mov bx,es:[NEHDR.NXTMOD]
	jmp nextitem
notfound:
	xor ax,ax
	stc
	jmp exit
found:
	mov ax,es
	clc
exit:
	pop es
if ?32BIT
	pop edi
else
	pop di
endif
	ret
SearchModule16 endp

;*** load module if not already loaded
;*** ES:SI -> name of module
;*** CL: max. length of module name
;*** Out: AX= module handle
;***      module name in szModName
;*** Entries: LoadLibIntern2: in DS:(E)DX=path
;***          LoadLibIntern:  in ES:(E)SI=module name, length in CX

LoadLibIntEx:
	ret

LoadLibIntern2 proc	;Name -> DS:(E)DX, length still undefined
	push ds
	pop es
if ?32BIT
	mov edi,edx
	mov esi,edx
else
	mov di,dx
	mov si,dx
endif
	call strlen
	mov ax,cx
	stc
	jcxz LoadLibIntEx
if ?32BIT
	movzx ecx,cx
	add esi,ecx
@@:
	dec esi
	mov al,[esi]
	cmp al,'\'
	jz @F
	cmp al,'/'
	jz @F
	cmp al,':'
	jz @F
	loop @B
	dec esi
@@:
	inc esi
else
	add si,cx
@@:
	dec si
	mov al,[si]
	cmp al,'\'
	jz @F
	cmp al,'/'
	jz @F
	cmp al,':'
	jz @F
	loop @B
	dec si
@@:
	inc si
endif
	mov ds,cs:[wLdrDS]
	mov [wlError],2			;default error "file not found"
if ?RESETDEFPATH
	mov szPath,00			;reset default path
endif
	mov cx,0FFFFh
if ?32BIT
	mov dword ptr [blksize+0],edi
	mov word ptr [blkaddr+0],es
	movzx edi,di
else
	mov word ptr [blksize+0],di   ;is used as temp variable here
	mov word ptr [blksize+2],es
endif
	jmp @F
LoadLibIntern::							;<--- entry
	mov di,offset szModName
if ?32BIT
	movzx edi,di
	mov dword ptr [blksize+0],edi
	mov word ptr [blkaddr+0],ds
else
	mov word ptr [blksize+0],di
	mov word ptr [blksize+2],ds
endif
@@:										;used by LoadLibIntern+LoadLibIntern2
	mov ah,00					;copy name
	mov di,offset szModName
nextitem:
if ?32BIT
	mov al,es:[esi]
else
	mov al,es:[si]
endif
	cmp al,'a'
	jb @F
	cmp al,'z'
	ja @F
	sub al,'a'-'A'
@@:
	mov [di],al
	and al,al
	jz lli_1
	cmp al,'.'
	jnz @F
	inc ah
@@:
	inc di
if ?32BIT
	inc esi
else
	inc si
endif
	loop nextitem
	mov [di],cl
lli_1:
	push ds
	pop es
	and ah,ah
	jnz @F
	mov cx,0005
	mov si,offset szDotDLL		;strcat ".DLL",00 
	rep movsb
@@:
	mov si,offset szModName		;^ name of module
if ?32BIT
	movzx esi,si
endif
	call strlen
	sub cx,4
	call SearchModule16			;check if module already loaded
	jnc LoadLibIntern3  		;if yes, then just simple update
if ?32BIT
	mov eax,dword ptr [blksize+0]
	mov dx,word ptr [blkaddr+0]
else
	mov ax,word ptr [blksize+0]
	mov dx,word ptr [blksize+2]
endif
	call LoadModule16			;load DLL DX:(E)AX
	jc LoadLib_Err
	mov es,ax					;added 2.7.2005
cntupdate:
	inc es:[NEHDR.ne_count]		;added 2.7.2005
	@trace_s <"module ">
	@trace_w es
	@trace_s <" count now ">
	@trace_w es:[NEHDR.ne_count]
	@trace_s <lf>
	clc
	ret
LoadLibIntern3:
	mov es,ax
	xor cx,cx
	xchg cx,es:[NEHDR.ne_cmod]	;get no of referenced modules
	jcxz cntupdate
	mov si,es:[NEHDR.ne_modtab]
	push cx
nextmodule:
	lods word ptr es:[si]
	push es
	push cx
	push si
	call LoadLibIntern3
	pop si
	pop cx
	pop es
	loop nextmodule
	pop es:[NEHDR.ne_cmod]
	mov ax,es
	jmp cntupdate
LoadLib_Err:
	test byte ptr wErrMode+1,HBSEM_NOOPENFILEBOX
	jnz @F
	cmp ax,offset szNotaNE		   ;"not NE format"?
	jz @F
	call stroutax
@@:
	stc
	ret
LoadLibIntern2 endp

;*** load all referenced modules 
;*** ES -> current module
;*** in case of errors: C and AX -> error text

LoadRefMods16 proc
	@trace_s <"LoadRefMods16 enter; loading referenced modules",lf>
	test byte ptr es:[NEHDR.APPFLGS],AF_DLL
	jnz @F						;if application save path
	call savepathNE				;as default for DLLs
@@:
	xor cx,cx
	xchg cx,es:[NEHDR.ne_cmod]	;get no of referenced modules
	jcxz done					;none are there, done
	mov si,es:[NEHDR.ne_modtab]
	push cx
nextitem:
	mov [wlError],0014h
	push cx
	push si
	mov ax,es:[si]				;this is offset in table
	mov si,es:[NEHDR.ne_imptab]	;of imported names
	add si,ax
if ?32BIT
	movzx esi, si
endif
	sub cx,cx
	mov cl,es:[si]				;length of name
	inc si
	push es
	call LoadLibIntern
	pop es
	pop si
	pop cx
	jc UnloadMod16Ex
	mov es:[si],ax				;instead of offset now save module
	inc si						;handle in MD
	inc si
	loop nextitem				;next modul
	pop es:[NEHDR.ne_cmod]
done:
	clc
	@trace_s <"LoadRefMods16 exit",lf>
	ret
LoadRefMods16 endp

;*** error handling when loading modules
;*** module counts aren't adjusted yet, but segments
;*** are loaded (partially!)

UnloadMod16Ex:
	pop ax
	sub ax,cx
	mov es:[NEHDR.ne_cmod],ax

UnloadMod16 proc
	mov cx,es:[NEHDR.ne_cmod]
@@:
	mov si,es:[NEHDR.ne_modtab]
	jcxz done
nextitem:
	push es
	mov ax,es:[si]
	verr ax
	jnz @F
	mov es,ax
;	cmp es:[NEHDR.ne_count],0
;	jnz @F
	push cx
	mov ax,es
	call FreeLib16
	pop cx
@@:
	inc si
	inc si
	pop es
	loop nextitem
done:
	mov ax,-1
	stc
	@trace_s <"UnloadMod16(Ex): fatal exit",lf>
	ret
UnloadMod16 endp

;--- call dowep, but only for dlls and AF_INIT must be set (LibEntry called)
;--- inp: ES=MD

dowep proc

	@trace_s <"delete module ">
	@tracemodule
	@trace_s lf

	test byte ptr es:[NEHDR.APPFLGS],AF_DLL	;dll?
	jz dowep_3
if ?SETINIT
	test es:[NEHDR.APPFLGS],AF_INIT ;LibEntry called?
	jz exit
endif
	push si
	push cx
	mov si,offset szWEP		;search WEP
if ?32BIT
	movzx esi,si
endif
	mov ds,cs:[wLdrDS]
	mov cl,3
	call SearchNEExport		;search in resident + nonres names
	jc dowep_2
	@trace_s <"calling WEP",lf>
if ?32BIT
	push ax
	push bx
	pop edx					;EDX=CS:IP
	push ds
	push 0
	pop ds
	mov bx,es:[NEHDR.DGROFS]	;offset to dgroup
	and bx,bx
	jz @F
	mov ds,es:[bx].SEGITEM.wSel
@@:
	push 0000				;WEP parameter
	mov ebx, esp			;DS:EBX -> parameters
	mov cx, 1
	call CallProc16
	pop cx
	movzx edx, dx
	movzx ebx, bx
	pop ds
else
	push es
	push ds
	mov si,sp
	push 0000				;WEP Parameter
	push cs
	push offset dowep_1
	push ax
	push bx
	xor ax,ax
	mov ds,ax
	mov bx,es:[NEHDR.DGROFS]	;offset to dgroup
	and bx,bx
	jz @F
	mov ds,es:[bx].SEGITEM.wSel
@@:
	mov es,ax
	retf
dowep_1:
	mov sp,si
	pop ds
	pop es
endif
	@trace_s <"returned from WEP, RC=">
	@trace_w ax
	@trace_s lf
dowep_2:						;WEP doesnt exist
	pop cx
	pop si
dowep_3:
if ?INT41SUPPORT
	mov ax,DS_DELMODULE		;"module about to be removed"
	int 41h
endif
exit:
	ret
dowep endp


checkne proc public
	verr ax
	jnz @F
	mov es,ax
	cmp word ptr es:[0],"EN"
	jnz @F
	ret
@@:
	stc
	ret
checkne endp

;*** decrement module reference counter, if 0, call WEP
;*** will decrement all referenced modules as well
;*** AX = MD ***
;*** modifies BX, sets ES=0 if ES=MD
;*** C if MD is invalid or other error
;--- called for dlls and apps!

if ?32BIT
FreeLib16 proc public uses ds bx esi edi
else
FreeLib16 proc public uses ds bx si di
endif

	push es
	mov ds,cs:[wLdrDS]
	@trace_s <"FreeLib16 ">
	@trace_w ax
	@trace_s <lf>
	call checkne
	jc error23
	@trace_s <"cnt=">
	@trace_w es:[NEHDR.ne_count]
	@trace_s <lf>
	cmp es:[NEHDR.ne_count],1
	jnz @F
	call dowep
@@:
	xor cx,cx
	xchg cx,es:[NEHDR.ne_cmod]
	push cx
	jcxz refsdone
	mov si,es:[NEHDR.ne_modtab]
	add si,cx
	add si,cx
nextitem:
	dec si
	dec si
	mov ax,es:[si]
	push cx
	call FreeLib16
	pop cx
	loop nextitem
refsdone:
	pop cx
	mov ax,es
	verw ax
	jnz done
	mov es:[NEHDR.ne_cmod],cx
	cmp es:[NEHDR.ne_count],0
	jz @F
	dec es:[NEHDR.ne_count]
	jnz done
@@:
	push es
	call DeleteModule16	;delete module from module list
	pop es
	call CleanUpNE		;free resources
	@trace_s <"library freed",lf>
done:
	clc
exit:
	pop cx
	pushf
	verr cx				;if ES is invalid now, clear it
	jz @F
	@trace_s <"MD ">
	@trace_w cx
	@trace_s <" now invalid, clearing ES",lf>
	xor cx, cx
@@:
	mov es, cx
	popf
	ret
error23:
	test byte ptr [wErrMode+1],HBSEM_NOOPENFILEBOX
	jnz @F
	mov di,offset es23hdl
	call WORDOUT 		;bin2ascii(AX)
	mov bx,offset szErr23
	@strout_err
@@:
	stc
	jmp exit
FreeLib16 endp

;*** search entry in external module (Import)
;*** input: es -> MD external module
;*** DS:(E)SI -> entry to be found
;*** CL=length of name
;--- if CL=0, it is an ordinal in SI
;*** if found, call GetProcAddr16(), return Selector:Offset in AX:BX

SearchNEExport proc public
	mov ax,si
	cmp cl,0
	jz found
	mov bl,cl
	push di
	mov di,es:[NEHDR.ne_restab]
	mov ax,es:[NEHDR.NRESNAM]
nextitem:					;<----
	sub cx,cx
	mov cl,es:[di]	;compare names
	jcxz notfound	;table end reached -> error
	inc di
if _TESTIMPORT_
	pusha
	push ds
	push es

	push es
	pop ds
	mov bx,di
	call stroutBXn
	@cr_out

	pop es
	pop ds
	popa
endif
	cmp bl,cl		 ;do lengths match?
	jnz skipitem
if ?32BIT
	push esi
	movzx edi,di
	repe cmps byte ptr [edi],[esi]
	pop esi
else
	push si
	repe cmpsb
	pop si
endif
	jz @F
skipitem:
	add di,cx
	inc di			;skip number
	inc di
	jmp nextitem	;--->
@@:
	mov ax,es:[di]
	pop di
found:
	call GetProcAddr16	;entry ES.AX -> AX:BX
	ret
notfound:
	mov di,ax		;address of nonres names table (or NULL) to di
	xor ax,ax
	and di,di
	jnz nextitem	;--->
	mov bx,ax
	pop di
	cwd
	stc
	ret
SearchNEExport endp

;*** GetProcAddress: Entry# -> selector:offset
;*** input: ES -> MD , Entry# in AX
;*** output: selector:offset in AX:BX, ^Entry in CX

;*** structure of entry table (in windows):
;*** 6 Bytes header (WORD firstentry#,WORD lastentry#,WORD ^nextentryheader)
;*** 5 Bytes entry  (BYTE Type,BYTE Flags,BYTE Seg#,WORD Offset)

;--- here in DPMILDxx it is:
;*** if first byte is ZERO, table end is reached
;*** if second byte is ZERO, first byte is to be added to entry #
;--- else first byte is number of entries
;--- and second byte determines if entries are 3 or 6 bytes long

GetProcAddr16 proc uses dx si di

	and ax,ax
	jz error1			;entry 0 is error
	mov si,es:[NEHDR.ne_enttab]	;entries (integer)
	mov dx,0001
	xor cx,cx
	mov bh,ch
nextitem:				;<----
	mov cl,es:[si]
	jcxz error1			;end reached? then error "entry not found"
	inc si
	mov di,si
	mov bl,es:[si]
	inc si
	and bl,bl
	jnz @F
	add dx,cx
	jmp nextitem
@@:
	cmp bl,0FFh
	mov bl,3
	jnz gpa_1
	mov bl,6
gpa_1:
	cmp ax,dx
	jz found			;found, we are done
	add si,bx
	inc dx
	loop gpa_1
	jmp nextitem		;---->
found:
	xor ax,ax
	mov al,es:[di]
	cmp al,0FFh
	jnz @F
	add si,3

	mov al,es:[si+0]	;get segment number
@@:
	mov bx,es:[si+1]	;offset
	cmp al,0FEh
	jnz @F
	mov ax,bx
	jmp done
@@:
	call SegNo2Sel		;selector of entry (->AX)
done:
	mov cx,si			;^ Entry -> CX
	clc
	ret
error1:
	xor ax,ax
	cwd
	stc
	ret

GetProcAddr16 endp

;-------------------------------------------------------

if ?RMSEGMENTS

;--- this code is not active any more!!!

;*** call a real mode Proc
;*** called by exception handler
;*** EBP -> PUSHA(D), Errorcode, CS:IP, flags

ExecRMProc proc
if ?32BIT

	push esi
	push ds
	lds esi,[ebp+0Eh]	   ;CS:EIP of exception address
	cmp byte ptr [esi],9Ah ;far call?
	pop ds
	pop esi
	jnz error2			   ;anything else is invalid

	push ebp
	mov dx,ss
	mov bx,[ebp+20h]	   ;get SS:ESP
	mov ebp,[ebp+1Ch]
	mov ss,bx
	mov ecx,[ebp+00h]	   ;and then CS:EIP
	mov bx,[ebp+04h]?
	mov ss,dx
	pop ebp

else
	push si
	push ds
	lds si,[bp+08h]		;CS:IP of exception
	cmp byte ptr [si],9Ah
	pop ds
	pop si
	jnz error2

	push bp
	mov dx,ss
	mov bx,[bp+10h] 	;SS
	mov bp,[bp+0Eh] 	;SP
	mov ss,bx
	mov cx,[bp+00h] 	;IP
	mov bx,[bp+02h] 	;CS
	mov ss,dx
	pop bp

endif
	push cx
	call Sel2Segment	;get base von BX
	pop cx
	jc error1			;error: nicht im 1. MB
if ?32BIT
	push edi
	sub esp,sizeof RMCS
	mov edi,esp
else
	push di
	sub sp,sizeof RMCS
	mov di,sp
endif
	mov ax,es:[si+XDOSSEG]
	push es

	push ss
	pop es
if ?32BIT
	mov es:[edi.RMCS.rCS],ax   ;what's with (E)IP?
else
	mov es:[di.RMCS.rCS],ax
endif
	push bx
	push cx
	mov cx,0002 		;copy 2 words???
	xor bx,bx
	mov ax,0301h		;call Real Mode Proc
	call dpmicall
	jc error3
	add sp,+04
if ?32BIT
	mov eax,word ptr es:[edi.RMCS.rEAX]
	mov edx,word ptr es:[edi.RMCS.rEDX]
	add dword ptr [ebp+0Eh],+07  ;adjust EIP (call far32)
else
	mov ax,word ptr es:[di.RMCS.rEAX]
	mov dx,word ptr es:[di.RMCS.rEDX]
	add word ptr [bp+08h],+05  ;adjust EIP (call far16)
endif
	add sp,sizeof RMCS
	clc
exit:
	pop es
if ?32BIT
	pop edi
else
	pop di
endif
	ret

error1:
	mov ax,offset errstr41	;error 'cant get base address'
	stc
	ret
error2:
	mov ax,offset errstr43	;error 'invalid call instr'
	stc
	ret
error3:
	mov ax,offset errstr42	;error 'CallRealModeProc Error'
	add sp,4 + sizeof RMCS
	stc
	jmp exit

ExecRMProc endp

;*** selector -> segment (BX=selector) ***
;*** RC: Carry on errors, else SEGMENT in BX ***

Sel2Segment proc
	mov ax,0006h		;get base
	call dpmicall
	jc exit
if ?32BIT
	push cx
	push dx
	pop eax
	shr eax,4
	test eax,0FFFF0000h
else
	mov ax,dx
	mov dx,cx
	mov bx,0010h		;shr 4
	div bx
	cmp dx,+00			;im 1. MB?
endif
	stc
	jnz exit
	mov bx,ax
	clc
exit:
	ret

Sel2Segment endp

endif	;?RMSEGMENTS

;---------------------------------------------

;--- there is no longer a copy to the PSP, since the loader
;--- PSP is larger than 100h bytes and the termination code
;--- always remains in conv. memory

if ?EXTLOAD
if _COPY2PSP_

copy_to_psp_and_exit proc
	test byte ptr fHighLoad,1
	jnz @F
	ret
@@:
	@trace_s <"critical section: create code alias for PSP and jump",lf>
	mov bx,[wLdrPSP]
	mov ss,bx
if ?32BIT
	mov esp,100h
else
	mov sp,100h
endif
	push ax
	mov si,word ptr [dwMemHdl+2]
	mov di,word ptr [dwMemHdl+0]
	mov ax,ds
	call CreateAlias			;BX -> codesel -> AX
	push ax						;new CS -> [SP]
if ?HDPMI
	mov ax, offset psp_rou + 100h
	add ax, offset endhdpmi
	push ax
else
	push offset psp_rou + 100h	;IP
endif
	mov ax,0502h
	mov bx,cs
	retf
copy_to_psp_and_exit endp

endif	;_COPY2PSP
endif	;?EXTLOAD

doscall proc
if ?32BIT
	pushfd
	call fword ptr cs:[oldint21]
else
	pushf
	call dword ptr cs:[oldint21]
endif
	ret
doscall endp

dpmicall proc
	push ax
if ?32BIT
	pushfd
	call fword ptr cs:[oldint31]
	jc @F
	lea esp,[esp+2]
else
	pushf
	call dword ptr cs:[oldint31]
	jc @F
	inc sp
	inc sp
endif
	ret
@@:
if _SUPRESDOSERR_
	test cs:fMode, FMODE_NOERRDISP
	jnz nodisp
endif
	pusha
	push ds
	mov ds,cs:[wLdrDS]
ife ?32BIT
	mov bp,sp
endif
	mov di,offset dpmifunc
if ?32BIT
	mov ax,[esp+2+16]
else
	mov ax,[bp+2+16]			;display AX
endif
	cmp ax,0203h				;not for this function
	jz @F
	call WORDOUT
	mov di,offset dpmicaller
if ?32BIT
	mov ax,[esp+2+18]
else
	mov ax,[bp+2+18]			;display IP
endif
	call WORDOUT
	@strout_err szDpmiErr,1
@@:
	pop ds
	popa
nodisp:
	add sp,2
	stc
	ret
dpmicall endp

;--- bin to ascii conversion

if ?32BIT
DWORDOUT:
	push eax
	shr  eax, 16
	call WORDOUT
	pop eax
endif

;*** bin2ascii(WORD in AX) (-> DS:DI) ***

WORDOUT:
	push ax
	mov al,ah
	call BYTEOUT
	pop ax
BYTEOUT:
	mov ah,al
	shr al,4
	call NIBOUT
	mov al,ah
NIBOUT:
	and al,0Fh
	add al,'0'
	cmp al,'9'
	jle @F
	add al,07h
@@:
	mov [di],al
	inc di
	ret

;--- display routines

printchar proc public
if ?32BIT
	push ds
	push ss
	pop ds
	push bx
	push ecx
	push edx
	push eax
	mov edx,esp
	mov ecx,1
	mov bx,?STDERR
	mov ah,40h
	int 21h
	pop eax
	pop edx
	pop ecx
	pop bx
	pop ds
else
	mov dl,al
	mov ah,02
	int 21h
endif
	ret
printchar endp

dpmildrout proc
	pusha
if ?32BIT
	@strout <"DPMILD32: ">
else
	@strout <"DPMILD16: ">
endif
	popa
	ret
dpmildrout endp

;*** display string onto Stack
;--- this is the standard output routine

stroutstk_err:
	call dpmildrout
							;fall throu		
stroutstk proc public
if ?32BIT
	push bx
	mov bx,[esp+4]
else
	push bp
	mov bp,sp
	push bx
	mov bx,[bp+4]
endif
	push ds
	mov ds,cs:[wLdrDS]
	call stroutBX
	pop ds
	pop bx
ife ?32BIT
	pop bp
endif
	ret 2
stroutstk endp

;*** display string (^BX)
;--- this routine should be bimodal

strout_err:
	call dpmildrout

stroutBX proc public uses ax dx

nextchar:
	mov al,[bx]
	and al,al
	jz done
	cmp al,lf
	jnz @F
	mov al,cr
if _DBGOUT_ or _TRACE_ or ?DEBUG
	@dbgout
else
	call printchar
endif
	mov al,lf
@@:
if _DBGOUT_ or _TRACE_ or ?DEBUG
	@dbgout
else
	call printchar
endif
	inc bx
	jmp nextchar
done:
	ret
stroutBX endp

;*** display string (^ BX, length in CL)

stroutBXn proc near uses dx

@@:
	mov al,[bx]
	call printchar
	inc bx
	dec cl
	jnz @B
	ret
stroutBXn endp

;--- display module name of ES

modnameout proc near
	pusha
	push ds
	push es
	pop ds
	mov bx,offset NEHDR.szModPath
	@stroutbx
	pop ds
	popa
	ret
modnameout endp

;----------------------------------------------------------

	include trace.inc

;--- check if int 21/4bh has been called by loader
;--- possibly redundant

if ?CHECKCALLER
checkcaller proc
	push ds
	push es
	cld
	push cs
	pop ds
if ?32BIT
	pushad
	les edi,[esp+8*4+2*2+2]		;get cs:eip of caller
	mov esi,offset ctxt
	mov ecx,lctxt
	repz cmps byte ptr [edi],[esi]
	popad
else
	pusha
	mov bp,sp
	mov si,offset ctxt
	les di,[bp+8*2+2*2+2]
	mov cx,lctxt
	repz cmpsb
	popa
endif
	pop es
	pop ds
	ret
checkcaller endp
endif

;*** terminate program (int 21h, ah=4Ch) psp security check 
;*** search current psp ( in AX ) in task list!
;*** if task isn't found at all
;*** then do nothing, route call to previous handler
;*** if it wasn't the last task,
;*** change tasks values in list
;*** new 5.1.2004: dont compare selectors, but base addresses

;if ?MULTPSP
;if _LOADERPARENT_

sel2segm proc uses bx cx
	mov bx,ax
	mov ax,6
	call dpmicall		;get selectors base address
	mov ax,dx
	shr ax,4
	shl cx,12
	or ax,cx		;return real-mode address in AX
	ret
sel2segm endp

checkpsp proc
	pusha
	push ds
	mov ds,cs:[wLdrDS]
	mov ah,51h
	call doscall 			;current PSP -> BX
	mov ax,bx
	call sel2segm
	mov bx,ax
	@trace_s <"checkpsp: current psp segment is ">
	@trace_w bx
	@trace_s lf
if ?MULTPSP
	mov si,[wTDStk]
	lea di,[si-sizeof TASK]
nextitem:
	cmp si,offset starttaskstk
	jz error
	sub si,size TASK
	mov ax,[si].TASK.wPSP
  if ?USE1PSP        
	and ax,ax
	jnz @F
	mov ax,wLdrPSP
@@:
  endif
	call sel2segm	;get selectors segment value in AX
	@trace_s <"checkpsp: compare with ">
	@trace_w ax
	@trace_s lf
	cmp bx,ax
	jz found

	jmp nextitem
else
	mov ax,[wRMPSP]
	cmp bx,ax
	jz found
endif
error:
	@trace_s <"checkpsp: PSP not found, will route to previous handler",lf>
	stc
	jmp exit
found:
if ?DOS4G
	cmp byte ptr [esp+2+0Eh+1],0FFh
	jz allok
endif
if ?MULTPSP
	cmp si,di				;is it the last task launched?
	jz allok				;then nothing to do
	mov cx,size TASK
@@:
	lodsb
	xchg al,[di] 			;else exchange si and di
	inc di

	loop @B
endif
allok:
	@trace_s <"checkpsp: PSP found, ok",lf>
	clc
exit:
	pop ds
	popa
	ret
checkpsp endp


;endif
;endif

_mycrout proc public
	pusha
	mov al,cr
	call printchar
	mov al,lf
	call printchar
	popa
	ret
_mycrout endp

getnum proc
	xor dx,dx
next:
	mov al, es:[di]
	inc di
	sub al, '0'
	jc exit
	cmp al, 9
	ja exit
	add dx, dx
	mov cx, dx
	shl dx, 2
	add dx, cx
	mov ah, 0
	add dx, ax
	jmp next
exit:
	mov ax, dx
	ret
getnum endp

_TEXT ends

;-------------------------------------------------------
;--- initialization routines, called during startup only
;-------------------------------------------------------

_ITEXT segment

;--- move loader in extended memory

if ?EXTLOAD

moveinextmem proc
	push ds
	@trace_s <"moveinextmem enter",lf>
	xor bx,bx
	mov cx,[wCSlim] 			;alloc memory
	inc cx
	mov ax,0501h
	int 31h
	jc exit
	@trace_s <"extload: high memory allocated",lf>
	mov word ptr [dwMemHdl+0],di
	mov word ptr [dwMemHdl+2],si

	mov word ptr [blkaddr+2],bx
	mov word ptr [blkaddr+0],cx
	mov dx,cx
	mov cx,bx
	mov bx,[aliassel]

	mov ax,0007h				;set base
	int 31h
	jc exit
	@trace_s <"extload: set base ok",lf>
	xor cx,cx
	mov dx,[wCSlim]
	mov ax,0008h				;set limit
	int 31h
	jc exit
	@trace_s <"extload: set limit ok",lf>

	mov es,bx					;es now contains ext mem block
	xor si,si					;copy CS:0 -> ES:0, size wCSlim
	mov di,si
	mov cx,wCSlim
	inc cx
	shr cx,1
	cld
	rep movsw
;--- the loader has been copied to extended memory now
;--- now CS should be switched to the new block (critical)
;--- this requires attributes of current CS to change
if ?FASTCSCHANGE
	mov ax,cs					;copy CS desc first 
	call CreateAlias				;descriptor BX -> AX
	jc exit
else
	mov cx,1					;do it the safe way, get a temp sel
	xor ax,ax					;alloc selector
	int 31h
	jc exit
	@trace_s <"extload: alloc temp selector ok",lf>
	call CreateAlias				;[BX] -> [AX], AX=Codesel
	jc exit
	@trace_s <"extload: CreateAlias ok",lf>
	push ax
	mov ax,cs
	push offset nextsm			;switch to new CS
	retf
nextsm:
	call CreateAlias				;now original CS can be modified
	jc exit
	push bx
	push ax
	mov bx,cs
	push offset nextsm2
	retf
nextsm2:
	@trace_s <"extload: nextsm2 reached",lf>
	mov ax,0001					;free temp selector
	int 31h
	pop bx
endif
if ?32BIT
	push bx
	mov ax,bx
	mov cx,0FFFFh
	mov dx,4000h				;set BIG-Bit of highmem data sel
	call setaccrights
	pop bx
endif
	mov ss,bx					;set SS temporarily

	mov ax,ds
	call CopyDescriptor			;copy DS (BX->AX)
	push ds
	pop ss						;now set SS permanently
	@trace_s <"extload: ds ss copied",lf>
if _RESIZEPSP_
	;--- size PSP + 20h bytes (for int2f rm)
  if ?HDPMI
	mov bx, [wResHDPMI]
  else
	mov bx, offset endoflowcode
	mov al, bl
	shr bx, 4
	test al, 0Fh
	jz @F
	inc bx
@@:
  endif
	add bl,10h
	mov dx,[wLdrPSP]
	mov ax,0102h				;resize dos memory block
if _SUPRESDOSERR_
	or fMode, FMODE_NOERRDISP
endif
	int 31h
	jc exit
endif
	@trace_s <"moveinextmem: move high ok, low DOS memory resized",lf>
	or byte ptr fHighLoad,1
exit:
if _SUPRESDOSERR_
	and fMode, not FMODE_NOERRDISP
endif
	pop ds
	ret
moveinextmem endp

endif

if ?HDPMI

;--- this is for the standalone DPMILD32.BIN stub
;--- runs in real-mode!

inithdpmi proc
	pusha
	push ds
	mov ah,51h
	int 21h
	mov es,bx	;HDPMI expects ES=PSP
	add bx,10h
	push bx
	push 0
	mov bp,sp
	call far16 ptr [bp]
	add sp,4
	pop ds
	mov [wResHDPMI],dx
	mov ah,0
	cmp al,4
	cmc
	popa 
	ret
inithdpmi endp

endif

;*** load dpmi server HDPMI (still in real mode)
;*** dont display traces in real mode! ***

if ?SERVER
loadserver proc
	pusha
	mov bp,sp

	push ds
	pop es

;----------------------------- build an exec param struct on stack (real mode)
	mov cx,[wLdrPSP]
	push cx
	push offset 006Ch		;fcb2
	push cx
	push offset 005Ch		;fcb1 
	push ds
	push offset nullstr		;dos command tail
	push 0					;environment segment
if ?KERNEL16
	mov si,offset KernelNE.szModPath
else
	mov si,offset segtable
endif
	mov di,offset szModName ;copy filename
	cld
nextchar0:
	mov bx,di
nextchar:
	lodsb
	stosb
	cmp al,00
	jz donechar
	cmp al,'\'
	jz nextchar0
	cmp al,'/'
	jz nextchar0
	jmp nextchar
donechar:
	mov di,bx
	mov si,offset HostName		;strcat filename to path (HDPMI..)
	mov cx,SIZE_HOSTNAME
	rep movsb
tryagain:
	mov bx,sp
	mov dx,offset szModName
	mov ax,4b00h			;load dpmi server
	int 21h
	jc loadfailed
doneload:
	mov sp,bp
	popa
	ret
loadfailed:
if ?STUB
	mov di,offset szName
	mov si,offset HostName
	mov cx,SIZE_HOSTNAME
	rep movsb
	call ScanPath
	jc @F
	mov bx,ax
	mov ah,3Eh
	int 21h
	push ds
	pop es
	jmp tryagain
@@:
	mov dx,offset szModName
endif
;	call checkoutoffh
;	jc tryagain
if ?SLOADERR
	mov bx,offset errstr26	;"cannot load "
	@strout_err
	mov bx,dx				;hdpmi path
	@stroutbx
	@cr_out
	xor ax,ax
	call stroutax
endif
	jmp doneload

loadserver endp

endif

if ?LOADDBGDLL
loaddbg proc
	test bEnvFlgs2, ENVFL2_LOADDBGOUT
	jz done
	@pusha
	@trace_s <"trying to load debugout.dll",lf>
	or byte ptr [wErrMode+1],HBSEM_NOOPENFILEBOX
	mov ax,offset szDbgout
if ?32BIT
	movzx eax,ax
endif
	mov dx,ds
	call LoadModule16
	jc @F
	mov es,ax
	mov hModDbg,ax
	call CallLibEntry
@@:
	and byte ptr [wErrMode+1],not HBSEM_NOOPENFILEBOX
	@popa
done:
	ret
loaddbg endp
endif

;--- set vector for int 21h in protected mode

setvec21 proc
	pusha
	mov bl,21h
	mov cx,cs
if ?32BIT
	mov edx, offset int21proc
else
	mov dx, offset int21proc
endif
	mov ax,0205h			;set Int 21 PM vector
	call dpmicall
	popa
	ret
setvec21 endp


;*** read command line parameter
;*** will be called for 1. task only
;*** set exec parameter block (int 21,4b)
;*** RC: Carry if error
;*** else: module name in szPgmName
;***	   parameter block in ParmBlk

GetPgmParms proc uses ds
	push ds
	pop es				;es=DGROUP
	@trace_s <"GetPgmParms enter",lf>
if ?STUB
  if ?KERNEL16
	mov si,offset KernelNE.szModPath
  else
	mov si,offset segtable
  endif
	mov di,offset szPgmName
@@:
	lodsb
	stosb
	and al,al
	jnz @B
	mov si,0080h
	mov ds,[wLdrPSP]
else
	mov fCmdLOpt,0
	mov ds,[wLdrPSP]
	mov si,0080h
	test cs:[fMode],FMODE_OVERLAY	;loaded as overlay?
	jnz gpp_1						;then PSP is ok
	mov di,offset szPgmName
	sub cx,cx
	mov cl,[si] 		;get parameter line
	inc si
	jcxz error
	mov ah,0
nextws:
	lodsb
  if ?32BIT
	cmp al,'-'
	jnz @F
	mov ah,al
	jmp skipcharx
@@:
  endif
	cmp al,' '			;skip spaces
	jnz parmfound
skipcharx:
	loop nextws
error:
	mov ax,offset errstr8	;"filename missing or invalid"
	stc
	ret
parmfound:
  if ?32BIT
	and ah,ah
	jz nooption
	or al,20h
	cmp al,'g'
	jnz error
	or es:[fCmdLOpt], FO_GUI
	mov ah,0
	jmp skipcharx
nooption:
  endif
	dec si
	mov dl,0
nextchar:
	lodsb
	cmp al,'"'
	jnz @F
	xor ah,1
	jmp skipchar
@@:
	test ah,1
	jnz @F
	cmp al,' '
	jz copydone	   ;copy is done
@@:
	cmp al,'.'
	jnz @F
	inc dl
@@:
	stosb
	cmp al,'/'
	jz @F
	cmp al,'\'
	jnz skipchar
@@:
	mov dl,0
skipchar:
	loop nextchar
copydone:
	test ah,1
	jnz error
	and dl,dl		;file extension supplied? 
	jnz @F
	@trace_s <"'.EXE' added to module name",lf>
	mov ax,'E.'
	stosw
	mov ax,'EX'
	stosw
@@:
	mov al,00
	stosb

;------------------- copy rest of parameter line to psp cmd tail

	push es
	push ds
	pop es
	mov di, 80h
	push di
	mov al,cl
	stosb
	dec si
	inc cl			; copy 0D at least

	rep movsb
	pop si
	pop es
gpp_1:
endif	;?STUB

	mov di,offset ParmBlk
if ?32BIT
	movzx eax,si
	stosd				;cmdline
	mov ax,ds
	stosd
	xor eax,eax 		;fcb1+fcb2
	stosd
	stosd
	stosd
	stosd
else
	xor ax,ax
	stosw				;environment (nur bei 16 Bit)
	mov ax,si
	stosw				;cmdline
	mov ax,ds
	stosw
	xor ax,ax			;fcb1+fcb2
	stosw
	stosw
	stosw
	stosw
endif
	clc
	ret
GetPgmParms endp


changememstrat proc
	mov ax,5802h			 ;save umb link state
	int 21h
	xor ah,ah
	mov word ptr [blksize+0],ax
	mov ax,5800h			 ;save memory alloc strategie
	int 21h
	xor ah,ah
	mov word ptr [blksize+2],ax
	mov ax,5803h			 ;set umb link state
	mov bx,0001h
	int 21h
	mov ax,5801h			 ;set "fit best" strategy
	mov bx,0081h			 ;first high, then low
	int 21h
	ret
changememstrat endp

restorememstrat proc
	mov bx,word ptr [blksize+2]
	mov ax,5801h			  ;memory alloc strat restore
	int 21h
	mov bx,word ptr [blksize+0]
	mov ax,5803h			  ;umb link restore
	int 21h
	ret
restorememstrat endp

;*** JumpToPM
;--- returns C on errors, bx->error msg 

JumpToPM proc
	call changememstrat
if ?SERVER
	mov cx,1
endif
JumpToPM_1:
	push cx
	mov ax,1687h			;get address of PM entry in ES:DI
	int 2Fh
	pop cx
	mov bp,offset szNoDPMI  ;message "no dpmi server"
if ?32BIT
	and ax,ax				;ax=0 -> DPMI server installed
	jnz JumpToPM_2
	mov bp,offset szNo32Bit ;message "no 32 bit apps supported"
	test bl,1
	jnz JumpToPM_3			;jmp if ok
else
	and ax,ax
	jz JumpToPM_3			;ok, DPMI host found
endif
JumpToPM_2:
if ?SERVER
	mov ax,bp
  if ?DEBUG
	and cx,cx
	jz ERROR0
  else
	jcxz ERROR0				;just try 2 times, else error
  endif
	call loadserver			;try to load HDPMIxx
	xor cx,cx
	jmp JumpToPM_1			;try a second time
else
  if ?HDPMI
	call inithdpmi
	jnc JumpToPM_1
  endif
	mov ax,bp
	jmp ERROR0
endif
JumpToPM_3:
	push es
	push di
	test si,si
	jz @F
	mov bx,si
	mov ah,48h				  ;alloc real-mode mem block
	int 21h
	jc ERROR1
	mov es,ax
@@:
	call restorememstrat
if ?32BIT
	mov ax,0001
else
	xor ax,ax
endif
	mov bp,sp
	call dword ptr [bp]
	mov ax,offset errstr3		;cannot switch to prot-mode
	jc ERROR3
	@int3 _INT03JMPPM_
	mov [wLdrDS],ds
	mov [wDPMIFlg],cx			;DPMI Flags
	mov [wDPMIVer],dx			;dito
	mov [wLdrPSP],es			;psp
if 1;?USE1PSP
	mov [wCurPSP],es
endif
if ?32BIT
	movzx eax,ax
	movzx ebx,bx
	movzx ecx,cx
	movzx edx,dx
	movzx esi,si
	movzx edi,di
endif
	@trace_s <lf,"------------------------------------",lf>
	@trace_s <"DPMILDxx now in protected mode, PSP=">
	@trace_w es
	@trace_s <",CS=">
	@trace_w cs
	@trace_s <",SS=">
	@trace_w ss
	@trace_s <",DS=">
	@trace_w ds
	@trace_s <lf>
	add sp,4
	ret
ERROR1:
	mov ax,offset errstr2	;insufficient DOS memory
ERROR3:
	add sp,4
ERROR0:
	push ax
	call restorememstrat
	pop bx
	stc
	ret
JumpToPM endp

;*** global constructor ***

InitProtMode proc

	@trace_s <"enter initialize PM",lf>

	mov bl,21h				;get int 21 PM vector
	mov ax,0204h			;get pm int
	int 31h
if ?32BIT
	mov dword ptr [oldint21+0],edx
	mov word ptr [oldint21+4],cx
else
	mov word ptr [oldint21+0],dx
	mov word ptr [oldint21+2],cx
endif
	mov bl,31h				;get int 31 PM vector
	int 31h
if ?32BIT
	mov dword ptr [oldint31+0],edx
	mov word ptr [oldint31+4],cx
else
	mov word ptr [oldint31+0],dx
	mov word ptr [oldint31+2],cx
endif
if ?TRAPINT41
	mov bl,41h
	int 31h
  if ?32BIT
	mov dword ptr [oldint41+0],edx
	mov word ptr [oldint41+4],cx
	mov edx,offset myint41
  else
	mov word ptr [oldint41+0],dx
	mov word ptr [oldint41+2],cx
	mov dx,offset myint41
  endif
	mov al,5
	mov cx,cs
	int 31h
endif

if _SETCSLIM_
	mov bx,cs
	xor cx,cx
	mov dx,[wCSlim]
	mov ax,0008h			;set limit	
	int 31h
endif
if _SETDSLIM_
	mov bx,ds
	xor cx,cx
	mov dx,[wCSlim]
	mov ax,0008h			;set limit
	int 31h
endif
	mov cx,0001 			;get a selector for ALIAS segments
	mov ax,0000
	int 31h
	jc initprex
	mov [aliassel],ax
;--- for 32bit clients: clear bits FF00h (dosemu + cwsdpmi)
if ?DOSEMUSUPP
if ?32BIT
	mov bx,ax
	lar cx,ax
	shr cx,8
	mov ax,0009				;set acc rights
	int 31h
endif
endif

if ?EXTLOAD
	test bEnvFlgs,ENVFL_DONTLOADHIGH
	jnz @F
	cmp byte ptr wVersion,20	;not for OS/2
	jnb @F
if 0;?DOSEMUSUPP
	test fMode, FMODE_DOSEMU		;not for DOSEMU
	jnz @F
endif
	call moveinextmem	   ;move ldr Code/Data in extended memory
@@:
endif
if ?PESUPP
	call InitPELoader
endif
if _TRAPEXC0D_
	mov bl,0Dh
	mov ax,0202h		   ;get Exception 0D
	int 31h
  if ?32BIT		 
	mov dword ptr oldexc0D+0,edx
	mov word ptr oldexc0D+4,cx
	mov edx, offset LEXC0D
  else
	mov word ptr oldexc0D+0,dx
	mov word ptr oldexc0D+2,cx
	mov dx, offset LEXC0D
  endif
	mov cx,cs
	call setexc
	jc initprex
endif
if ?EXC01RESET
	mov bl,01h
	mov ax,0202h		   ;get Exception 01
	int 31h
  if ?32BIT
	mov dword ptr oldexc01+0,edx
	mov word ptr oldexc01+4,cx
  else
	mov word ptr oldexc01+2,dx
	mov word ptr oldexc01+2,cx
  endif
endif

initprex:
	ret
InitProtMode endp

_ITEXT ends

end  main

