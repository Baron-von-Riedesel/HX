
@seg BEGGRP16
@seg _TEXT16
@seg _DATA16
@seg _DATA16V
@seg _DATA16C
@seg ENDGRP16

@seg _TEXT32
@seg _DATA32C
ifndef ?PE
@seg ENDGRP32
endif

SEG16 segment byte use16 public 'CODE'
SEG16 ends

;--- GDT selectors

externdef _VCPICS_:abs
externdef _CSSEL_:abs
externdef _SSSEL_:abs
externdef _TSSSEL_:abs
externdef _LDTSEL_:abs
externdef _FLATSEL_:abs
externdef _TLBSEL_:abs
externdef _INTSEL_:abs
externdef _SELLDT_:abs
externdef _CSALIAS_:abs
externdef _CSR3SEL_:abs
externdef _DSR3SEL_:abs
if 1;?MOVEHIGHHLP
externdef _CSGROUP16_:abs
endif
externdef _STDSEL_:abs
if ?LPMSINGDT
externdef _LPMSSEL_:abs
else
_LPMSSEL_ equ 0084h or ?RING
endif
if ?INT1D1E1F eq 0
externdef _I1ESEL_:abs
endif
if ?SCRATCHSEL
externdef _SCRSEL_:abs
endif
if ?LDTROSEL
externdef _SELLDTSAFE_:abs
endif
if ?KDSUPP
externdef _GDTSEL_:abs
externdef _KDSEL_:abs
endif

	include pagemgr.inc
	include int31api.inc

;--- int21api

intr21 proto near ; handler int 21
if ?INT21API
intr21_ proto near ; handler int 21 ring 3 (if ?FASTINT21)
resetdta proto near
endif
rmdos proto near ; call real-mode dos
rmdosintern proto near ; call real-mode dos internally (clears pm DS+ES)

;--- int2Fapi.asm

intr2F proto near
unsupp proto near
unsuppcallx proto near

;--- heap

_heapalloc        proto near

;--- output routines

_stroutx proto near
ife ?DOSOUTPUT
IsTextMode    proto near
forcetextmode proto near
endif
;_putchrx proto near 

if ?I41SUPPORT
_getchrx proto near
endif

_$stroutx proto near16


;--- A20GATE

_disablea20 proto near16
_enablea20 proto near16
;_GetA20State_pm proto near

;--- vxd

checkvxd proto near
_I2f168A_Msdos proto near
if ?VENDORAPI
_I2f168A_Hdpmi proto near
endif
_vxd_0001 proto near
_vxd_0009 proto near
_vxd_0017 proto near
_vxd_0021 proto near
_vxd_002A proto near
_vxd_0442 proto near

;--- api translation helpers

copy_dsdx_2_tlb proto near    ;copy cx bytes from DS:E/DX to tlb:0, v86-es=TLB
copy_tlb_2_dsdx proto near    ;copy cx bytes from tlb:0 to DS:E/DX

copy_esdi_2_tlb proto near    ;copy cx bytes from ES:E/DI to tlb:0, v86-ds=TLB
copy_tlb_2_esdi proto near    ;copy cx bytes from tlb:0 to ES:E/DI

copy_tlbxx_2_esdi  proto near ;copy xx bytes from tlb:yy to ES:E/DI
copy_far32_2_tlbxx proto near ;copy xx bytes from far32 to tlb:xx

copyz_far32_2_tlbxx proto near 
copyz_tlbxx_2_far32 proto near 

copy_far32_2_flat proto near
copy_flat_2_far32 proto near

copy_dta_2_tlbdta proto near  ;function 4F (get next dir entry)
copy_tlbdta_2_dta proto near  ;functions 11,12,13,4E,4F

copy$_dsdx_2_tlb proto near   ;copy dos string from DS:E/DX to TLB:0
copyz_dsdx_2_tlb proto near   ;copy asciiz from DS:E/DX to tlb:0, dx=0, v86-ds=TLB
copyz_dssi_2_tlb proto near   ;copy asciiz from DS:E/SI to tlb:0, si=0, v86-ds=TLB
copyz_tlb_2_dssi proto near   ;copy asciiz form TLB:0 to DS:E/SI
copyz_tlb_2_dsdx proto near   ;copy asciiz form TLB:0 to DS:E/DX

_AllocDosMemory proto near
_FreeDosMemory  proto near

desc_alloc  proto near
desc_free   proto near
desc_resize proto near
desc_avail  proto near

bx_sel2segm proto near        
sel2segm    proto near        
ds_segm2sel proto near        
es_segm2sel proto near        
segm2sel    proto near           

setdsreg2tlb proto near       
setesreg2tlb proto near       

getpspsel proto near          
setpspsel proto near          

getlinaddr proto near         
getrmdesc  proto near          

;--- int2xapi

intr23 proto near            
intr24 proto near            
intr25 proto near            
intr26 proto near            
PrepareDiskIoRead  proto near 
PrepareDiskIoWrite proto near
AfterDiskIoRead    proto near   

;--- clients

_restoreclientstate proto near
_saveclientstate proto near
_getidtofs proto
_getcldata32 proto

;--- except

_exceptX proto near    ;R3 exception with full frame
_exceptY proto near    ;R3 exception with
_exceptZ proto near    ;R0 exception
fatappexit2 proto near 

;--- movehigh.asm

_movehigh proto near

;--- int33api.asm

intr33 proto near
mouse33_reset proto near
;mouse33_exit proto near

;--- int41api.asm

intr41 proto near		;int 41 handler ring 0/3
intr41_ proto near		;int 41 handler ring 3

;--- intxxapi.asm

intr10_ proto near
intr13  proto near	
intr15  proto near	
mouse15_reset proto near
intr4B  proto near	

;--- hdpmi

EnlargeLDT       proto near
simint09         proto near
installirqhandler proto near
pms_call_int     proto near	;call ring3 protected mode INT
lpms_call_int    proto near	;switch stack to LPMS, call ring3 pm INT
_callrmsint      proto near	;call real-mode INT from client
callrmintintern  proto near	;call real-mode INT from inside host
callrmprocintern proto near	;call real-mode near proc from inside host
_myinit          proto near
retf2exit        proto near	;adjust all std flags, then perform IRETD
iret_with_CF_mod proto near	;adjust CF, then perform IRETD
if ?HSINEXTMEM
setuphoststack   proto near
endif
if ?EARLYIVTSAVE
saveivtvecs      proto near
endif
if ?VM
updateclonesize  proto near
endif

_exitclient_pm proto near	 ;terminate client
_exitclientEx proto near	 ;enter text mode, then terminate client
_exitclientEx4 proto near	 ;_exitclientEx with error code 4
_exitclientEx5 proto near	 ;_exitclientEx with error code 5
setpmstate proto near
closeinterrupts proto near

_rawjmp_pm proto near16		;raw jump to protected-mode, esp = dwHostStack
_rawjmp_pm_savesegm proto near16
_jmp_pm proto near16		;full switch to protected-mode
_jmp_pmX proto near16		;do a INT 96h, then _jmp_pm

_rawjmp_rm proto near		;@rawjmp_rm, raw jump real-mode
externdef _rawjmp_rm_savesegm: near	;v3.19: added
_jmp_rm proto near			;@jmp_rm, saves pm segregs

vcpi_pmentry proto near

externdef _RETCB_:abs
externdef _RMSWT_:abs
externdef _SRTSK_:abs
externdef _I2F168A_MSDOS:abs
if ?VENDORAPI
externdef _I2F168A_HDPMI:abs
endif
externdef _I2F1684_0001_:abs
externdef _I2F1684_0009_:abs
externdef _I2F1684_0017_:abs
externdef _I2F1684_0021_:abs
externdef _I2F1684_002A_:abs
externdef _I2F1684_0442_:abs
;externdef SIZEINTRMCB:abs
;externdef RMCBMOUSE:abs

externdef RAWJMP_PM_PATCHVALUE:abs

BEGGRP16 segment
externdef logo:byte
externdef llogo:abs
externdef curGDT:DESCRPTR
if ?HSINEXTMEM and ?MAPDOSHIGH
externdef taskseg:TSSSEG
;taskseg equ <TSSSEG[2000h]>
else
externdef taskseg:TSSSEG
endif
BEGGRP16 ends

ENDGRP16 segment
externdef endof16bit:near
ENDGRP16 ends

ifndef ?PE
ENDGRP32 segment
externdef endof32bit:near
ENDGRP32 ends
endif

_DATA16C segment
externdef wEnvFlags:word
_DATA16C ends

_TEXT32 segment
;externdef intr09:near
externdef simint09:near
externdef rawjmp_rm_novcpi:near
externdef rawjmp_rm_vcpi:near
_TEXT32 ends

_TEXT16 segment
externdef callrmintintern_rm_exit:near16
externdef meventr:near16			;real-mode mouse event proc
externdef linadvs:dword
externdef unhookIVTvecs:near
if ?MOVEHIGHHLP
externdef wPatchGrp161:word
endif
externdef wPatchGrp163:word
externdef kdpatch1:near
externdef kdpatch2:near
externdef rawjmp_pm_patch:near
externdef intrrm2pm:far
externdef kdinit_rm:near
externdef kdinit2_rm:near
;externdef load_rmsegs:near
externdef rawjmp_rm_all:near
_TEXT16 ends

BEGGRP16 segment
externdef wSegTLB:word			;segment TLB
externdef dwSegTLB:dword		;segment TLB (same as wSegTLB, but DWORD)
externdef cApps:byte			;cnt active clients
externdef fMode:byte			;global mode flags
externdef fMode2:byte			;2. global mode flags
BEGGRP16 ends

;--- _DATA16 publics

_DATA16 segment

externdef rawjmp_rm_vector:dword
externdef ivthooktab:byte
externdef dwHost16:PF16
externdef dbgpminit:fword
externdef dwFeatures:dword
externdef int15hk:IVTHOOK
externdef wEMShandle:word
externdef intrmcbrs:INTRMCBr

if ?DYNBREAKTAB
externdef _MAXCB_:abs
externdef pmbpdes:DESCRPTR
endif

externdef dtaadr:fword

if ?LDTROSEL
externdef selLDTsafe:word
endif

externdef _StartOfVMData:near16
externdef _StartOfClientData:near16
externdef _EndOfClientData:near16
externdef _cpu:byte
if ?MOVEGDT
externdef endofgdtseg:near16
endif

externdef dwPmDest:dword
externdef dwPmDest2:dword

externdef curGDT:DESCRPTR		;address GDT (valid during startup only)
externdef curIDT:GATE			;address IDT (valid during startup only)
ife ?HSINEXTMEM
externdef stacktop:near16		;host real-mode stack top
endif
externdef vcpidesc:DESCRPTR
externdef pmbrdesc:DESCRPTR
externdef pdIDT:PDESCR			;pseudo descriptor IDT
externdef pdGDT:PDESCR			;pseudo descriptor GDT
;externdef atlb:dword			;linear address TLB
externdef dwLDTAddr:dword		;linear address LDT
externdef selLDT:word			;ring3 selector for LDT access
externdef wLDTLimit:word		;limit LDT

;externdef tmpBXReg:word
externdef tmpFLReg:word			;temp storage for flags register
externdef tmpFLRegD:dword		;same address, but DWORD type
externdef bEnvFlags:byte		;value HDPMI environment variable
externdef bEnvFlags2:byte		;high byte of HDPMI environment variable
externdef bExcEntry:byte		;exception mutex
externdef bTrap:byte			;serial input Ctrl-D received
externdef bFPUAnd:byte
externdef bFPUOr:byte
externdef bLPMSused:byte		;flag LPMS used
externdef cRMCB:word			;count open real-mode callbacks
externdef cIntRMCB:word			;count open internal real-mode callbacks
externdef dwSSBase:dword		;linear address base of host stack
externdef wHostSeg:word			;segment host CS/DS (==GROUP16)
externdef dwHostSeg:dword		;segment host CS/DS (==GROUP16)
externdef dwTSSdesc:DWORD		;normalized address TSS descriptor
if ?CR0COPY
externdef bCR0:byte				;clients LowByte(CR0)
endif
externdef dwLoL:dword			;linear address DOS ListOfLists
externdef dwSDA:dword			;linear address DOS SDA
externdef fDebug:byte			;kernel debugger flags
externdef fHost:byte			;flag: running as VCPI/XMS client?
externdef fXMSAlloc:byte		;XMS alloc command (v2/v3)
externdef fXMSQuery:byte		;XMS query command (v2/v3)
externdef ltaskaddr:dword		;linear address next client data
;externdef rmcbs:RMCB			;start client real-mode callbacks
externdef rmsels:dword			;start real-mode selector list
if ?SUPP32RTM
externdef szVirtual:byte		;string "VIRTUAL SUPPORT"
endif
externdef pmstate:PMSTATE		;client pm segregs
externdef v86iret:V86IRET		;client v86/real-mode segments
externdef vcpiOfs:dword			;offset VCPI host entry
externdef vcpicall:PF32			;address VCPI host entry (used by pm)
externdef v86topm:VCPIRM2PM		;contains CR3
dwHostStack textequ <taskseg._Esp0>
if ?HSINEXTMEM
externdef dwStackTop:dword		;top of host stack
else
externdef ring0stack:near
endif
externdef wVersion:word			;DPMI version
externdef xmsaddr:PF16			;XMS entry (RM)
;externdef rmpsp:word			;current real-mode PSP of active client
externdef wPSPSegm:word			;initial real-mode PSP of active client
externdef wRmDest:word
externdef wIntRmCb:word
externdef wHostPSP:word
if ?DTAINHOSTPSP
externdef dwHostDTA:dword
else
externdef dwDTA:dword
endif
externdef wrmSPtmp:word
externdef wrmSStmp:word
externdef dwrmSSSPtmp:dword
if ?DPMI10EXX
externdef wExcHdlr:word
endif
externdef wPatchGrp162:word
if ?HSINEXTMEM and ?MAPDOSHIGH
externdef v86iretesp:dword
endif
ifdef _DEBUG
externdef traceflgs:word
externdef bStdout:byte
endif
ifdef ?PE
externdef dwVSize:dword
endif
_DATA16 ends

;--- _DATA32C publics

_DATA32C segment
externdef intrmcbs:INTRMCB		;start internal real-mode callbacks
externdef r3vect00:R3PROC
externdef r3vect20:R3PROC
  if ?FASTINT21
externdef r3vect21:R3PROC
  endif
  if ?WINDBG
externdef r3vect22:R3PROC
  endif
externdef r3vect30:R3PROC
  if ?FASTINT31
externdef r3vect31:R3PROC
  endif
externdef r3vect41:R3PROC
externdef r3vect70:R3PROC

externdef mevntvec:R3PROC

externdef excvec:R3PROC

externdef mouse15_rmcb:dword

_DATA32C ends

;externdef startcldata32:near
;externdef endcldata32:near
ifndef ?PE
externdef endoftext32:near
endif
