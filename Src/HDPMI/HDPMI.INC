
?RING			equ 3	;clients running in ring 3
?PLVL			equ (?RING shl 5)	;value for descriptor priv level

_IGATE32_ equ 8Eh
_TGATE32_ equ 8Fh
;_IGATE16_ equ 86h	;not used
_TGATE16_ equ 87h

if ?32BIT
_TGATE_ = _TGATE32_
else
_TGATE_ = _TGATE16_
endif

	include version.inc
	include dpmi.inc

ifndef ?386SWAT
?386SWAT		equ 0	;std=0, 1=support 386SWAT
endif
ifndef ?WDEB386
?WDEB386		equ 0
endif
?KDSUPP			equ ?WDEB386 or ?386SWAT
?WINDBG			equ ?KDSUPP	;1=support Win386 pm int 22h debug API

ifndef ?ENHANCED
?ENHANCED		equ 0	;std=0, 1=simulate Win386 (enhanced mode)
endif

if ?ENHANCED
?SUPI2F1600		equ 1	;int 2F,ax=1600 support (win enh mode) - real mode
?SUPI2F160A		equ 1	;int 2F,ax=160A support (get version) - real mode
?WINMODE		equ 3	;3=enhanced mode (Pharlap TNT has problems with this)
else
?SUPI2F1600		equ 0
?SUPI2F160A		equ 0	;used by win.com to detect if windows is running
;?WINMODE		equ 2	;2=standard mode
endif

if ?SUPI2F1600
 ifndef ?2F1600VER
?2F1600VER		equ 0A03h
;?2F1600VER		equ 0004h
 endif
endif
if ?SUPI2F160A
 ifndef ?2F160AVER
?2F160AVER		equ 030Ah
;?2F160AVER		equ 0400h
 endif
endif
                        
?LOGINT30		equ 0	;std=0, 1=log last int 30h call if exc occurs
ifndef ?MOVEGDT
?MOVEGDT		equ 1	;std 1: 1=move GDT into extended memory
endif
ifndef ?MOVEIDT
?MOVEIDT		equ 1	;std=1, 1=move IDT into extended memory on startup
endif
?DYNBREAKTAB	equ 1	;std=1, 1=create pm break table dynamically (MUST be 1)
?INTRM2PM		equ 1	;std=1, use a real-mode int to protect switch to
						;protected mode (int 96h)
if ?INTRM2PM
?XRM2PM 		equ 96h	;std=96h, real-mode to prot-mode int no
endif

?DYNTLBALLOC	equ 1	;std=1, 1=alloc a temp 64 kB TLB for int 21, ah=3f/40
?SETRMIOPL		equ 0	;std=0, 1=set IOPL for real/v86 mode (not needed)
?SCRATCHSEL		equ 0	;std=0, scratch selector required?
?INT1D1E1F		equ 0	;std=0, 1=modify int 1d,1e,1f to writeable
?I15MEMMGR		equ 0	;std=0, int 15 memory management (no longer needed)
?WATCHDOG		equ 0	;std=0, 1=deactivate watchdog timer
if ?WDEB386
?USEDEBUGOUTPUT equ 1	;std=1, send trace msgs in dbg mode to KD if detected
else                        
?USEDEBUGOUTPUT equ 0
endif                        
ifndef ?DOSOUTPUT
?DOSOUTPUT		equ 1	;std=1, use DOS for dbg output if inDOS flag not set
endif
if ?DOSOUTPUT
?USEHOSTPSP		equ 1	;std 1, 1=switch to host psp for DOS output
else
?USEHOSTPSP		equ 0	;must be 0
endif

?DPMI10			equ 1	;std=1, support some DPMI 1.0 functions (0504-0507)
?DPMI10EX		equ 1	;std=1, support more DPMI 1.0 functions (0508-050B)
?DPMI10EXX		equ 1	;std=1, support even more DPMI 1.0 functions (0210-0213)
?LDTROSEL		equ 0	;std=0, 1=LDT alias selector is r/o
?USESYSSPACE2	equ 1	;std=1, 1=use a second sys space ptr (downwards)
?CANTEXIT		equ 0	;std=0, 1=support FM_CANTEXIT flag
?LPMSINGDT		equ 0	;std=0, 1=LPMS selector in GDT
?SAVEPSP		equ 1	;std=1, 1=save real-mode psp of client in wPSPSegm;
						;       this psp will be used as owner for the 
                        ;       dyn. TLB (avoids memory leaks when in 
                        ;       int 21h, ah=3Fh Ctrl-C is pressed)
?CR0COPY		equ 1	;std 1: 1=copy cr0 to/from real-mode                        
?FASTINT31		equ 1	;std 1: 1=direct int 31h, 0=call by int 30h dispatcher
ifndef ?MOVEHIGH
?MOVEHIGH		equ 1	;std 1: 1=move GROUP32 into extended memory
endif
?FASTINT21		equ 0	;std 0: 1=direct int 21h, 0=call by int 30h dispatcher
?I41SUPPORT		equ 0	;std 0: 1=support some Int 41h codes
?DTAINHOSTPSP	equ 0	;std 0: 1=global DTA located in host PSP:80h
?RMCBSTATICSS	equ 1	;std 1: 1=alloc a selector for SS in real-mode callb.
?INT21API		equ 1	;std 1: 0=no int 21h api translation
?VM				equ 1	;std 1: 1=optionally support address contexts
?MOU33RESET		equ 0	;std 0, 1=reset int 33h mouse (v3.18: changed to 0)
?MOU15RESET		equ 0	;std 0, 1=reset int 15h mouse
?VCPIPREF		equ 1	;std 1: 1=optionally prefer VCPI, ignore XMS
?INT15XMS		equ 1	;std 1: 1=optionally use ext. mem the XMS host ignored
?SUPPDOS33		equ 1	;std 1: 1=support DOS 3.3
?MEMBUFF		equ 1	;std 1: 1=optionally don't report true free phys pages
ifndef ?FORCETEXTMODE
?FORCETEXTMODE	equ 0	;std 0: 0=don't set text mode in default exception handler
endif
?DYNTLBSIZE		equ 0FE00h	;std 0FE00, size of dynamic TLB
?NOINVLPG		equ 0	;std 0: 1=optionally disable INVLPG usage
?CHECKHOSTSTACK	equ 1	;std 1: 1=detect host stack exhaustion (in host reentries)
?CHECKLPMS		equ 1	;std 1: 1=detect LPMS exhaustion; v3.19
?RESTRICTMEM	equ 1	;std 1: 1=support -x option to restrict reported free mem
ifndef ?JHDPMI
?JHDPMI			equ 0	;std 0; 1=support jhdpmi JLM in vcpi mode
endif

if ?DPMI10EXX
?EXCRESTART		equ 1	;std 1: 1=support exception restartability
else
?EXCRESTART		equ 0
endif

if ?MOVEHIGH
?MOVEHIGHHLP	equ 1	;std 1: a helper code selector is required for CS
						;		because paging cannot be disabled on _TEXT32
else
?MOVEHIGHHLP	equ 0
endif
                        
ifndef ?MPICBASE                        
?MPICBASE	equ 08h		;std 08: master PIC base
endif
ifndef ?SPICBASE                        
?SPICBASE	equ 70h		;std 70: slave PIC base
endif

ifndef ?PMIOPL
?PMIOPL 		equ 3	;value for IOPL bits in flags in protected mode
endif
?RMIOPL 		equ 3	;value for IOPL bits in flags in v86 mode (see ?SETRMIOPL)

if ?DYNTLBALLOC
?TLBSIZE	equ 2000h	;std 2000h
else
?TLBSIZE	equ 4000h	;std 4000h
endif
?TLBSECS	equ ?TLBSIZE/200h
?RMSTKSIZE	equ 200h			;std 200h, real mode stack size


?NTCLEAR		equ 1	;std 1; clear NT flag on switch to protected mode
?IRQMAPPING		equ 1	;std 1; always route IRQs to protected-mode
?MAPRING0EXC	equ 0	;std 0; 1=route exc in ring 0 to client handler
?IGNEXC01INR0	equ 0	;std 0: 1=ignore exc 01 in ring0
?FASTJUMPS		equ 1	;std 1: 1=fast handling of intr30 jumps (gains 10%)
?I2FINITEXIT	equ 0	;std 0; 1=int 2F, ax=1605/1606 broadcast
?TLBINUMB		equ 1	;std 1: 1=TLB allocated in UMB if possible
?SINGLESETCR3	equ 0	;std 0; 1 only for test purposes!
?RING0FLATCS	equ 1	;std 1; supply a ring 0 flat CS in GDT (for wdeb386)   

?TRAPINT06RM	equ 0	;std 0: 1=watch int 06h real-mode
?TRAPINT21RM	equ 0	;std 0: 1=watch int 21h real-mode
?INT10SUPP		equ 1	;std 1: 1=check for exception 10h/INT 10h
?INT11SUPP		equ 1	;std 1: 1=support exception 11h
?MAPEXC00		equ 1	;std 1: 1=route exc 00 to int 00 protected-mode
?MAPINT00		equ 0	;std 0: 0=don't route int 00 to real-mode
?TESTEXC01		equ 1	;std 1: 1=test if INT 01 is a true exception.
						;		if not, just call INT 01 ring 3 PM
?MAPINT05		equ 1	;std 1: 1=route int 05 to real-mode. Int 05 is
						;		print screen, which makes it a special case.
?TESTEXC06		equ 1	;std 1: 1=check for exc 06 if [CS:EIP-2]==CD 06 
?MAPINT07		equ 0	;std 0: 0=dont route int 07 to real-mode

?DISINT@RM2PM	equ 0	;std 0: 1=clear IF in Flags onto stack
?CMPCR3 		equ 1	;std 1: 1=improves performance by 2-3%
?EMUMOVREGCRX	equ 1	;std 1: 1=emulate mov reg, crX (req. by 32rtm!)
?EMUMOVCRXREG	equ 1	;std 1: 1=emulate mov crX, reg
?EMUMOVCR0REG	equ 0	;std 0: 1=emulate mov cr0, reg
?EMUMOVREGDRX	equ 0	;std 0: 1=emulate mov reg, drX
?EMUMOVDRXREG	equ 0	;std 0: 1=emulate mov drX, reg

;--- v3.19: set this switch to 0, until it's clear what this "vendor" is supposed to do
?SUPP32RTM		equ 0	;std 0: 1=support int2f, ax=168a, "VIRTUAL SUPPORT"

?CATCHREBOOT	equ 1	;std 1; 1=catch ctrl-alt-delete
?SAVERMCR3		equ 0	;std 0: save/restore real mode CR3
?SAVERMIDTR		equ 0	;std 0: save real mode idtr
?SAVERMGDTR		equ 0	;std 0: save real mode gdtr
?CLRLDTR		equ 0	;std 0: clear LDTR before jump to real mode
?COPYFLRM2PM	equ 1	;std 1: copy flags from real-mode after int xx call
?SIMHLT			equ 0	;std 0: 1=simulate HLT, do not execute
ifndef ?ALLOWR0IRQ
?ALLOWR0IRQ		equ 0	;std 0: allow interrupts in ring 0
endif
?RESIDENT		equ 1	;std 1: support -r switch
?LOCALINT2324	equ 1	;std 1: init int 23/24 locally for each client
?SUPPDISABLE	equ 1	;std 1: support -d and -e command line switches
?CR0_NE 		equ 0	;std 0: 0 since 3.19; support -t and HDPMI=32768
?CR0_EM 		equ 0	;std 0: support -w ( clear EM bit on host init )
?CSIPFROMTOP	equ 1	;std 1: get CS:E/IP from top of LPMS
?CLEARHWESPRM	equ 1	;std 1: clear highword(esp) in real mode
?VCPIPICTEST	equ 1	;std 1: test if vcpi host did not remap PICs
?QEMMSUPPORT	equ 1	;std 1: make HDPMI compatible with QEMM vcpi host
?CALLPREVHOST	equ 1	;std 1: route to a previously installed 16bit host
?GLOBALTLBUSAGE	equ 1	;std 1: share one TLB between HDPMI instances
?LOADHIGH		equ 0	;std 0: move resident part into upper memory (not yet)
?CLEARDR6		equ 0	;std 0: 1=clear DR6 on client init
?LATELGDT		equ 0	;std 0: 1=load GDTR *after* switch to protected-mode
?CLEARHIWORDS	equ 1	;std 1: 1=opt. clear hiword of esi,edi on init. entry
?TLBLATE		equ 1	;std 1: 1=opt. alloc TLB when client starts (late)
?SAVEMSW		equ 0	;std 0: 1=save/restore MSW on entry/exit
?SSED			equ 0	;std 0: 1=host stack segment (GROUP16) is expand down
ifndef ?HSINEXTMEM
?HSINEXTMEM		equ 1	;std 1: 1=host stack is in extended memory. If option
						;		?MAPDOSHIGH is 0, this will cause HIWORD(esp)
						;		<> 0, which may be a problem if 16-bit stacks
						;		are used, due to a cpu design bug.
endif                        
if ?HSINEXTMEM
 ifndef ?MAPDOSHIGH
?MAPDOSHIGH		equ 1	;std 1: map the 16-bit part of the host in high memory   
 endif
 if ?MAPDOSHIGH
?CHECKSSIS32	equ 0	;std 0   
 else
?CHECKSSIS32	equ 1	;std 1: 1=check if client SS is 32bit
 endif
else
?MAPDOSHIGH		equ 0	;std 0: no need to map dos if ?HSINEXTMEM is zero.
?CHECKSSIS32	equ 0	;std 0
endif

?LPMSSIZE		equ 1000h	;std 1000h: size of LPMS
?DBGSUPP		equ 1		;std 1: 1=set TF on client's switch to pmode
?EXC10FRAME		equ 0		;std 0: 1=always set dpmi v1 exc frame if host
							;		is to be a v1 host (doesnt work yet)

?TRAPI15E801	equ 1	;std 1: trap int 15h, ax=e801h in raw mode
						;this may be required if HDPMI=32 is set

ife ?PMIOPL
?TRAPCLISTI		equ 1	; std=1: trap API for CLI/STI
?IFALWAYSON		equ 0	; std=0: don't reset IF, set VIF on mode switches only;
						; 1 won't work unless IRQs are hold back in a queue
endif
?PREDEFIDTGATES equ 78h	;number of predefined IDT gates
?DIO2RMS		equ 1	;std 1: 1=copy diskio packet onto rm-stack (int 25h/26h/21h,ax=7305h)

;--- since v3.20, the vendor API is generally available
?VENDORAPI		equ 1	;std 1: 1=support vendor API int 2Fh, ax=168Ah

?CHECKR3SS		equ 0	;std 0; 1=for debugging of stack problems

;----------------------------------------------------------------

if ?32BIT

?RSIZE equ 4
@iret macro
	iretd
endm

else

?RSIZE equ 2
@iret macro
	iret
endm

endif

;--- paging flags

PTF_PRESENT 	equ 001h;1=present,0=not present
PTF_WRITEABLE	equ 002h;1=writeable,0=readonly
PTF_USER		equ 004h;1=user,0=system
PTF_PWT 		equ 008h;1=write throu
PTF_PCD 		equ 010h;1=cache disabled
PTF_ACCESSED	equ 020h;1=accessed, 0=not accessed
PTF_DIRTY		equ 040h;1=dirty, 0=clean
PTF_PAT			equ 080h;1=page attribute table
PTF_GLOBAL		equ 100h;1=global

;?GPBIT			equ PTF_USER	;if ?GUARDPAGE0 = 1

;--- fatal __exitclient errorcodes

;_EAERR2_  equ 0002H 		; server termination requested
_EAERR3_  equ 0003H 		; Interrupt in ring 0 occured
ife ?RMCBSTATICSS
_EAERR4_  equ 0004H			; no free selector in real-mode callback
endif
if ?CHECKHOSTSTACK
_EAERR5_  equ 0005H			; host stack exhausted
endif
_EAERR6_  equ 0006H 		; PSP error on getpspsel (helper.asm)
if ?CHECKLPMS
_EAERR7_  equ 0007H 		; LPMS out of space
endif
if ?TRAPINT06RM
_EAERR8_  equ 0008H 		; exception 06 in real mode
endif

ifndef _SCRNTRACE_	;if screen output is direct, use special
_SCRNTRACE_ = 1		;attribute to see what comes from hdpmi
endif

ifndef _LTRACE_
ifdef _DEBUG
_LTRACE_ = 1
else
_LTRACE_ = 0
endif
endif

;--------------------------------- structures and equates

DOSSDA struct
		db ?		;critical error flag
bInDOS	db ?
		db 0Eh dup (?)
wPSP	dw ?
DOSSDA ends

cr		equ 13
lf		equ 10

;--- fMode flags

FM_TLBMCB	equ 1		;1=TLB is extra dos memory block
FM_RESIDENT	equ 2		;1=HDPMI is resident ( -r option )
FM_DISABLED equ 8		;1=server disabled
if ?CANTEXIT
FM_CANTEXIT	equ 10h		;1=cannot exit (IVT vecs not restorable)
endif
FM_CLONE    equ 20h		;1=this instance is a clone
FM_INIT 	equ 80h		;1=server initialized

;--- fMode2 flags

FM2_TLBLATE		equ 01h ;-b: alloc TLB late/free when idle
FM2_VCPI		equ 02h ;-v: prefer VCPI, ignore any XMS host
FM2_INT15XMS	equ 04h ;-y: use extended memory not managed by XMS
FM2_MEMBUFF		equ 08h ;-n: don't report true free phys pages
if ?FORCETEXTMODE
FM2_FORCETEXT	equ 10h ;-k: force text mode when displaying register dump
endif
FM2_NOINVLPG	equ 20h ;don't use invlpg (80386 or option -g)
FM2_RESTRMEM	equ 40h ;restrict free memory reported to client to 256MB
ifdef _DEBUG
FM2_LOG			equ 80h ;log file writing enabled
endif

;--- flags in bEnvFlags (low byte of environment variable HDPMI)

ENVF_INCLDOSMEM equ 02h ; include dos memory in page pool
ENVF_DPMI10		equ 04h	; report DPMI 1.0 version
ENVF_TLBLOW		equ 08h	; TLB is in low dow memory
ENVF_NODYNTLB	equ 10h ; don't alloc a 64 kB dynamic TLB
ENVF_VM     	equ 20h ; give each client its own VM
ENVF_NOXMS30  	equ 40h	; don't use xms 3.0 functions
ENVF_NOLFN  	equ 80h	; don't translate DOS LFN functions

;--- flags in bEnvFlags2 (high byte of environment variable HDPMI)

ENVF2_HMAMAPPING equ 01h;   256 remap PTEs for HMA in VCPI mode so that
						;       linear address==physical address
ENVF2_LDTLOW	equ 02h ;   512 allocate IDT+LDT in user address space +
						;       dont move GDT high
ENVF2_NOMEM10	equ 04h ;  1024 disable DPMI 1.0 memory functions
ENVF2_CLRHIWORD equ 08h ;  2048 clear hiword of esi/edi on init (32RTM)
ENVF2_SYSPROT	equ 10h ;  4096 alloc pages for GDT/IDT/LDT readonly
ENVF2_DEBUG  	equ 20h ;  8192 assume a (kernel) debugger is present
;ENVF2_NOI2F160A	equ 40h	; 16384 don't respond to int 2fh, ax=160Ah
if ?CR0_NE
ENVF2_NOCR0NE  	equ 80h	; 32768 don't touch CR0 NE bit
endif

;------------------------ flags in fDebug

FDEBUG_KDPRESENT	equ 1	;is any kernel debugger present?
FDEBUG_OUTPFORKD	equ 2	;outputs to kernel debugger if present?
FDEBUG_WDEB386		equ 4	;(w)deb386 active ( int 68h real-mode ok )

;------------------------ flags in fHost

FH_XMS		equ 1
FH_VCPI		equ 2
FH_RAW		equ 4
FH_HDPMI	equ 40h		; there is another HDPMI host installed already
FH_XMS30	equ 80h

;------------------------ HDPMI exit codes

;	00 - hdpmi installed in Int15/raw mode
;	01 - hdpmi installed in XMS mode
;	02 - hdpmi installed in VCPI mode
;	03 - DPMI host found, no VCPI host found, hdpmi not installed
;	04 - error: DOS memory low, cannot initialize
;	05 - error: cannot enable A20 in raw mode 
;	06 - error: VCPI host has remapped PICs
;	07 - error: cpu in V86-mode, but no VCPI or DPMI host found
;	08 - error: DOS Version not 4+
;	09 - error: CPU not 80386+
;	0A - error: invalid cmdline

EXIT_HDPMI_IN_RAWMODE	equ 0
EXIT_HDPMI_IN_XMSMODE	equ 1
EXIT_HDPMI_IN_VCPIMODE	equ 2
EXIT_DPMIHOST_RUNNING	equ 3
EXIT_OUT_OF_DOSMEMORY	equ 4
EXIT_CANNOT_ENABLE_A20	equ 5
EXIT_INCOMPAT_VCPI_HOST equ 6
EXIT_UNKNOWN_PM_HOST	equ 7
EXIT_NO_DOS4			equ 8
EXIT_NO_80386			equ 9
EXIT_CMDLINE_INVALID	equ 10

;------------------------ registers on stack after pushad

PUSHADS struct
union
rEDI	dd ?		;0
rDI 	dw ?		;0
ends
union
rESI	dd ?		;4
rSI 	dw ?		;4
ends
union
rEBP	dd ?		;8
rBP 	dw ?		;8
ends
RESERVE dd ?		;12
union
rEBX	dd ?		;16
rBX 	dw ?		;16
_BL 	db ?		;16
ends
union
rEDX	dd ?		;20
rDX 	dw ?		;20
_DL 	db ?		;20
ends
union
rECX	dd ?		;24
rCX 	dw ?		;24
_CL 	db ?		;24
ends
union
rEAX	dd ?		;28
rAX 	dw ?		;28
_AL 	db ?		;28
ends
PUSHADS ends

PUSHAS struct
rDI 	dw ?		;0
rSI 	dw ?		;2
rBP 	dw ?		;4
RESERVE dw ?		;6
rBX 	dw ?		;8
rDX 	dw ?		;10
rCX 	dw ?		;12
rAX 	dw ?		;14
PUSHAS ends

;--- descriptor (GDT/LDT)

DESCRPTR struct 	;8 byte segment descriptor
limit	dw ?		;+0 limit[0..15]
A0015	dw ?		;+2 base addr[0..15]
A1623	db ?		;+4 base addr[16..23]
attrib	db ?		;+5 attribut
					;bits 0-3: type
					;bit	4: 1=memory segments,0=gates
					;bit  5-6: descriptor privilege level
					;bit	7: present bit (1=present)
lim_gr	db ?		;+6 bits 0-3:limit[16..19] (80386)
					;bit	4:AVL = available to software
					;bit	5:0
					;bit	6:default size (0=16 Bit,1=32 Bit)
					;bit	7:granularity (80386)
A2431	db ?		;+7 base addr[24..31] (80386)
DESCRPTR ends

;*** type (memory segments):
;*** bit 3 = 1 -> CODE,0 -> DATA
;*** bit 2 = 1 -> DATA:expand down,CODE:conforming
;*** bit 1 = 1 -> DATA:writable,CODE:readable
;*** bit 0 = 1 -> accessed
;*** type (system segments (TSS) ***
;*** bit 3 = 1 -> 386
;*** bit 2 = 1 -> Gate
;*** bit 1 = 1 ->
;*** bit 0 = 1 ->
;     7/F -> trap gate
;     6/E -> Interrupt gate
;     4/C -> Call gate

;--- pseudo descriptor (for LGDT/SGDT/LIDT/SIDT)

PDESCR	struct
wLimit	dw ?
dwBase	dd ?
PDESCR	ends

;--- gates

;*** 4G 16-Bit-Code-Segment -> <0ffffh,0,0,9bh,08fh,0>
;*** 4G 32-Bit-Code-Segment -> <0ffffh,0,0,9bh,0cfh,0>
;*** 4G 16-Bit-Data-Segment -> <0ffffh,0,0,93h,08fh,0>

GATE    struct
ofs     dw ?
sel     dw ?
attrib  dw ?
ofs32   dw ?
GATE    ends

TSSSEG struct
dwLink	dd ?	;+00 selector
_Esp0	dd ?	;+04
_SS0    dd ?
dqStk1	dq ?	;+0C
dqStk2	dq ?	;+14
_CR3	dd ?	;+1C
_Eip	dd ?	;+20
_Efl	dd ?	;+24
_Eax	dd ?	;+28
_Ecx	dd ?	;+2C
_Edx	dd ?	;+30
_Ebx	dd ?	;+34
_Esp	dd ?	;+38
_Ebp	dd ?	;+3C
_Esi	dd ?	;+40
_Edi	dd ?	;+44
_ES		dd ?	;+48
_CS		dd ?	;+4C
_SS		dd ?	;+50
_DS		dd ?	;+54
_FS		dd ?	;+58
_GS		dd ?	;+5C
_LDT	dd ?	;+60
wFlags  dw ?	;+64
wOffs   dw 68h	;+66
TSSSEG ends

;--- CR0 flags

CR0_PE	equ 01h			;protected mode segmentation mechanism
CR0_MP	equ 02h			;math present
CR0_EM	equ 04h			;emulate FPU
CR0_TS	equ 08h			;task switch
CR0_NE	equ 20h			;numeric exception (exc 10h instead of int 75h)
;CR0_WP	equ 10000h		;write to r/o pages not allowed in ring 0 (486+)
CR0_WPbit equ 16		;write to r/o pages not allowed in ring 0 (486+)
CR0_PG	equ 80000000h   ;paging

;--- internal real-mode callbacks
;--- the structure is splitted in 2, one
;--- that has to be accessed in rm (INTRMCBr)
;--- and another that is accessed in pm only (INTRMCB).

INTRMCBr struct
rm_vec	 dd ?	; rm cs:ip routed to from pm INTs ( IRQs, 1C, 23, 24 )
INTRMCBr ends

?RMCBMOUSE	equ 13h		;index of internal rmcb for int 33h mouse event proc

;--- ring 3 far proc address structure

R3PROC struct
if ?32BIT
_Eip	dd ?
_Cs		dd ?
else
_Eip	dw ?
_Cs		dw ?
endif
R3PROC ends

;--- real-mode callback item
;--- size is fix 16

RMCB struct
		R3PROC <>
ife ?32BIT
		dd ?
endif
rmcs	df ?		;far32 address of real mode call structure
if ?RMCBSTATICSS
wSS		dw ?
else
		dw ?
endif 
RMCB ends

PMSTATE struct

union
rESDS	dd ?		;+0
struct
rES		dw ?		;+2
rDS		dw ?		;+0
ends
ends

union
rFSGS	dd ?		;+4
struct
rFS		dw ?		;+4
rGS		dw ?		;+6
ends
ends

rSSd	dd ?
rESP	dd ?

PMSTATE ends

;--- store current client ss:esp into pmstate, used by:
;--- _pm2rm in i31swt.asm ( raw mode switch to real-mode )
;--- _jmp_rm in switch.asm ( std jump to real-mode )
;--- assumes:
;--- [dwHostStack]: esp -> ABOVE an IRET32 struct

@store_ssesp macro
if 1
	push ebp
	mov ebp,ss:[dwHostStack]
	push [ebp-sizeof IRET32].IRET32.rSP
	mov ebp,[ebp-sizeof IRET32].IRET32.rSSd
 if ?CHECKR3SS
	verw bp
	jz @F
	int 3
@@:
 endif
	pop ss:pmstate.rESP
	mov ss:pmstate.rSSd, ebp
	pop ebp
else
;--- 1 push less, 1 pop more
	push ebp
	mov ebp, ss:[dwHostStack]
	lea ebp, [ebp-2*4] 
	xchg esp, ebp
	pop ss:pmstate.rESP
	pop ss:pmstate.rSSd
	mov esp, ebp
	pop ebp
endif
endm

;--- structure for VCPI function DE0C (switch to protected mode)

VCPIRM2PM struct
_cr3	dd ?			;value for cr3
_gdtr	dd ?			;linear address of pseudo descriptor for GDTR
_idtr	dd ?			;linear address of pseudo descriptor for IDTR
_LDTR	dw ?			;value for LDTR
_TR		dw ?			;value for TR
_Eip	dd ?			;value for Eip
_CS		dw ?			;value for CS
VCPIRM2PM ends


;--- structure for VCPI function DE0C (switch to V86 mode)
;--- switch is done inside the VCPI host by a IRETD with 
;--- VM bit set in EFlags.

V86IRET struct
 union
rEIP	dd ?
rIP		dw ?
 ends
 union
rCSd	dd ?
rCS 	dw ?
 ends
 union
rEFL	dd ?
rFL		dw ?
 ends
 union
rESP	dd ?
rSP		dw ?
 ends
 union
rSSd	dd ?
rSS 	dw ?
 ends
 union
rESd	dd ?
rES		dw ?
 ends
 union
rDSd	dd ?
rDS		dw ?
 ends
 union
rFSd	dd ?
rFS		dw ?
 ends
 union
rGSd	dd ?
rGS		dw ?
 ends
V86IRET ends

;--- IRET stack frames

;--- IRET protected mode without SS:E/SP

IRET32PM struct
union
 struct
rCSIP	df ?
  		dw ?
 ends
 struct
rIP 	dd ?
  union
rCSd	dd ?
rCS 	dw ?
  ends
 ends
ends
rFL 	dd ?

IRET32PM ends

IRET16PM struct

union
rCSIP	dd ?
struct
rIP 	dw ?
rCS 	dw ?
ends
ends
rFL 	dw ?

IRET16PM ends

IRETSPM struct
if ?32BIT
	IRET32PM <>
else
	IRET16PM <>
endif
IRETSPM ends

;--- IRET protected mode with switch to ring 3
;--- (includes SS:E/SP)

IRET32 struct
	IRET32PM <>

union
 struct
rSSSP	df ?
    	dw ?
 ends
 struct
rSP 	dd ?
  union
rSSd	dd ?
rSS 	dw ?
  ends
 ends
ends

IRET32 ends

IRET16 struct
		IRET16PM <>

union
rSSSP	dd ?
struct
rSP 	dw ?
rSS 	dw ?
ends
ends

IRET16 ends

IRETS struct
if ?32BIT
	IRET32 <>
else
	IRET16 <>
endif
IRETS ends

;--- IRET real mode

IRETSRM struct
rIP 	dw ?
rCS 	dw ?
rFL 	dw ?
IRETSRM ends

;--- RETF with SS:E/SP

RETF32 struct

union
 struct
rCSIP	df ?
		dw ?
 ends        
 struct
rIP 	dd ?
  union
rCSd	dd ?  
rCS 	dw ?
  ends
 ends
ends

union
 struct
rSSSP	df ?
    	dw ?
 ends        
 struct
rSP 	dd ?
  union
rSSd 	dd ?
rSS 	dw ?
  ends
 ends
ends

RETF32 ends

RETF16 struct

union
rCSIP	dd ?
struct
rIP 	dw ?
rCS 	dw ?
ends
ends
union
rSSSP	dd ?
struct
rSP 	dw ?
rSS 	dw ?
ends
ends

RETF16 ends

RETFS struct
if ?32BIT
		RETF32 <>
else
		RETF16 <>
endif
RETFS ends

;--- fault (with error code) without SS:E/SP

R0FAULT32 struct

rErr	dd ?
union
 struct
rCSIP	df ?
		dw ?
 ends
 struct
rIP 	dd ?
  union
rCSd	dd ?  
rCS 	dw ?
  ends        
 ends
ends
rFL 	dd ?

R0FAULT32 ends

R0FAULT struct
;--- v3.20: ring 0 fault is ALWAYS 32-bit, R0FAULT16 has been removed
if 1
		R0FAULT32 <>
else
		R0FAULT16 <>
endif
R0FAULT ends

;--- fault with SS:E/SP

R3FAULT32 struct
		R0FAULT32 <>

union
 struct
rSSSP	df ?
		dw ?
 ends
 struct
rSP 	dd ?
  union
rSSd 	dd ?
rSS 	dw ?
  ends
 ends
ends

R3FAULT32 ends

R3FAULT16 struct
rErr	dw ?
union
struct
rIP 	dw ?
rCS 	dw ?
ends
struct
rCSIP	dd ?
ends
ends
rFL 	dw ?

union
struct
rSP 	dw ?
rSS 	dw ?
ends
struct
rSSSP	dd ?
ends
ends

R3FAULT16 ends

R3FAULT struct
if ?32BIT
		R3FAULT32 <>
else
		R3FAULT16 <>
endif
R3FAULT ends

;--- DPMI 0.9 exception frame

DPMIEXC  struct
if ?32BIT
rDPMIIP dd ?
rDPMICS dd ?
else
rDPMIIP dw ?
rDPMICS dw ?
endif
		R3FAULT <>
DPMIEXC  ends

;--- DPMI 1.0 exception frame

if ?DPMI10EXX

DPMI10EXC struct
		DPMIEXC <>
ife ?32BIT
		db 10h dup (?)
endif
rDPMIIPx	dd ?	;+20h
rDPMICSx	dd ?	;+24h
rErrx		dd ?	;+28h	;filled with dr6 if exc 01
rEIPx		dd ?	;+2Ch
rCSx		dw ?	;+30h
rInfoBits	dw ?	;+32h
rEFLx		dd ?	;+34h
rESPx		dd ?	;+38h
rSSx		dd ?	;+3Ch
rESx		dd ?	;+40h
rDSx		dd ?	;+44h
rFSx		dd ?	;+48h
rGSx		dd ?	;+4Ch
rCR2		dd ?	;+50h	;exc 0E only
rPTE		dd ?	;+54h	;exc 0E only, bits 0-8 of PTE only
DPMI10EXC ends

endif

PF16 typedef far16 ptr
PF32 typedef far32 ptr

IVTHOOK struct
bInt		db ?	;int# to hook, or -2 if to be ignored
;dwOldVec	dd ?
wOldVec		dw ?	;near16 ptr where the old ivt vector is stored
wNewOfs		dw ?	;offset part of new value for vector (segment is GROUP16)
IVTHOOK ends

;-------------------------------- macros

ifdef ?PE
GROUP32	equ <FLAT>
?USE32	equ <flat>
?CODER3	equ <>
else
?USE32	equ <use32>
?CODER3	equ <'CODE'>
endif

@defseg32 macro name_, align_, cls:=<'CODE'>
ifdef ?PE
name_ segment align_ flat  public cls
else
name_ segment align_ use32 public 'CODE'
endif
name_ ends
ifndef ?PE
GROUP32 group name_
endif
endm

@defseg16 macro name_, align_, cls:=<'CODE'>
name_ segment align_ use16 public cls
name_ ends
GROUP16 group name_
endm

@seg macro segname
	ifidn <segname>,<_TEXT32>
	  @defseg32 segname, dword
	elseifidn <segname>,<CONST32>
	  @defseg32 segname, dword
	elseifidn <segname>,<_ITEXT32>
	  @defseg32 segname, dword
	elseifidn <segname>,<_DATA32C>
	  @defseg32 segname, dword, 'DATA'
	elseifidn <segname>,<ENDGRP32>
	  @defseg32 segname, para
	elseifidn <segname>,<BEGGRP16>
	  @defseg16 segname, para
	elseifidn <segname>,<_DATA16>
	  @defseg16 segname, dword
	elseifidn <segname>,<_DATA16V>
	  @defseg16 segname, dword
	elseifidn <segname>,<_DATA16C>
	  @defseg16 segname, dword
	elseifidn <segname>,<_TEXT16>
	  @defseg16 segname, dword
	elseifidn <segname>,<_ITEXT16>
	  @defseg16 segname, byte
	elseifidn <segname>,<ENDGRP16>
	  @defseg16 segname, para
	else
%	  .err <unknown segment segname in macro @seg>
	endif
endm

CStr macro xx:VARARG
local xxxx
CONST32 segment dword ?USE32 public 'CODE'
xxxx db xx
	db 0
CONST32 ends
ifndef ?PE
GROUP32 group CONST32
endif
	exitm <LOWWORD offset xxxx>
endm

@printf macro xx,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12
  ifnb <a12>
	echo too many parameters for @printf
	.err1
  endif
  for arg, <a11,a10,a9,a8,a7,a6,a5,a4,a3,a2,a1>
   ifnb <arg>
	if type arg eq 1
	 push word ptr arg
	else
	 push arg
	endif
   endif
  endm
	call _stroutx
	dw CStr(<xx>)
endm

;--- trace macros for debug version

@ResetTrace macro
ifndef _DEBUG
_LTRACE_ = 0
endif
endm
        
;--- formatted trace output in protected-mode

@dprintf macro strg:REQ, xx:VARARG
if _LTRACE_
	@printf <"#",strg,lf>,xx
endif
endm

;--- formatted conditional trace output in protected-mode

@dprintfx macro cond, strg:REQ, xx:VARARG
local lbl
if _LTRACE_
	pushfd
	test ss:traceflgs, cond
	jz lbl
	@printf <"#",strg,lf>,xx
lbl:
	popfd
endif
endm

;--- same as @dprintfx, but don't change ESP

@dprintfxx macro cond, strg:REQ, xx:VARARG
local lbl
if _LTRACE_
	test ss:traceflgs, cond
	jz lbl
	@printf <"#",strg,lf>,xx
lbl:
endif
endm

ifdef _DEBUG
?LOG_PMGREXT	equ 1	;extended pagemgr log
?LOG_INT30		equ 2	;int 30h dispatcher log
?LOG_INTRMCB	equ 4	;internal rmcbs log
?LOG_CLISTI		equ 8	;CLI/STI emulation
?LOG_RMCALL		equ 16	;dpmi rm calls (ax=030x)
endif

;--- formatted output in real-mode

@rprintf macro xx,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12
local xxxx
CONST16 segment byte use16 public 'CODE'
xxxx   db xx,0
CONST16 ends
GROUP16 group CONST16
  ifnb <a12>
	echo too many parameters for @rprintf
	.err1
  endif
  for arg, <a11,a10,a9,a8,a7,a6,a5,a4,a3,a2,a1>
   ifnb <arg>
	push arg
   endif
  endm
	call _$stroutx
	dw offset xxxx
endm

@drprintf macro strg:REQ, xx:VARARG
if _LTRACE_
	@rprintf <"-",strg,lf>,xx
endif
endm

@checkhoststack macro
if ?CHECKHOSTSTACK
  if ?HSINEXTMEM
	cmp esp, ss:dwStackTop
  else
	cmp esp, 80h
  endif
	jc _exitclientEx5
endif
endm

;--- call real-mode software int xx 
;--- esp -> IRET32
;--- (will return flags)

@callrmsint macro xx
	push xx
	jmp  _callrmsint
	align 4
endm

;--- call real-mode int xx 
;--- used internally

@simrmint macro xx
	push xx
	call callrmintintern
endm

;--- call ring 3 protected-mode int xx
;--- usually this is done by the Int 30h dispatcher
;--- but some ints don't use Int 30h
;--- esp -> IRET32

@simintpms macro xx
	pushd offset r3vect&xx
	jmp pms_call_int
	align 4
endm

;--- save current real-mode SS:SP
;--- so it can be saved on the host stack later.
;--- this is used by internal & client real-mode callbacks
;--- this macro should be followed by @pushstate in protected-mode

@savermstk macro
	mov cs:wrmSPtmp,sp
	mov cs:wrmSStmp,ss
endm

;--- restore value of real-mode stack
;--- this is done after a @popstate macro in protected-mode
;--- this is used by internal & client real-mode callbacks

@restorermstk macro
	push cs:dwrmSSSPtmp
	pop cs:v86iret.rSP
	pop cs:v86iret.rSS
endm

;--- save client state on host stack
;--- this is used by internal & client real-mode callbacks

@pushstate macro bRMSegs
ifnb <bRMSegs>
 if 0;e ?HIDEIVTHOOKS
	push dword ptr ss:[wIrqOrgRm]
 endif
	push ss:v86iret.rESd
	push ss:v86iret.rDSd
	push ss:v86iret.rFSd
	push ss:v86iret.rGSd
endif
	push ss:v86iret.rSS
	push ss:v86iret.rSP

	push ss:dwrmSSSPtmp
	pop ss:v86iret.rSP
	pop ss:v86iret.rSS

	push ss:pmstate.rESDS
	push ss:pmstate.rFSGS
	push ss:pmstate.rESP
	push ss:pmstate.rSSd

	push ss:[dwHostStack]
	mov ss:[dwHostStack], esp
endm

;--- restore client state from host stack
;--- this is used by internal and client real-mode callbacks

@popstate macro bRMSegs
	pop ss:[dwHostStack]
	pop ss:pmstate.rSSd
	pop ss:pmstate.rESP
	pop ss:pmstate.rFSGS
	pop ss:pmstate.rESDS
	pop ss:dwrmSSSPtmp
ifnb <bRMSegs>
	pop ss:v86iret.rGSd
	pop ss:v86iret.rFSd
	pop ss:v86iret.rDSd
	pop ss:v86iret.rESd
 if 0;e ?HIDEIVTHOOKS
	pop dword ptr ss:[wIrqOrgRm]
 endif
endif
endm

;--- real-mode to protected-mode break
;--- this prevents debuggers from stepping in untraceable code
;--- also clears IF and TF flags

@rm2pmbreak macro
if ?INTRM2PM
	int ?XRM2PM
	nop
else
	cli
endif
endm


@DebugBreak macro x
local sm
if x
	test ss:fDebug,FDEBUG_KDPRESENT
	jz sm
	int 3
sm:
endif
endm

@waitesckey macro bNoPush
local sm1
if _LTRACE_
ifb <bNoPush>
	pushfd
	push eax
endif
sm1:
	in al,64h		;key from keyboard arrived?
	test al,1
	jz sm1
	in al,60h
	cmp al,81h		;wait for ESC released
	jnz sm1
ifb <bNoPush>
	pop eax
	popfd
endif
endif
endm

;--- the lgdt,sgdt,lidt and sidt opcodes
;--- are CS Default bit dependant!
;--- in 16bit code segments the highest byte of the address
;--- is *not* loaded without prefix 66h!

@lgdt macro x
	db 66h
	lgdt x
endm
@sgdt macro x
	db 66h
	sgdt x
endm
@lidt macro x
	db 66h
	lidt x
endm
@sidt macro x
	db 66h
	sidt x
endm

@mov_eax_cr4 macro
;	mov eax, cr4
	db 0Fh,20h,0E0h
endm

@mov_cr4_eax macro
;	mov cr4, eax
	db 0Fh,22h,0E0h
endm

@cpuid macro
;	cpuid
	db 0Fh,0A2h
endm

@int_31 macro
if ?FASTINT31
	int 31h
else
	call intr31_
endif
endm

@int_21 macro
if ?FASTINT21
	int 21h
else
	call intr21_
endif
endm

;-- switches to real-mode

@jmp_rm macro dest
	mov ss:[wRmDest], offset dest
	jmp _jmp_rm
endm

@rawjmp_rm macro dest
	mov ss:[wRmDest], offset dest
	jmp _rawjmp_rm
endm

@rawjmp_rm_savesegm macro dest
	mov ss:[wRmDest], offset dest
	jmp _rawjmp_rm_savesegm
endm

;-- switches to protected-mode

@jmp_pm macro dest
	pushw LOWWORD offset dest
	jmp _jmp_pm
endm

;--- v3.21: simplified real-mode call
;--- either NEAR, FAR or IRET frame.
;--- used by @simrmint - won't work anymore for int 25h/26h!

@call_rm macro dest_rm, ?far, flags
local rmhelp, pmret
	@jmp_rm rmhelp
	align 4
_TEXT16 segment
rmhelp:
	pushw LOWWORD offset pmret
ifnb <flags>
 ifidn <flags>,<1>
	pushf
 else
	push flags
 endif
endif
if ?far
	push cs
endif
	push offset _jmp_pmX
	jmp dest_rm
	align 2
_TEXT16 ends
pmret:
endm

;--- @jmp_pmX is like @jmp_pm, but with @rm2pmbrk first
@jmp_pmX macro dest
	pushw LOWWORD offset dest
	jmp _jmp_pmX
endm

@rawjmp_pm macro dest
	pushw LOWWORD offset dest
	jmp _rawjmp_pm
endm

@rawjmp_pm_savesegm macro dest
	pushw LOWWORD offset dest
;--- save segment regs in v86iret before switch
	jmp _rawjmp_pm_savesegm
endm

