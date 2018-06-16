
        include pagemgr.inc
        include int31api.inc

;--- int21api

@proto intr21      ; handler int 21
if ?INT21API
@proto intr21_     ; handler int 21 ring 3 (if ?FASTINT21)
@proto resetdta
endif
@proto rmdos       ; call real-mode dos
@proto rmdosintern ; call real-mode dos internally (clears pm DS+ES)

;--- int2Fapi.asm

@proto intr2F
@proto unsupp
@proto unsuppcallx

;--- heap

@proto _heapalloc
@proto _allocmemhandle
@proto _freememhandle
@proto _addmemhandle
;@proto _linkmemhandle
;@proto _unlinkmemhandle

;--- putchrx

@proto byteout   
@proto wordout   
@proto dwordout  
@proto _charout  
@proto _byteout  
@proto _wordout  
@proto _dwordout 
@proto _stroutsi 
@proto _stroutx  
ife ?DOSOUTPUT
@proto forcetextmode
endif
;@proto _putchrx 

if ?I41SUPPORT
@proto _getchrx
endif

@proto _$stroutx, near16


;--- A20GATE

@proto _disablea20, near16
@proto _enablea20, near16
;@proto _GetA20State_pm

;--- vxd

@proto checkvxd
@proto _I2f168A
@proto _vxd_0001
@proto _vxd_0009
@proto _vxd_0017
@proto _vxd_0021
@proto _vxd_002A
@proto _vxd_0442

;--- helpers

@proto copy_dsdx_2_tlb    ;copy cx bytes from DS:E/DX to tlb:0, v86-es=TLB
@proto copy_tlb_2_dsdx    ;copy cx bytes from tlb:0 to DS:E/DX

@proto copy_esdi_2_tlb    ;copy cx bytes from ES:E/DI to tlb:0, v86-ds=TLB
@proto copy_tlb_2_esdi    ;copy cx bytes from tlb:0 to ES:E/DI

@proto copy_tlbxx_2_esdi  ;copy xx bytes from tlb:yy to ES:E/DI
@proto copy_far32_2_tlbxx ;copy xx bytes from far32 to tlb:xx

@proto copyz_far32_2_tlbxx 
@proto copyz_tlbxx_2_far32 

@proto copy_far32_2_flat
@proto copy_flat_2_far32

@proto copy_dta_2_tlbdta  ;function 4F (get next dir entry)
@proto copy_tlbdta_2_dta  ;functions 11,12,13,4E,4F

@proto copy$_dsdx_2_tlb   ;copy dos string from DS:E/DX to TLB:0
@proto copyz_dsdx_2_tlb   ;copy asciiz from DS:E/DX to tlb:0, dx=0, v86-ds=TLB
@proto copyz_dssi_2_tlb   ;copy asciiz from DS:E/SI to tlb:0, si=0, v86-ds=TLB
@proto copyz_tlb_2_dssi   ;copy asciiz form TLB:0 to DS:E/SI
@proto copyz_tlb_2_dsdx   ;copy asciiz form TLB:0 to DS:E/DX

@proto _AllocDosMemory
@proto _FreeDosMemory

@proto selector_alloc
@proto selector_resize
@proto selector_free
@proto selector_avail

@proto bx_sel2segm        
@proto sel2segm        
@proto ds_segm2sel        
@proto es_segm2sel        
@proto segm2sel           

@proto setdsreg2tlb       
@proto setesreg2tlb       

@proto getpspsel          
@proto setpspsel          

@proto getlinaddr         

@proto getmysel           
@proto getmyseldata       
@proto getmyselx          
if ?32BIT
@proto getmyseldatabig    
endif

;--- int2xapi

@proto intr23            
@proto intr24            
@proto intr25            
@proto intr26            
@proto PrepareDiskIoRead 
@proto PrepareDiskIoWrite
@proto AfterDiskIoRead   

;--- clients

@proto _restoreclientstate
@proto _saveclientstate
_getidtaddr proto
_getcldata32 proto

;--- except

@proto _exceptX    ;R3 exception with full frame
@proto _exceptY    ;R3 exception with
@proto _exceptZ    ;R0 exception

;--- movehigh.asm

@proto _movehigh_pm

;--- int33api.asm

@proto intr33
@proto mouse33_reset
;@proto mouse33_exit

;--- int41api.asm

@proto intr41       ;int 41 handler ring 0/3
@proto intr41_      ;int 41 handler ring 3

;--- intxxapi.asm

@proto intr10_
@proto intr13   
@proto intr15   
@proto mouse15_reset
@proto intr4B   

;--- hdpmi

@proto EnlargeLDT
@proto setldtinfos
@proto simint09
@proto installirqhandler
@proto pms_call_int      ;call ring3 protected mode INT
@proto lpms_call_int     ;switch stack to LPMS, call ring3 pm INT
@proto dormsint          ;call real-mode INT from client
@proto dormintintern     ;call real-mode INT from inside host
@proto dormprocintern    ;call real-mode near proc from inside host
@proto _myinit           
@proto retf2exit         ;adjust all std flags, then perform IRETD
@proto iret_with_CF_mod  ;adjust CF, then perform IRETD

@proto _exitclient_pm    ;terminate client
@proto _exitclientEx     ;enter text mode, then terminate client
@proto _exitclientEx4    ;_exitclientEx with error code 4
@proto _exitclientEx5    ;_exitclientEx with error code 5
@proto setpmstate        
@proto closeinterrupts   

@proto load_pmsegs
@proto _rawjmp_pm, near16;raw jump to protected-mode, esp=dwHostStack
@proto _gotopm,    near16;full switch to protected-mode
@proto _gotopmEx,  near16;do a INT 96h, then _gotopm

@proto _rawjmp_rm        ;@rawjmp_rm, raw jump real-mode, sp unchanged
@proto _gotorm           ;@jmp_rm, full switch to real-mode, ss:sp=RMS

@proto vcpi_pmentry
@proto vcpi_pmentry2

externdef   _RETCB_:abs
externdef   _RMSWT_:abs
externdef   _SRTSK_:abs
externdef   _I2F168A_:abs
externdef   _I2F1684_0001_:abs
externdef   _I2F1684_0009_:abs
externdef   _I2F1684_0017_:abs
externdef   _I2F1684_0021_:abs
externdef   _I2F1684_002A_:abs
externdef   _I2F1684_0442_:abs
;externdef   SIZESTDRMCB:abs
;externdef	RMCBMOUSE:abs

externdef RAWJMP_PM_PATCHVALUE:abs
externdef _CSGROUP16_:abs
if ?KDSUPP
externdef _KDSEL_:abs
endif
externdef PATCHVALUE2:abs


@seg BEGTEXT16
@seg ENDTEXT16
@seg ENDTEXT32
@seg _TEXT16
@seg _TEXT32
@seg CDATA16
@seg _DATA16

BEGTEXT16 segment
externdef logo:byte
externdef llogo:abs
externdef curGDT:DESCRPTR
externdef taskseg:TSSSEG
BEGTEXT16 ends

ENDTEXT16 segment
externdef endof16bit:byte
ENDTEXT16 ends

ENDTEXT32 segment
externdef endof32bit:byte
ENDTEXT32 ends

CDATA16 segment
externdef wEnvFlags:word
CDATA16 ends

_TEXT32 segment
externdef intr09:near
externdef rawjmp_rm_novcpi:near
externdef rawjmp_rm_vcpi_1:near
externdef rawjmp_rm_vcpi_2:near
_TEXT32 ends

_TEXT16 segment
externdef dormintintern_rm_exit:near16
externdef meventr:near16			;real-mode mouse event proc
externdef PatchRMStkSize:word
externdef linadvs:byte
externdef unhookIVTvecs:near
externdef wPatchDgrp1:word
externdef kdpatch1:near
externdef kdpatch2:near
externdef rawjmp_pm_patch:near
externdef _rawjmp_pm_setsegm:near
externdef intrrm2pm:far
externdef kdinit_rm:near
externdef kdinit2_rm:near
externdef load_rmsegs:near
externdef vcpi_rmentry:near
_TEXT16 ends

;--- _DATA16 publics

_DATA16 segment

externdef rawjmp_rm_vector:dword
externdef ivthooktab:byte
externdef dwHost16:PF16
externdef dbgpminit:fword
externdef dwFeatures:dword
externdef int15hk:IVTHOOK
externdef wEMShandle:word

if ?DYNBREAKTAB
externdef   _MAXCB_:abs
externdef   pmbpdes:DESCRPTR
endif

externdef   dtaadr:fword

if ?RMSCNT
externdef   bRMScnt:byte
endif

if ?USEINTS
externdef   intnr0:byte
else
externdef   calladdr0:dword
endif

if ?LDTROSEL
externdef   selLDTsafe:word
endif

externdef   MyRMCS:RMCS
externdef   _StartOfVMData:near16
externdef   _StartOfClientData:near16
externdef   _EndOfClientData:near16
externdef   _cpu:byte

externdef	dwRetAdr:dword
externdef	dwRetAdr2:dword

externdef   curIDT:near16           ;address IDT (valid during startup only)
externdef   curGDT:DESCRPTR         ;address GDT (valid during startup only)
externdef   stacktop:near16         ;host real-mode stack top
externdef	vcpidesc:DESCRPTR
externdef	pmbrdesc:DESCRPTR
externdef   pdIDT:PDESCR            ;pseudo descriptor IDT
externdef   pdGDT:PDESCR            ;pseudo descriptor GDT
;externdef   atlb:dword				;linear address TLB
externdef   dwLDTAddr:dword			;linear address LDT
externdef   selLDT:word				;ring3 selector for LDT access
externdef   wLDTLimit:word			;limit LDT

externdef   tmpBXReg:word
externdef   tmpFLReg:word			;temp storage for flags register
externdef   tmpFLRegD:dword			;same address, but DWORD type
externdef   bEnvFlags:byte			;value HDPMI environment variable
externdef   bEnvFlags2:byte			;high byte of HDPMI environment variable
externdef   bExcEntry:byte			;exception dump mutex
externdef   bExcMode:byte			;used by default exception handler
externdef   bTrap:byte				;serial input Ctrl-D received
externdef   bFPUAnd:byte
externdef   bFPUOr:byte
externdef   cApps:byte				;cnt active clients
externdef   cLPMSused:byte			;flag LPMS used
externdef   cRMCB:word				;count open real-mode callbacks
externdef   cStdRMCB:word			;count open std real-mode callbacks
externdef   dwHostBase:dword		;linear address host CS/DS (GROUP16)
externdef   wHostSeg:word			;segment host CS/DS (==GROUP16)
externdef   dwHostSeg:dword			;segment host CS/DS (==GROUP16)
externdef	dwTSSdesc:DWORD			;normalized address TSS descriptor
if ?CR0COPY
externdef   bCR0:byte				;clients LowByte(CR0)
endif
externdef   dwLoL:dword				;linear address DOS ListOfLists
externdef   dwSDA:dword				;linear address DOS SDA
externdef   fDebug:byte				;kernel debugger flags
externdef   fMode:byte				;global mode flags
externdef   fMode2:byte				;2. global mode flags
externdef   fHost:byte              ;flag: running as VCPI/XMS client?
externdef   fXMSAlloc:byte			;XMS alloc command (v2/v3)
externdef   fXMSQuery:byte			;XMS query command (v2/v3)
externdef   ltaskaddr:dword			;linear address next client data
externdef   pMemItems:dword			;start list of memory items
externdef   pg0ptr:dword			;for page 0 access guard
;externdef   rmcbs:RMCB				;start client real-mode callbacks
externdef   rmsels:dword			;start real-mode selector list
externdef   stdrmcbs:STDRMCB		;start std real-mode callbacks
externdef   szVirtual:byte			;string "VIRTUAL SUPPORT"
externdef   tskstate:TASKSTATE		;client task state
externdef   v86iret:V86IRET			;client v86/real-mode segments
externdef   vcpiOfs:dword			;offset VCPI host entry
externdef   vcpicall:PF32           ;address VCPI host entry (pm)
externdef   v86topm:VCPIRM2PM       ;contains CR3
if ?FIXTSSESP
externdef   dwHostStack:dword		;current value of host stack
else
externdef   dwHostStackExc:dword	;current bottom of host stack (exceptions)
endif
externdef   wSegTLB:word			;segment TLB
externdef   dwSegTLB:dword			;segment TLB (same as wSegTLB, but DWORD)
externdef   wVersion:word			;DPMI version
externdef   xmsaddr:PF16            ;XMS entry (RM)
;externdef	rmpsp:word				;current real-mode PSP of active client
externdef	rmpsporg:word			;initial real-mode PSP of active client
externdef   wRetAdrRm:word
externdef   wRetAdrRm2:word
externdef	wStdRmCb:word
externdef	wHostPSP:word
if ?DTAINHOSTPSP
externdef	dwHostDTA:dword
else
externdef	dwDTA:dword
endif
if ?SAVERMSPONHS
externdef	wCurSS:word
externdef	wCurSP:word
externdef	dwCurSSSP:dword
endif
if ?DPMI10EXX
externdef	wExcHdlr:word
endif
externdef	wPatchDgrp2:word

_DATA16 ends

;--- CDATA32 publics

CDATA32 segment dword use32 public 'CODE'

GROUP32 group CDATA32

externdef   r3vect00:R3PROC
externdef   r3vect20:R3PROC
  if ?FASTINT21
externdef   r3vect21:R3PROC
  endif
  if ?WINDBG
externdef   r3vect22:R3PROC
  endif
externdef   r3vect30:R3PROC
  if ?FASTINT31
externdef   r3vect31:R3PROC
  endif
externdef   r3vect41:R3PROC
externdef   r3vect70:R3PROC

externdef   mevntvec:R3PROC

externdef   excvec:R3PROC

externdef mouse15_rmcb:dword

externdef cldata32:byte
externdef endcldata32:byte
externdef endoftext32:byte

CDATA32 ends

