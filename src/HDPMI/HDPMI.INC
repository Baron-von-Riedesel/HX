
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
?WDEB386		equ 1 - ?386SWAT;support either swat or wdeb
?KDSUPP			equ ?WDEB386+?386SWAT
?WINDBG			equ 0	;std=0, 1=support Win386 pm int 22h debug API
ifndef ?ENHANCED
?ENHANCED		equ 0	;std=0, 1=simulate Win386 (enhanced mode)
endif
if ?ENHANCED
?SUPI2F1600		equ 1	;int 2F,ax=1600 support (win enh mode) - real mode
?SUPI2F160A		equ 1	;int 2F,ax=160A support (get version) - real mode
?WINMODE		equ 3	;3=enhanced mode (Pharlab TNT has problems with this)
else
?SUPI2F1600		equ 0
?SUPI2F160A		equ 1	;used by win.com to detect if windows is running
?WINMODE		equ 2	;2=standard mode
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
                        
?LOGINT30		equ 0	;std=0, 1=log last int 30h call
?LOGINT31		equ 0	;std=0, 1=log last int 31h call
?MOVEGDT		equ 1	;std 1: 1=move GDT into extended memory
?MOVEIDT		equ 1	;std=1, 1=move IDT into extended memory on startup
?DYNBREAKTAB	equ 1	;std=1, 1=create pm break table dynamically
?CHECKIRQRM		equ 1	;std=1, 1=get/set the fake real-mode ints with
						; functions 31h, ax=0200/0201 for std realmode cbs
?ALLOCRMS		equ 0	;std=0, 0=RMS is allocated by client
						;       1=RMS is allocated by server
?INTRM2PM		equ 1	;std=1, use a real-mode int to protect switch to
						;protected mode (int 96h)
?XRM2PM 		equ 96h	;std=96h, real-mode to prot-mode int no
?USEINTS		equ 0	;std=0, 1=use true INT opcode for client rm INT
						;       0=use IVT vector directly
?GUARDPAGE0		equ 1	;std=1, optionally guard page 0 (HDPMI=1)
						;       required to watch IRQs in real-mode (DOS4GW?)
?DYNTLBALLOC	equ 1	;std=1, 1=alloc a temp 64 kB TLB for int 21, ah=3f/40
?SETRMIOPL		equ 0	;std=0, 1=set IOPL for real mode (not needed)
?SCRATCHSEL		equ 0	;std=0, scratch selector required?
?INT1D1E1F		equ 0	;std=0, 1=modify int 1d,1e,1f to writeable
?I15MEMMGR		equ 0	;std=0, int 15 memory management (no longer needed)
?WATCHDOG		equ 0	;std=0, 1=deactivate watchdog timer
if ?WDEB386
?USEDEBUGOUTPUT equ 1	;std=1, send trace msgs in debug mode to KD
						;       if one is active
else                        
?USEDEBUGOUTPUT equ 0
endif                        
?DOSOUTPUT		equ 1	;std=1, use DOS for output if inDOS flag not set
?DPMI10			equ 1	;std=1, support some DPMI 1.0 functions (0504-0507)
?DPMI10EX		equ 1	;std=1, support more DPMI 1.0 functions (0508-050B)
?DPMI10EXX		equ 1	;std=1, support even more DPMI 1.0 functions (0210-0213)
?CATCHLDTACCESS	equ 0	;std=0, 1=catch LDT write access if LDT is r/o
?LDTROSEL		equ 0	;std=0, 1=LDT alias selector is r/o
?SAFEPAGETABS	equ 0	;std=0, 1=page tables cannot be accessed from ring 3
?USESYSSPACE2	equ 1	;std=1, 1=use a second sys space ptr (downwards)
?CANTEXIT		equ 0	;std=0, 1=support FM_CANTEXIT flag
?LPMSINGDT		equ 0	;std=0, 1=LPMS selector in GDT
?SAVEPSP		equ 1	;std=1, 1=save real-mode psp of client in wPSPSegm;
						;       this psp will be used as owner for the 
                        ;       dyn. TLB (avoids memory leaks when in 
                        ;       int 21h, ah=3Fh Ctrl-C is pressed)
?CR0COPY		equ 1   ;std 1: 1=copy cr0 to/from real-mode                        
?FASTINT31		equ 1	;std 1: 1=direct int 31h, 0=call by int 30h dispatcher
ifndef ?MOVEHIGH
?MOVEHIGH		equ 1	;std 1: 1=move _TEXT32 in extended memory
endif
?FASTINT21		equ 0	;std 0: 1=direct int 21h, 0=call by int 30h dispatcher
?I41SUPPORT		equ 0	;std 0: 1=support some Int 41h codes
?DTAINHOSTPSP	equ 0	;std 0: 1=global DTA located in host PSP:80h
?RMCBSTATICSS	equ 1	;std 1: 1=alloc a selector for SS in real-mode callb.
?INT21API		equ 1	;std 1: 0=no int 21h api translation
?VM				equ 1	;std 1: 1=optionally support address contexts
?MOU33RESET		equ 1	;std 1, 1=reset int 33h mouse
?MOU15RESET		equ 0	;std 0, 1=reset int 15h mouse
?VCPIPREF		equ 1	;std 1: 1=optionally prefer VCPI, ignore XMS
?INT15XMS		equ 1	;std 1: 1=optionally use ext. mem the XMS host ignored
?SUPPDOS33		equ 1	;std 1: 1=support DOS 3.3
?MEMBUFF		equ 1	;std 1: 1=optionally don't report true free phys pages
if ?DOSOUTPUT
?FORCETEXTMODE	equ 0	;std 0: don't force text mode if DOS output is used
else
?FORCETEXTMODE	equ 1	;std 1: 1=optionally don't switch to text mode
endif
?DYNTLBSIZE		equ 0FE00h	;std 0FE00, size of dynamic TLB
?NOINVLPG		equ 0	;std 0: 1=optionally disable INVLPG usage
?SETEXCHS		equ 1	;std 1: 1=set exception host stack value
?CHECKHOSTSTACK	equ 1	;std 1: 1=detect host stack exhaustion (in host reentries)
?RESTRICTMEM	equ 0ffffh	;std=0ffffh - free page restriction is 256MB, 0 disables

if ?DPMI10EXX
?EXCRESTART   = 1		;std 1: 1=support exception restartability
else
?EXCRESTART   = 0
endif

if ?MOVEHIGH
?MOVEHIGHHLP	equ 1	;std 1: a helper code selector is required for CS
;								because paging cannot be disabled on _TEXT32
else
?MOVEHIGHHLP	equ 0
endif
                        
ifndef ?MPICBASE                        
?MPICBASE	= 08h   	;std 08: master PIC base
endif
ifndef ?SPICBASE                        
?SPICBASE	= 70h   	;std 70: slave PIC base
endif

if ?ENHANCED
?SUPI2F16840001	equ 1	;std=1, support int 2f,ax=1684,bx=1 (vmm)
?SUPI2F16840009	equ 1	;std=1, support int 2f,ax=1684,bx=9 (reboot)
?SUPI2F16840017	equ 1	;std=1, support int 2f,ax=1684,bx=17 (shell)
?SUPI2F16840021	equ 1	;std=1, support int 2f,ax=1684,bx=21 (pagefile)
?SUPI2F1684002A	equ 0	;std=0, support int 2f,ax=1684,bx=2A (vwin32)
?SUPI2F16840442	equ 1	;std=1, support int 2f,ax=1684,bx=442 (vtdapi)
else
?SUPI2F16840001	equ 0	;std=0, support int 2f,ax=1684,bx=17 (vmm)
?SUPI2F16840009	equ 0	;std=0, support int 2f,ax=1684,bx=9 (reboot)
?SUPI2F16840017	equ 0	;std=0, support int 2f,ax=1684,bx=17 (shell)
?SUPI2F16840021	equ 0	;std=0, support int 2f,ax=1684,bx=21 (pagefile)
?SUPI2F1684002A	equ 0	;std=0, support int 2f,ax=1684,bx=2A (vwin32)
?SUPI2F16840442	equ 0	;std=0, support int 2f,ax=1684,bx=442 (vtdapi)
endif

?GPBIT			equ 04h	;set USER (04) (if ?GUARDPAGE0 = 1)

ifndef ?PMIOPL
?PMIOPL 		equ 30h	;value for IOPL bits in flags in protected mode
endif
?RMIOPL 		equ 30h	;value for IOPL bits in flags in v86 mode (needed?)

if ?DYNTLBALLOC
?TLBSIZE	equ 2000h
else
?TLBSIZE	equ 4000h
endif

?TLBSECS	equ ?TLBSIZE/200h
?RMSTKSIZE	equ 200h			;real mode stack size


?NTCLEAR	 = 1		;std 1; clear NT flag on switch to protected mode
?IRQMAPPING  = 1		;std 1; always route IRQs to protected-mode
?MAPRING0EXC = 0		;std 0; route exc in ring 0 to client handler
?IGNEXC01INR0 = 0		;std 1: ignore exc 01 in ring0
?FASTJUMPS	 = 1		;std 1: fast handling of intr30 jumps (gains 10%)
?I2FINITEXIT = 0		;std 0; int 2F, ax=1605/1606 broadcast
?TLBINUMB	 = 1		;std 1: TLB allocated in UMB if possible
?CHECKSSIS32 = 0		;std 0: 1=check if client SS is 32bit
?SINGLESETCR3 = 0		;std 0; 1 only for test purposes!
?RING0FLATCS  = 1		;std 1; supply a ring 0 flat CS in GDT (for wdeb386)   

?IRQ00VAL	  = 0		;std 0: 0=route IRQ 00 to PM
?IRQ05VAL	  = 0		;std 0: 0=route IRQ 05 to PM
?IRQ06VAL	  = 0		;std 0: 0=route IRQ 06 to PM
?IRQ14VAL	  = 0		;std 0: 0=route IRQ 14 to PM
?IRQ15VAL	  = 0		;std 0: 0=route IRQ 15 to PM

?TRAPINT06RM  = 0		;std 0: watch int 06h real-mode
?TRAPINT21RM  = 0		;std 0: watch int 21h real-mode
?INT10SUPP	  = 1		;std 1: check for exception 10h/INT 10h
?INT11SUPP    = 1		;std 1: support exception 11h
?TRANSFL	  = 1		;std 1: copy flags when returning from internal rmcbs
?COPYTF 	  = 0		;std 0: copy TF when returning from internal rmcbs
						;       2005/07/30: std changed to 0 
						;       it was nonsense to copy the TF flag 
                        ;       because at best we get an int 01 in real-mode.
                        ;       it is "impossible" to transfer this flag
                        ;       back to the protected-mode execution path.

?MAPEXC00	  = 1		;std 1: 1=route exc 00 to int 00 protected-mode
?MAPINT00	  = 0		;std 0: 0=don't route int 00 to real-mode
?TESTEXC01	  = 1		;std 1: 1=test if INT 01 is a true exception.
						;		if not, just call INT 01 ring 3 PM
?MAPINT05	  = 1		;std 1: 1=route int 05 to real-mode. Int 05 is
                        ;		print screen, which makes it a special case.
?TESTEXC06	  = 1		;std 1: 1=check for exc 06 if [CS:EIP-2]==CD 06 
?MAPINT07	  = 0		;std 0: 0=dont route int 07 to real-mode

?DISINT@RM2PM = 0		;std 0: 1=clear IF in Flags onto stack
?CMPCR3 	  = 1		;std 1: 1=improves performance by 2-3%
?EMUMOVREGCRX = 1		;std 1: emulate mov reg, crX (req. by 32rtm!)
?EMUMOVCRXREG = 1		;std 1: emulate mov crX, reg
?EMUMOVCR0REG = 0		;std 0: emulate mov cr0, reg
?EMUMOVREGDRX = 0		;std 0: emulate mov reg, drX
?EMUMOVDRXREG = 0		;std 0: emulate mov drX, reg
?SUPP32RTM	  = 1		;std 1: support int2f, ax=168a, "VIRTUAL SUPPORT"
?CATCHREBOOT  = 1		;std 1; catch ctrl-alt-delete

?SAVERMCR3	  = 0		;std 0: save/restore real mode CR3
?SAVERMIDTR   = 0		;std 0: save real mode idtr
?SAVERMGDTR   = 0		;std 0: save real mode gdtr
?CLRLDTR	  = 0		;std 0: clear LDTR before jump to real mode
?COPYFLRM2PM  = 1		;std 1: copy flags from real-mode after int xx call
?SIMHLT		  = 0		;std 0: 1=simulate HLT, do not execute
?ALLOWR0IRQ   = 0		;std 0: allow interrupts in ring 0
?RESIDENT	  = 1		;std 1: support -r switch
?LOCALINT2324 = 1		;std 1: init int 23/24 locally for each client
?SUPPDISABLE  = 1		;std 1: support -d and -e command line switches
?CR0_NE 	  = 1		;std 1: support -t and HDPMI=32768
?CR0_EM 	  = 0		;std 0: support -w ( clear EM bit on host init )
?CSIPFROMTOP  = 1		;std 1: get CS:E/IP from top of LPMS
?CLEARHWESPRM = 1		;std 1: clear highword(esp) in real mode
?VCPIPICTEST  = 1		;std 1: test if vcpi host did not remap PICs
?QEMMSUPPORT  = 1		;std 1: make HDPMI compatible with QEMM vcpi host
?CALLPREVHOST = 1		;std 1: route to a previously installed 16bit host
?GLOBALTLBUSAGE = 1		;std 1: share one TLB between HDPMI instances
?LOADHIGH     = 0		;std 0: move resident part into upper memory (not yet)
?LPMSCNT      = 0		;std 0: 0=LPMS counter is a flag only
?CLEARDR6     = 0		;std 0: 1=clear DR6 on client init
?LATELGDT     = 0		;std 0: 1=load GDTR *after* switch to protected-mode
?CLEARHIWORDS = 1		;std 1: 1=opt. clear hiword of esi,edi on init. entry
?TLBLATE      = 1		;std 1: 1=opt. alloc TLB when client starts (late)
?SAVEMSW      = 0		;std 0: 1=save/restore MSW on entry/exit
?SSED         = 0		;std 0: 1=host stack segment (GROUP16) is expand down
ifndef ?HSINEXTMEM
?HSINEXTMEM   = 0		;std 0: 1=host stack is in extended memory. this will
						;       make HIWORD(esp) != 0 for host stack, which
                        ;       is a problem for 16-bit client stacks due
                        ;       to a weak cpu design.
endif                        
?LPMSSIZE     = 1000h	;std 1000h: size of LPMS
?PATCHCODE    = 0		;std 0: 1=???
?DBGSUPP      = 1		;std 1: 1=set TF on client's switch to pmode
?EXC10FRAME   = 0		;std 0: 1=always set dpmi v1 exc frame if host
						;       is to be a v1 host (doesnt work yet)

if ?GUARDPAGE0
?CHECKIFINRMIVT = 0		;check if host owns the ivt IRQ vector
else
?CHECKIFINRMIVT = 1		;why
endif

?FIXTSSESP    = 0		;std 0: change SS:ESP in TSS for R0

if ?HSINEXTMEM
;?CHECKSSIS32 = 1		;test if client SS is 32bit
?FIXTSSESP	  = 1
endif

if ?MOVEIDT
  if ?HSINEXTMEM
?RING0STACK = 200h-4
  else
?RING0STACK = 440h-4	;alloc a smaller stack (IDT space will be reused)
  endif
else
?RING0STACK = 600h-4
endif
?TRAPI15E801	equ 1	;std 0: trap int 15h, ax=e801h in raw mode
						;this may be required if HDPMI=32 is set

?PREDEFIDTGATES equ 78h	;number of predefined IDT gates

;----------------------------------------------------------------

if ?32BIT

?RSIZE equ 4
@iret macro
	iretd
endm

@retf macro x
	retf  x
endm

else

?RSIZE equ 2
@iret macro
	iret
endm

@retf macro x
	db 66h
	retf x
endm

endif

;--- paging flags

PTF_PRESENT 	= 01h
PTF_WRITEABLE	= 02h
PTF_USER		= 04h
PTF_PWT 		= 08h
PTF_PCD 		= 10h
PTF_ACCESSED	= 20h
PTF_DIRTY		= 40h
PTF_NORMAL		= PTF_WRITEABLE + PTF_USER


;------------------------------- GDT selectors

externdef _CSSEL_:abs
externdef _SSSEL_:abs
externdef _TSSSEL_:abs
;externdef _STDSEL_:abs		;not used outside hdpmi.asm
externdef _FLATSEL_:abs
externdef _TLBSEL_:abs
externdef _INTSEL_:abs
externdef _CSR3SEL_:abs
externdef _DSR3SEL_:abs
externdef _SELLDT_:abs
externdef _LDTSEL_:abs
if ?SCRATCHSEL
externdef _SCRSEL_:abs
endif
if ?KDSUPP
externdef _GDTSEL_:abs
endif
externdef _STDSEL_:abs

if 1;?MOVEHIGH
externdef _CSALIAS_:abs
endif

if ?MOVEHIGHHLP
;externdef _CSGROUP16_:abs	;not used outside hdpmi.asm
endif

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

FM_TLBMCB	equ 1		;TLB is extra dos memory block
FM_RESIDENT	equ 2		;-r: HDPMI is resident
FM_RMVECS	equ 4		;real-mode irqs vectors are set
FM_DISABLED equ 8		;server disabled
if ?CANTEXIT
FM_CANTEXIT	equ 10h		;cannot exit (rm vecs not restorable)
endif
FM_CLONE    equ 20h		;this instance is a clone
FM_CPUID	equ 40h		;cpuid + cr4 is valid
FM_INIT 	equ 80h		;1=server initialized

;--- fMode2 flags

FM2_TLBLATE		equ 01h ;-b: alloc TLB late/free when idle
FM2_VCPI		equ 02h ;-v: prefer VCPI, ignore any XMS host
FM2_INT15XMS	equ 04h ;-y: use extended memory not managed by XMS
FM2_MEMBUFF		equ 08h ;-n: don't report true free phys pages
FM2_FORCETEXT	equ 10h ;-k: force text mode when displaying register dump
FM2_NOINVLPG	equ 20h ;don't use invlpg (80386 or option -g)
FM2_RESTRMEM	equ 40h ;restrict free memory reported to client to 256MB
ifdef _DEBUG
FM2_NOLOG		equ 80h ;suppress log file writing
endif

;--- flags in bEnvFlags (low byte of environment variable HDPMI)

ENVF_GUARDPAGE0	equ 01h	; guard page 0 (for DOS4G extender)
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
ENVF2_CLRHIWORD equ 08h ;  2048 clear hiword of esi/edi
ENVF2_SYSPROT	equ 10h ;  4096 alloc pages for GDT/IDT/LDT readonly
ENVF2_DEBUG  	equ 20h ;  8192 assume a (kernel) debugger is present
ENVF2_NOI2F160A	equ 40h	; 16384 don't respond to int 2fh, ax=160Ah
ENVF2_NOCR0NE  	equ 80h	; 32768 don't touch CR0 NE bit

;------------------------ flags in fDebug

FDEBUG_KDPRESENT	equ 1	;is kernel debugger present?
FDEBUG_OUTPFORKD	equ 2	;outputs to kernel debugger if present?

;------------------------ flags in fHost

FH_XMS		equ 1
FH_VCPI		equ 2
FH_RAW		equ 4
FH_DPMI		equ 8
FH_HDPMI    equ 40h		;there is another HDPMI host installed already
FH_XMS30	equ 80h

;------------------------ HDPMI exit codes

;	 00 - hdpmi installed in Int15/raw mode
;	 01 - hdpmi installed in XMS mode
;	 02 - hdpmi installed in VCPI mode
;	 03 - DPMI host found, no VCPI host found, hdpmi not installed
;	 04 - error: DOS memory low, cannot initialize
;	 05 - error: cannot enable A20 in raw mode 
;	 06 - error: VCPI host has remapped PICs
;	 07 - error: cpu in V86-mode, but no VCPI or DPMI host found
;	 08 - error: DOS Version not 4+
;	 09 - error: CPU not 80386+
;	 0A - error: invalid cmdline

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

;--- pseudo descriptor (for LGDT/SGDT/LIDT/SIDT)

PDESCR	struct
wLimit	dw ?
dwBase	dd ?
PDESCR	ends

;--- gates

;*** type (memory segments):
;*** bit 3 = 1 -> CODE,0 -> DATA
;*** bit 2 = 1 -> DATA:expand down,CODE:conforming
;*** bit 1 = 1 -> DATA:writable,CODE:readable
;*** bit 0 = 1 -> accessed

;*** 4G 16-Bit-Code-Segment -> <0ffffh,0,0,9fh,08fh,0>
;*** 4G 32-Bit-Code-Segment -> <0ffffh,0,0,9fh,0cfh,0>
;*** 4G 16-Bit-Data-Segment -> <0ffffh,0,0,93h,08fh,0>

;*** type (system segments (TSS) ***
;*** bit 3 = 1 -> 386
;*** bit 2 = 1 -> Gate
;*** bit 1 = 1 ->
;*** bit 0 = 1 ->
;     7/F -> trap gate
;     6/E -> Interrupt gate
;     4/C -> Call gate

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

;------------------------ client memory item structure

MEMITEM struct
pNext	dd  ?			; points to next element (must be first)
dwBase  dd  ?			; linear address
dwSize	dd  ?			; size (in pages)
flags	dw  ?			; flags (see HDLF_xxx)
owner	dw  ?			; owner (just no of current client)
MEMITEM ends

;------------------------ values of flags in HDLELM

HDLF_ALLOC  equ 01h     ; 0=block free, 1=block allocated
HDLF_COMMIT equ 02h     ; was originally allocated as committed block
HDLF_MAPPED equ 04h     ; is a mapped physical area

;--- CR0 flags

CR0_PE	equ 01h			;protected mode segmentation mechanism
CR0_MP	equ 02h			;math present
CR0_EM	equ 04h			;emulate FPU
CR0_TS	equ 08h			;task switch
CR0_NE	equ 20h			;numeric exception (exc 10h instead of int 75h)
CR0_PG	equ 80000000h   ;paging

;--- internal real-mode callbacks
;--- this table contains no client-specific data

INTRMCB struct			;size must be 16!
rm_vec	 dd ?			;current real mode vector (must be first!)
orgvec	 dd ?			;saved (original) real mode vector
myproc	 dw ?			;near16 offset host handler (curr IP value in ivt)
flags	 dw ?			;see RMVFL_xxx
pmvec	 dw ?			;near16 pointer to a R3PROC (current client vector)
wIvtOfs  dw ?			;offset IVT
INTRMCB ends

?RMCBMOUSE	equ 13h		;the int 33h mouse std rm callback index

;--- values of flags in INTRMCB.flags (global, not client specific)

RMVFL_IGN		equ 01h		;don't touch this INT's vector in IVT
RMVFL_IDT		equ 02h		;field pmvec point directly in IDT
RMVFL_FARPROC   equ 04h		;is a far proc, not an int
RMVFL_SETALWAYS equ 08h		;init RM vector for each client (int 23/24)

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
rmcs	df ?			;address of real mode call structure
if ?RMCBSTATICSS
wSS		dw ?
else
		dw ?
endif 
RMCB ends

;*** structure of protected mode segment save

PMSTATE struct
wPrevStack	dw ?	;previous value of host stack
PMSTATE ends

TASKSTATE struct

union
rDSES   dd ?		;+0
struct
rDS		dw ?		;+0
rES		dw ?		;+2
ends
ends
union
rFSGS   dd ?		;+4
struct
rFS		dw ?		;+4
rGS		dw ?		;+6
ends
ends
rESP	dd ?		;+8  client protected mode esp
rSS		dd ?		;+12 client protected mode ss
union
rmSSSP	dd ?		;+16
struct
rmSP	dw ?		;+16 real mode sp
rmSS	dw ?		;+18 real mode ss
ends
ends

TASKSTATE ends

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
;--- switch is done by a IRETD with VM bit set in EFlags

V86IRET struct
rEIP 	  dd ?		;1
rCS 	  dw ?		;2 cs v86 mode
		  dw ?		;3
rEFL	  dd ?		;4
rESP 	  dd ?		;5 value for (e)sp v86 mode
rSS 	  dw ?		;6 = GROUP16
		  dw ?
rES 	  dw ?      ;es V86 mode
		  dw ?
rDS 	  dw ?		;ds v86 mode
		  dw ?
rFS 	  dw ?		;fs v86 mode
		  dw ?
rGS 	  dw ?		;gs v86 mode
		  dw ?
V86IRET ends

;--- item of linked list of "real-mode" selectors (int 31h, ax=0002)

RMSEL struct
pNext dd ?		;next item
segm  dw ?		;segment value
limit dw ?		;limit
sel   dw ?		;selector
RMSEL ends

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

;--- IRET protected mode with SS:E/SP

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

R0FAULT16 struct

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

R0FAULT16 ends


R0FAULT struct
if ?32BIT
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
		R0FAULT16 <>

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
rErrx		dd ?	;+28h
rEIPx		dd ?	;+2Ch
rCSx		dw ?	;+30h
rInfoBits	dw ?	;+32h
rEFLx    	dd ?	;+34h
rESPx    	dd ?	;+38h
rSSx    	dd ?	;+3Ch
rESx    	dd ?	;+40h
rDSx    	dd ?	;+44h
rFSx    	dd ?	;+48h
rGSx    	dd ?	;+4Ch
rCR2    	dd ?	;+50h
rPTE    	dd ?	;+54h
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

@useext macro
	db 67h
endm

@movsd macro
ife ?32BIT
	@useext
endif
	movsd
endm

@stosw macro
ife ?32BIT
	@useext
endif
	stosw
endm

@stosb macro
ife ?32BIT
	@useext
endif
	stosb
endm

@lodsw macro
ife ?32BIT
	@useext
endif
	lodsw
endm

@lodsb macro
ife ?32BIT
	@useext
endif
	lodsb
endm

@inctrace equ <_LTRACE_ = _LTRACE_ + 1>
@dectrace equ <_LTRACE_ = _LTRACE_ - 1>

@ResetTrace macro
ifndef _DEBUG
_LTRACE_ = 0
endif
endm
        
@SetTrace macro
_LTRACE_ = 1
endm

@defseg macro name_, align_, use_, group_
name_ segment align_ use_ public 'CODE'
name_ ends
ifnb <group_>
group_ group name_
endif
endm

@seg macro segname
	ifidn <segname>,<_TEXT32>
	  @defseg segname, <dword>, <use32>, <GROUP32>
	elseifidn <segname>,<CDATA32>
	  @defseg segname, <dword>, <use32>, <GROUP32>
	elseifidn <segname>,<_ITEXT32>
	  @defseg segname, <dword>, <use32>, <GROUP32>
	elseifidn <segname>,<ENDTEXT32>
	  @defseg segname, <para>, <use32>, <GROUP32>
	elseifidn <segname>,<_DATA16>
	  @defseg segname, <dword>, <use16>, <GROUP16>
	elseifidn <segname>,<VDATA16>
	  @defseg segname, <dword>, <use16>, <GROUP16>
	elseifidn <segname>,<CDATA16>
	  @defseg segname, <dword>, <use16>, <GROUP16>
	elseifidn <segname>,<BEGTEXT16>
	  @defseg segname, <para>, <use16>, <GROUP16>
	elseifidn <segname>,<_TEXT16>
	  @defseg segname, <dword>, <use16>, <GROUP16>
	elseifidn <segname>,<_ITEXT16>
	  @defseg segname, <byte>, <use16>, <GROUP16>
	elseifidn <segname>,<ENDTEXT16>
	  @defseg segname, <para>, <use16>, <GROUP16>
	else
	  @defseg segname, <byte>, <use16>, <GROUP16>
	endif
endm

@checkssattr macro x,y
local xxxx
if ?32BIT
	ifnb <x>
		mov ax,x
	endif
		lar eax,eax
		bt eax,22
		jc xxxx
		movzx e&y,y
endif
xxxx:
endm

CStr macro xx:VARARG
local xxxx
CONST32 segment byte use32 public 'CODE'
xxxx db xx
	db 0
CONST32 ends
GROUP32 GROUP CONST32
	exitm <LOWWORD(offset xxxx)>
endm

@printf macro xx,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12
  ifnb <a12>
	echo too many parameters for @printf
	.err1
  endif
  ifnb <a11>
	push a11
  endif
  ifnb <a10>
	push a10
  endif
  ifnb <a9>
	push a9
  endif
  ifnb <a8>
	push a8
  endif
  ifnb <a7>
	push a7
  endif
  ifnb <a6>
	push a6
  endif
  ifnb <a5>
	push a5
  endif
  ifnb <a4>
	push a4
  endif
  ifnb <a3>
	push a3
  endif
  ifnb <a2>
	push a2
  endif
  ifnb <a1>
	push a1
  endif
	call _stroutx
	dw CStr(<xx>)
endm

@strout macro strg:REQ, xx:VARARG
if _LTRACE_
	@printf <strg>,xx
endif
endm

;--- formatted output in real-mode

@stroutrm macro xx,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12
local xxxx
if _LTRACE_
CONST16 segment byte use16 public 'CODE'
xxxx   db xx,0
CONST16 ends
GROUP16 group CONST16
  ifnb <a12>
	echo too many parameters for @stroutrm
	.err1
  endif
  ifnb <a11>
	push a11
  endif
  ifnb <a10>
	push a10
  endif
  ifnb <a9>
	push a9
  endif
  ifnb <a8>
	push a8
  endif
  ifnb <a7>
	push a7
  endif
  ifnb <a6>
	push a6
  endif
  ifnb <a5>
	push a5
  endif
  ifnb <a4>
	push a4
  endif
  ifnb <a3>
	push a3
  endif
  ifnb <a2>
	push a2
  endif
  ifnb <a1>
	push a1
  endif
	call _$stroutx
	dw offset xxxx
endif
endm

;--- call real-mode software int xx 
;--- esp -> IRET32
;--- (will return flags)

@callrmsint macro xx
	push xx
	jmp  dormsint
	align 4
endm

;--- call real-mode int xx 
;--- used internally

@simrmint macro xx
	push xx
	call dormintintern
endm

;--- call ring 3 protected-mode int xx
;--- usually this is done by the Int 30h dispatcher
;--- but some ints don't use Int 30h
;--- esp -> IRET32

@simintpms macro xx
	db 68h
	dd offset GROUP32:r3vect&xx
	jmp pms_call_int
	align 4
endm

;--- switch to LPMS, then call ring 3 protected mode int xx

@simintlpms macro xx
	db 68h
	dd offset GROUP32:r3vect&xx
	jmp lpms_call_int
	align 4
endm

;--- save current real-mode SS:SP
;--- so it can be saved on the host stack later.
;--- this is used by standard and client real-mode callbacks
;--- this macro should be followed by @pushstate in protected-mode

@savermstk macro
	push cs:tskstate.rmSSSP
	pop cs:dwrmSSSPtmp
	mov cs:tskstate.rmSP,sp
	mov cs:tskstate.rmSS,ss
endm

;--- restore value of real-mode stack
;--- this is done after a @popstate macro in protected-mode
;--- this is used by standard and client real-mode callbacks

@restorermstk macro
	lss sp, cs:tskstate.rmSSSP
	push cs:dwrmSSSPtmp
	pop cs:tskstate.rmSSSP
endm

;--- save client state on host stack
;--- this is used by standard and client real-mode callbacks

@pushstate macro bRMSegs
ifnb <bRMSegs>
	push ss:v86iret.rES
	push ss:v86iret.rDS
	push ss:v86iret.rFS
	push ss:v86iret.rGS
endif
	push ss:dwrmSSSPtmp
	push ss:tskstate.rSS
	push ss:tskstate.rESP
	push ss:tskstate.rFSGS
	push ss:tskstate.rDSES
if ?FIXTSSESP
	mov ss:dwHostStack, esp
else
	mov ss:taskseg._Esp0, esp
	lea esp, [esp - sizeof R3FAULT32]
	mov ss:dwHostStackExc, esp
	lea esp, [esp + sizeof R3FAULT32]
endif
endm

;--- restore client state from host stack
;--- this is used by standard and client real-mode callbacks

@popstate macro bRMSegs
	pop ss:tskstate.rDSES
	pop ss:tskstate.rFSGS
	pop ss:tskstate.rESP
	pop ss:tskstate.rSS
	pop ss:dwrmSSSPtmp
ifnb <bRMSegs>
	pop ss:v86iret.rGS
	pop ss:v86iret.rFS
	pop ss:v86iret.rDS
	pop ss:v86iret.rES
endif
if ?FIXTSSESP
	mov ss:[dwHostStack], esp
else
	mov ss:[taskseg._Esp0], esp
	lea esp, [esp - sizeof R3FAULT32]
	mov ss:[dwHostStackExc], esp
	lea esp, [esp + sizeof R3FAULT32]
endif
endm

;--- save protected-mode state in tskstate.
;--- this macro is used before a jump to real-mode
;--- 1. in raw mode switch to real-mode
;--- 2. in function _gotorm
;--- saves current protected-mode segment registers and ring 3 ss:esp
;--- assumes value in taskseg._Esp0 points BEHIND an IRET32 struct

@savepmstate macro
	mov ss:tskstate.rDS,ds
	mov ss:tskstate.rES,es
	mov ss:tskstate.rFS,fs
	mov ss:tskstate.rGS,gs
;--- get ring3 ESP & SS
	push ebp
	mov ebp, ss:taskseg._Esp0
	push [ebp - sizeof IRET32].IRET32.rSP
	mov ebp, dword ptr [ebp - sizeof IRET32].IRET32.rSS
	pop ss:tskstate.rESP
	mov ss:tskstate.rSS, ebp
	pop ebp
endm

;--- real-mode to protected-mode break
;--- this prevents debuggers from stepping in untraceable code

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
	test cs:fDebug,FDEBUG_KDPRESENT
	jz sm
	int 3
sm:
endif
endm

@waitesckey macro
local sm1
if _LTRACE_
	pushfd
	push eax
sm1:
	in al,64h		;key from keyboard arrived?
	test al,1
	jz sm1
	in al,60h
	cmp al,81h		;wait for ESC released
	jnz sm1
	pop eax
	popfd
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

;-- switches real-mode

@jmp_rm macro xx
	mov ss:[wRetAdrRm], xx
	jmp _gotorm
endm

@rawjmp_rm macro xx
	mov ss:[wRetAdrRm2], offset xx
	jmp _rawjmp_rm
endm

@exitserver_pm macro xx
;	push offset xx
	db 68h
	dd offset xx
	jmp _exitserver_pm
endm

;-- switches to protected-mode

@jmp_pm macro xx
	push word ptr LOWWORD(offset xx)
	jmp _gotopm
endm

@jmp_pmX macro xx
	push word ptr LOWWORD(offset xx)
	jmp _gotopmEx
endm

@rawjmp_pm macro xx, bSaveSegm
	push word ptr LOWWORD(offset xx)
ifb <bSaveSegm>        
	jmp _rawjmp_pm
else
	jmp _rawjmp_pm_savesegm	;save segment regs in v86iret before switch
endif
endm

;--- push offset of a real-mode proc (inside hdpmi) as dword

@pushproc macro procaddr
;; masm doesn't like "push dword ptr seg procaddr shl 16 + offset procaddr"
	db 68h
	dd offset procaddr
endm

@proto macro name, type
  ifb <type>
name proto near
  else
name proto type
  endif
endm

