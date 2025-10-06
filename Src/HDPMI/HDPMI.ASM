
;--- HDPMI's main source

;--- Warning: this source is old and sometimes incomprehensible.

;--- what's implemented here:
;--- real-mode initialization/termination
;--- client initialization/termination
;--- exception handlers
;--- stack switching
;--- internal real-mode callbacks (for IRQs, int 1C, 23, 24)
;--- global data
;--- default IDT
;--- host stack

	page ,132

	.486P

ifndef ?STUB
?STUB = 0
endif

if ?STUB
?STACKLAST = 1
else
?STACKLAST = 0		;std 0: 1=stack is last segment (behind GROUP32)
endif

?EMUHLTINR0	equ 0	;std 0: 1=emulate HLT in ring 0 instead of v86/real-mode
?AUTOSTI	equ 1	;std 1: 1=set client IF=1 for IOPL=0 variant upon return from IRQ

;--- GROUP16
@definegroup16 macro
BEGGRP16 segment para use16 public 'CODE'
BEGGRP16 ends
_DATA16 segment dword use16 public 'CODE'
_DATA16 ends
_DATA16V segment dword use16 public 'CODE'
_StartOfVMData label byte
_DATA16V ends
_DATA16C segment dword use16 public 'CODE'
_StartOfClientData label byte
_DATA16C ends
_TEXT16 segment dword use16 public 'CODE'
_EndOfClientData label byte
ifdef _DEBUG
externdef wCloneSize:word	; used in dprintf as forward ref ( problem with TYPE op )
endif
_TEXT16 ends
_TEXT16X segment dword use16 public 'CODE'
_TEXT16X ends
CONST16 segment byte use16 public 'CODE'
CONST16 ends
GDTSEG segment para use16 public 'CODE'
_Endof16bitres label byte
GDTSEG ends
IDTSEG segment para use16 public 'CODE'
;externdef startofidtseg:byte
;startofidtseg label byte
IDTSEG ends
_ITEXT16 segment byte use16 public 'CODE'
extern mystart:near					;use EXTERN to force include of mystart!
_ITEXT16 ends
ife ?STACKLAST
;STACK segment use16 stack 'CODE'	;with VALX+MS, the stack must be 'CODE'
STACK segment use16 stack 'STACK'	;WLink needs 'STACK' to find the stack seg
STACK ends
endif
ENDGRP16 segment para use16 public 'CODE'
endof16bit label byte
ENDGRP16 ends
endm

;--- GROUP32
@definegroup32 macro use_
_TEXT32  segment dword use_ public 'CODE'
_TEXT32  ends
CONST32  segment dword use_ public 'CODE'
CONST32  ends
ifdef ?PE
_DATA32C segment dword use_ public 'DATA'
else
_DATA32C segment dword use_ public 'CODE'
endif
	public startcldata32
startcldata32 label byte
_DATA32C ends

ifndef ?PE
_DATA32C$Z segment para use_ public 'CODE'
	public endcldata32
endcldata32 label byte
	public startof32bitr3
startof32bitr3 label byte
_DATA32C$Z ends
else
?SIZECLDATA32 equ 400h	;also defined in clients.asm
endif

ifdef ?PE
_TEXT32R3 segment dword use_ public
;	public startof32bitr3
;startof32bitr3 label byte
_TEXT32R3 ends
else
_TEXT32R3 segment dword use_ public 'CODE'
_TEXT32R3 ends
endif

_ITEXT32  segment dword use_ public 'CODE'
ifndef ?PE
endoftext32 label near
endif
_ITEXT32  ends
ifndef ?PE
ENDGRP32  segment para  use_ public 'CODE'
endof32bit label near
ENDGRP32  ends
endif
endm

ifdef ?PE
	@definegroup32 flat
	@definegroup16
else
	@definegroup16
	@definegroup32 use32
endif

GROUP16  group BEGGRP16, _DATA16, _DATA16V, _DATA16C, _TEXT16, _TEXT16X, CONST16, GDTSEG, IDTSEG, _ITEXT16, ENDGRP16
;ife ?STACKLAST
;GROUP16 group STACK
;endif
;--- _TEXT32R3 must NOT be in GROUP32
ifndef ?PE
GROUP32 group _TEXT32, CONST32, _DATA32C, _DATA32C$Z, _ITEXT32, ENDGRP32
endif

	include hdpmi.inc
	include external.inc
	include keyboard.inc
	include debugsys.inc

	option proc:private

;--- configuration constants

_CY equ 1	;carry flag in LOBYTE(flags)
_TF	equ 1	;trace flag in HIBYTE(flags)
_IF	equ 2	;interrupt flag in HIBYTE(flags)	
_NT	equ 40h	;NT flag in HIBYTE(flags)

JHD_CONNECT    equ 1
JHD_DISCONNECT equ 2
JHD_HOOKIRQ    equ 3
JHD_UNHOOKIRQ  equ 4

;------------ macros --------------

;--- get IVT vector (ebx is modified inside this macro!)
;--- but do not modify flags!

@getIVTvector macro saveflags
if 0
	push ds
	push byte ptr _FLATSEL_
	pop ds
	mov ebx, ds:[ebx*4]
	pop ds
else
 if saveflags
	pushfd
 endif
	shl ebx, 2
	sub ebx, ss:[dwSSBase]
 if saveflags
	popfd
 endif
	mov ebx, ss:[ebx]
endif
endm

;--- jump to default exception handler (exc2int) for exceptions 00-05 + 07
;--- these exceptions are then routed to protected-mode INT xx

@mapexc2int macro xx
defexc&xx&::
	push xx&h
	jmp exc2int
	align 4
endm

;--- if exception 00-05 + 07 is *not* to be routed to real-mode
;--- use this macro:
;--- call host default exception handler from an int handler 
;--- DPMI CS:(E)IP and errorcode are NOT on the stack, so
;--- this has to be emulated

@termint macro xx,yy
ifnb <yy>
yy&xx:
else
defint&xx:
endif
	push 0		;DWORD error code
	push xx&h
	jmp _exceptY
	align 4
endm

;--- @testexception MACRO must be placed BEFORE @simintlpms macro
;--- it's used for INT 08, 0A, 0B, 0C, 0D, 0E, 11 to determine if it
;--- is an exception or an IRQ/programmed INT

@testexception macro exclbl, r0exclbl
	cmp [esp].R0FAULT.rCS,_CSSEL_	;exception in r0?
ifnb <r0exclbl>
	jz r0exclbl
else
	jz exclbl
endif
if ?KDSUPP or ?ALLOWR0IRQ
	push eax
	lea eax, [esp+R3FAULT32+4]
	cmp eax, ss:[dwHostStack]
	pop eax
else
	lea esp, [esp+sizeof R3FAULT32]	; this code also works as a debug protection
	cmp esp, ss:dwHostStack		;exception in r3?
	lea esp, [esp-sizeof R3FAULT32]
endif
;	jbe exclbl	;v3.18: changed, to allow IRQ in r0
	je exclbl
endm

;--- jump to exception handler lpms_call_exc, which does:
;--- + switch to LPMS if not used
;--- + create a stack frame to switch stack back
;--- + jmp to the clients registered exception handler
;---   (or just jump to the default exception handler)

@exception macro excno, bErrorCode, bDisplay
ifnb <bDisplay>
	push ebp
	mov ebp,esp
	@dprintf "entry exception %X, cs:eip=%X:%lX", word ptr excno ,word ptr [ebp+4].IRET32.rCS, [ebp+4].IRET32.rIP
	pop ebp
endif
ifb <bErrorCode>	;correct missing error code
	push 0		;push a DWORD
endif
	push excno&h
	jmp lpms_call_exc
	align 4
endm

;--- call host's default exception handler
;--- esp+0 -> DPMIEXC
;--- used by exc 00, 06, 08-0E, 10

@defaultexc macro xx,yy,zz
ifb <zz>
defexc&xx&::
endif
if 0
 if ?KDSUPP
  ifnb <yy>
	push offset exc&xx&str
	call calldebugger
  endif
 endif
endif
	push xx&h
	jmp _exceptX
	align 4
endm

;--- testint may be used to determine if
;--- a programmed INT opcode or an exception caused
;--- the call. MUST be placed before @exception macro
;--- used by 06, 09 (80386 only), 10

@testint macro intno, label1
local label2, bint
%bint = intno&h
	push ds
	push esi
	lds esi, [esp+8].IRET32.rCSIP
	cmp esi,2
	jb label2
	cmp word ptr [esi-2], bint * 100h + 0CDh
label2:
	pop esi
	pop ds
	jnz label1
endm

;--- used for ints 00-07: route int to real-mode
;--- only if ?MAPINTxx is 1 (default is 0)
;--- esp -> IRET32

@callrmint macro xx, yy
ifnb <yy>
yy&xx:
else
defint&xx:
endif
	push xx&h
	jmp dormint
	align 4
endm

;--- call a real-mode far proc with IRET frame
;--- used to route the std real-mode callback INTs to real-mode

@callrmirq macro xx
defint&xx&:
if xx&h lt 10h
	push xx&h-8
elseif xx&h ge 70h
	push xx&h-68h
elseif xx&h eq 1Ch
	push 16
else
	.err <invalid usage of macro @callrmirq>
endif
	jmp callrmproc_iretframe
	align 4
endm

@checkssattr macro x,y
local xxxx
if ?CHECKSSIS32
ifnb <x>
	mov eax,x
endif
	lar eax,eax
	bt eax,22
	jc xxxx
	movzx e&y,y
xxxx:
endif
endm

;--- switch to LPMS, then call ring 3 protected mode int xx
;--- this macro is used for IRQs only

@simintlpms macro xx
	pushd offset r3vect&xx
	jmp lpms_call_int
	align 4
endm

;------------ begin code/data --------------

BEGGRP16 segment

logo label byte
if ?STUB
	jmp mystart
else
	db "HDP"
endif
	db "MI", ?VERMAJOR, ?VERMINOR
llogo	equ $ - logo
	db ?32BIT

;--- variables that may be accessed by other host instances

dwSegTLB label dword		;segment translation buffer
wSegTLB	dw 0				;defined here so this variable can be
		dw 0				;accessed by another host instance
cApps	db 0				;number of clients
fMode	db 0				;flags (FM_xxx)
fMode2	db 0				;more flags (FM2_xxx)

;--- IDT (vectors 00-7F only)
;--- the IDT usually is moved to extended memory
;--- then the space here may be used for the host stack

	align 8

ife ?HSINEXTMEM
stacktop label byte
endif

if ?MOVEGDT
if ?HSINEXTMEM
IDTSEG segment
endif
endif

?IVAL	equ (_IGATE32_ + ?PLVL) shl 8
?TVAL	equ (_TGATE_ + ?PLVL) shl 8

if ?ALLOWR0IRQ
?XVAL	equ ?TVAL
else
?XVAL	equ ?IVAL
endif

;--- HIGHWORD offset label32 not accepted by Masm/JWasm
HIBASE macro intno
ifdef ?PE
	exitm <HIGHWORD offset intr&intno>
else
	exitm <0>
endif
endm

@GATE macro intno, gatetype:=<?IVAL>
if 0;def ?PE
	dd offset intr&intno
	dw gatetype
	dw _CSSEL_
else
	GATE <lowword offset intr&intno, _CSSEL_, gatetype, 0>
endif
endm

;--- this is the predefined IDT, which contains 78h gates (Int 00h-77h)

curIDT label GATE
  @GATE 00	;divide error
  @GATE 01	;debug exception
  @GATE 02	;NMI
  @GATE 03	;int 3
  @GATE 04	;INTO
  @GATE 05	;print screen/bounds check
  @GATE 06	;invalid opcode
  @GATE 07	;DNA/80x87 not available

  @GATE 08	;timer/double fault
  @GATE 09	;keyboard/FPU operand
  @GATE 0A	;cascade/tss invalid
  @GATE 0B	;com2/segment fault
  @GATE 0C	;com1/stack fault
  @GATE 0D	;lpt2/GPF
  @GATE 0E	;floppy disk/page error
  @GATE 0F	;lpt1/reserved

if ?INT10SUPP
  @GATE 10
else
  GATE <10h*2		,_INTSEL_,?TVAL, 0>
endif
if ?INT11SUPP
  @GATE 11
else
  GATE <11h*2		,_INTSEL_,?TVAL, 0>
endif  
  GATE <12h*2		,_INTSEL_,?TVAL, 0>
  GATE <_INT13_ 	,_INTSEL_,?TVAL, 0>
  GATE <14h*2		,_INTSEL_,?TVAL, 0>
  GATE <_INT15_ 	,_INTSEL_,?TVAL, 0>
  GATE <16h*2		,_INTSEL_,?TVAL, 0>
  GATE <17h*2		,_INTSEL_,?TVAL, 0>

  GATE <18h*2		,_INTSEL_,?TVAL, 0>
  GATE <19h*2		,_INTSEL_,?TVAL, 0>
  GATE <1Ah*2		,_INTSEL_,?TVAL, 0>
  GATE <1Bh*2		,_INTSEL_,?TVAL, 0>
  GATE <_INT1C_ 	,_INTSEL_,?TVAL, 0>
  GATE <1Dh*2		,_INTSEL_,?TVAL, 0>
if ?INT1D1E1F
  GATE <1Eh*2		,_INTSEL_,?TVAL, 0>
else
  GATE <0			,_I1ESEL_,?TVAL, 0>
endif
  GATE <1Fh*2		,_INTSEL_,?TVAL, 0>

if ?ENHANCED
  @GATE 20
else
  GATE <20h*2		,_INTSEL_,?TVAL, 0>
endif
if ?FASTINT21
  @GATE 21
else
  GATE <_INT21_ 	,_INTSEL_,?TVAL, 0>
endif  
if ?WINDBG
  @GATE 22
else
  GATE <22h*2		,_INTSEL_,?TVAL, 0>
endif
  GATE <23h*2		,_INTSEL_,?TVAL, 0>
  GATE <24h*2		,_INTSEL_,?TVAL, 0>
  GATE <_INT25_ 	,_INTSEL_,?TVAL, 0>
  GATE <_INT26_ 	,_INTSEL_,?TVAL, 0>
  GATE <27h*2		,_INTSEL_,?TVAL, 0>

  GATE <28h*2		,_INTSEL_,?TVAL, 0>
  GATE <29h*2		,_INTSEL_,?TVAL, 0>
  GATE <2Ah*2		,_INTSEL_,?TVAL, 0>
  GATE <2Bh*2		,_INTSEL_,?TVAL, 0>
  GATE <2Ch*2		,_INTSEL_,?TVAL, 0>
  GATE <2Dh*2		,_INTSEL_,?TVAL, 0>
  GATE <2Eh*2		,_INTSEL_,?TVAL, 0>
  GATE <_INT2F_ 	,_INTSEL_,?TVAL, 0>

  @GATE 30, ?XVAL
if ?FASTINT31
  @GATE 31
else
  GATE <_INT31_ 	,_INTSEL_,?TVAL, 0>
endif  
  GATE <32h*2		,_INTSEL_,?TVAL, 0>
  GATE <_INT33_ 	,_INTSEL_,?TVAL, 0>
  GATE <34h*2		,_INTSEL_,?TVAL, 0>
  GATE <35h*2		,_INTSEL_,?TVAL, 0>
  GATE <36h*2		,_INTSEL_,?TVAL, 0>
  GATE <37h*2		,_INTSEL_,?TVAL, 0>

  GATE <38h*2		,_INTSEL_,?TVAL, 0>
  GATE <39h*2		,_INTSEL_,?TVAL, 0>
  GATE <3Ah*2		,_INTSEL_,?TVAL, 0>
  GATE <3Bh*2		,_INTSEL_,?TVAL, 0>
  GATE <3Ch*2		,_INTSEL_,?TVAL, 0>
  GATE <3Dh*2		,_INTSEL_,?TVAL, 0>
  GATE <3Eh*2		,_INTSEL_,?TVAL, 0>
  GATE <3Fh*2		,_INTSEL_,?TVAL, 0>

  GATE <40h*2		,_INTSEL_,?TVAL, 0>
  @GATE 41
  GATE <42h*2		,_INTSEL_,?TVAL, 0>
  GATE <43h*2		,_INTSEL_,?TVAL, 0>
  GATE <44h*2		,_INTSEL_,?TVAL, 0>
  GATE <45h*2		,_INTSEL_,?TVAL, 0>
  GATE <46h*2		,_INTSEL_,?TVAL, 0>
  GATE <47h*2		,_INTSEL_,?TVAL, 0>

  GATE <48h*2		,_INTSEL_,?TVAL, 0>
  GATE <49h*2		,_INTSEL_,?TVAL, 0>
  GATE <4Ah*2		,_INTSEL_,?TVAL, 0>
  GATE <_INT4B_ 	,_INTSEL_,?TVAL, 0>
  GATE <4Ch*2		,_INTSEL_,?TVAL, 0>
  GATE <4Dh*2		,_INTSEL_,?TVAL, 0>
  GATE <4Eh*2		,_INTSEL_,?TVAL, 0>
  GATE <4Fh*2		,_INTSEL_,?TVAL, 0>

?int	= 50h
  rept 20h
  GATE <?int*2		  ,_INTSEL_,?TVAL, 0>
?int	= ?int + 1
  endm

  @GATE 70
  @GATE 71
  @GATE 72
  @GATE 73
  @GATE 74
  @GATE 75
  @GATE 76
  @GATE 77

	.errnz ($ - offset curIDT) - (?PREDEFIDTGATES shl 3)

ife ?MOVEIDT

;--- if the IDT is not moved in extended memory,
;--- define the rest of the gates here.

?int = ?PREDEFIDTGATES
  rept 100h - ?PREDEFIDTGATES
  GATE <?int*2		,_INTSEL_,?TVAL, 0>
?int = ?int + 1
  endm

endif

if ?MOVEGDT
if ?HSINEXTMEM
IDTSEG ends
endif
endif

;-------------- ring 0 stack ---------------------
;--- this shouldn't be moved, since the space for IDT
;--- will be reused for the stack

ife ?HSINEXTMEM
  if ?MOVEIDT
	?R0STACKSIZE = 440h-4	;alloc a smaller stack (IDT space will be reused)
  else
	?R0STACKSIZE = 600h-4
  endif
	db ?R0STACKSIZE dup (?)
ring0stack label byte
endif

;--- task state segment (TSS)
;--- hdpmi will not use the x86 task switching
;--- but one is needed for switching from ring 3 to ring 0

	align 8

taskseg TSSSEG <0, 0, _SSSEL_>

;*** global descriptor table

if ?MOVEGDT
GDTSEG segment
endif

	align 8

@defdesc macro content, value, ring
ifnb <value>
ifnb <ring>
value	equ $ - offset curGDT + ring
else
value	equ $ - offset curGDT
endif
endif
	DESCRPTR {content}
endm

;--- GDT - since version 3.02 the GDT is moved to extended memory
;--- but optionally ( set HDPMI=512 ) it may stay in conv. memory.

curGDT label DESCRPTR
	@defdesc <0,0,0,0,0,0>						;00 null descriptor

;--- 3 descriptors reserved for VCPI (8,10,18)
;--- leave them here at the very start of GDT (SBEINIT)

vcpidesc label DESCRPTR    
	@defdesc <0,0,0,0,0,0>,_VCPICS_
	@defdesc <0,0,0,0,0,0>
	@defdesc <0,0,0,0,0,0>

	@defdesc <-1,0,0,9Ah,40h,0>,_CSSEL_			;20 CS (=GROUP32)
if ?SSED
	@defdesc <7,0,0,96h,40h,0>,_SSSEL_			;28 SS (=GROUP16)
else
  if ?HSINEXTMEM
	@defdesc <-1,0,0,92h,0CFh,0>,_SSSEL_
  else
	@defdesc <-2,0,0,92h,0CFh,0>,_SSSEL_
  endif
endif    
tssdesc label DESCRPTR
	@defdesc <0067h,0,0,89h,0,0>,_TSSSEL_		;30 available 386 TSS
	@defdesc <0,0,0,82h,0,0>,_LDTSEL_			;38 LDT

;--- 40+3 BIOS Data (fix)

	@defdesc <02ffh,0400h,0,92h or ?PLVL,0,0>

;--- 48 FLAT data selector

;	@defdesc <-1,0,0,92h or ?PLVL,0CFh,0>,_FLATSEL_, ?RING
	@defdesc <-1,0,0,92h,0CFh,0>,_FLATSEL_

;--- 50+3 selector describing TLB

if ?TLBLATE
?TLBSELATTR equ 0	;make TLB readonly until we have a valid one
else
?TLBSELATTR equ 2
endif
	@defdesc <?TLBSIZE-1,0,0Fh,90h or ?TLBSELATTR,0,0>,_TLBSEL_

;--- 58+3 protected mode breakpoints

pmbrdesc label DESCRPTR    
	@defdesc <_MAXCB_*2-1,0,0,9Ah or ?PLVL,0,0>,_INTSEL_, ?RING

;--- 60 LDT data selector

	@defdesc <0FFFh,0,0,92h or ?PLVL,0,0>,_SELLDT_, ?RING

;--- 68 ring 0 data alias for GROUP32
;--- _CSALIAS_, _CSR3SEL_ and _DSR3SEL_ must be consecutive!

	@defdesc <-1,0,0,92h,40h,0>,_CSALIAS_

ifdef ?PE
;--- 70+3 ring3 cs
;--- 78+3 ring3 csalias
	@defdesc <-1,0,0,9Ah or ?PLVL,40h,0>,_CSR3SEL_, ?RING
	@defdesc <-1,0,0,92h or ?PLVL,00h,0>,_DSR3SEL_, ?RING
else
;--- 70+3 ring 3 _TEXT32R3 code selector
;--- 78+3 ring 3 _TEXT32R3 data selector
	@defdesc <3ffh,0,0,9Ah or ?PLVL,40h,0>,_CSR3SEL_, ?RING
	@defdesc <3ffh,0,0,92h or ?PLVL,00h,0>,_DSR3SEL_, ?RING
endif

;--- alias for GROUP16 (code)
;--- needed to disable paging in xms and raw mode (which
;--- can't be done when CS=GROUP32).

if ?MOVEHIGHHLP
	@defdesc <-1,0,0,9Ah,0,0>,_CSGROUP16_
endif

;--- std 64 kB data selector to initialize segments (used in switch.asm)

	@defdesc <-1,0,0,92h,0,0>,_STDSEL_

;--- LPMS selector (if not in LDT)

if ?LPMSINGDT
  if ?32BIT
	@defdesc <0FFFh,0,0,92h or ?PLVL,040h,0>,_LPMSSEL_, ?RING
  else
	@defdesc <0FFFh,0,0,92h or ?PLVL,0,0>,_LPMSSEL_, ?RING
  endif
endif

if ?INT1D1E1F eq 0
	@defdesc <00FFh,0,0,92h or ?PLVL,0,0>,_I1ESEL_, ?RING		;int 1E
endif

;--- Scratch selector

if ?SCRATCHSEL
	@defdesc <0,0,0,0,0,0>,_SCRSEL_, ?RING
endif

;--- LDT data selector r/o

if ?LDTROSEL
	@defdesc <0FFFh,0,0,90h or ?PLVL,0,0>,_SELLDTSAFE_, ?RING
endif

;--- selectors for kernel debugger wdeb386/386swat

if ?KDSUPP
  if ?RING0FLATCS
	@defdesc <-1,0,0,9Ah,0CFh,0>				;flat ring 0 CS descriptor
  endif
	@defdesc <?GDTLIMIT,offset curGDT,0,92h,0,0>,_GDTSEL_
	@defdesc <0,0,0,0,0,0>,_KDSEL_
  if ?386SWAT
	rept 29   ;386swat requires max 30 free entries
	@defdesc <0,0,0,0,0,0>						;reserved
	endm
  else
	rept 3
	@defdesc <0,0,0,0,0,0>						;reserved
	endm
  endif
endif

?SIZEGDT equ $ - curGDT
?GDTLIMIT equ ?SIZEGDT - 1

if ?MOVEGDT
;endofgdtseg label byte
endofgdtseg equ $+15	; offset is used as "segment offset" (shr 4), so ensure its big enough
GDTSEG ends
endif

CONST32 segment

;--- int 30h Dispatch table (constant) ---
;--- defines INT 30h at offset >= 200h in the PM break segment

;--- the INT 30h handler will check if client-IP is >= 200h,
;--- if no, it will call real-mode INT (IP/2)
;--- if yes, if will call the address defined here in spectab

@defx macro  x,y
ifnb <y>
y	equ ($ - offset spectab) / 2 + 200h
endif
	dd offset x
endm

;	align 4	;not required, this table is at segment start

spectab label dword
	@defx defexc00, _EXC00_
	@defx defexc01, _EXC01_
	@defx defexc02, _EXC02_
	@defx defexc03, _EXC03_
	@defx defexc04, _EXC04_
	@defx defexc05, _EXC05_
	@defx defexc06, _EXC06_
	@defx defexc07, _EXC07_
	@defx defexc08, _EXC08_
	@defx defexc09, _EXC09_
	@defx defexc0A, _EXC0A_
	@defx defexc0B, _EXC0B_
	@defx defexc0C, _EXC0C_
	@defx defexc0D, _EXC0D_
	@defx defexc0E, _EXC0E_
	@defx defexcxx, _EXC0F_
if ?INT10SUPP
	@defx defexc10, _EXC10_
else
	@defx defexcxx, _EXC10_
endif
if ?INT11SUPP
	@defx defexc11, _EXC11_
else
	@defx defexcxx, _EXC11_
endif
	@defx defexcxx, _EXC12_
	@defx defexcxx, _EXC13_
	@defx defexcxx, _EXC14_
	@defx defexcxx, _EXC15_
	@defx defexcxx, _EXC16_
	@defx defexcxx, _EXC17_
	@defx defexcxx, _EXC18_
	@defx defexcxx, _EXC19_
	@defx defexcxx, _EXC1A_
	@defx defexcxx, _EXC1B_
	@defx defexcxx, _EXC1C_
	@defx defexcxx, _EXC1D_
	@defx defexcxx, _EXC1E_
	@defx defexcxx, _EXC1F_

	@defx defint00, _INT00_
	@defx defint01, _INT01_
	@defx defint02, _INT02_
	@defx defint03, _INT03_
	@defx defint04, _INT04_
	@defx defint05, _INT05_
	@defx defint06, _INT06_
	@defx defint07, _INT07_
	@defx defint08, _INT08_
	@defx defint09, _INT09_
	@defx defint0A, _INT0A_
	@defx defint0B, _INT0B_
	@defx defint0C, _INT0C_
	@defx defint0D, _INT0D_
	@defx defint0E, _INT0E_
	@defx defint0F, _INT0F_

	@defx defint70, _INT70_
	@defx defint71, _INT71_
	@defx defint72, _INT72_
	@defx defint73, _INT73_
	@defx defint74, _INT74_
	@defx defint75, _INT75_
	@defx defint76, _INT76_
	@defx defint77, _INT77_

  if ?FASTINT21
	@defx intr21_,  _INT21_
  else
	@defx intr21,   _INT21_
  endif
	@defx intr23,   _INT23_
	@defx intr24,   _INT24_
	@defx intr2F,   _INT2F_
if ?FASTINT31
	@defx intr31_,  _INT31_
else
	@defx intr31,   _INT31_
endif
	@defx intr33,   _INT33_
	@defx intr41_,  _INT41_
	@defx intr15,   _INT15_
	@defx intr4B,   _INT4B_
	@defx intr25,   _INT25_
	@defx intr26,   _INT26_
	@defx intr13,   _INT13_
	@defx defint1C, _INT1C_
if ?INT10SUPP
	@defx intr10_,  _INT10_		;int 10h is translated!
else
	_INT10_ equ 2 * 10H
endif
	@defx intr30,   _INT30_		;intr30 indirect
	@defx rpmstacke,_RTEXC_		;switch from LPMS to PMS after EXC
	@defx rpmstacke_nosw,_RTEXC2_	;switch after EXC, LPMS still in use
;	@defx _meventp, _MEVENT_	;mouse event proc (ring 0)
;--- here start PMBREAKs with retf frame
_RETF_ equ ($ - offset spectab) / 2 + 200h
	@defx _srtask, _SRTSK_		;save/restore task state (call)
if ?INT21API
	@defx _I2f168A_Msdos, _I2F168A_MSDOS	;"MS-DOS" DPMI extensions entry (retf)
endif
if ?VENDORAPI
	@defx _I2f168A_Hdpmi, _I2F168A_HDPMI	;"HDPMI" DPMI extensions entry (retf)
endif
if ?ENHANCED
?DEFINEVXDBP equ <>
	include vxd.inc
endif
;--- here start PMBREAKs with no frame
_JMPF_ equ ($ - offset spectab) / 2 + 200h
	@defx rpmstacki,_RTINT_		;switch from LPMS to PMS after IRQ
	@defx rpmstackr,_FRTIN_		;return from internal RMCBs, flags unchanged
	@defx rpmstackr2,_FRTIN2_	;return from internal RMCBs, std flags changed
	@defx _retcb,  _RETCB_		;return from client RMCBs
	@defx _pm2rm,  _RMSWT_		;raw mode switch pm -> rm (call)
if ?ALLOWR0IRQ or ?EMUHLTINR0
	@defx _retirqr0,_RTINTR0_	;return from IRQ in ring 0
endif
if ?EXCRESTART
	@defx retexcr0,_RTEXCR0_	;return from exc in ring 0
endif

_MAXCB_ equ ($ - offset spectab) / 4 + 100h

CONST32 ends

;--- break table for ring switches
;--- usually this table is generated during startup in extended memory

ife ?DYNBREAKTAB
inttable dw _MAXCB_ dup (30CDh)
endif

BEGGRP16 ends

_DATA16 segment

;--- the _DATA16 segment should not contain data which is client-specific
;--- for this segment _DATA16C is to be used

;--- VCPI jump to v86 mode (DE0Ch) expects SS:ESP pointing to a V86IRET
;--- structure (which must be located in 1. MB)
;--- EIP,CS,EFL,ESP,SS,ES,DS,FS,GS (all dwords)

		dq 0,0			;16 bytes stack space below v86iret for VCPI-Host
ifdef ?QEMMSUPPORT
		dq 0			;QEMM requires 8 bytes more
endif
		dq 0			;space for VCPI, since it is called with CALL FAR
v86iret		V86IRET <<offset rawjmp_rm_all>>

;--- v3.20: pmstate moved to client-specific region
;--- if pmstate doesn't follow v86iret, ?NOPMSTATECONSEC=1 in i31swt.asm.srtask must be set
;pmstate	PMSTATE <>	; protected mode segment register values

;dwHostStack	dd 0

pdGDT	PDESCR <?GDTLIMIT,0>	;pseudo descriptor GDT
	align 4

if 0
pdIDT	PDESCR <7FFh,0>			;pseudo descriptor IDT protected mode
else
pdIDT	PDESCR <?PREDEFIDTGATES*8-1,0>			;pseudo descriptor IDT protected mode
endif
selLDT	dw _SELLDT_				;Selector LDT alias (fix)
	align 4
;nullidt PDESCR <3FFh,0>		;pseudo descriptor IDT real mode
;	align 4

rawjmp_rm_vector dd offset rawjmp_rm_novcpi

;--- used for VCPI function DE0C (switch rm to pm)
;--- CR3, address pd GDTR, address pd IDTR, LDTR, TR, EIP, CS
v86topm VCPIRM2PM <0,0,0,_LDTSEL_,_TSSSEL_, offset vcpi_pmentry, _CSSEL_>

wVersion	dw 005ah	;DPMI version 0.90
	align 4

vcpicall label PF32 	;VCPI far32 address to switch to v86-mode
vcpiOfs		dd 0		;offset (got from VCPI host)
vcpiSeg		dw _VCPICS_ ;selector for VCPI code segment

wHostPSP	dw 0        ;PSP segment of host
v86iretesp	dd offset v86iret

	align 4

dwLDTAddr	dd 0				;linear address LDT (set on init)
if ?DYNTLBALLOC
dwLoL		dd 0				;linear address DOS LoL
endif
dwSDA		dd 0				;linear address SDA
if ?SAVERMCR3
dwOldCR3	dd 0				;CR3 in real mode
endif
if ?CALLPREVHOST
dwHost16	PF16 0				;previous DPMI host entry
endif
xmsaddr		PF16 0				;XMS driver entry
dwSSBase	dd 0				;linear address base of SS in protected-mode (=GROUP16)
dwFeatures	dd 0				;features from CPUID
if ?DTAINHOSTPSP
dwHostDTA	dd 0
else
dwDTA		dd 0
endif
ifdef ?PE
dwVSize		dd 0
endif

if ?SAVERMGDTR
rmgdt		df 0				;GDT pseudo descriptor for real mode
endif
if ?SAVEMSW
wMSW		dw 0				;real-mode MSW on entry
endif

if ?INTRM2PM
dwOldVec96	dd 0
endif
if ?TOPMEM
dwTopMem	dd 0				;value returned in ECX by XMS call ah=88h
endif
wHostSeg	dw 0				;segment host (GROUP16)

_cpu		db 0				;CPU (3=386,4=486, ...)
bExcEntry	db -1				;entries default exception handler
bNoRMCBEntry db 0				;1=don't reenter host thru RMCBs

fHost		db 0				;1=xms,2=vcpi,4=raw,8=dpmi,...
fXMSQuery	db 8				;default function code for XMS query
fXMSAlloc	db 9				;default function code for XMS alloc
if 0 ;0 since v3.19
bFPUAnd		db not (CR0_EM or CR0_TS or CR0_NE)
bFPUOr		db CR0_NE
else
bFPUAnd		db not (CR0_EM or CR0_TS)
bFPUOr		db 0
endif
if ?RESTRICTMEM
resshift	db 0				;shift right factor for -x option
endif

if ?KDSUPP
fDebug	  db 0					;kernel debugger present?
bTrap	  db 0
dbgpminit df 0
endif
if ?LOGINT30
lint30	  dw 0
endif
wEMShandle dw 0
ifdef _DEBUG
;traceflgs  dw ?LOG_PMGREXT or ?LOG_INT30 or ?LOG_INTRMCB or ?LOG_INT31GEN or ?LOG_RMCALL
traceflgs  dw 0
bStdout db 80h
endif

;--- table of real-mode IVT vectors to intercept

@jmpoldvec macro intno
	db 0EAh
dwOldVec&intno dd 0
endm

ivthooktab label byte
if ?TRAPINT06RM
int06hk IVTHOOK <06h, offset dwOldVec06, offset int06rm>
endif
if ?TRAPINT21RM
int21hk IVTHOOK <21h, offset dwOldVec21, offset int21rm>
endif
int2Fhk IVTHOOK <2Fh, offset dwOldVec2F, offset int2Frm>
if ?INTRM2PM
int96hk IVTHOOK <?XRM2PM, offset dwOldVec96, offset intrm2pm>
endif
;------------------------------- int 15 should be last 
if ?WATCHDOG or ?CATCHREBOOT
int15hk IVTHOOK <15h, offset dwOldVec15, offset int15rm>;watch int 15 in any case
else
int15hk IVTHOOK < -1, offset dwOldVec15, offset int15rm>;watch int 15 conditionally in raw mode
endif
	db -1

	align 4

_DATA16V segment
dwTSSdesc	dd offset tssdesc	;normalized address TSS descriptor in GDT
pRMSel		dd 0				;normalized start "conv. memory selector" list (int 31h, ax=2)
_DATA16V ends

;*** temporary variables
        
calladdr1	dd 0		;used to store a IVT vector value
calladdr2	dd 0		;used to store a IVT vector value
wRmDest		label word	;real-mode destination offset, used by _jmp_rm & _rawjmp_rm
dwPmDest	dd 0		;protected-mode destination offset, used by _jmp_pm
dwPmDest2	dd 0		;protected-mode destination offset, used by _rawjmp_pm
tmpFLReg	label word	;temporary storage for FL register
tmpFLRegD	dd 0
dwInitSSSP	label dword
wInitSP		dw 0		;sp real mode on client init
wInitSS		dw 0		;ss real mode on client init
dwrmSSSPtmp	label dword
wrmSPtmp	dw 0		;temp store for rmSP on protected-mode reentry
wrmSStmp	dw 0		;temp store for rmSS on protected-mode reentry

calladdr3	dw 0		;used by callrmprocintern
dwTmpRegAXBX label dword
wTmpRegAX	dw 0		;temporary storage for AX
wTmpRegBX	dw 0		;temporary storage for BX

	align 4

;--- internal real-mode callbacks (for IRQ 00-0F, Int 1C, 23, 24, mouse).
;--- unlike the client real-mode callbacks
;--- these callbacks have no real-mode call structure
;--- and DS:E/SI doesn't point to the real-mode stack on entry.

;--- for HDPMI < 3.0 this table was in client data
;--- then the "active" flag has been moved to the new dwIntRmCb bitfield
;--- and this table is now global

;--- IRQs on standard PCs:
;--- 0=PIT timer 1=kbd 2=slave PIC 3=COM2/COM4 4=COM1/COM3
;--- 5=LPT2/SB 6=floppy 7=LPT1/SB
;--- 8=RTC 9=VGA/free, 10=free, 11=free, 12=PS/2, 13=FPU exc
;--- 14=IDE1, 15=IDE2

;--- the table of internal realmode callbacks is now in client data again
;--- (it was in _DATA16 for v3.02-3.04)

?INTRMCB_IN_CDATA	equ 1

if ?INTRMCB_IN_CDATA
_DATA32C segment
endif

?INT1CVAL equ RMVFL_IDT
?INT23VAL equ RMVFL_IDT ;or RMVFL_SETALWAYS
?INT24VAL equ RMVFL_IDT ;or RMVFL_SETALWAYS

intrmcb_int label byte
	db 0+?MPICBASE
	db 1+?MPICBASE
	db 2+?MPICBASE
	db 3+?MPICBASE
	db 4+?MPICBASE
	db 5+?MPICBASE
	db 6+?MPICBASE
	db 7+?MPICBASE
	db 0+?SPICBASE
	db 1+?SPICBASE
	db 2+?SPICBASE
	db 3+?SPICBASE
	db 4+?SPICBASE
	db 5+?SPICBASE
	db 6+?SPICBASE
	db 7+?SPICBASE
	db 1Ch
	db 23h
	db 24h
	db -1
SIZEINTRMCB equ ($ - offset intrmcb_int)

@defvec macro xx
	exitm <LOWWORD offset r3vect&xx>
endm

intrmcb_vec label word
	dw @defvec(08)
	dw @defvec(09)
	dw @defvec(0A)
	dw @defvec(0B)
	dw @defvec(0C)
	dw @defvec(0D)
	dw @defvec(0E)
	dw @defvec(0F)
	dw @defvec(70)
	dw @defvec(71)
	dw @defvec(72)
	dw @defvec(73)
	dw @defvec(74)
	dw @defvec(75)
	dw @defvec(76)
	dw @defvec(77)
	dw 0
	dw 0
	dw 0
	dw LOWWORD offset mevntvec

TESTINTRMCB equ 17	;test IRQs + Int 1Ch

if ?INTRMCB_IN_CDATA
    align 4
_DATA32C ends

_DATA16C segment
intrmcbrs INTRMCBr 16+4 dup (<?>)
_DATA16C ends

endif

_DATA16 ends

;--- _DATA16C: client instance data both modes

_DATA16C segment

;--- v3.20: pmstate moved to client-specific data region;
;--- it was in _DATA16, but there the values become invalid when
;--- a client has terminated. This is a problem if another client
;--- is still active and has hooked into IRQ interrupts ( so
;--- lpms_call_int may be called with invalid PMS in pmstate )
pmstate		PMSTATE <>	; protected mode segment register values

if 1
dwrmSSSPsave	dd 0	; v86iret SS:SP saved when a client starts (used for restore in case of errors).
endif

dwHSsaved		dd 0	; this is the host stack value saved when the client starts; see @makeinitclpmframe
						; allows to safely terminate the app even if it's in a rmcb.
if ?HSINEXTMEM
dwStackTop		dd 0	; todo: explain the purpose of this variable
endif

ltaskaddr	dd 0		;addr tcb previous client
ife ?CR0COPY
dwCR0		dd 0		;?CR0COPY=0: current value of CR0 in protected mode
endif                        
spPMS		dq 0		;ring 3 PMS (SS:ESP) saved when a switch to LPMS occurs
;cIntRMCB	dw 0		;number of open internal rmcbs
cRMCB		dw 0		;number of open rmcbs (not finished with IRET yet)
wLDTLimit	dw 0		;limit of LDT
bLPMSused	db 0		;is LPMS in use? (just a flag now)
            db 0
if ?CR0COPY
bCR0		db 0		;value of LowByte(CR0)
endif

		align 4

if ?INT21API
dtaadr		df 0h		;dos DTA
endif
if ?SAVEPSP
wPSPSegm	dw 0		;initial psp segment of client
endif

dwIntRmCb	dd 0		; flags for up to 32 intrmcbs
dwIrqRouted	dd 0		; flags that IRQ has been routed to the other mode
if ?JHDPMI
dwExtHook	dd 0		; flags to indicate hook is handled by jhdpmi
endif

if ?DPMI10EXX
wExcHdlr	dw 2 dup (0);32 bits for exception handler type
endif

wEnvFlags	label word
bEnvFlags	db 0		;flags of environment string "HDPMI="
bEnvFlags2	db 0		;flags 256-32768 of "HDPMI="


_DATA16C ends

;--- end of client specific data in GROUP16

;--- start client specific data in GROUP32

_DATA32C segment

;--- ring 3 vectors int 00-10 and 70-77
;--- + some special ints. The other vectors can be read directly from IDT.
;--- these values are returned by Int 31h, ax=0204/0205

r3vect00	R3PROC < _INT00_,_INTSEL_>
r3vect01	R3PROC < _INT01_,_INTSEL_>
r3vect02	R3PROC < _INT02_,_INTSEL_>
r3vect03	R3PROC < _INT03_,_INTSEL_>
r3vect04	R3PROC < _INT04_,_INTSEL_>
r3vect05	R3PROC < _INT05_,_INTSEL_>
r3vect06	R3PROC < _INT06_,_INTSEL_>
r3vect07	R3PROC < _INT07_,_INTSEL_>
r3vect08	R3PROC < _INT08_,_INTSEL_>
r3vect09	R3PROC < _INT09_,_INTSEL_>
r3vect0A	R3PROC < _INT0A_,_INTSEL_>
r3vect0B	R3PROC < _INT0B_,_INTSEL_>
r3vect0C	R3PROC < _INT0C_,_INTSEL_>
r3vect0D	R3PROC < _INT0D_,_INTSEL_>
r3vect0E	R3PROC < _INT0E_,_INTSEL_>
r3vect0F	R3PROC < _INT0F_,_INTSEL_>
r3vect10	R3PROC < _INT10_,_INTSEL_>
if ?INT11SUPP
r3vect11	R3PROC < 2*11h  ,_INTSEL_>
endif

r3vect70	R3PROC < _INT70_,_INTSEL_>
r3vect71	R3PROC < _INT71_,_INTSEL_>
r3vect72	R3PROC < _INT72_,_INTSEL_>
r3vect73	R3PROC < _INT73_,_INTSEL_>
r3vect74	R3PROC < _INT74_,_INTSEL_>
r3vect75	R3PROC < _INT75_,_INTSEL_>
r3vect76	R3PROC < _INT76_,_INTSEL_>
r3vect77	R3PROC < _INT77_,_INTSEL_>

if ?FASTINT21
r3vect21	R3PROC < _INT21_,_INTSEL_>
endif
r3vect30	R3PROC < _INT30_,_INTSEL_>
if ?FASTINT31
r3vect31	R3PROC < _INT31_,_INTSEL_>
endif
r3vect41	R3PROC < _INT41_,_INTSEL_>
r3vect20	R3PROC < 2*20h  ,_INTSEL_>
if ?WINDBG
r3vect22	R3PROC < 2*22h  ,_INTSEL_>
endif

r3vectmp	R3PROC <0,0>

;--- ring3 exception vectors
;--- these values are used by Int 31h, ax=0202/0203

excvec label R3PROC
	R3PROC < _EXC00_,_INTSEL_>
	R3PROC < _EXC01_,_INTSEL_>
	R3PROC < _EXC02_,_INTSEL_>
	R3PROC < _EXC03_,_INTSEL_>
	R3PROC < _EXC04_,_INTSEL_>
	R3PROC < _EXC05_,_INTSEL_>
	R3PROC < _EXC06_,_INTSEL_>
	R3PROC < _EXC07_,_INTSEL_>
	R3PROC < _EXC08_,_INTSEL_>
	R3PROC < _EXC09_,_INTSEL_>
	R3PROC < _EXC0A_,_INTSEL_>
	R3PROC < _EXC0B_,_INTSEL_>
	R3PROC < _EXC0C_,_INTSEL_>
	R3PROC < _EXC0D_,_INTSEL_>
	R3PROC < _EXC0E_,_INTSEL_>
	R3PROC < _EXC0F_,_INTSEL_>
	R3PROC < _EXC10_,_INTSEL_>
	R3PROC < _EXC11_,_INTSEL_>
	R3PROC < _EXC12_,_INTSEL_>
	R3PROC < _EXC13_,_INTSEL_>
	R3PROC < _EXC14_,_INTSEL_>
	R3PROC < _EXC15_,_INTSEL_>
	R3PROC < _EXC16_,_INTSEL_>
	R3PROC < _EXC17_,_INTSEL_>
	R3PROC < _EXC18_,_INTSEL_>
	R3PROC < _EXC19_,_INTSEL_>
	R3PROC < _EXC1A_,_INTSEL_>
	R3PROC < _EXC1B_,_INTSEL_>
	R3PROC < _EXC1C_,_INTSEL_>
	R3PROC < _EXC1D_,_INTSEL_>
	R3PROC < _EXC1E_,_INTSEL_>
	R3PROC < _EXC1F_,_INTSEL_>

if ?PMIOPL eq 0
	R3PROC < 0, 0 >	; filled by ioinstr()
endif

_DATA32C ends

;--- end client specific data in GROUP32

;--------------- start code ------------------

_TEXT32 segment

;--- macro for IOPL==0 and PVI=1
;--- eax is supposed to contain EFL

@iopl0vif macro reg
local xxx
ife ?PMIOPL
 if ?IFALWAYSON
	test byte ptr ss:[dwFeatures], 2
	jz xxx
	.586p
	mov reg, cr4
	.486p
	bt reg, 1
	jnc xxx
	or ah, 2
xxx:
 endif
	btr eax, 19		; reset VIF?
endif
endm

;--- exc2int()
;--- default exception handler for exceptions 0,1,2,3,4,5,7

;--- a client exception handler can do 2 things
;--- 1. return to the dpmi host by a RETF
;---    this will result in rpmstacke() being called
;--- 2. jump to the previous handler
;---    this will result in exc2int() being called for some exceptions

;--- route exception to protected-mode int
;--- + copy E/IP,CS,E/FL to PMS
;--- + switch stack back to PMS

;--- since rpmstacke() isnt called reset bLPMSused here!

;--- ERRC is removed already!

;--- [esp] on entry: EXC2INT

	@ResetTrace

EXC2INT struct
rEdi	dd ?
rEsi	dd ?
rEbx	dd ?
rEax	dd ?
rDs		dd ?
n		IRET32 <>
dwExc	dd ?
o		IRET32 <>
EXC2INT ends

exc2int proc
	sub esp, sizeof IRET32
	push ds
	push eax
	push ebx
	push esi
	push edi

	mov edi, [esp].EXC2INT.dwExc
if ?32BIT
	mov ebx, cs:[edi*sizeof R3PROC+offset r3vect00].R3PROC._Eip
	mov eax, cs:[edi*sizeof R3PROC+offset r3vect00].R3PROC._Cs
else
	movzx ebx, cs:[edi*sizeof R3PROC+offset r3vect00].R3PROC._Eip
	movzx eax, cs:[edi*sizeof R3PROC+offset r3vect00].R3PROC._Cs
endif
	mov [esp].EXC2INT.n.rIP, ebx
	mov [esp].EXC2INT.n.rCSd, eax

if _LTRACE_
	push ebp
	mov ebp, esp
	@dprintf "entry exc_to_int: cs:ip=%X:%lX fl=%lX ss:sp=%X:%lX proc=%X:%lX",\
		[ebp+4].EXC2INT.o.rCS, [ebp+4].EXC2INT.o.rIP,\
		[ebp+4].EXC2INT.o.rFL,\
		[ebp+4].EXC2INT.o.rSS, [ebp+4].EXC2INT.o.rSP,\
		[ebp+4].EXC2INT.n.rCS, [ebp+4].EXC2INT.n.rIP 
	pop ebp
endif

	lds esi,[esp].EXC2INT.o.rSSSP
	mov eax, ds
	cmp ax,_LPMSSEL_
	jnz @F
	cmp si,?LPMSSIZE - sizeof IRETS
	jnz @F
	mov ss:bLPMSused,0
@@:

if ?32BIT
	mov edi,[esi].IRET32.rIP 		;original EIP
	mov ebx,[esi].IRET32.rCSd
	mov eax,[esi].IRET32.rFL 		;original Flags
	lds esi,[esi].IRET32.rSSSP		;original SS:ESP
else
	@checkssattr ds,si
	movzx edi,[esi].IRET16.rIP
	movzx ebx,[esi].IRET16.rCS
	movzx eax,[esi].IRET16.rFL
	lds si,[esi].IRET16.rSSSP
	movzx esi, si
endif

	sub esi,sizeof IRETSPM			;make room for IRET32/IRET16
	mov [esp].EXC2INT.n.rSP,esi
	mov [esp].EXC2INT.n.rSS,ds
if ?32BIT
	mov [esi].IRET32PM.rIP,edi
	mov [esi].IRET32PM.rCSd,ebx
	mov [esi].IRET32PM.rFL,eax
else
	mov [esi].IRET16PM.rIP,di
	mov [esi].IRET16PM.rCS,bx
	mov [esi].IRET16PM.rFL,ax
endif

	and ah, not (1+2)		;reset IF & TF
	@iopl0vif ebx
	mov [esp].EXC2INT.n.rFL, eax

	pop edi
	pop esi
	pop ebx
	pop eax
	pop ds
	iretd
	align 4

exc2int endp

;*** emulate int xx on PMS
;--- used by macro @simintpms for ints 01,06,10h,11h,31h,41h
;--- 01,06,10h and 11h only after check if it's an exception.
;--- [esp+0]: near ptr to R3PROC
;--- esp+4  : IRET32

	@ResetTrace

pms_call_int proc public
	push ebx
	push edi
	push ds

PCIFR struct
dwDs	dd ?
dwEdi	dd ?
dwEbx	dd ?
pR3Proc dd ?
		IRET32 <>
PCIFR ends

	mov ebx, [esp].PCIFR.pR3Proc
	lds edi, [esp].PCIFR.rSSSP
	mov [esp].PCIFR.pR3Proc, eax	;save content of EAX
	@checkssattr ds,di
	sub edi,sizeof IRETSPM          ;make room on client stack for IRET16/32 frame
	mov [esp].PCIFR.rSP,edi
if ?32BIT
	mov eax, cs:[ebx].R3PROC._Eip
	mov ebx, cs:[ebx].R3PROC._Cs
	xchg eax, [esp].PCIFR.rIP
	xchg ebx, [esp].PCIFR.rCSd
	mov [edi].IRETSPM.rIP, eax
	mov [edi].IRETSPM.rCSd, ebx

	mov eax,[esp].PCIFR.rFL
	mov [edi].IRETSPM.rFL, eax
else
	movzx eax, cs:[ebx].R3PROC._Eip
	mov bx, cs:[ebx].R3PROC._Cs
	xchg eax, [esp].PCIFR.rIP
	xchg ebx, [esp].PCIFR.rCSd
	mov [edi].IRETSPM.rIP, ax       ;16-bit client looses hiword(EIP)
	mov [edi].IRETSPM.rCS, bx

	mov eax, [esp].PCIFR.rFL
	mov [edi].IRETSPM.rFL, ax
endif
	and byte ptr [esp].PCIFR.rFL+1,not _TF	;reset TF
	pop ds
	pop edi
	pop ebx
	pop eax
	iretd
	align 4
pms_call_int endp

;--- lpms_call_int()
;*** switch to LPMS, then call client's ring3 handler
;*** used for IRQs, real-mode callbacks and INT 1C, 23, 24
;*** if IRQ happened in ring 0, just do a fatal exit

;*** parameter onto stack:
;*** [esp+0]: near pointer to R3PROC (CS:E/IP)
;*** esp+4  : IRET32
;***   IRET32.E/SP+SS only valid for ring3 irq
;*** ----------------------------------------------------
;*** a IRET32 stack frame is generated onto the host stack
;*** jump to ring 3 is then done with a IRETD, Interrupts disabled
;*** ----------------------------------------------------
;*** another frame (IRETS) is created onto the LPMS:
;*** format:
;***  (E)IP=_RTINT_
;***     CS=_INTSEL_
;***  (E)FL=Client Flags
;---  client EIP, CS
;--- _RTINT_ will switch the stack back to PMS. PMS is saved
;--- in the client data structure
;---
;--- if LPMS is in use already, use current PMS instead
;--- and don't create the backswitching frame

;--- v3.22: if IOPL==0, there's now a change if LPMS is in use:
;--- in this case, there will also be a switch back to ring 0
;--- after the ring3 interrupt proc has finished, not to switch stacks
;--- back, but to ensure that IF is 1.

	@ResetTrace


lpms_call_int proc public

	cmp [esp+4].IRET32.rCS,_CSSEL_ ;interrupt in ring 0?
	jz lpms_call_inr0
	sub esp,sizeof IRET32
	push ds
	push eax
	push edx
	push edi

IRQFRAME struct
rEdi	dd ?
rEdx	dd ?
rEax	dd ?
rDs		dd ?
new		IRET32 <>
pR3Proc	dd ?
old		IRET32 <>
IRQFRAME ends

	mov edi,[esp].IRQFRAME.pR3Proc
if ?32BIT
	mov eax, cs:[edi].R3PROC._Eip
	mov edx, cs:[edi].R3PROC._Cs
else
	movzx eax, cs:[edi].R3PROC._Eip
	movzx edx, cs:[edi].R3PROC._Cs
endif
	mov [esp].IRQFRAME.new.rIP,eax
	mov [esp].IRQFRAME.new.rCSd,edx

	cmp ss:bLPMSused,0			;LPMS free?
	jz lpms_ci_21

	lds edi, [esp].IRQFRAME.old.rSSSP
	sub edi, sizeof IRETSPM
	mov [esp].IRQFRAME.new.rSP, edi
	mov [esp].IRQFRAME.new.rSS, ds
ife ?32BIT
	@checkssattr ds,di
endif
	mov eax, [esp].IRQFRAME.old.rIP
	mov edx, [esp].IRQFRAME.old.rCSd
if ?32BIT
	mov [edi].IRETSPM.rIP, eax
	mov [edi].IRETSPM.rCSd, edx
	mov eax, [esp].IRQFRAME.old.rFL
	mov [edi].IRETSPM.rFL, eax
else
	mov [edi].IRETSPM.rIP, ax
	mov [edi].IRETSPM.rCS, dx
	mov eax, [esp].IRQFRAME.old.rFL
	mov [edi].IRETSPM.rFL, ax
endif
	and ah, not 1+2		;reset TF + IF
	@iopl0vif edx
	mov [esp].IRQFRAME.new.rFL, eax
if 0;_LTRACE_	;this might be called quite frequently, spoiling any useful log file
	push ebp
	mov ebp, esp
	@dprintf "lpms_call_int, nosw:ip=%X:%lX fl=%lX nip=%X:%lX nsp=%X:%lX",\
		[ebp+4].IRQFRAME.old.rCS,[ebp+4].IRQFRAME.old.rIP,[ebp+4].IRQFRAME.old.rFL,\
		[ebp+4].IRQFRAME.new.rCS,[ebp+4].IRQFRAME.new.rIP,[ebp+4].IRQFRAME.new.rSS,[ebp+4].IRQFRAME.new.rSP
	mov ds, [ebp+4].IRQFRAME.rDs
	mov ds, [ebp+4].IRQFRAME.new.rSS
	mov ds, [ebp+4].IRQFRAME.new.rCS
	lsl eax, [ebp+4].IRQFRAME.new.rSSd
	lar edx, [ebp+4].IRQFRAME.new.rSSd
	@dprintf "lpms_call_int, nosw: nfl=%lX ds:esi=%X:%lX slSS=%lX arSS=%lX",[ebp+4].IRQFRAME.new.rFL, word ptr [ebp+4].IRQFRAME.rDs, esi, eax, edx
	pop ebp
endif
	jmp done
	align 4

	@ResetTrace

;*** LPMS is free
;--- 1. save client SS:ESP in spPMS
;--- 2. mark LPMS as used
;--- 3. set LPMS ss:esp in new.IRET32 for return to ring3
;--- 4. build a frame onto LPMS (ds:[EDI]):
;---    IRETS {_RTINT_, _INTSEL_, E/FL}, client EIP, CS

lpms_ci_21:
	mov eax, [esp].IRQFRAME.old.rSP
	mov edx, [esp].IRQFRAME.old.rSSd
if ?CHECKR3SS	;for debugging
	verw dx
	jz @F
	int 3
@@:
endif
	mov dword ptr ss:spPMS+0,eax
	mov dword ptr ss:spPMS+4,edx
	mov ss:bLPMSused,1
ifdef _DEBUG
	verw dx
	jz @F
	@dprintf "lpms_call_int, sw: invalid PMS=%X:%lX", dx, eax
@@:
endif
	mov edi, ?LPMSSIZE- (2*4 + sizeof IRETSPM)	;initial value LPMS
	mov eax, _LPMSSEL_
	mov ds,eax
	mov [esp].IRQFRAME.new.rSP, edi
	mov [esp].IRQFRAME.new.rSSd, eax

	mov eax, [esp].IRQFRAME.old.rFL
	mov [edi].IRETSPM.rIP, _RTINT_
	mov [edi].IRETSPM.rCS, _INTSEL_
if ?32BIT
	mov [edi].IRETSPM.rFL, eax
else
	mov [edi].IRETSPM.rFL, ax
endif
	and ah, not 1+2		;reset TF + IF (+ also RF?)
	@iopl0vif edx
	mov [esp].IRQFRAME.new.rFL, eax

	mov edx, [esp].IRQFRAME.old.rIP
if ?32BIT
	mov eax, [esp].IRQFRAME.old.rCSd
else
	mov ax, word ptr [esp].IRQFRAME.old.rCSd	; in 16bit, save hiword(efl) on LPMS
endif
	mov [edi+sizeof IRETSPM+0], edx
	mov [edi+sizeof IRETSPM+4], eax

if 0;_LTRACE_	;this might be called quite frequently, spoiling any useful log file
	push ebp
	mov ebp,esp
	@dprintf "lpms_call_int, sw:ip=%X:%lX sp=%X:%lX fl=%lX nip=%X:%lX nsp=%X:%lX",\
		[ebp+4].IRQFRAME.old.rCS, [ebp+4].IRQFRAME.old.rIP,\
		[ebp+4].IRQFRAME.old.rSS, [ebp+4].IRQFRAME.old.rSP,\
		[ebp+4].IRQFRAME.old.rFL
		[ebp+4].IRQFRAME.new.rCS,[ebp+4].IRQFRAME.new.rIP,[ebp+4].IRQFRAME.new.rSS,[ebp+4].IRQFRAME.new.rSP
	pop ebp
endif   

done:
	pop edi
	pop edx
	pop eax
	pop ds
	iretd

;*** IRQ in Ring 0 - this is not possible currently
;--- just do a fatal exit.
;--- however, for a quick HLT "emulation" interrupts
;--- may be enabled (very selectively) inside the host;
;--- this seems to work stable.

lpms_call_inr0:
;--- 
if ?ALLOWR0IRQ or ?EMUHLTINR0
	@ResetTrace
	pop ss:taskseg._Eax		;save the client R3PROC ptr temporarily here
							;now ESP->IRET32
	push ss:taskseg._Esp0
	mov ss:taskseg._Esp0, esp
	sub esp, sizeof IRET32
	push ss:taskseg._Eax
;--- now esp points to this struct:
IRQ0FR struct
pR3Proc dd ?		;the r3 proc that we will call (irq handler) thru lpms_call_int
irn		IRET32 <>	;the r3 frame that will be used by lpms_call_int
dwEsp0	dd ?		;old taskseg._Esp0
iro		IRET32PM <>	;the frame that returns to where the IRQ has happened in r0
IRQ0FR ends

 if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintf "lpms_call_int: cs:ip=%X:%lX fl=%lX",\
		[ebp+4].IRQ0FR.iro.rCS, [ebp+4].IRQ0FR.iro.rIP, [ebp+4].IRQ0FR.iro.rFL
	pop ebp
;	@dprintf "lpms_call_int: esp=%lX", esp
 endif
;--- build the IRET32 frame that returns to r0.
;--- the old taskseg._Esp0 is on the stack and
;--- may be used to get the r3 ss:esp.
	push eax
	mov [esp+4].IRQ0FR.irn.rIP, _RTINTR0_
	mov [esp+4].IRQ0FR.irn.rCS, _INTSEL_
	mov eax, [esp+4].IRQ0FR.iro.rFL
	mov [esp+4].IRQ0FR.irn.rFL, eax
	push ebp
	mov ebp, [esp+8].IRQ0FR.dwEsp0
	mov eax, [ebp-sizeof IRET32].IRET32.rSP
	mov [esp+8].IRQ0FR.irn.rSP, eax
	mov eax, [ebp-sizeof IRET32].IRET32.rSSd
	pop ebp
	mov [esp+4].IRQ0FR.irn.rSSd, eax
	pop eax
 if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintf "lpms_call_int: irq in r0, cs:ip=%X:%lX fl=%lX, ss:sp=%X:%lX",\
		[ebp+4].IRQ0FR.irn.rCS, [ebp+4].IRQ0FR.irn.rIP,\
		[ebp+4].IRQ0FR.irn.rFL,\
		[ebp+4].IRQ0FR.irn.rSS, [ebp+4].IRQ0FR.irn.rSP
	pop ebp
 endif
	jmp lpms_call_int

;--- returning from r3 interrupt handler
;--- skip the IRET32 frame, restore taskseg._Esp0 and do a IRETD back
;--- to the interrupted r0 code.

_retirqr0::
	add esp,sizeof IRET32
	xchg eax,[esp]
	mov ss:taskseg._Esp0, eax		;restore hoststack entry value
	pop eax
 if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintf "retirqr0: cs:ip=%X:%lX fl=%lX", [ebp+4].IRET32PM.rCS, [ebp+4].IRET32PM.rIP, [ebp+4].IRET32PM.rFL
	pop ebp
;	@dprintf "retirqr0: esp=%lX", esp
 endif
	iretd	;return to ring 0 code that was interrupted.
else
	mov ax,_EAERR3_
	jmp _exitclientEx
endif ; ?ALLOWR0IRQ or ?EMUHLTINR0

	align 4

lpms_call_int endp

;--- rpmstacki()
;--- switch stack back to PMS
;--- called by int30 dispatcher

;--- int 23h may be exited with RETF instead if IRET/RETF
;--- that's why ?CSIPFROMTOP is used!

;--- why is this code executed in ring 0?
;--- in ring 3 it would be almost impossible to leave the ring 3
;--- stack "below" esp untouched

RPMIFR struct
ife ?CSIPFROMTOP
rEbx	dd ?
endif
rDs		dd ?
	IRET32 <>	; CS:EIP in this frame is 5B:2xx
RPMIFR ends

	@ResetTrace

rpmstacki proc
if ?CHECKR3SS
	verw word ptr ss:[spPMS+4]		;valid stack segment?
	jz @F
	int 3
@@:
endif
	push ds
	mov ss:bLPMSused,0
ife ?CSIPFROMTOP
	push ebx
	lds ebx,[esp].RPMIFR.rSSSP		;get the LPMS
	push dword ptr ss:spPMS+4		;SS
	push dword ptr ss:spPMS+0		;ESP
 if ?32BIT
	push dword ptr [ebx-4]			;v3.22: EFL src LPMS
 else
	push word ptr [ebx+6]			;v3.22: hiword efl (in hiword(cs))
	push word ptr [ebx-4]			;v3.22: loword efl
 endif
	push dword ptr [ebx+4]			;CS
	push dword ptr [ebx+0]			;EIP
	lds ebx,[esp+sizeof IRET32]		;restore DS,EBX
else
	push _LPMSSEL_
	pop ds
	push dword ptr ss:spPMS+4		;SS
	push dword ptr ss:spPMS+0		;ESP

;--- v3.22: problem with RF, which is lost.
;--- using the value from r0stack definitely will set RF=0.
;--- using the value from LPMS won't work with 16-bit.
;--- So the fix currently is: for 32-bit, use hiword(efl) from LPMS;
;--- for 16-bit, RF is saved in lpms_call_int in hiword(cs)
;--- and restored here. loword(efl) is copied from r0stack, since
;--- this will have TF preserved.

	assume ds:GROUP16
if ?32BIT
;	push dword ptr ds:[?LPMSSIZE-12];v3.22: EFL src LPMS; 32-bit only
	push word ptr ds:[?LPMSSIZE-10]		;v3.22: hiword(EFL) src LPMS;
	push word ptr [esp+8+2].RPMIFR.rFL	;v3.22: hiword(EFL) src r0stack
	push dword ptr ds:[?LPMSSIZE-4]		;CS
else
	push word ptr ds:[?LPMSSIZE-2]		; hiword(EFL) on LPMS
	push word ptr [esp+8+2].RPMIFR.rFL	; EFL src r0stack
	pushw 0
	push word ptr ds:[?LPMSSIZE-4]		; CS
endif

	push dword ptr ds:[?LPMSSIZE-8]	;EIP
	mov ds,[esp+sizeof IRET32]
endif
if (?PMIOPL eq 0) and (?AUTOSTI eq 1) 
;--- ensure that interrupts are enabled -
;--- an IRET in ring3 does NOT restore IF if IOPL is 0.
;--- since rpmstacki() is called only if a stack must be switched back to PMS,
;--- this is no guarantee that flags are enabled after an IRQ.

;--- hack: set IF only if next CS is NOT another INTSEL.
;--- this is "usually" the case when the IRQ was routed from real-mode.
	cmp word ptr [esp].IRET32.rCS, _INTSEL_
	jz @F
	or byte ptr [esp].IRET32.rFL+1, 2
@@:
endif
	iretd
	align 4
rpmstacki endp

;*** lpms_call_exc()
;*** exception occured.
;*** on entry:
;*** [ESP+0]: excno
;*** [ESP+4]: R3FAULT32 (ErrCode,EIP,CS,EFL,...
;*** ----------------------------------------------
;*** - build a DPMIEXC frame on L/PMS:
;*** - build a IRET32 frame on host stack
;*** - execute IRET32

	@ResetTrace

LCEFR struct
r		IRET32 <>
dwExc	dd ?
f		R3FAULT32 <>	;or R0FAULT32 for an exception in ring 0
LCEFR ends

lpms_call_exc proc
	sub esp,sizeof IRET32
	push ebp
	mov ebp,esp
	push eax

	lar eax, [ebp+4].LCEFR.f.rCSd
	and ah,60h			;exception in ring 0?
	jz lpms_call_host_exc

	push ecx
	push edx
	push esi
	push edi
	push ds

    mov ecx,_RTEXC2_
	cmp ss:bLPMSused,0	;LPMS free?
	jnz @F
	mov cx,_RTEXC_
	mov ss:bLPMSused,1
	mov ax,_LPMSSEL_
	mov edi,?LPMSSIZE - sizeof DPMIEXC
	jmp lpms_ce_2
@@:								;LPMS in use, no stack switch
	@dprintf "lpms_call_exc: called while LPMS is in use, no stack switch"
	mov edi, [ebp+4].LCEFR.f.rSP
	mov eax, [ebp+4].LCEFR.f.rSSd
	lar esi,eax
	bt esi,22
	jc @F
	movzx edi,di
@@:
	sub edi,sizeof DPMIEXC
if ?CHECKLPMS
	jbe _exitclientEx7
endif

lpms_ce_2:
	mov ds,eax
if _LTRACE_
	mov esi,[ebp+4].LCEFR.dwExc
	@dprintf "lpms_call_exc: exc=%X errc=%lX cs:ip=%X:%lX ss:sp=%X:%lX",si,\
		[ebp+4].LCEFR.f.rErr, [ebp+4].LCEFR.f.rCS,\
		[ebp+4].LCEFR.f.rIP, [ebp+4].LCEFR.f.rSS, [ebp+4].LCEFR.f.rSP
endif
	mov [ebp+4].LCEFR.r.rSSd, eax

if ?DPMI10EXX
	mov esi, [ebp+4].LCEFR.dwExc
	bt ss:[wExcHdlr],si
	jnc nodpmi10handler
	sub edi,sizeof DPMI10EXC - sizeof DPMIEXC
if ?32BIT
	mov [edi].DPMI10EXC.rDPMIIPx, ecx
	mov [edi].DPMI10EXC.rDPMICSx, _INTSEL_
else
	mov word ptr [edi].DPMI10EXC.rDPMIIPx+0, cx
	mov word ptr [edi].DPMI10EXC.rDPMIIPx+2, _INTSEL_
	mov [edi].DPMI10EXC.rDPMICSx, 0
endif
	cmp esi,14		; page fault?
	jnz noexc0e
	mov eax, cr2
	mov [edi].DPMI10EXC.rCR2, eax
	push edi
	call pm_Linear2PT	; set EDI to linear addr of PTE
	mov ax,0
	jc @F
	push ds
	push byte ptr _FLATSEL_
	pop ds
	mov eax,dword ptr [edi]
	pop ds
@@:
	pop edi
	and eax,1FFh
	mov [edi].DPMI10EXC.rPTE, eax
noexc0e:
	mov eax, [ebp+4].LCEFR.f.rErr
	cmp esi,1		; debug exception?
	jnz @F
;--- todo: BS (bp single step) should be bit 15, in dr6 it's bit 14
;--- bits 4-14 should be 0.
	mov eax, dr6	; then error code contains a "virtual dr6"
@@:
	mov edx, [ebp+4].LCEFR.f.rIP
	mov esi, [ebp+4].LCEFR.f.rCSd
	mov [edi].DPMI10EXC.rErrx, eax
	mov [edi].DPMI10EXC.rEIPx, edx
	mov [edi].DPMI10EXC.rCSx, si
	xor eax, eax
if ?EXCRESTART
	shl esi,16
	mov si,dx
	cmp esi, (_INTSEL_ shl 16) + _RTEXCR0_
	setz al		;bit 0=1 (exc in host), bit 1=0 (can be retried)
endif
	mov [edi].DPMI10EXC.rInfoBits, ax
	mov eax, [ebp+4].LCEFR.f.rFL
	mov edx, [ebp+4].LCEFR.f.rSP
	mov esi, [ebp+4].LCEFR.f.rSSd
	mov [edi].DPMI10EXC.rEFLx, eax
	mov [edi].DPMI10EXC.rESPx, edx
	mov [edi].DPMI10EXC.rSSx, esi
	mov eax, [esp]
	mov [edi].DPMI10EXC.rDSx, eax
	mov [edi].DPMI10EXC.rESx, es
	mov [edi].DPMI10EXC.rFSx, fs
	mov [edi].DPMI10EXC.rGSx, gs
nodpmi10handler:
endif
	mov [ebp+4].LCEFR.r.rSP, edi

if ?32BIT
	mov [edi].DPMIEXC.rDPMIIP, ecx
else
	mov [edi].DPMIEXC.rDPMIIP, cx
endif
	mov [edi].DPMIEXC.rDPMICS, _INTSEL_
	mov eax, [ebp+4].LCEFR.f.rErr
	mov edx, [ebp+4].LCEFR.f.rIP
	mov esi, [ebp+4].LCEFR.f.rCSd
if ?32BIT
	mov [edi].DPMIEXC.rErr, eax
	mov [edi].DPMIEXC.rIP, edx
	mov [edi].DPMIEXC.rCSd, esi
else
	mov [edi].DPMIEXC.rErr, ax
	mov [edi].DPMIEXC.rIP, dx
	mov [edi].DPMIEXC.rCS, si
endif
	mov eax, [ebp+4].LCEFR.f.rFL
	mov edx, [ebp+4].LCEFR.f.rSP
	mov esi, [ebp+4].LCEFR.f.rSSd
if ?32BIT
	mov [edi].DPMIEXC.rFL, eax
	mov [edi].DPMIEXC.rSP, edx
	mov [edi].DPMIEXC.rSSd, esi
else
	mov [edi].DPMIEXC.rFL, ax
	mov [edi].DPMIEXC.rSP, dx
	mov [edi].DPMIEXC.rSS, si
endif
	and ah, not 1+2
	@iopl0vif ecx
	mov [ebp+4].LCEFR.r.rFL, eax

	mov edi, [ebp+4].LCEFR.dwExc
  if ?32BIT
	mov eax, cs:[edi*sizeof R3PROC+offset excvec].R3PROC._Eip
	mov esi, cs:[edi*sizeof R3PROC+offset excvec].R3PROC._Cs
  else
	movzx eax, cs:[edi*sizeof R3PROC+offset excvec].R3PROC._Eip
	movzx esi, cs:[edi*sizeof R3PROC+offset excvec].R3PROC._Cs
  endif
	mov [ebp+4].LCEFR.r.rIP, eax
	mov [ebp+4].LCEFR.r.rCSd, esi

	@dprintf "jmp handler: cs:ip=%X:%lX ss:sp=%X:%lX",\
		[ebp+4].LCEFR.r.rCS, [ebp+4].LCEFR.r.rIP,\
		[ebp+4].LCEFR.r.rSS, [ebp+4].LCEFR.r.rSP

	pop ds
	pop edi
	pop esi
	pop edx
	pop ecx
	pop eax
	pop ebp
	iretd
	align 4
lpms_call_exc endp

	@ResetTrace

lpms_call_host_exc proc

LCEFR0 struct
r	 	IRET32 <>
dwExc	dd ?
f	  	R0FAULT32 <>
LCEFR0 ends


;--- exception in ring 0, eax+ebp saved on stack

	mov eax, ss
	cmp ax, _SSSEL_				;exception in ring 0 with unknown SS?
	jz ss_is_hoststack
	pushad
	push ds

	push byte ptr _SSSEL_
	pop ds
if 1
	mov esi, ds:taskseg._Esp0
	sub esi, sizeof R3FAULT32 + sizeof IRET32 + 4
else
	mov esi, 100h 
endif
	mov eax,[ebp+4].LCEFR0.f.rErr
	mov ecx,[ebp+4].LCEFR0.f.rIP
	mov edx,[ebp+4].LCEFR0.f.rCSd
	mov ebx,[ebp+4].LCEFR0.f.rFL
	lea edi,[ebp+4+sizeof LCEFR0]
	mov [esi+4].R3FAULT32.rErr,eax
	mov [esi+4].R3FAULT32.rIP,ecx
	mov [esi+4].R3FAULT32.rCSd,edx
	mov [esi+4].R3FAULT32.rFL,ebx
	mov [esi+4].R3FAULT32.rSP,edi
	mov [esi+4].R3FAULT32.rSSd,ss
	mov eax, [ebp+4].LCEFR0.dwExc
	mov [esi+0], eax
	mov ds:taskseg._Esi, esi
	pop ds
	popad
	mov eax,[ebp-4]
	mov ebp,[ebp+0]
	push byte ptr _SSSEL_
	pop ss
	mov esp, ss:taskseg._Esi
	@dprintf "an exception occured in ring 0, ss unknown"
	jmp _exceptZ

ss_is_hoststack:        
	mov eax,[ebp+4].LCEFR0.dwExc

	@dprintf "an exception %X occured in ring 0",ax
if _LTRACE_
	push eax
	lar eax, [ebp+4].LCEFR0.f.rCSd
	@dprintf "acc rights of CS=%lX",eax
	pop eax
endif

if ?IGNEXC01INR0
	cmp eax,1			  ;single step exc?
	jz lpms_ce_4
endif
        
if ?EXCRESTART

LCEFR0X struct
dwExc	dd ?
f	  	R3FAULT32 <>	;6 DWORDS
dwHST	dd ?
rES		dd ?
rDS		dd ?
f0	  	R0FAULT32 <>
LCEFR0X ends

	bt ss:[wExcHdlr],ax
	jnc nodpmi10handlerX
	pop eax
	pop ebp
	add esp, sizeof IRET32
	pop ss:taskseg._Eax			;get exception no
	push ds
	push es
	push ss:taskseg._Esp0
	mov ss:taskseg._Esp0, esp
	sub esp,sizeof R3FAULT32
	push ss:taskseg._Eax
	pushad
	mov ebp,esp
	mov eax, [ebp+32].LCEFR0X.f0.rErr
	mov [ebp+32].LCEFR0X.f.rErr, eax
	mov [ebp+32].LCEFR0X.f.rIP, _RTEXCR0_
	mov [ebp+32].LCEFR0X.f.rCS, _INTSEL_
	mov esi, [ebp+32].LCEFR0X.dwHST
	mov eax, ss:[esi-sizeof IRET32].IRET32.rFL
	mov edx, ss:[esi-sizeof IRET32].IRET32.rSP
	mov esi, ss:[esi-sizeof IRET32].IRET32.rSSd
	mov [ebp+32].LCEFR0X.f.rFL, eax
	mov [ebp+32].LCEFR0X.f.rSP, edx
	mov [ebp+32].LCEFR0X.f.rSSd, esi
	xor ecx, ecx
	mov eax, es
	lar edx, eax
	and dh,60h			;ring 0 descriptor?
	jnz @F
	mov es, ecx
@@:
	mov eax, ds
	lar edx, eax
	and dh,60h			;ring 0 descriptor?
	jnz @F
	mov ds, ecx
@@:
	popad
	@dprintf "frame for exc in ring 0 built, esp=%lX, jmp to lpms_call_exc",esp
	jmp lpms_call_exc

retexcr0::
if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintf "[esp]=%lX %X %lX %lX %X",[ebp+4].IRET32.rIP,\
		[ebp+4].IRET32.rCS,[ebp+4].IRET32.rFL,\
		[ebp+4].IRET32.rSP,[ebp+4].IRET32.rSS
	pop ebp
endif
	add esp, sizeof IRET32
	@dprintf "return from ring 0 exception handler, esp=%lX",esp
	pop ss:taskseg._Esp0
	pop es
	pop ds
	lea esp, [esp+4]	;skip error code
	iretd

nodpmi10handlerX:
endif

if ?MAPRING0EXC 

;--- to route exc in ring 0 to a ring 3 
;--- exception handler it would be necessary
;--- to know the full client state. Currently this isn't the case,
;--- so just a fatal exit is possible

	push ebx
	mov ebx,ss:taskseg._Esp0
	sub ebx,4 + sizeof R3FAULT	;5 register + errorcode + ?
	sub word ptr ss:[ebx+4].R3FAULT.rIP,2  ;"int xx"
	mov ax,[ebp+4+1 * ?RSIZE]	;address in table
	mov ss:[ebx+0],ax
	mov ax,[ebp+4+2 * ?RSIZE]	;errcode
	mov ss:[ebx+2],ax
	mov eax,ds
	test al,4	;LDT selector? better check priv level!
	jnz @F
	push 0
	pop ds
@@:
	mov eax,es
	test al,4	;LDT selector? better check priv level!
	jnz @F
	push 0
	pop es
@@:
	pop ebx
	pop eax
	pop ebp
	mov esp, ss:taskseg._Esp0]
	sub esp, sizeof R3FAULT32 + 4
	jmp lpms_call_exc
else

;--- don't try to route ring0 exceptions to client
;--- eax == excnr

	@dprintf "ring 0 exc at %X:%lX",[ebp+4].LCEFR0.f.rCS,\
		[ebp+4].LCEFR0.f.rIP

	sub esp,sizeof R3FAULT32
	push eax						;wExcNo
	mov eax,[ebp+4].LCEFR0.f.rErr
	mov [esp+4].R3FAULT32.rErr,eax
	mov eax,[ebp+4].LCEFR0.f.rIP
	mov [esp+4].R3FAULT32.rIP,eax
	mov eax,[ebp+4].LCEFR0.f.rCSd
	mov [esp+4].R3FAULT32.rCSd,eax
	mov eax,[ebp+4].LCEFR0.f.rFL
	mov [esp+4].R3FAULT32.rFL,eax
	lea eax,[ebp+4+sizeof LCEFR0]
	mov [esp+4].R3FAULT32.rSP,eax
	mov [esp+4].R3FAULT32.rSSd,ss
        
	mov eax,[ebp-4]
	mov ebp,[ebp+0]
	@dprintf "ring 0 exc jmp to _exceptZ"
	jmp _exceptZ
endif

if ?IGNEXC01INR0

;--- might be an exception 01 in VCPI host

lpms_ce_4:
	@dprintf "single step exception in ring 0 occured, ignored"
	cmp ss:[cApps],0			;is a client active?
	jz @F
	mov ebp, ss:taskseg._Esp0	;set client Trace flag
	or byte ptr [ebp-sizeof IRET32].IRET32.rFL+1,1
@@:
	pop eax
	pop ebp
	add esp,sizeof IRET32 + 4 + 4	;RETF32 + excno + errcode
	and byte ptr [esp].IRET32.rFL+1, not 1
	iretd
endif
	align 4

lpms_call_host_exc endp

;*** client has done a RETF in its exception handler
;--- the errorcode has already been skipped in intr30!
;*** now switch stack back to PMS
;--- [esp]=IRET32 
;--- if we are on top of the LPMS, new SS:ESP is 
;--- LPMS:FFF8h (32-bit) or LPMS:FFFCh (16-bit)

RPMEFR struct
rEax	dd ?
rEsi	dd ?
rDs		dd ?
		IRET32 <>
RPMEFR ends

	@ResetTrace

rpmstacke proc
	mov ss:bLPMSused,0
rpmstacke_nosw::
	push ds
	push esi
	push eax
if _LTRACE_
	push ebp
	mov ebp, esp
	@dprintf "rpmstacke: CS:IP=%X:%lX Fl=%lX SS:SP=%X:%lX",\
		 [ebp+4].RPMEFR.rCS, [ebp+4].RPMEFR.rIP, [ebp+4].RPMEFR.rFL,\
		 [ebp+4].RPMEFR.rSS, [ebp+4].RPMEFR.rSP
	pop ebp
endif
	lds esi,[esp].RPMEFR.rSSSP
if 0 ;v3.19: stack compare now obsolete
	mov eax, ds
	cmp ax,_LPMSSEL_
	jnz @F
	cmp si,?LPMSSIZE - 2 * ?RSIZE
	jnz @F
	mov ss:bLPMSused,0
@@:
endif
	@checkssattr ds,si
if ?32BIT
	mov eax,[esi+ 0 * ?RSIZE]
	mov esi,[esi+ 1 * ?RSIZE]
else
	movzx eax,word ptr [esi+ 0 * ?RSIZE]
	movzx esi,word ptr [esi+ 1 * ?RSIZE]
endif
	mov [esp].RPMEFR.rSP,eax
	mov [esp].RPMEFR.rSSd,esi
if _LTRACE_
	push ebp
	mov ebp, esp
	@dprintf "rpmstacke: org SS:SP=%X:%lX",[ebp+4].RPMEFR.rSS, [ebp+4].RPMEFR.rSP
	pop ebp
endif
	pop eax
	pop esi
	pop ds
	iretd
	align 4

rpmstacke endp

;*** adjust carry flag on stack, then iretd (used by int 31h/4Bh handler)
;--- no other flags modified

iret_with_CF_mod proc public
	jc @F
	and byte ptr [esp].IRET32.rFL,not _CY	;reset carry
	iretd
	align 4
@@:
	or byte ptr [esp].IRET32.rFL, _CY
	iretd
	align 4
iret_with_CF_mod endp

;*** main PM Break dispatcher (INT 30h)
;*** function: translate (E)IP to the functions requested,
;*** then call it.
;*** since int 30h is always called indirectly, 
;*** the original values for E/IP,CS,E/FL must be copied from the
;*** client's stack und the stack must be adjusted
;*** Int 30h is a interrupt gate (interrupts disabled) 

	@ResetTrace
_LTRACE_ = 0	;no log of int 30h calls

intr30 proc
if ?FASTJUMPS
	cmp word ptr [esp].IRET32.rIP,_JMPF_+2
	jnb intr30_jmps
endif
	sub esp,4

	push ebx
	push eax

I30FR struct
dwEax	dd ?
dwEbx	dd ?
dwRes	dd ?
		IRET32 <>
I30FR ends

	mov ebx,[esp].I30FR.rIP
	sub ebx,2
if ?LOGINT30
	mov ss:[lint30],bx
endif
	cmp bh,02h			;break 00h-ffh?
	jnb intr30_special

if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintfx ?LOG_INT30, "int30 simint ip=%X:%lX %lX sp=%X:%lX",[ebp+8].I30FR.rCS,\
		 [ebp+8].I30FR.rIP, [ebp+8].I30FR.rFL, [ebp+8].I30FR.rSS, [ebp+8].I30FR.rSP
	pop ebp
endif

	shr ebx,1
	push ds
	mov [esp+4].I30FR.dwRes,ebx	;is an intno now
	lds ebx, [esp+4].I30FR.rSSSP
if ?CHECKSSIS32
	lar eax, [esp+4].I30FR.rSSd
	test eax,400000h
	jnz @F
	movzx ebx,bx
@@:
endif

if ?32BIT
	mov eax, [ebx].IRETS.rIP
	mov [esp+4].I30FR.rIP,eax
	mov eax, [ebx].IRETS.rCSd
	mov [esp+4].I30FR.rCSd,eax
	mov eax, [ebx].IRETS.rFL
	mov [esp+4].I30FR.rFL,eax
else
	movzx eax, word ptr [ebx].IRETS.rIP
	mov [esp+4].I30FR.rIP,eax
	mov ax, [ebx].IRETS.rCS
	mov [esp+4].I30FR.rCSd,eax
	mov ax, [ebx].IRETS.rFL
;--- bits 16-31 of EFL aren't stored on the client stack
;--- v3.23: but they are still stored on the host stack
;	mov [esp+4].I30FR.rFL,eax
	mov word ptr [esp+4].I30FR.rFL,ax
endif
	add [esp+4].I30FR.rSP,sizeof IRETSPM	;adjust client stack
	pop ds
	pop eax
	pop ebx
;   pop ebp
	jmp _callrmsint
	align 4

if ?FASTJUMPS
intr30_jmps:
  if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintfx ?LOG_INT30, "int30 jmps ip=%X:%lX %lX sp=%X:%lX",[ebp+4].IRET32.rCS,\
		 [ebp+4].IRET32.rIP, [ebp+4].IRET32.rFL, [ebp+4].IRET32.rSS, [ebp+4].IRET32.rSP
	pop ebp
  endif
	push ebx
	mov ebx, [esp+4].IRET32.rIP
	push dword ptr cs:[ebx*2+offset spectab-404h]
	mov ebx,[esp+4] 
	retn 4
endif
	align 4

	@ResetTrace

;--- special breaks ( offset >= 200h in breakpoint table )

intr30_special:
	mov eax,dword ptr cs:[ebx*2+offset spectab-400h]
if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintfx ?LOG_INT30, "int30 special ip=%X:%lX %lX sp=%X:%lX eax=%lX",[ebp+4].I30FR.rCS, ebx,\
		[ebp+4].I30FR.rFL, [ebp+4].I30FR.rSS, [ebp+4].I30FR.rSP, eax
	pop ebp
endif
	mov [esp].I30FR.dwRes,eax	;function address
if ?FASTJUMPS eq 0
	cmp bx,_JMPF_			;no stack parameters
	jnb intr30_3
endif
	push ds
	mov eax,ebx

	lds ebx,[esp+4].I30FR.rSSSP
if ?CHECKSSIS32
	push eax
	@checkssattr ds,bx
	pop eax
endif
	cmp ax,_RTEXC2_			;return from exceptionhandler without switch?
	jz @F
	cmp ax,_RTEXC_			;return from exceptionhandler?
	jnz noexcret
@@:
	@dprintfx ?LOG_INT30, "int30 special: return from exception, remove error code %lX",dword ptr [ebx]
	add ebx, ?RSIZE			;remove error code from client stack
	add [esp+4].I30FR.rSP, ?RSIZE
noexcret:
	cmp ax,_RETF_			   ;retf oder iret frame?
if ?32BIT
	mov eax, [ebx].IRET32.rIP
	mov [esp+4].I30FR.rIP,eax
	mov eax, [ebx].IRET32.rCSd
else
	mov eax,0
	mov ax, [ebx].IRET16.rIP
	mov [esp+4].I30FR.rIP,eax
	mov ax, [ebx].IRET16.rCS
endif
	mov [esp+4].I30FR.rCSd,eax
	jnb @F
if ?32BIT
	mov eax, [ebx].IRETS.rFL
else
	mov ax, [ebx].IRETS.rFL
endif
	@dprintfx ?LOG_INT30, "int30 special: IRET frame, copy flags=%lX", eax
	mov [esp+4].I30FR.rFL,eax
if 0;	;v3.18: what was that supposed to do?
	and ah,not _TF			   ;reset TF
	mov ss:[tmpFLReg],ax
endif
	add [esp+4].I30FR.rSP, ?RSIZE
@@:
	add [esp+4].I30FR.rSP, ?RSIZE * 2
;intr30_1:	;v3.18: unused
if _LTRACE_
	push ebp
	mov ebp, esp
	@dprintfx ?LOG_INT30, "int30 special: exit, ip=%X:%lX fl=%lX sp=%X:%lX",[ebp+8].I30FR.rCS,\
		[ebp+8].I30FR.rIP, [ebp+8].I30FR.rFL,\
		[ebp+8].I30FR.rSS, [ebp+8].I30FR.rSP
	pop ebp
endif
	pop ds
intr30_3:
	pop eax
	pop ebx
	retn				  ;now jump to the function
	align 4
intr30 endp

ifdef _DEBUG
_LTRACE_ = 1
endif

;--- adjust all standard flags, then perform IRETD

retf2exit proc public
	push eax
	lahf
	mov byte ptr [esp+4].IRET32.rFL,ah
	pop eax
iretexit::
	iretd
	align 4
retf2exit endp

	@ResetTrace

if ?ENHANCED

;--- int 20h is used in win9x 

intr20  proc
	push eax
	lar eax,[esp+4].IRET32.rCSd	;called from ring 0?
	test ah,60h
	pop eax
	jnz @F             
	or byte ptr [esp].IRET32.rFL,1 ;set carry flag
if _LTRACE_
	push ebp
	mov ebp,esp
	push ds
	push esi
	lds esi,[ebp+4].IRET32.rCSIP
	@dprintf "intr20 (r0): sp=%X:%X ip=%X:%lX fl=%lX [ip]=%X %X",\
		ss,sp,[ebp+4].IRET32.rCS,[ebp+4].IRET32.rIP,[ebp+4].IRET32.rFL,\
		[esi+0],[esi+2]
	pop esi
	pop ds
	pop ebp
endif
	add [esp].IRET32.rIP,4
	iretd
@@:
	@dprintf "intr20 (r3): call Int 20h real mode"
	@callrmsint 20h
intr20  endp

endif

if ?WINDBG

;--- int 22h in PL0 protected-mode is an API that
;--- the Win3x/9x VMM supplies for the debugger ( WDeb386 ).
;--- it's called with a function # in AX (or AH?)
;---  0: is installed?; must return AX=F386h if service available
;---  1: query Win386 state; ds:[esi]=cmd string, ds:[edi]=client struct
;---  2: phys2linear; esi=phys addr, cx=bytes, returns ax=0/1, esi=linaddr
;---  3: addr valid?; esi=linear addr, cx=bytes, returns ax=0/1

;--- assumes ss==GROUP16!!!

	@ResetTrace
intr22 proc
	@dprintf "intr22: Win386 debug API called, ax=%X", ax
 if 0
	test ss:[fDebug], FDEBUG_KDPRESENT
	jz exit
	cmp ax, 0
	jz is0
	cmp ax, 2
	jz is2
exit:
	iretd
is0:
	mov ax, 0F386h
	iretd
is2:
	pushad
	@dprintf "intr22: ax=2, esi=%lX, cx=%X", esi, cx
	mov word ptr [esp].PUSHADS.rEAX, 0
	jcxz @F
	mov edx, esi
	movzx eax, cx
	add eax, 1000h-1
	shr eax, 12
	call pm_searchphysregion   ;not active!!!
	jc @F
	and dx, 0FFFh
	or ax, dx
	@dprintf "intr22: ax=2 ok, esi=%lX", eax
	mov [esp].PUSHADS.rESI, eax
	mov word ptr [esp].PUSHADS.rEAX, 1
@@:
	popad
 endif
	iretd
	align 4
intr22 endp
endif

	@ResetTrace

;--- default exception handler for exc 02-05 + 07 routes the exceptions
;--- to protected mode INTs
;--- for exc 00 this is also true if MAPEXC00 == 1 (which is standard)
;--- for exc 01 check register DR6 and don't call exception handler
;--- if it is a programmed INT 01.

intr00 proc
	@exception 00
if ?MAPEXC00				;route exc 00 to int 00?
	@mapexc2int 00
else
	@defaultexc 00, 1	;terminate client
endif
intr00 endp

;--- exc 01: test if it is a hw break
;--- register dr6: bits 0-3: hw break
;--- bit 14: BS, "single-step" ( must be reset by software! )
;--- bit 15: BT, "task switch"

intr01 proc
if ?TESTEXC01
	push eax
	mov eax, dr6
	test ax, 0C00Fh ; bits 0-3: watchpoint triggered, bit 14: 1=single-step thru TF
	jz @F
	@dprintf "intr01: debug exception occured, dr6=%lX", eax
	mov ah,0		; reset DR6 bits 12-15 - why?
	mov dr6, eax
	pop eax
	jmp isdebugexc
@@:
	pop eax
	@simintpms 01
isdebugexc::
endif
	@exception 01
	@mapexc2int 01

intr01 endp

intr02 proc
	cmp word ptr [esp.IRET32.rCS],_CSSEL_ ;skip NMI in ring 0
	jz iretexit
	@exception 02
	@mapexc2int 02
intr02 endp

intr03 proc
	cmp word ptr [esp.IRET32.rCS],_CSSEL_ ;skip int3 in ring 0
	jz iretexit
	@exception 03
	@mapexc2int 03
intr03 endp

intr04 proc
	@exception 04
	@mapexc2int 04
intr04 endp

;--- win9x routes exception 05 to protected mode and as long as hdpmi
;--- wants to run win3.1 it should behave similar. But if it is a real
;--- bound exception, it should not be routed to real-mode!

intr05 proc
	@exception 05
	@mapexc2int 05
intr05 endp

intr06 proc
if ?TESTEXC06
	@testint 06, noint06 ;exc 6 is not mapped to int 6, so check for int 6
	@simintpms 06
noint06:
endif
	@exception 06
	@defaultexc 06, 1
intr06 endp

intr07 proc
	@exception 07
	@mapexc2int 07
intr07 endp

;--- exceptions 08-0F share the same INTs as IRQ0-7, which
;--- requires some additional detection

intr08 proc
	@testexception exc08
	@simintlpms 08
exc08:
	@exception 08, TRUE
	@defaultexc 08
intr08 endp

;--- exc 09 is for 80286/80386 only
;--- and there is no errorcode
;--- this code is not active if a 80486+ has been detected!

intr09 proc public
	push eax
	mov al,0Bh		;get ISR of MPIC
	out 20h,al
	in al,20h
	test al,02		;IRQ 1 happened?
	pop eax
	jnz simint09
	@testint 09, noint09	;test for programmed int 09	(would be strange)
	align 4
intr09 endp

simint09 proc public
	@simintlpms 09
noint09::        
	@exception 09
	@defaultexc 09
simint09 endp

intr0A proc
	@testexception exc0A
	@simintlpms 0A
exc0A:
	@exception 0A, TRUE
	@defaultexc 0A
intr0A endp

intr0B proc
	@testexception exc0B
	@simintlpms 0B
exc0B:
	@exception 0B, TRUE
	@defaultexc 0B,1
intr0B endp

intr0C proc
	@testexception exc0C
	@simintlpms 0C
exc0C:
	@exception 0C, TRUE
	@defaultexc 0C,1
intr0C endp

	@ResetTrace

intr0D proc
if 0
	push ebp
	mov ebp,esp
	push eax
	lea eax,[esp+8]
	@dprintf "int 0D: sp=%lX,[sp]=%lX,%lX,%lX,%lX,%lX",\
		eax, dword ptr [ebp+4], dword ptr [ebp+8],\
		dword ptr [ebp+12], dword ptr [ebp+16],\
		dword ptr [ebp+20]
	pop eax
	pop ebp
endif
	@testexception exc0D, exc0Dx
	@simintlpms 0D
exc0D:
	call emuprivinstr		;emulate some privileged opcodes in ring 3
exc0Dx:
	@exception 0D, TRUE
	@defaultexc 0D,1
;int0dcalled:
;	@simintpms 0D
intr0D endp

	@ResetTrace

intr0E proc
	@testexception exc0E
	@simintlpms 0E
exc0E:
	@exception 0E, TRUE
	@defaultexc 0E,1 
intr0E endp

;--- exception 0F doesn't exist, just switch to LPMS

intr0F proc
	@simintlpms 0F
intr0F endp

if ?INT10SUPP
	@ResetTrace
intr10 proc
if 0
	push eax
	fnstsw ax
	test al,80h		;unmasked exception occured?
	pop eax
	jz int10called
	push ds
	push ebx
	lds ebx,[esp+8].IRET32.rCSIP
	mov bl,[ebx]
	cmp bl,9Bh		;WAIT opcode?
	jz @F
	and bl,0F8h
	cmp bl,0D8h		;D8-DF opcode
@@:
	pop ebx
	pop ds
	jnz int10called
else
	@testint 10, noint10	;exc 10h has no error code
	@simintpms 10
noint10:
endif
	@exception 10			;no error code supplied!
	@defaultexc 10
intr10 endp
endif

if ?INT11SUPP
	@ResetTrace
intr11 proc
	@testexception exc11
	@simintpms 11
exc11:
	@exception 11, TRUE
	@defaultexc 11
intr11 endp        
endif

;--- exceptions 12-1F not supported

defexcxx:		;default exceptions 12-1F
;	@printf <"unsupported exception",lf>
	push cs
	pop ss
;	int 3
;	iretd
	align 4

	@ResetTrace

ints70_77 proc
intr70::
	@simintlpms 70
intr71::
	@simintlpms 71
intr72::
	@simintlpms 72
intr73::
	@simintlpms 73
intr74::
	@simintlpms 74
intr75::
	@simintlpms 75

	@ResetTrace

intr76::
	@simintlpms 76

	@ResetTrace

intr77::
	@simintlpms 77
ints70_77 endp

;--- here are the default interrupt handlers for int 00 - 0F, 70-77

	@ResetTrace

if ?MAPINT00
	@callrmint 00	;route int 00 to real-mode
else
	@termint 00		;terminate client
endif
	@callrmint 01
	@callrmint 02
	@callrmint 03
	@callrmint 04
if ?MAPINT05
defint05:
	push ds
	push esi
	lds esi, [esp+8].IRET32.rCSIP
	cmp byte ptr [esi],62h		;bound opcode
	pop esi
	pop ds
	jz @F
	@callrmint 05,int05torm	;05 is a fault, should be terminated?
@@:
	@termint 05, int05term
else
	@termint 05		;terminate client
endif
	@callrmint 06	;06 is no problem (is *not* called for exceptions)
if ?MAPINT07
	@callrmint 07	;07 route int 07 to real-mode
else
	@termint 07		;terminate client
endif
	@callrmirq 08
	@callrmirq 09
	@callrmirq 0A
	@callrmirq 0B
	@callrmirq 0C
	@callrmirq 0D
	@callrmirq 0E
	@callrmirq 0F

	@callrmirq 70
	@callrmirq 71
	@callrmirq 72
	@callrmirq 73
	@callrmirq 74
if 0 ;v3.19
	@callrmirq 75
else
defint75:
;--- new for v3.19:
;--- default int 75h handler
;--- send EOI to FPU and PICs
	push eax
	mov al,0
	out 0F0h,al	; it's actually a "clear busy latch"
	mov al,20h
	out 0a0h,al
	out 20h,al
	pop eax
;--- and now launch an numeric exception (10h) as if CR0.NE is 1
;	iretd
  if 0
	_LTRACE_ = 1
	push ebp
	mov ebp,esp
	@dprintf "int 75: sp-4=%lX,[sp]=%lX %lX %lX %lX %lX",\
		ebp, dword ptr [ebp+4], dword ptr [ebp+8], dword ptr [ebp+12],\
		dword ptr [ebp+16], dword ptr [ebp+20]
	pop ebp
  endif
;--- if the stack is to be switched from LPMS to PMS,
;--- there's _INTSEL_:_RTINT_ as CS:IP onto the stack
	cmp [esp].IRET32.rCS, _INTSEL_
	jnz @F
	push ds
	push eax
	push _LPMSSEL_
	pop ds
	mov ss:[bLPMSused],0
	mov eax,dword ptr ds:[?LPMSSIZE-8]	;EIP
	mov [esp+8].IRET32.rIP,eax
	mov eax,dword ptr ds:[?LPMSSIZE-4]	;CS
	mov [esp+8].IRET32.rCSd,eax
	mov eax,dword ptr ss:spPMS+0		;ESP
	mov [esp+8].IRET32.rSP,eax
	mov eax,dword ptr ss:spPMS+4		;SS
	mov [esp+8].IRET32.rSSd,eax
	pop eax
	pop ds
@@:
	@exception 10
endif
	@callrmirq 76
	@callrmirq 77
	@callrmirq 1C
;	@callrmirq 23

_TEXT32 ends

_TEXT16X segment

;--- common entry for internal real-mode callbacks;
;--- used to route IRQs from real-mode to protected-mode;
;--- also used for int 1ch, 23h, 24h and mouse-event proc.
;--- switch to protected mode only if client has modified pm vectors!

;--- NOTE: label 'intrmcb_rm' must be beyond 19*16 (0x130), so that there
;--- won't be an overflow of the calculated offset. That's why it is placed
;--- in segment _TEXT16X.

;--- the mouse event proc is somewhat different because it's expected to exit
;--- with RETF instead of IRET. That's why entry intrmcb_rm_retf exists, which
;--- supplies a proper IRET frame.

	align 4

IRQLOG	equ 0	;set to 1 if irqs are to be logged

	@ResetTrace

intrmcb_rm_retf proc public
;--- entry for mouse event proc, creates a IRET frame.
	push bp
	mov bp,sp
	push eax
	pushf
	mov eax,[bp+2]		;get cs:ip into eax
	pop word ptr [bp+4]	;store flags at the final location
	xchg eax,[bp+0]		;store cs:ip at the final location, get bp into ax
	mov bp,ax
	pop eax
intrmcb_rm_retf endp	;fall thru'

	align 4

intrmcb_rm proc public

	push bp
	mov bp,cs
	db 0eah			;jmp far16
	dw offset @F
wPatchGrp163 dw 0	;will be patched with GROUP16
@@:
	sub bp,cs:wHostSeg
	bt word ptr cs:[dwIrqRouted], bp
	jc jmpprev

;--- v3.22: no longer needed, exception handler masks interrupts
;--- v3.23: reactivated (and renamed), since masking interrupts caused problems.
;	cmp cs:[bExcEntry],-1	;host entry possible?
	cmp cs:[bNoRMCBEntry],0	;host entry possible?
	jnz jmpprev				;if no, jump to previous handler

	public intrmcb_brk
intrmcb_brk::
	@rm2pmbrk
	mov cs:[wTmpRegBX],bx
	mov cs:[wTmpRegAX],ax
	mov bx,bp
	mov bp,sp
	mov ax,[bp+2].IRETSRM.rFL
	pop bp

if ?NTCLEAR
	and ah, 08Fh 				;reset NT,IOPL
 if ?PMIOPL
	or ah, ?PMIOPL shl 4		;set iopl (0 or 3)
 endif
endif
if ?DISINT@RM2PM
	and ah,not 2
endif
	mov cs:[tmpFLReg],ax

if _LTRACE_ and IRQLOG
	push bp
	mov bp,sp
	cmp bx,0	 ;int 8?
	jz @F
	cmp bx,10h	 ;int 1C?
	jz @F
	@drprintf "intrmcb_rm: #=%X cs:ip=%X:%X fl=%X ds=%X es=%X ss:sp=%X:%X",\
		bx, [bp+2].IRETSRM.rCS, [bp+2].IRETSRM.rIP, [bp+2].IRETSRM.rFL, ds, es, ss, sp
@@:
	pop bp
endif

	@savermstk	;save real-mode SS+SP 

;--- raw jump in pm, ss:sp=hoststack;
;--- real-mode segments stored in v86iret;
;--- ds,es,fs,gs undefined.

	@rawjmp_pm_savesegm intrmcb_pm

;--- jump to vector stored in intrmcbrs[].
;--- v3.22: since internal rmcbs are released as soon as the protected-mode
;--- vector has been reset, when is this label jumped to?
;--- a) if jhdpmi is loaded this code never runs, since intrmcb_rm() isn't
;---    part of the IVT chain.
;--- b) if interrupt occured in real-mode, then routed to protected-mode
;---    and finally routed back to real-mode, callrmproc_iretframe() will
;---    directly use the vector stored in intrmcbrs[].
;--- c) interrupt occured in protected-mode, protected-mode handler is
;---    installed, but jumps to/calls its predecessor in chain;
;---    callrmproc_iretframe() is reached, which sets the bit in dwIrqRouted
;---    and then calls the code stored in IVT.
;--- so only case c) is relevant!

jmpprev:
	shl bp,2		;sizeof INTRMCBr == 4!
if 0;_LTRACE_
	@drprintf "intrmcb %X: calling old rm handler %X:%X [dwIntRmCb=%lX]", bp,\
		word ptr cs:[bp+intrmcbrs].rm_vec+2, word ptr cs:[bp+intrmcbrs].rm_vec+0,\
		cs:[dwIntRmCb]
endif
	pushd cs:[bp+intrmcbrs].INTRMCBr.rm_vec
	mov bp,sp
	mov bp,[bp+4]
	retf 2	;skip bp on stack

	align 4

intrmcb_rm endp

_TEXT16X ends

_TEXT32 segment

	@ResetTrace

intrmcb_pm proc

;--- internal real-mode callback - protected-mode entry.
;--- bx=IRQ

	push ss:[dwIrqRouted]

	@pushstate 1	;save client state, including realmode segm DS/ES/FS/GS

;--- build an IRET32 frame on the host stack for IRETD to ring3.
;--- E/IP, CS and E/FLAGS will be copied to the LPMS/PMS
;--- after this is done, real-mode code can be called again

if 0
;--- pre v3.19 code
;--- assumed a certain structure of the host stack, that
;--- didn't work in all cases ( IIRC, raw mode switches were a problem )
	lea esp,[esp-sizeof IRET32]
	mov [esp].IRET32.rIP, _FRTIN_
	mov [esp].IRET32.rCS, _INTSEL_
	push ebp
	push eax
	mov eax,ss:tmpFLRegD
	mov [esp+2*4].IRET32.rFL, eax
	mov ebp,[esp+2*4+ sizeof IRET32]	;get previous dwHostStack
	mov eax,[ebp-sizeof IRET32].IRET32.rSP
	mov ebp,[ebp-sizeof IRET32].IRET32.rSSd
	mov [esp+2*4].IRET32.rSP,eax
	mov [esp+2*4].IRET32.rSSd,ebp
	pop eax
	pop ebp
else
;--- since v3.19: use new fields rESP, rSSd in pmstate
;--- v3.20: may have caused a crash if a client terminated and another one
;--- became active due to intercepting IRQs. Cause: pmstate wasn't located in
;--- client data area and hence still contained selectors of the terminated client
	push ss:pmstate.rSSd
 if ?CHECKR3SS
	verw word ptr [esp+0]
	jz @F
	int 3
@@:
 endif
	push ss:pmstate.rESP
	push ss:tmpFLRegD
	pushd _INTSEL_
	pushd _FRTIN_
endif

;--- now displays (via dos or bios) are possible again

	push 0						;the true value will be set below

;	inc ss:[cIntRMCB]

	push ebx
	movzx ebx, bx
if ?JHDPMI
	bt ss:[dwExtHook], ebx		;v3.22: do not set routing bits that are handled by jhdpmi
	jc @F
endif
	bts ss:[dwIrqRouted], ebx	;v3.22: IRQ is "routed"
@@:

	mov ax, cs:[ebx*2][intrmcb_vec]
	cmp ax, 0		;is offset a IDT offset?
	jnz irqrm2pm_1
	mov al, cs:[ebx][intrmcb_int]
	shl ax, 3		; size of GATE is 8

	cmp bx, 11h		; int 23h?
	jnz @F
	mov [esp+2*4].IRET32.rIP, _FRTIN2_		;int 23h returns C flag!
@@:
	cmp bx, 12h		; int 24h? for Int 24h BP holds a segment, must be translated
	mov bx, ax
	jnz @F
	@dprintf "intrmcb: int 24, translation of bp=%X", bp
	push ebp
	call segm2sel
	pop ebp						;now BP has a selector
@@:
	push byte ptr _FLATSEL_
	pop ds

	add ebx,ss:[pdIDT.dwBase]
if ?32BIT
	mov ax, [ebx+6]			; hiword(EIP)
endif
	mov ebx, [ebx+0]		; loword(EIP) + CS
	push byte ptr _CSALIAS_
	pop ds
	assume ds:GROUP32
if ?32BIT
	mov word ptr ds:[r3vectmp+0],bx		; CS:EIP
	mov word ptr ds:[r3vectmp+2],ax
	shr ebx,16
	mov word ptr ds:[r3vectmp+4],bx
else
	mov dword ptr ds:[r3vectmp+0],ebx	; CS:IP
endif
	mov ax,LOWWORD offset r3vectmp
irqrm2pm_1:
	pop ebx
	mov [esp], ax			;set lowword of 32-bit offset of R3PROC
	mov es, ss:pmstate.rES
	mov ds, ss:pmstate.rDS
	mov fs, ss:pmstate.rFS
	mov gs, ss:pmstate.rGS

ifdef _DEBUG
	verw word ptr ss:pmstate.rSSd
	jz @F
	@dprintf "intrmcb: invalid value in pmstate ss:esp=%X:%lX", word ptr ss:pmstate.rSSd, dword ptr ss:pmstate.rESP
@@:
endif

	@checkhoststack

if _LTRACE_
	push eax
	movzx eax,ax
 if ?32BIT
	@dprintfx ?LOG_INTRMCB, "intrmcb enter: call=%lX:%lX", cs:[eax].R3PROC._Cs, cs:[eax].R3PROC._Eip
 else
	@dprintfx ?LOG_INTRMCB, "intrmcb enter: call=%X:%X", cs:[eax].R3PROC._Cs, cs:[eax].R3PROC._Eip
 endif
	pop eax
endif

	mov bx,ss:[wTmpRegBX]
	mov ax,ss:[wTmpRegAX]

	jmp lpms_call_int		;LPMS switch + jump to ring 3
	align 4

intrmcb_pm endp

	assume ds:nothing

	@ResetTrace

;--- returning from internal real-mode callback (_FRTIN2_)
;--- jump back to real-mode, flags transfered from protected-mode.
;--- used for int 23h.

rpmstackr2 proc
	push eax
	push ebx
	mov eax,ss:v86iret.rESP
	movzx ebx,ss:v86iret.rSS
	shl ebx,4
	add ebx, eax
	mov eax,[esp+8].IRET32.rFL
	push ds
	push byte ptr _FLATSEL_
	pop ds
	mov byte ptr [ebx].IRETSRM.rFL,al
	pop ds
	pop ebx
	pop eax
rpmstackr2 endp	;fall thru!

;--- returning from internal real-mode callback (_FRTIN_)
;--- jump back to real-mode, flags NOT modified.

rpmstackr proc
	lea esp, [esp + sizeof IRET32]	;skip the IRET32 frame
;	dec ss:[cIntRMCB]
if _LTRACE_ and IRQLOG
	@dprintf "rpmstackr: rms=%X:%X, _Esp0=%lX, esp=%lX", ss:v86iret.rSS, ss:v86iret.rSP, ss:taskseg._Esp0, esp
endif
	@popstate 1					;restore client state

	pop ss:[dwIrqRouted]

	@rawjmp_rm rpmstackr_rm
	align 4
_TEXT16 segment
rpmstackr_rm:
	@restorermstk		;restore v86iret.rSS & rSP
	iret				;real mode iret!
	align 2
_TEXT16 ends

rpmstackr endp

	@ResetTrace

;*** mode switches
;*** there exist some cases
;*** 1. client hasn't set pm-vecs -> count = zero
;***    -> no pm-mapper installed in rm  -> call original int
;*** 2. client has set pm-vecs, there are 2 alternatives:
;***  a. irq occured in protected mode -> route to client pm proc
;***     if irq arrives at default handler, it will be routed to real-mode.
;***     problem: unknown rm-handler, which hasn't used INT 31h to install,
;***     is not notified
;***  b. irq im real mode -> is routed to protected mode
;***     if irq arrives at default handler, it will be routed to real-mode
;***     handler installed before HDPMI

;--- Ints 00-05 + 07 route to real-mode
;--- stack frame:
;--- esp+0 : int#
;--- esp+4 -> IRET32
;--- flags not modified
;--- used by macro @callrmint 

dormint proc
	xchg ebx, [esp]
	push ss:[dwIrqRouted]
	jmp callrmproc_1
	align 4
dormint endp

;--- call a real-mode IRQ, then return to r3 via IRETD;
;--- this is the default handling for Ints 08-0F and 70-77, 1C.
;--- esp+0 : IRQ#
;--- esp+4 -> IRET32
;--- r3 flags not modified.
;--- used by macro @callrmirq.

CRFRAME struct
dwIrqRouted dd ?
_ebx        dd ?
            IRET32 <>
CRFRAME ends

callrmproc_iretframe proc
	xchg ebx, [esp]
	push ss:[dwIrqRouted]
if ?JHDPMI
	bt ss:[dwExtHook], ebx			; skip tests for IRQs handled by jhdpmi
	jc @F
endif
	bt  ss:[dwIntRmCb], ebx			; is the IRQ hooked? (todo: check why this extra test is needed!)
	jnc @F
	bts ss:[dwIrqRouted], ebx		; if "routed" flag is set ...
	jnc @F
	mov ebx, ss:[ebx*4][intrmcbrs.rm_vec]	;... then IRQ comes from real-mode
	jmp crp1
@@:
	mov bl, cs:[ebx][intrmcb_int]
callrmproc_1::
	@getIVTvector 0
crp1:
	mov ss:[calladdr1], ebx
	mov ebx, [esp].CRFRAME.rFL
	and bh, not _TF		;reset TF

if ?SETRMIOPL	;is 0 by default
	and bh, 0CFh
	or bh, ?RMIOPL shl 4
endif
	mov ss:[tmpFLReg], bx
	mov ebx, [esp].CRFRAME._ebx
	@call_rm cs:[calladdr1], 1, cs:[tmpFLReg]
	pop ss:[dwIrqRouted]
	add esp, 4	; skip _ebx member
	iretd
	align 4
callrmproc_iretframe endp

;***  call real-mode interrupt, then return to r3 via IRETD
;---  unlike dormint above, flags are returned!
;---  esp+0 : int#
;---  esp+4 -> IRET32
;---  used by macro @callrmsint

	@ResetTrace

_callrmsint proc public

	xchg ebx,[esp]
;	@dprintf "callrmsint %X", bx
	@getIVTvector 0
	mov ss:calladdr2, ebx
	mov ebx,[esp+4].IRET32.rFL
;	pushfd
	and bh,not _TF		;reset TF
	mov ss:[tmpFLReg],bx
;	popfd
	pop ebx				;stack: ip,cs,fl,sp,ss
	@jmp_rm callrmsint_rm
	align 4
_TEXT16 segment
callrmsint_rm:
	push cs:[tmpFLReg]
	call cs:[calladdr2]
	pushf
callrmsint_brk::
	@rm2pmbrk
	pop cs:[tmpFLReg]
	@jmp_pm callrmsint_pm
	align 2
_TEXT16 ends
callrmsint_pm:
	push eax
	mov ax,ss:[tmpFLReg]
	and ah, 8Fh				;reset NT, IOPL
if ?PMIOPL
	or ah, ?PMIOPL shl 4
endif
	mov word ptr [esp+4].IRET32.rFL,ax
	pop eax
	iretd
	align 4
_callrmsint endp

;--- call a real-mode near16 proc internally
;--- esp+0 : return address
;--- esp+4 : near16 proc to call
;--- DS+ES may contain ring 0 selectors!

callrmprocintern proc public
	push eax
	mov eax, [esp+2*4]
	mov ss:[calladdr3], ax
	pop eax
	@call_rm cs:[calladdr3], 0
	ret 4
	align 4
callrmprocintern endp

	@ResetTrace

;--- call a real-mode INT from inside host
;--- esp+0 : return address
;--- esp+4 : int#
;--- flags must be preserved ( see int21api.asm, rmdoswithcarry )
;--- used by macro @simrmint
;--- simplified in v3.21 - but caused a regression for INT 25h/26h calls (Exc 0Dh)

callrmintintern proc public

	push ebx
	mov ebx,[esp+2*4]
;	@dprintf "callrmintintern: int=%X",bx
	@getIVTvector 1
	mov ss:calladdr2, ebx
	pop ebx
	@call_rm cs:[calladdr2], 1, 1
	ret 4
	align 4

callrmintintern endp

	@ResetTrace

if 0;?CATCHREBOOT
myint09proc proc near
	pushfd
	push eax
	push ds
	push byte ptr _FLATSEL_
	pop ds
	mov al,byte ptr ds:[417h]
	and al,0Ch					;ctrl+alt pressed?
	cmp al,0Ch
	jnz @F
	in al,60h
	cmp al,__DEL_MAKE
	jz isreboot
@@:
	pop ds
	pop eax
	popfd
	ret
isreboot:
if ?SAVEPSP
;--- if another PSP is active, do NOT try to terminate the client
	mov eax,ss:[dwSDA]
	mov ax,[eax].DOSSDA.wPSP
	cmp ax, ss:[wPSPSegm]
	jnz @B
endif        
	mov al,20h
	out 20h,al
	pop ds
	pop eax
	popfd
	lea esp, [esp+4]   	;throw away return address

	@printf <lf,"hdpmi: app terminated by user request",lf>

	mov [esp].IRET32.rIP, offset clientexit
	mov [esp].IRET32.rCS, _CSR3SEL_
	iretd
	align 4

myint09proc endp

_TEXT32R3 segment
clientexit:
	mov ax,4cffh
	int 21h
_TEXT32R3 ends
endif

if ?CATCHREBOOT
catchreboot proc
	mov al,0Bh		;get ISR of MPIC
	out 20h,al
	in al,20h
	test al,02		;IRQ 1 happened?
	jz @F
	mov al,20h		;send EOI to PIC
	out 20h,al
@@:
	XOR ECX,ECX
@@:
	IN AL,64h		;wait until kbd buffer is free
	TEST AL,02
	LOOPNZ @B
	MOV AL,0AEh 	;enable keyboard
	OUT 64h,AL
	xor eax, eax
	mov es, eax
	mov ds, eax
	@printf <lf,"hdpmi: ctrl-alt-del detected, app terminated",lf>
	jmp fatappexit2
	align 4
catchreboot endp
endif

;--- exception 0Dh
;--- 1. emulate HLT and move to/from special registers
;--- 2. ?PMIOPL == 0: emulate sti,cli
;--- 3. ?PMIOPL == 0: if current instr is IN[S]/OUT[S], check if port is trapped

EMUINSFR struct
dwEAX	dd ?
dwESI	dd ?
dwDS	dd ?
		dd ?			;return address (intr0D)
		R3FAULT32 <>
EMUINSFR ends        

	@ResetTrace

if ?PMIOPL eq 0
prefseg:
	mov byte ptr [esp].EMUINSFR.rErr+1, al
	jmp nextipbyte
pref66:
	or ah, 20h
	jmp nextipbyte
pref67:
	or ah, 40h
	jmp nextipbyte
preff3:
	or ah, 80h
	jmp nextipbyte
endif


emuprivinstr proc
	push ds
	push esi
	push eax
	lds esi,[esp].EMUINSFR.rCSIP
	mov eax,ds
	lsl eax,eax
	cmp eax,esi		;EIP > CS limit?
	jc done
	cld
if ?PMIOPL eq 0
	mov ah, 0
endif
nextipbyte::
	lodsb
if ?PMIOPL eq 0
	cmp al, 26h	;ES?
	jz prefseg
	cmp al, 2Eh	;CS?
	jz prefseg
	cmp al, 36h	;SS?
	jz prefseg
 if 0
	cmp al, 3Eh	;DS?
	jz prefseg
 endif
	cmp al, 64h	;FS?
	jz prefseg
	cmp al, 65h	;GS?
	jz prefseg
	cmp al, 66h
	jz pref66
	cmp al, 67h
	jz pref67
	cmp al, 0F3h	;REP?
	jz preff3

	cmp al, 0FAh	;CLI?
	jz emucli
	cmp al, 0FBh	;STI?
	jz emusti

	push eax

SI_STRING   equ 8
SI_CPORT    equ 40h	; if IN/OUT: 1=port in bits 8-15

;--- E4/E5/E6/E7? IN AL/AX,XX - OUT XX,AL/AX
;--- EC/ED/EE/EF? IN AL/AX,DX - OUT DX,AL/AX
;--- 6C/6D/6E/6F? (INSB/W, OUTSB/W)
;--- AL[1]: 0=IN, 1=OUT

	and al, 0FCh
	cmp al, 0E4h
	jz ioinstr1
	cmp al, 0ECh
	jz ioinstr2
	or ah, SI_STRING	; string instr
	cmp al, 6Ch
	jz ioinstr3

	pop eax
endif
	cmp al, 0F4h	;HLT?
	jz emuhlt
	;--- v3.18: no emulation of spec reg moves in "safe" mode
	test ss:bEnvFlags2, ENVF2_SYSPROT
	jnz donespec
if ?EMUMOVREGCRX or ?EMUMOVCRXREG or ?EMUMOVCR0REG or ?EMUMOVREGDRX or ?EMUMOVDRXREG
	cmp al, 0Fh
	jnz donespec
	lodsb
if ?EMUMOVREGCRX
	cmp al,20h		;mov xxx,crx?
	jz emuspecregmove
endif
if ?EMUMOVCRXREG or ?EMUMOVCR0REG       
	cmp al,22h		;mov crx,xxx?
	jz emumov2crxreg
endif
if ?EMUMOVREGDRX
	cmp al,21h		;mov xxx,drx?
	jz emuspecregmove
endif
if ?EMUMOVDRXREG
	cmp al,23h		;mov drx,xxx?
	jz emumov2drxreg
endif
	jmp done
donespec:
done:
;	@dprintf "exception 0d, unknown instr %X", word ptr [esi]
	pop eax
	pop esi
	pop ds
	ret

	align 4

ife ?PMIOPL
emucli:
	@dprintfxx ?LOG_CLISTI, "emulate cli eip=%lX", [esp].EMUINSFR.rIP
	and byte ptr [esp].EMUINSFR.rFL+1, not 2	; reset IF
 if ?TRAPCLISTI
	cmp [clihdlr._Cs], 0
	jnz clitrapped
 endif
	jmp done_emuclisti
 if ?TRAPCLISTI
stitrapped:
	push offset stihdlr
	jmp @F
clitrapped:
	push offset clihdlr
@@:
	push edi
	push es
;--- make room on client stack for an IRET frame
	les edi, [esp+3*4].EMUINSFR.rSSSP
	lea edi, [edi-sizeof IRETSPM]
	mov [esp+3*4].EMUINSFR.rSP, edi
;--- store client's current CS:E/IP and flags (with adjusted IF) there
  if ?32BIT
	mov eax, esi
	stosd
	mov eax, [esp+3*4].EMUINSFR.rCSd
	stosd
	mov eax, [esp+3*4].EMUINSFR.rFL
	stosd
  else
	mov eax, esi
	stosw
	mov eax, [esp+3*4].EMUINSFR.rCSd
	stosw
	mov eax, [esp+3*4].EMUINSFR.rFL
	stosw
  endif
	mov edi, [esp+2*4]     ;get offset for R3PROC (clihdlr/stihdlr)
  if ?32BIT
	mov esi, cs:[edi].R3PROC._Eip
	mov eax, cs:[edi].R3PROC._Cs
	mov [esp+3*4].EMUINSFR.rCSd, eax
  else
	movzx esi, cs:[edi].R3PROC._Eip
	mov ax, cs:[edi].R3PROC._Cs
	mov [esp+3*4].EMUINSFR.rCS, ax
  endif
	pop es
	pop edi
	add esp, 4
	and byte ptr [esp].EMUINSFR.rFL+1, not 1	; v3.23: reset TF
	jmp done_emuclisti
 endif
	align 4
emusti:
	@dprintfxx ?LOG_CLISTI, "emulate sti eip=%lX", [esp].EMUINSFR.rIP
	or byte ptr [esp].EMUINSFR.rFL+1, 2	; set IF
 if ?TRAPCLISTI
	cmp [stihdlr._Cs], 0
	jnz stitrapped
 endif
	jmp done_emuclisti
endif

emuhlt:
	@dprintf "emulate hlt"
ife ?SIMHLT
  if ?ALLOWR0IRQ
  ;--- this code works, but just for an emulation of HLT
  ;--- in protected-mode it requires too much (hackish) code.
	mov [esp].EMUINSFR.rIP, esi
	pop eax
	pop esi
	pop ds
	lea esp,[esp+4+4]		;skip returnaddr + error code
	sti
	hlt
	cli
   if _LTRACE_
	push ebp
	mov ebp,esp
	@dprintf "back from hlt, frame cs:eip=%X:%lX, fl=%lX, ss:esp=%X:%lX",\
		[ebp+4].IRET32.rCS, [ebp+4].IRET32.rIP,\
		[ebp+4].IRET32.rFL,\
		[ebp+4].IRET32.rSS, [ebp+4].IRET32.rSP
	pop ebp
   endif
	iretd   
  else
	pushd offset emu_hlt
	call callrmprocintern
  endif
else
@@:
	in al,21h
	xor al,0FFh
	mov ah,al
	mov al,0Ah
	out 20h,al
	in al,20h
	and al,ah
	jnz @F
	in al,0A1h
	xor al,0FFh
	mov ah,al
	mov al,0Ah
	out 0A0h,al
	in al,0A0h
	and al,ah
	jz @B
@@:
endif
done_emuclisti:
	mov [esp].EMUINSFR.rIP, esi
	pop eax
	pop esi
retfromsim2:
	pop ds
	lea esp,[esp+4+4]		;skip returnaddr + error code
	iretd					;back to client
	align 4

_DATA32C segment
tmpProc label near		; v3.20: now called "near"
tmpCode dd ?
_DATA32C ends

emumov2crxreg:      ; "mov crx, reg"
ife ?EMUMOVCR0REG	; v3.20: "mov cr0, reg" is rejected
	mov al,[esi]
	test al,038h	; "mov cr0, reg"?
	jnz emuspecregmove
	cmp al,0C0h		; "mov cr0, eax"?
	jnz done		; anything else causes a GPF
	mov eax, [esp]
	or eax, 80000001h; v3.21: "mov cr0, eax" is allowed, but bits 0 & 31 stay 1
	mov cr0, eax
	inc esi
	jmp done_emuclisti
endif
emumov2drxreg:		; "mov drx, reg"
emuspecregmove:
	lodsb
;	mov ah,0CBh		;RETF v3.20: changed to near call
	mov ah,0C3h		;RETN
	shl eax, 16
	mov ax,[esi-3]	;the opcode is 3 bytes long (0F 2x xx)
	push byte ptr _CSALIAS_
	pop ds
	mov ds:[tmpCode], eax
	mov [esp].EMUINSFR.rIP, esi
	@dprintf "emulate 'mov eax, crx', eax=%lX", eax
	pop eax
	pop esi
if 0	; v3.20: changed to near call
	push cs
	push offset tmpCode
	call fword ptr [esp]
	add esp, 3*4		; dont touch esi now, skip far32 & esi
else
	call tmpProc
endif
	jmp retfromsim2
	align 4
endif

if ?PMIOPL eq 0

gettrapproc proto

ioinstr1: ; IN/OUT, port at CS:E/IP 
	or ah, SI_CPORT
	lodsb
	mov byte ptr [esp+4].EMUINSFR.rErr+1, al
ioinstr2: ; IN/OUT, port in DX
ioinstr3: ; INS/OUTS
	mov al, [esp]
	sub esi, [esp+4].EMUINSFR.rIP
	or word ptr [esp+4].EMUINSFR.rErr, si
	mov [esp], edx
	mov esi, ds
	lar esi, esi
	shr esi, 23
	setc dl
	shl dl, 5
	test al, 1	; byte or word/dword access?
	jz @F
	or ah, 10h	; word/dword acc
	xor ah, dl	; dword if a) D=1 and no 66h b) D=0 and 66h
@@:
	test ah, 8	; string instruction?
	jz @F
	shl dl, 1
	xor dl, 40h
	xor ah, dl	; clear hiword if a) D=0 and no 67h b) D=1 and 67h
@@:
	or byte ptr [esp+4].EMUINSFR.rErr, ah

;--- get trap proc in SI:E/AX
;--- AL[1] = mode (0=IN/1=OUT)

	mov edx, [esp]
	and ah, SI_STRING or SI_CPORT
	cmp ah, SI_CPORT	; port in DX?
	jnz @F
	movzx edx, byte ptr [esp+4].EMUINSFR.rErr+1
@@:
	call gettrapproc	; get trap proc for port in DX
	pop edx
	push _CSALIAS_
	pop ds
	assume ds:GROUP32
if ?32BIT
	mov dword ptr [excvec + 20h * sizeof R3PROC+0], eax
	mov  word ptr [excvec + 20h * sizeof R3PROC+4], si
else
	mov word ptr [excvec + 20h * sizeof R3PROC+0], ax
	mov word ptr [excvec + 20h * sizeof R3PROC+2], si
endif
	pop eax
	pop esi
	pop ds
	assume ds:nothing
	lea esp, [esp+4]	; skip return addr
	push 20h
	jmp lpms_call_exc

endif

emuprivinstr endp

if ?JHDPMI
_TEXT16 segment
jhdpmicall:
	db 9ah
dwJHdpmi dd 0
	ret
_TEXT16 ends
endif

;*** check if interrupt to modify is a IRQ (or 1Ch,23h,24h)
;*** if yes, activate internal real-mode callback for this INT.
;*** this routine is called with new PM-IRQ vector in CX:(E)DX
;*** by DPMI func ax=205h (set pm vector).
;--- in: AL=IRQ, DS=flat
;--- all registers must be preserved.

installirqhandler proc near public

	@ResetTrace

if ?IRQMAPPING

	push eax
	push ebx
	push edi
	push ds
	push es
	movzx ebx, al

	push ds
	pop es
	push ss
	pop ds
	assume ds:GROUP16

 if ?JHDPMI
	bt [dwExtHook], ebx
	jc handle_jhdpmi
 endif


;--- if INTRMCB.pm_vec is IDT offset, no restauration is possible.
;--- todo: explain why this should be the case.

;--- v3.22: check removed.
;	test cs:[ebx*sizeof INTRMCB+intrmcbs].bFlags,RMVFL_IDT
;	jnz setvector

	test cl,4			;is it a LDT selector?
	jnz setvector

	btr [dwIntRmCb], ebx
	jnc done
	movzx edi,cs:[ebx][intrmcb_int]
	shl edi, 2
	mov eax, [ebx*4+intrmcbrs].rm_vec
	mov es:[edi], eax		; restore IVT vector
 if 1
	mov [ebx*4+intrmcbrs].rm_vec, 0
 endif
	@dprintf "internal callback irq=%X deactivated, cx:edx=%X:%lX", bx, cx, edx
	jmp done

;--- pm-vector will be set

setvector: 
	bts [dwIntRmCb], ebx
	jc done
	@dprintf "internal callback irq=%X activated, cx:edx=%X:%lX", bx, cx, edx

	call getivtcsip
	movzx edi,cs:[ebx][intrmcb_int]
	shl edi, 2
	xchg eax,es:[edi]		;get/set IVT vector
	mov [ebx*4+intrmcbrs].rm_vec, eax
done:
	pop es
	pop ds
	pop edi
	pop ebx
	pop eax
endif
	ret

if ?IRQMAPPING
 if ?JHDPMI
handle_jhdpmi:
	test cl,4						;is it a LDT selector?
	jnz setvector_jhdpmi
	btr [dwIntRmCb], ebx
	jnc done
	mov bl, cs:[ebx][intrmcb_int]
	mov ax, JHD_UNHOOKIRQ
	pushd offset jhdpmicall
	call callrmprocintern
	jmp done
setvector_jhdpmi:
	bts [dwIntRmCb], ebx
	jc done
	push ecx
	push edx
	call getivtcsip
	push eax
	pop dx
	pop cx
	mov bl, cs:[ebx][intrmcb_int]
	mov ax, JHD_HOOKIRQ
	pushd offset jhdpmicall
	call callrmprocintern
	pop edx
	pop ecx
	jmp done
 endif

;--- there's just one entry for all internal callbacks
;--- they are distinguished by the segment value of the far call
;--- in: BX=IRQ
;--- out: EAX=CS:IP
getivtcsip:
	push ecx
	mov eax, ebx
	mov ecx, ebx
	add ax, [wHostSeg]				;GROUP16
	shl ecx, 4
	shl eax, 16
	mov ax, offset intrmcb_rm
	sub ax, cx
	pop ecx
	ret
endif
	assume ds:nothing

	align 4

installirqhandler endp

	@ResetTrace

;*** initialization procs ***

	assume ds:GROUP16

;*** server initialization when first client starts
;--- DS=GROUP16, ES=FLAT
;--- C=error (out of memory)

	@ResetTrace

_initfirstclient proc near

	pushad
	assume ds:GROUP16

	@dprintf "initfirstclient enter"
if ?CR0COPY
	mov eax,cr0				;use CR0, lmsw cannot set NE bit!
	and al, bFPUAnd
	or al, bFPUOr
	mov cr0,eax
endif
	test byte ptr dwFeatures+3, 2	;ISSE supported?
	jz @F
	@mov_eax_cr4
	or ah,2
	@mov_cr4_eax
@@:

;---- alloc address space for LDT

	mov ecx,10h				;alloc 64k for LDT
	test bEnvFlags2, ENVF2_LDTLOW
	jz @F
	call _allocaddrspaceX
	jnc ldtallocated
@@:
	call pm_AllocSysAddrSpace
	jc exit
ldtallocated:
	mov [dwLDTAddr],eax
	@dprintf "space for LDT is allocated: %lX", eax

;---- commit 1. page for LDT

	call EnlargeLDT
	jc exit

	@dprintf "LDT is initialized, allocating LPMS"
							;alloc memory for LPMS
	mov ecx,1
	call pm_AllocSysPagesU	;LPMS
	jc exit
	@dprintf "LPMS allocated"

ifdef _DEBUG
	mov dword ptr es:[eax],"SMPL"
endif

if ?LPMSINGDT
	mov ecx, pdGDT.dwBase
	mov es:[ecx+(_LPMSSEL_ and 0F8h].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[ecx+(_LPMSSEL_ and 0F8h].DESCRPTR.A1623,al
	mov es:[ecx+(_LPMSSEL_ and 0F8h].DESCRPTR.A2431,ah
else
	mov esi,80h
	add esi,dwLDTAddr
	mov es:[esi].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[esi].DESCRPTR.A1623,al
	mov es:[esi].DESCRPTR.A2431,ah
	mov es:[esi].DESCRPTR.limit,0FFFh
 if ?32BIT
	mov word ptr es:[esi].DESCRPTR.attrib,92h or ?PLVL + 4000h
 else
	mov es:[esi].DESCRPTR.attrib,92h or ?PLVL
 endif
endif
if ?INT1D1E1F
	mov esi,[pdIDT.dwBase]
	mov ecx,1Dh
@@:
	mov bx,es:[ecx*4+2]
	mov ax,0002			;segm to selector
	@int_31
	shl eax,16
	mov ax,es:[ecx*4+0]
	mov es:[esi+ecx*8+0],eax
	inc cl
	cmp cl,1Fh+1
	jnz @B
else					;int 1E immer umsetzen

	assume es:SEG16		;make sure it is 16bit
	movzx eax,word ptr es:[1Eh*4+2]
	movzx ebx,word ptr es:[1Eh*4+0]
	assume es:nothing

	shl eax,4
	add eax,ebx

	mov ecx, pdGDT.dwBase
	mov es:[ecx+(_I1ESEL_ and 0F8h)].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[ecx+(_I1ESEL_ and 0F8h)].DESCRPTR.A1623,al
endif
ife ?LOCALINT2324
	mov cx,_INTSEL_
if ?32BIT
	mov edx,_INT23_
else
	mov dx,_INT23_
endif
	mov bl,23h
	mov ax,205h 		;set pm vector
	@int_31
if ?32BIT
	mov edx,_INT24_
else
	mov dx,_INT24_
endif
	mov bl,24h
	@int_31
endif
	clc
	@dprintf "initfirstclient exit"
exit:
	popad
	ret
	align 4

_initfirstclient endp

if ?TLBLATE

;--- DS=GROUP16, ES=FLAT
;--- EDI must be preserved

	@ResetTrace

settlb_pm proc
	pushad
	@dprintf "settlb_pm: wSegTLB=%X, instance=%X, es=%lX", wSegTLB, wHostSeg, es
	cmp wSegTLB,0
	jnz exit
	call setstrat
	mov bx,?TLBSIZE/10h
	mov ah,48h
	call rmdosintern
	jc @F
	@dprintf "settlb_pm: new wSegTLB=%X", ax
	mov wSegTLB, ax
	or fMode, FM_TLBMCB
if 1
ife ?STUB
	movzx eax, ax
	dec eax
	shl eax, 4
	mov cx, wHostPSP
	mov es:[eax+1], cx	;make the host the owner
endif
endif
@@:
	pushfd
	call resetstrat
	popfd
	jc error
exit:
	movzx eax, wSegTLB
	shl eax, 4
	mov ecx, pdGDT.dwBase
	mov es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.A1623,al
	or es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.attrib,2	;writeable
error:
	popad
	ret
setstrat:
	mov ax,5800h			;get alloc strat
	call rmdosintern
	movzx esi, al
	mov ax,5802h			;get umb link status
	call rmdosintern
	movzx edi, al

	xor eax, eax
	mov bx,0001h			;fit best
	test bEnvFlags, ENVF_TLBLOW
	jnz @F
	inc eax					;add umbs to alloc strat
	or bl,80h				;+ search in UMBs first
@@:
	push ebx
	push eax
	jmp resetstrat_1
resetstrat:
	push edi
	push esi
resetstrat_1:
	pop ebx
	mov ax,5803h			;set umb link status
	call rmdosintern
	pop ebx
	mov ax,5801h			;set alloc strat
	call rmdosintern
	retn
	align 4
settlb_pm endp

endif

setcr0wpbit proc
	cmp _cpu,4
	jb @F
	mov eax,cr0
	bts eax, CR0_WPbit	;set write protect bit
	mov cr0,eax
@@:
	ret
setcr0wpbit endp

if ?HSINEXTMEM

 if ?MAPDOSHIGH

;--- if HDPMI's conv. memory is remapped, and the TSS is set
;--- to the high address, it can contain a full IO-bitmap!
  if ?PMIOPL eq 0
?STACKPAGES equ 2+2+1		;2 for host's DOS code, 2 for TSS, 1 for hs 
  else
?STACKPAGES equ 2+1			;2 for host's DOS code, 1 for hs 
  endif
 else
?STACKPAGES equ 1			;1 for hs 
 endif

;--- set a new host stack
;--- in: dwSSBase
;--- out: EAX=new host stack linear address
;--- out: dwHostStack, dwStackTop, v86iretesp
;--- out: dwSSBase: will be set to new base in extended memory
;--- DS=GROUP16, ES=FLAT
;--- modifies ebx,ecx,edx

setuphoststack proc public
	@dprintf "setuphoststack: reserve %X pages for host stack", word ptr ?STACKPAGES
 if _LTRACE_
	mov eax, dwSSBase
	mov eax, es:[eax+offset ltaskaddr]
	@dprintf "setuphoststack: dwSSBase=%lX ltaskaddr=%lX wLDTLimit=%X",dwSSBase, eax, wLDTLimit
 endif
 if ?MAPDOSHIGH
	mov ecx,?STACKPAGES		;reserve 3 (or 5 if IOPL==0) pages
	call pm_AllocSysAddrSpace
	jc error
	mov ebx, eax
	mov ecx,2				;into the first 2 the host's DOS code is mapped
	mov eax,dwSSBase
	xor edx,edx
	mov dl,PTF_WRITEABLE
	call pm_CopyPTEs
	lea eax,[ebx + 2 * 1000h]
	mov ecx,?STACKPAGES - 2	;the rest is used for (TSS and) host stack
;	push edx
	mov dl,PTF_PRESENT or PTF_WRITEABLE
	call pm_CommitRegionZeroFill	;commit region eax, ecx pages
;	pop edx
	jc error
	mov eax, dwSSBase
	and eax, 0FFFh
	lea eax, [ebx+eax]

	lea ebx,[ebx+?STACKPAGES * 1000h]
	sub ebx, eax

	mov edx, eax
	neg edx
	add edx,dwSSBase
	add edx,offset v86iret
	@dprintf "setuphoststack: old/new HS base=%lX/%lX, new v86iret esp=%lX", dwSSBase, eax, edx
	mov v86iretesp, edx
	mov dwSSBase, eax

	mov ecx, pdGDT.dwBase
	push eax
	mov es:[ecx+_SSSEL_].DESCRPTR.A0015, ax
	shr eax,16
	mov es:[ecx+_SSSEL_].DESCRPTR.A1623, al
	mov es:[ecx+_SSSEL_].DESCRPTR.A2431, ah
	pop eax

  if 1	;v3.19: set linear address of TSS to high memory
	lea edx,[eax+offset taskseg]
	mov es:[ecx+_TSSSEL_].DESCRPTR.A0015, dx
	shr edx,16
	mov es:[ecx+_TSSSEL_].DESCRPTR.A1623, dl
	mov es:[ecx+_TSSSEL_].DESCRPTR.A2431, dh
   if ?PMIOPL eq 0
;--- set limit of TSS and iobitmap offset if IOPL==0
	push eax
	lea edx,[eax+offset taskseg]
	add eax, 2000h
	and ax, 0F000h
	sub eax, edx
	mov ss:[taskseg.wOffs], ax
;	add ax, 2000h-1
	add ax, 2000h		; size of the IOPB must be 8k+1!
	mov es:[ecx+_TSSSEL_].DESCRPTR.limit, ax
	pop eax
   endif
  endif

	add ecx, _TSSSEL_
	sub ecx, eax
	mov dwTSSdesc, ecx

 else
	mov ecx,?STACKPAGES
	call pm_AllocSysPagesS
	jc error
	lea ebx, [eax+?STACKPAGES*1000h]
	sub ebx, dwSSBase
 endif
	mov eax,ebx
	sub ebx, 0F80h
	mov dwStackTop, ebx
	mov dwHostStack, eax
;--- no displays until SS has been reset!
;	@dprintf "setuphoststack: new host stack top=%lX, bottom=%lX", dwStackTop, eax
error:
	ret
setuphoststack endp
endif	;if ?HSINEXTMEM


INITCLPM struct	;protected mode stack frame
	PUSHADS <>
rDS	dd ?
	IRET32	<>
INITCLPM ends

;--- @makeinitclpmframe is invoked when esp==[dwHostStack]
;--- it first pushes the current segment register values of pmstate.
;--- however, macro @store_ssesp expects [dwHostStack] to point ABOVE
;--- an IRET32 struct.
;--- that's a problem when the host is reentered during initialization
;--- (for example due to callouts for debug displays) and a rmcb/irq is
;--- then routed to pm.
;--- v3.22: as a fix, ?SAVESSESPONINIT has been introduced (for _DEBUG).

;--- v3.23: switch now always 1;
;---        this ensures that theres a valid ss:esp below [dwHostStack]
;---        if another client is starting (for the first client it's still
;---        invalid, but shouldn't matter).
;---        test case: a client hooks an IRQ that's getting active while
;---        another client is initializing.

;ifdef _DEBUG
?SAVESSESPONINIT equ 1
;else
;?SAVESSESPONINIT equ 0
;endif

@makeinitclpmframe macro
if ?SAVESSESPONINIT
	push pmstate.rSSd
	push pmstate.rESP
endif
	push pmstate.rFSGS
	push pmstate.rESDS
	mov dwHSsaved,esp
;--- build a INITCLPM frame
	sub esp, sizeof IRET32 + 4
	pushad
	mov ebp, esp
endm

if ?VM

	@ResetTrace

;--- heap function to call when a new VM is created

hp_createvm proto

;--- CreateVM is called by initclient_pm
;--- during client's initial switch to protected-mode
;--- but not for the first client and only if -a
;--- cmdline switch ( or HDPMI=32 ) is set.
;--- the following data is cloned:
;--- + the host's GROUP16 segment (with adjustments)
;--- + the CLDATA32 part
;--- + GDT, IDT
;--- EBP -> client standard registers (PUSHADS)
;--- ES = FLATSEL
;--- DS = SS = GROUP16


CreateVM proc

	movzx eax,v86iret.rES
	@dprintf "CreateVM enter, task data=%X, client stack=%lX", ax, edi
	shl eax, 4
if 0
	mov edi, eax
	mov ecx, ?RMSTKSIZE/4
	xor eax, eax
	rep stosd
	@dprintf "CreateVM: new real-mode stack cleared"
else
	lea edi, [eax+?RMSTKSIZE]
endif
	push edi				;will become linear address of new instance (in conv. memory)
	mov ds:taskseg._Edi, edi;save new base here temporarily

;--- we need ltaskaddr, it's in _DATA16C, so copy it to _DATA16
	mov eax, ltaskaddr
	mov ds:taskseg._Esi, eax	;save it in _DATA16, so it won't be overwritten

;--- now copy the full 16-bit part!
;--- v3.19: The source has to be the true conventional memory, not the "remapped"
;--- DOS pages, because these are just 2 pages - for the debug version this might
;--- not be enough to contain the full resident part.
	call getclonesize
	movzx esi, ds:wHostSeg

;--- set ds=flatsel
	push es
	pop ds

	shl esi,4
	shl ecx, 2
	rep movsd
	@dprintf "CreateVM: %X paragraphs real-mode code + host data copied", ss:wCloneSize

;--- reinitialize contents of _DATA16V and _DATA16C 
	mov esi, eax
	mov ecx, offset _EndOfClientData
	sub ecx, offset _StartOfVMData
	@dprintf "CreateVM: prev client VM data=%lX (size %lX)", esi, ecx
	shr ecx, 2
	mov edi,[esp]	;get new base
	add edi, offset _StartOfVMData
	rep movsd
	@dprintf "CreateVM: client + VM data copied, edi=%lX",edi

;--- setup clone's GDT
	mov ecx,(?GDTLIMIT+1)/4
if ?MOVEGDT
	test ss:bEnvFlags2, ENVF2_LDTLOW	;IDT+LDT in user space?
	jz @F
	mov edx,[esp]	;get new base
	add edx,offset curGDT	;EDX = new GDT address
;--- if GDT is in conv. memory, it has been copied already!
	@dprintf "CreateVM: GDT in conv. memory, new base=%lX", edx
	jmp gdt_copied
@@:
endif
;--- create new GDT
;--- copy GDT temporarily in TLB
	mov edi, ss:dwSegTLB
	shl edi, 4
	mov edx, edi		;EDX = new GDT address
	mov esi, ss:pdGDT.dwBase
	rep movsd
	@dprintf "CreateVM: GDT copied to %lX (temp location in TLB), ds=%lX", edx, ds
gdt_copied:

	mov eax, [esp]		;get new dwSSBase
	mov [edx+_SSSEL_].DESCRPTR.A0015,ax
if ?MOVEHIGHHLP
	mov [edx+_CSGROUP16_].DESCRPTR.A0015,ax
endif
	shr eax,16
	mov [edx+_SSSEL_].DESCRPTR.A1623,al
	mov [edx+_SSSEL_].DESCRPTR.A2431,ah
if ?MOVEHIGHHLP        
	mov [edx+_CSGROUP16_].DESCRPTR.A1623,al
	mov [edx+_CSGROUP16_].DESCRPTR.A2431,ah
endif
	pop eax		;get new dwSSBase
	add eax, offset taskseg
	mov [edx+_TSSSEL_].DESCRPTR.A0015,ax
	shr eax,16
	mov [edx+_TSSSEL_].DESCRPTR.A1623,al

;--- v3.18: restore rmSSSP in source instance
	push ss:dwrmSSSPsave
	pop ss:v86iret.rSP
	pop ss:v86iret.rSS

;--- set new GDT, reload SS and DS caches

	push edx
	pushw ?GDTLIMIT
	lgdt fword ptr [esp]

;--- reload client standard registers
	mov esp, ebp
	popad
;--- set DS to new GROUP16
	push ss
	pop ds

;--- set SS to new GROUP16 base
	push ss
	pop ss
;--- now base of SS is new host base, GROUP16 variables of clone
;--- may be accessed from now on!

if ?HSINEXTMEM
;--- use the TLB temporarily as host stack
	mov esp, dwSegTLB
	shl esp, 4
	add esp, ?TLBSIZE
	sub esp, taskseg._Edi	;taskseg._Edi = new dwSSBase
;	mov taskseg._Esp0, esp
 if ?MAPDOSHIGH
	mov v86iretesp, offset v86iret
 endif
endif

;--- recreate a INITCLPM struct on new stack;
;--- readdress client standard registers with EBP
;--- if hs will be in extended memory, this will be
;--- done below after a new hoststack has been allocated.
ife ?HSINEXTMEM
	sub esp, sizeof IRET32 + 4
endif
	pushad
	mov ebp, esp

	mov eax, taskseg._Edi
	mov dwSSBase, eax
	mov ecx, dwSegTLB
	shl ecx, 4
	test bEnvFlags2, ENVF2_LDTLOW
	jz @F
	lea ecx, [eax + curGDT]
@@:
	mov pdGDT.dwBase, ecx
	mov pdGDT.wLimit, ?GDTLIMIT
	mov ecx, eax
	shr eax, 4

;--- repatch code in new GROUP16

	mov v86iret.rCS, ax	;GROUP16
;	mov v86iret.rSS, ax	;GROUP16
	mov wHostSeg, ax	;GROUP16
if ?MOVEHIGHHLP
	mov wPatchGrp161, ax;GROUP16
endif
	mov wPatchGrp162, ax;GROUP16
	mov wPatchGrp163, ax;GROUP16

;--- reset FM_RESIDENT and FM_TLBMCB (we use the TLB of the parent)
;--- also, don't assume the real-mode vectors have been saved!
;--- they must be resaved. 

	and fMode, not (FM_RESIDENT or FM_TLBMCB)
	or fMode, FM_CLONE

;--- some functions of filldesc must be reexecuted here
;--- ecx=dwSSBase

	lea eax,[ecx+ pdGDT]	;address GDT pseudo descriptor
	mov v86topm._gdtr,eax

	lea eax,[ecx+ pdIDT]	;address IDT pseudo descriptor
	mov v86topm._idtr,eax

	lea eax,[ecx+ v86topm]
	mov [linadvs],eax		;patch code in rawjmp_pm

	mov wLDTLimit, 0
	mov pRMSel, 0			;just to be sure
	mov al,-2
if ?INTRM2PM
	mov int96hk.bInt, al	;do not hook int 96/int 2F
endif
	mov int2Fhk.bInt, al	
	mov eax, pdGDT.dwBase
	add eax, _TSSSEL_
	sub eax, dwSSBase
	mov dwTSSdesc, eax		;this var must be init for real-mode access

;--- restore ltaskaddr
	mov eax, taskseg._Esi
	mov ltaskaddr, eax

if _LTRACE_
	mov ecx, pdGDT.dwBase
	mov dl,es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.A1623
	mov dh,0
	shl edx, 16
	mov dx,es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.A0015
endif
	@dprintf "CreateVM: GDT.base=%lX, dwSSBase=%lX, wSegTLB=%X, TLB=%lX", pdGDT.dwBase, dwSSBase, wSegTLB, edx
	@dprintf "CreateVM: taskseg.esp0=%lX, ltaskaddr=%lX", taskseg._Esp0, ltaskaddr

;--- let the heap mgr do its reinitialization
	call hp_createvm

	@dprintf "CreateVM: GDT and instance switched, new instance=%X, RMS=%X:%X", wHostSeg, v86iret.rSS, v86iret.rSP

;--- let the page manager do its reinitialization
	@dprintf "CreateVM: calling pm_createvm"
	call pm_createvm
	jc error
	@dprintf "CreateVM: pm_createvm called, ltaskaddr=%lX",ltaskaddr

	call mem_createvm

if ?HSINEXTMEM
	call setuphoststack	;this will modify dwSSBase and reload SS/DS caches!
	jc error
	mov esp, ebp
	popad
	push ds
	pop ds
	push ss
	pop ss
	mov esp, dwHostStack
	@makeinitclpmframe
	@dprintf "CreateVM: hoststack init, ss/ds reloaded, hoststack=%lX dwSSBase=%lX ltaskaddr=%lX", dwHostStack, dwSSBase, ltaskaddr
endif


;--- since the return address has been lost,
;--- a new one has to be pushed.
	push offset behindcreatevm

	test fHost, FH_XMS or FH_VCPI	;in raw mode?
	jnz @F
;--- in raw mode hook int 15h again.
;--- this is because our page pool is the current one
	movzx edi, int15hk.wOldVec
	mov ax, wHostSeg
	shl eax, 16
	mov ax, int15hk.wNewOfs
	mov ebx, 15h*4
	xchg eax, es:[ebx]	;get and set the IVT value
	mov [edi],eax		;save the old value
@@:

;--- now copy _DATA32C

	call _getcldata32	;return: eax=offset of cldata32 in ltaskaddr
	mov esi, ltaskaddr
	push es
	pop ds				;DS = FLATSEL?
	push byte ptr _CSALIAS_
	pop es				;ES = GROUP32
	add esi, eax
	mov edi, offset startcldata32
ifdef ?PE
	mov ecx, ?SIZECLDATA32
else
	mov ecx, offset endcldata32
	sub ecx, edi
endif
	@dprintf "CreateVM: cldata32 src=%lX, dst=%lX siz=%lX [%lX %lX]",\
		esi, edi, ecx, dword ptr [esi], dword ptr [esi+4]
	shr ecx, 2
	rep movsd
	push ds
	pop es			;ES = FLATSEL
	push ss
	pop ds			;DS = DGROUP16

;--- the IDT has to be moved high in any case, either in
;--- system space (ff8xxxxx) or user space (11xxxx)
	call _movehigh		;allocates+inits CD30s + IDT
	jc error
	@dprintf "CreateVM: movehigh_pm called, edi=%lX", edi

;--- again: re-access the client's stack with EDI

	call _initfirstclient		;host initialization on first client
	jc error
	@dprintf "CreateVM: initfirstclient called, ltaskaddr=%lX", ltaskaddr
	mov ltaskaddr, 0		;avoid to restore task state
	@dprintf "CreateVM exit"
	ret
error:
	jmp behindcreatevm
CreateVM endp

;--- get size of clone in paras

getclonesize proc
	xor ecx, ecx
	test ss:bEnvFlags, ENVF_VM
	jz @F
 if ?MOVEGDT
	mov cx, offset curGDT
	test ss:bEnvFlags2, ENVF2_LDTLOW
	jz @F
 endif
	mov cx, offset endofgdtseg
@@:
	shr ecx, 4
	ret
getclonesize endp

updateclonesize proc public
	push ecx
	call getclonesize
	mov ss:[wCloneSize], cx
	pop ecx
	ret
updateclonesize endp

endif


;--- called by _restoreclientstate
;--- ( must be here because subtraction of 2 external offsets can't be done )
;--- the current client has terminated, but may not have restored all IRQs.
;--- in: ESI=saved state of previous client

restoreV86Hooks proc public

	xor ebp, ebp
	cmp esi, 0
	jz @F
	mov edi, offset _StartOfClientData
	sub edi, offset _StartOfVMData
	add edi, esi
	sub edi, [dwSSBase]
	add edi, offset dwIntRmCb - offset _StartOfClientData
	mov ebp, [edi]		; get the old value of dwIntRmCb
@@:
	mov ecx, [dwIntRmCb]
	and ecx, 1ffffh		; skip int 23/24, just IRQs and int 1Ch
	xor edx, edx		; start with bit 0
nexthook:
	btr ecx, edx		; client has hooked IRQ?
	jnc skiphook
	bt ebp,edx			; IRQ was hooked?
	jc skiphook
	movzx ebx, cs:[edx][intrmcb_int]
if ?JHDPMI
	bt [dwExtHook], edx
	jc jhdpmi_type
endif
	mov eax, ss:[edx*4][intrmcbrs].rm_vec
	shl ebx, 2
	sub ebx, [dwSSBase]
	mov [ebx], eax
	jmp skiphook
if ?JHDPMI
jhdpmi_type:
	mov ax, JHD_UNHOOKIRQ
	pushd offset jhdpmicall
	call callrmprocintern
endif
skiphook:
	inc edx
	and ecx, ecx
	jnz nexthook
donehook:
	ret
restoreV86Hooks endp


_initclientstate proc
if ?MOU33RESET
	cmp word ptr cs:mevntvec._Cs, 0
	jz @F
	call mouse33_reset			;event proc, reset it now
@@:
endif
	ret
_initclientstate endp

INITCLRM struct	;real mode stack frame
wFlags	dw ?
wIP		dw ?
wCS		dw ?
INITCLRM ends

;--- client initialization protected mode

	@ResetTrace

_initclient_pm proc

	push ss
	pop ds
	assume ds:GROUP16
	push byte ptr _FLATSEL_
	pop es

	@makeinitclpmframe
	xor eax,eax
	mov fs,eax
	mov gs,eax

;--- the RMS of the previous client cannot be used (for DOS/BIOS calls);
;--- but it must be saved in client data space
;--- then set the RMS NOW, before saveclientstate(), to the client area;
;--- if this instance is to become a clone, the RMS of the source will
;--- be restored inside CreateVM!!!
	push v86iret.rSS
	push v86iret.rSP
	pop dwrmSSSPsave
	mov ax,v86iret.rES
	mov v86iret.rSP, ?RMSTKSIZE
	mov v86iret.rSS, ax

;--- before calling out ( to DOS/BIOS, anything that enables interrupts ), it has
;--- to be ensured that [dwHostStack] points ABOVE an IRET32 struct, because that is
;--- what macro @store_ssesp assumes.

	@dprintf "initclient: instance=%X, pmst.DS/ES=%X/%X RMS=%X:%X tss.esp0=%lX, esp=%lX",\
		wHostSeg, pmstate.rDS, pmstate.rES, v86iret.rSS, v86iret.rSP, taskseg._Esp0, esp

	test fMode, FM_INIT
	jnz @F
	call _initfirstclient		;host initialization on first client
	jc initclerr0
	@dprintf "initclient: initfirstclient returned"
	or fMode, FM_INIT
@@:

if ?VM
	test bEnvFlags, ENVF_VM
	jz novm
	cmp cApps,0
	jz firstvm
	call CreateVM		;expects EBP=client registers (PUSHADS )
behindcreatevm::        
	jc initclerr10
	jmp vmok
firstvm:
	call updateclonesize
novm:
endif
	@dprintf "initclient: calling saveclientstate, esp=%lX", esp
	call _saveclientstate	;increments cApps
	jc initclerr11			;no memory

	call _initclientstate
vmok:
if ?TLBLATE
	call settlb_pm
	jc initclerr20
endif

if 0;?CR0COPY	;now done for first client only        
	mov eax,cr0				;use CR0, lmsw cannot set NE bit!
	and al, bFPUAnd
	or al, bFPUOr
	mov cr0,eax
endif
	test bEnvFlags2,ENVF2_SYSPROT
	jz @F
	call setcr0wpbit
@@:
if ?CLEARDR6
	xor eax, eax
	mov dr6, eax
endif

	mov bx,v86iret.rDS

;--- get selector for DS
	@dprintf "initclient: call getrmdesc for DS"
if ?32BIT
	mov cx,4000h
else
	xor ecx,ecx
endif
	call getrmdesc
	jc initclerr21
	@dprintf "initclient: DS=%X, real mode DS=%X", ax, v86iret.rDS
	mov [ebp].INITCLPM.rDS,eax
	mov [ebp].INITCLPM.rSS,ax

	movzx eax, wInitSP
	movzx edi, wInitSS
	shl edi, 4
	add edi, eax
	add ax, sizeof INITCLRM
	mov [ebp].INITCLPM.rSP, eax
	mov ax, es:[edi].INITCLRM.wIP
	mov [ebp].INITCLPM.rIP, eax
	pushfd
	pop eax
	mov ax, es:[edi].INITCLRM.wFlags
	and ax, 8FFEh			; clear CF, IOPL, NT
if ?PMIOPL
	or ah, ?PMIOPL shl 4	; set protected-mode IOPL
else
	test ah, 2				; IF set?
	jz @F
	test byte ptr dwFeatures, 2	; PVI supported?
	jz @F
	.586
	mov ecx, cr4
	.386
	test cl, 2				; PVI set?
	jz @F
	bts eax, 19				; set VIF
@@:
endif
	mov [ebp].INITCLPM.rFL, eax

;--- get selector for CS
	mov bx,es:[edi].INITCLRM.wCS
	mov cx,0008 			;attrib CODE
	call getrmdesc
	jc initclerr23
	@dprintf "initclient: CS=%X, real mode CS=%X", ax, es:[edi].INITCLRM.wCS
	mov [ebp].INITCLPM.rCS, ax

;--- get selector for SS
	mov bx,[wInitSS]
;	cmp bx,es:[edi].INITCLRM.wDS
	cmp bx,v86iret.rDS
	jz @F
if ?32BIT
	mov cx,4000h
else
	xor ecx,ecx
endif
	call getrmdesc
	jc initclerr22
	@dprintf "initclient: SS=%X, real mode SS=%X", ax, [wInitSS]
	mov [ebp].INITCLPM.rSS, ax
@@:
if 0
	@dprintf "first dos call, disp '#'"
	mov ah,02h
	mov dl,'#'
	call rmdosintern
endif

if ?SAVEPSP
	mov eax,[dwSDA]
	mov bx,es:[eax].DOSSDA.wPSP
	@dprintf "initclient: PSP from real-mode dos=%X",bx
	mov [wPSPSegm],bx
	call getpspsel
	jc initclerr24
else
	@dprintf "initclient: first dos call, get PSP"
	mov ah,51h
	@int_21		;may fail and then won't return!
	@dprintf "initclient: protected mode PSP=%X",bx
endif
	mov es,ebx
	assume es:SEG16
	mov bx,es:[002ch]		;environment segment
	and bx,bx
	jz @F
	xor ecx,ecx
	call getrmdesc
	jc initclerr24
	mov es:[002ch],ax		;set environment selector
	@dprintf "initclient: ENV=%X", ax
@@:

if ?INT21API
	mov ah,2Fh
	call rmdosintern	;get DTA in ES:BX
	movzx ebx,bx
	mov dword ptr [dtaadr+0],ebx
  ife ?DTAINHOSTPSP
	movzx eax, v86iret.rES
	shl eax, 4
	add eax, ebx
	mov dwDTA, eax
  endif
	lea eax,[ebx+80h-1]
	mov bx, v86iret.rES
	call allocxsel		;should return the already translated PSP selector
;	jc initclerr24
	mov word ptr [dtaadr+4],ax
  if ?DTAINHOSTPSP
	call resetdta
  endif
endif
if ?LOCALINT2324
	mov cx,_INTSEL_
if ?32BIT
	mov edx,_INT23_
else
	mov dx,_INT23_
endif
	mov bl,23h
	mov ax,205h
	@int_31
if ?32BIT
	mov edx,_INT24_
else
	mov dx,_INT24_
endif
	mov bl,24h
	@int_31
endif
if ?WDEB386
	test fDebug,FDEBUG_KDPRESENT
	jz @F
if 0 ;no longer required, use HDPMI=8192, works with any debugger
	mov cx,[ebp].INITCLPM.rCS
	mov ebx,[ebp].INITCLPM.rIP
	mov ax,DS_ForcedGO
	int Debug_Serv_Int
endif
	mov ebx,[pdIDT.dwBase]
	push ds
	push byte ptr _FLATSEL_
	pop ds
	or byte ptr [ebx+41h*sizeof GATE + GATE.attrib+1],60h
	pop ds
@@:
endif
	lea eax,[ebp + sizeof INITCLPM]
	mov ds:taskseg._Esp0, eax
	@dprintf "initclient: client status ok, ebp=%lX, ss:esp=%lX:%lX", ebp, ss, esp
	@dprintf "initclient: client: CS:IP=%X:%lX, SS:SP=%X:%lX, DS=%lX",[ebp].INITCLPM.rCS, [ebp].INITCLPM.rIP, [ebp].INITCLPM.rSS, [ebp].INITCLPM.rSP,[ebp].INITCLPM.rDS
	@dprintf "initclient: GDT: %lX (%X), IDT: %lX (%X), LDT: %lX (%X)", pdGDT.dwBase, pdGDT.wLimit, pdIDT.dwBase, pdIDT.wLimit, dwLDTAddr, wLDTLimit

if ?BRKONENTRY
	test bEnvFlags2, ENVF2_DEBUG	;HDPMI=8192 set?
	jz @F
_TEXT32R3 segment
r3exc3:
	int 3
	retf
_TEXT32R3 ends
	push es
	les edi,[ebp].INITCLPM.rSSSP
	sub edi,2*4
	mov [ebp].INITCLPM.rSP,edi
	mov eax, offset r3exc3
	xchg eax,[ebp].INITCLPM.rIP
	stosd
	mov ax,_CSR3SEL_
	xchg ax,[ebp].INITCLPM.rCS
	stosd
	pop es
@@:
endif
	popad
if ?32BIT
  if ?CLEARHIWORDS
	test bEnvFlags2,ENVF2_CLRHIWORD
	jz @F
	movzx esi,si
	movzx edi,di
@@:
  endif
endif
	pop ds
	iretd

	assume ds:GROUP16

initclerr0:			;error global init PM
	@dprintf "init err0: initfirstclient failed"
	mov al,13h		;out of physical memory
	jmp termserver
initclerr10:		;createvm failed
;--- pm_createvm has ensured that a minimum of memory is available BEFORE
;--- starting to create the clone. So if there's an error, it happened
;--- very early, and no memory has been allocated yet - no need to do cleanup
;--- (which is rather difficult without doing an int 21h, ax=4c00h ).
	@dprintf "init err10: createvm failed, cApps=%X", word ptr ss:cApps
if _LTRACE_
	jmp @F
endif
initclerr11:		;saveclientstate failed
	@dprintf "init err11: saveclientstate failed"
if _LTRACE_
	jmp @F
endif
@@:
	mov al,14h		;what does error 8014h mean?
	test fMode, FM_RESIDENT
	jnz termclient2
	cmp [cApps],0
	je termserver
	jmp termclient2
if ?TLBLATE
initclerr20:		;settlb_pm failed
	@dprintf "init err20: settlb_pm failed"
 if _LTRACE_
	jmp @F
 endif
endif
initclerr21:		;cant alloc DS sel
	@dprintf "init err21: can't alloc DS sel"
if _LTRACE_
	jmp @F
endif
initclerr22:		;cant alloc SS sel
	@dprintf "init err22: can't alloc SS sel"
if _LTRACE_
	jmp @F
endif
initclerr23:		;cant alloc CS sel
	@dprintf "init err23: can't alloc CS sel"
if _LTRACE_
	jmp @F
endif
initclerr24:		;cant alloc ENV/PSP sel
	@dprintf "init err24: can't alloc ENV/PSP sel"
@@:
	mov al,11h		;8011: out of descriptors
initclerr:
	test fMode, FM_RESIDENT
	jnz termclient
	cmp [cApps],1	;cApps has been increased inside saveclientstate; so 1 means
	jbe termserver	;no client is running yet.
termclient:
	push ds			;ensure ES contains no ring3 selector   
	pop es
	call _restoreclientstate	;important: rms restore
termclient2:
	mov ah,80h
	mov [ebp].PUSHADS.rAX, ax
	mov esp, ebp
	popad
	lea esp, [esp+ sizeof IRET32 + 4]
	pop pmstate.rESDS
	pop pmstate.rFSGS
if ?SAVESSESPONINIT
	add esp, 2*4
endif
	@rawjmp_rm _initclienterr_rm

;--- no client running as of yet;
;--- the host will be shut down.

termserver:
	mov ah,80h
	mov [ebp].PUSHADS.rAX, ax
	mov esp, ebp
	popad

	@printf <"hdpmi: cannot initialize [%X]",lf>, ax

	push byte ptr _FLATSEL_
	pop es
	call restoreivtvecs

;--- this is tricky and should be improved: after server
;--- shutdown we want to return to the caller.
	pushd offset _initclienterr_rm
	jmp _exitserver_pm 	;preserves ax, back in real mode
	align 4

_initclient_pm endp


	@ResetTrace

;--- check if an interrupt is in service
;--- if so, send EOI to pic
;--- returns request in AX

?RESETKBD equ 1

closeinterrupts proc public

	mov al,0Bh		;irq 8-15 in service?
	out 0A0h,al
	in al,0A0h
	mov ah,al
	and al,al
	jz @F
	mov al,20h
	out 0A0h,al		;slave PIC EOI
@@:
	mov al,0Bh		;irq 0-7 in service?
	out 20h,al
	in al,20h
	and al,al
	jz exit
	push eax
if ?RESETKBD
	in al,64h
	test al,1h		;data at port 60h?
	jz no_kbd
	in al,60h		;ack keyboard and/or ps/2
no_kbd:
;	mov al,0AEh		;send "enable kbd"
;	out 64h,al
endif
	mov al,20h
	out 20h,al		;master PIC EOI

	pop eax
exit:
	ret
	align 4
closeinterrupts endp

;--- exit a client, possibly exit server as well

?ALWAYSRESTORE	equ 1	;restore task state always (a dummy task state exists)

if ?CHECKLPMS
_exitclientEx7:
	@dprintf "lpms_call_exc: LPMS out of space, edi=%lX, fatal exit", edi
	mov ax,_EAERR7_
	jmp _exitclientEx
endif

if ?CHECKHOSTSTACK
_exitclientEx5 proc public
	mov ax,_EAERR5_
	jmp _exitclientEx
_exitclientEx5 endp
endif

ife ?RMCBSTATICSS
_exitclientEx4 proc public
	mov ax,_EAERR4_		;real-mode callback: no more descriptors for rm ss
_exitclientEx4 endp ;fall through
endif

_exitclientEx proc near public

if (?DOSOUTPUT eq 0) or (?FORCETEXTMODE eq 1)
	call forcetextmode
	@DebugBreak 0
endif
	@printf <lf,"hdpmi: fatal exit %X",lf,lf>,ax

_exitclientEx endp ;fall through

	@ResetTrace

;--- client terminated with int 21h, ah=4Ch
;--- also jumped to from exception handler to terminate client

_exitclient_pm proc public
	@DebugBreak 0
	push ss
	pop ds
	assume DS:GROUP16

;--- don't skip the IRET32 frame if callouts will happen and the host may be reentered!
;--- v3.22: for callouts it is important that a IRET32 frame is "below" the value
;--- of dwHostStack - the current value of ESP isn't relevant.
;--- since "taskseg._Esp0" is an alias for dwHostStack, any "push" will actually destroy the contents
;--- of that IRET32 frame!. So the next line has been deactivated generally.
if 0;ndef _DEBUG
	mov esp, taskseg._Esp0	;skip the IRET32 from ring3 entry
endif

;--- don't save anything onto the stack, it is modified inside the proc
	mov ds:taskseg._GS, eax

	push byte ptr _FLATSEL_
	pop es
	@dprintf "exitclient enter, cApps=%X, task=%lX RMS=%X:%X, esp=%lX", word ptr cApps, ltaskaddr, v86iret.rSS, v86iret.rSP, esp
	call closeinterrupts
	cmp [cApps],0			;fatal error on host initialization?
	jz exitclient_1
if ?ALWAYSRESTORE
;--- make sure host is not reentered now (VCPI free memory)
	in al, 21h
	push eax
	mov al, -1
	out 21h, al
endif
	@dprintf "exitclient: call freeclientmemory"
	call _freeclientmemory	;no register modified
	@dprintf "exitclient: call pm_exitclient"
	call pm_exitclient		;no register modified

if ?ALWAYSRESTORE
	@dprintf "exitclient: call restoreclientstate, taskseg._Esp0=%lX, dwHoststack=%lX", taskseg._Esp0, dwHostStack
	call _restoreclientstate	;no register modified
	pop eax
	out 21h, al

;--- 3.22: esp is set to dwHSsaved (which has been set during initclient()!), the IRET32 frame gets lost!
;--- however, the old IRET32 frame "below" dwHostStack is no longer reliable since the segment parts 
;--- may not contain valid selectors anymore after _restoreclientstate.
;--- When ESP is set to dwHSsaved, it points to the frame setup by @makeinitclpmframe.
;--- That's why the "pop pmstate.xxx" below work.

	mov esp, dwHSsaved

endif

;--- callouts after esp has been set to dwHSsaved
;--- can only be made if _DEBUG is active ( see @makeinitclpmframe ).
	@dprintf "exitclient: last task check, taskseg._Esp0=%lX, esp=%lX", taskseg._Esp0, esp

if ?ALWAYSRESTORE
	cmp [cApps],0
	jz exitclient_1
else
	cmp [cApps],1
	jbe exitclient_1
endif

exitclient_2:
	@dprintf "exitclient: client about to terminate"
ife ?ALWAYSRESTORE
	@dprintf "exitclient: call restoreclientstate"
	call _restoreclientstate	;no registers modified
	mov esp, dwHSsaved
endif

	@dprintf "exitclient: jump to exitclient_rm, RMS=%X:%X [esp]=%lX",\
		v86iret.rSS, v86iret.rSP, dword ptr [esp]

	mov eax,taskseg._GS	;get return code

;--- these can't be restored earlier because any DOS/BIOS output will destroy pmstate
	pop pmstate.rESDS
	pop pmstate.rFSGS
if ?SAVESSESPONINIT
	add esp, 2*4	; skip pm esp/ss saved by @makeinitclpmframe
endif
	@rawjmp_rm _exitclient_rm
        
;--- either last client terminates
;--- or server terminates without client (fatal exit on init)
;--- ES=FLAT, DS=GROUP16
        
exitclient_1:
if ?CR0COPY
	mov eax,cr0
	@dprintf "current CR0=%lX",eax
	and al, bFPUAnd
	test bEnvFlags2,ENVF2_SYSPROT
	jz @F
	btr eax,CR0_WPbit
@@:
	or al, bCR0
	mov cr0,eax
	@dprintf "restored CR0=%lX",eax
endif        
if ?TLBLATE
	call resettlb_pm
endif
	@dprintf "no more clients, call restoreivtvecs (can server terminate?)"
	call restoreivtvecs 		;check IVT
	jc exitclient_2		;keep resident on errors
ife ?MOU33RESET
	call mouse33_reset
endif
	@dprintf "server termination would be ok"
if ?RESIDENT
	test fMode, FM_RESIDENT
	jnz exitclient_2
endif
	@dprintf "server about to terminate"

	mov eax,taskseg._GS			;get return code

	pushd offset _dosexit_rm
	jmp _exitserver_pm 	;will return to real mode
	align 4

_exitclient_pm endp

if ?TLBLATE

	@ResetTrace

;--- is called when server goes idle (no clients)
;--- DS=GROUP16, ES=FLAT
        
resettlb_pm proc

	@dprintf "resettlb_pm, tlbseg=%X", wSegTLB
	test fMode2, FM2_TLBLATE
	jz exit
	test fMode, FM_TLBMCB
	jz exit
	cmp wSegTLB,0
	jz exit
	pushad
	mov eax,[dwSDA]
	mov bx,es:[eax].DOSSDA.wPSP
	@dprintf "resettlb_pm: set owner TLB to current PSP %X", bx
	xor eax, eax
	xchg eax, dwSegTLB	;clears wSegTLB
	dec eax
	shl eax,4
	mov es:[eax+1],bx
	mov ecx, pdGDT.dwBase
	and es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.attrib,not 2	;readonly
	and fMode, not FM_TLBMCB
	popad
exit:
	ret
	align 4
resettlb_pm endp
endif

	@ResetTrace

;--- this proc will first check all vectors if they can be restored
;--- if yes, they will be restored
;--- in: DS=GROUP16, ES=FLAT
;--- out: C if vectors cannot be restored
;--- v3.22: all IRQ vectors are already restored when this proc is called
;--- (either by client itself or by restoreV86Hooks(). So this code
;--- has becomre mostly useless ( except for checking Int 2F and jhdpmi disconnect ).

	@ResetTrace
;_LTRACE_ = 1

restoreivtvecs proc 

	assume DS:GROUP16

;--- AH: bit0: 0=test mode, 1=restore mode
;---     bit1: 1=error occured

	pushad
	@dprintf "restoreivtvecs: try to restore ivt vectors, fMode=%X", word ptr fMode

	mov ah, 00
	mov di, wHostSeg				;GROUP16

	mov cl,TESTINTRMCB				;check IRQs and int 1C

	test fMode, FM_CLONE
	jnz l2
	cmp es:[2Fh*4+2], di			;check vector 2Fh in IVT
	jz l2
	@dprintf "restoreivtvecs: rm int 2Fh cannot be restored"
	mov ah,2
	jmp exit
restorestart:
	@dprintf "restoreivtvecs: label restorestart reached"
	mov cl,SIZEINTRMCB
	mov ah,01
l2:
	mov di, wHostSeg				;GROUP16
	xor ebx, ebx
nextvec:
	bt [dwIntRmCb], ebx
	jnc skipvec

	movzx edx, cs:[ebx][intrmcb_int]
	@dprintf "restoreivtvecs: ivt-vector %X=%lX", dx, dword ptr es:[edx*4]

if ?JHDPMI
	bt [dwExtHook], ebx				;no check for vectors that are handled by jhdpmi
	jc skipvec
endif
	test ah,01h						;test mode?
	jnz @F
	cmp es:[edx*4+2], di			;there might be the case that the app 
	jz skipvec						;itself has restored the IVT vector
	push eax
	mov eax, [ebx*4][intrmcbrs].rm_vec
	cmp eax,es:[edx*4]				;cmp with IVT vector
	pop eax
	jz skipvec
	@dprintf "restoreivtvecs: rm int %X cannot be restored", dx
	or ah,2							;save this in AH
	jmp skipvec
@@:
	push [ebx*4][intrmcbrs].rm_vec
	pop dword ptr es:[edx*4]		; restore IVT vector
skipvec:
	inc di
	inc ebx
	dec cl
	jnz nextvec
	cmp ah, cl
	jz restorestart
if ?JHDPMI
 if ?VM
	test [fMode], FM_CLONE
	jnz @F
 endif
	cmp [dwExtHook],0
	jz @F
	test [fMode], FM_RESIDENT
	jnz @F
	mov ax, JHD_DISCONNECT
	pushd offset jhdpmicall
	call callrmprocintern
	mov ah, 0
@@:
endif
exit:
	shr ah,2						;return with C if not ok
	popad
	ret
	align 4
restoreivtvecs endp

;--- exit the dpmi server
;--- this routine is actually never called without an active client;
;--- the hdpmi -u switch launches a temp client to remove the host.
;--- DS=GROUP16, ES=FLAT
;--- [esp]=routine to jump to (offset32) after switch to real-mode.

	@ResetTrace

_exitserver_pm proc

	push eax
if ?WDEB386
	test fDebug,FDEBUG_KDPRESENT
	jz @F
	mov ax,DS_ExitCleanup
	int Debug_Serv_Int
@@:
endif
	@dprintf "exitserver enter, ds=%lX es=%lX esp=%lX", ds, es, esp
	or fMode, FM_DISABLED		;disable int 2Fh real-mode interface
;	@dprintf "call mouse33_exit, esp=%lX", esp
;	call mouse33_exit
	@dprintf "call pm_exit_pm, ds=%lX es=%lX esp=%lX", ds, es, esp
	call pm_exit_pm				;modifies no general purpose register
	@dprintf "final jump to real-mode, ds=%lX es=%lX esp=%lX", ds, es, esp
	pop eax
	pop ss:taskseg._Esi
	@rawjmp_rm _exitserver_rm
	align 4

_TEXT16 segment
;--- final host termination code
;--- AX=exit code
_exitserver_rm:
	@drprintf "exitserver_rm: final switch to real-mode, ss:sp=%X:%X", ss, sp
	push cs
	pop ds
	push word ptr taskseg._Esi	;push the final real-mode dest
	push ax
if ?WDEB386 ; v3.22: tell kd that we are finished
	mov ah, D386_Real_Mode_Init
	public patchkd
patchkd::
	nop	; will be patched with "int 68h" if kd was detected
	nop
endif
if ?SAVEMSW
	smsw ax
	test al,1		;VM86?
	jnz @F
	mov ax,wMSW
	@drprintf "exitserver_rm: restoring old MSW=%X",ax
	lmsw ax
@@:
endif
	@drprintf "exitserver_rm: call pm_exit_rm"
	call pm_exit_rm
	@drprintf "exitserver_rm: call unhookivtvecs"
	call unhookIVTvecs		;reset IVT 2F,15 and 96 vectors
ifdef _DEBUG
 if ?DOSOUTPUT and ?USEHOSTPSP
	mov ah,51h				;get current psp in BX
	int 21h
	push bx
	mov bx,[wHostPSP]
	mov ah,50h
	int 21h
	mov bx,1
	mov ah,3Eh
	int 21h
	pop bx
	mov ah,50h
	int 21h
 endif
endif
if ?CANTEXIT
	test fMode, FM_CANTEXIT	;could host be terminated?
	jnz @F
endif
	@drprintf "exitserver_rm: call unlinkserver"
	call unlinkserver
@@:
	@drprintf "exitserver_rm: call disablea20"
	call _disablea20
if ?I2FINITEXIT
	mov ax,1606h
	mov dx,0001h
	int 2Fh
endif
	pop ax
	@drprintf "exitserver_rm: exit, ax=%X, sp=%X", ax, sp
	ret
	align 4
_TEXT16 ends

_exitserver_pm endp

_TEXT32 ends

_TEXT16 segment

	@ResetTrace

;*** we have been started as task making ourself resident
;*** now we want to terminate with the exiting app

unlinkserver proc
	pusha
if ?VM
	test fMode, FM_CLONE	;nothing to be done if this is a clone
	jnz @exit
endif
	mov dx,[wEMShandle]
	and dx,dx
	jz @F
	mov ah,45h
	int 67h
@@:
ife ?STUB
	@drprintf "unlinkserver: calling int 21h, ah=51h [sp=%X]",sp
	mov ah,51h				;get current psp in BX
	int 21h
	mov ax,[wHostPSP]
	dec ax
	mov es,ax
	mov es:[1],bx				;set owner of host segment to cur psp
	@drprintf "unlinkserver: set psp of mcb %X to %X",ax,bx
	test fMode, FM_TLBMCB		;is TLB an extra MCB?
	jz @exit
	mov ax,[wSegTLB]
if ?TLBLATE
	and ax,ax
	jz @exit
endif
	dec ax
	mov es,ax
	mov es:[1],bx
	@drprintf "unlinkserver: set psp of mcb %X to %X",ax,bx
endif
@exit:
	popa
	ret
unlinkserver endp

;--- unhook IVT vectors
;--- 96    ?INTRM2PM=1    (usually 1)
;--- 06    ?TRAPINT06RM=1 (usually 0)
;--- 21    ?TRAPINT21RM=1 (usually 0)
;--- 2f                   ( always 1)
;--- 15    ?CATCHREBOOT=1 (usually 1)

unhookIVTvecs proc public
	pusha
	push 0
	pop es
	cld
	mov cl, 0
	mov dx, wHostSeg	;GROUP16
	mov si, offset ivthooktab
nextitem:
	lodsb
	cmp al,-1		;end of table?
	jz exit
	movzx bx,al
	lodsw			;old vector offset -> ax
	mov di, ax
	lodsw
	cmp bl,-2		;ignore this entry?
	jz nextitem
	shl bx,2
	cmp es:[bx+2], dx	;is GROUP16?
	jz @F
if ?CANTEXIT
	or fMode, FM_CANTEXIT
endif
	or cl,1
	@drprintf "unhookIVTvecs: cannot restore rm vec at %X [%X %X]", bx, ax, di
	jmp nextitem
@@:
	push dword ptr [di]
	pop dword ptr es:[bx]
	@drprintf "unhookIVTvecs: restored rm vec at 0000:%X", bx
	mov byte ptr [si-5],-2
	jmp nextitem
exit:
	shr cl,1
	popa
	ret
	align 4
unhookIVTvecs endp

	@ResetTrace

if ?I2FINITEXIT	;this switch is off by default to optimize size

;--- host real-mode init on 1. client's initial switch to protected-mode
;--- ds=GROUP16
;--- es-> taskdata
;--- currently this call cannot fail

_init2server_rm proc

	assume ds:GROUP16

	pusha
	push es

	@drprintf "init2server_rm entry, first client starting"
if ?I2FINITEXIT
	push ds
	xor cx,cx
	mov bx,cx
	mov si,cx
	mov ds,cx
	mov es,cx
	mov dx,1
	mov ax,1605h
	int 2Fh
	pop ds
	cmp cx,-1
	jnz exit
endif
	clc
exit:
	pop es
	popa
	ret
_init2server_rm endp

endif

;--- client's initial switch to protected-mode
;--- this proc is called as far proc (no INT!)
;--- AX=0000 -> 16bit client, AX=0001 -> 32bit client
;--- ES=client data (used for real-mode stack)

	@ResetTrace

_initclient_rm proc 

	assume DS:nothing

	test al,1
if ?32BIT
	jz req_bad
else
	jnz req_bad
endif
	pushf
	public initclient_brk
initclient_brk::
	@rm2pmbrk

	mov cs:[wInitSP],sp
	mov cs:[wInitSS],ss

	@drprintf "initclient_rm: new client starting, host=%X, es=%X, ss:sp=%X:%X",cs,es,ss,sp

if ?I2FINITEXIT        
	test cs:fMode, FM_INIT
	jnz @F
	call _init2server_rm		;server initialization on first client
;;  jc initclerrx
	@drprintf "_init2server_rm ok"
@@:
endif
	@rawjmp_pm_savesegm _initclient_pm

req_bad:
if ?CALLPREVHOST
	test cs:[fHost],FH_HDPMI	;is another instance of HDPMI installed?
	jz @F
	jmp cs:[dwHost16]		;then route the request to it
@@:
endif
	@drprintf "initclient_rm: bad client request, ax=%X",ax
	mov ax,8021h
	stc
	retf

_initclient_rm endp

;--- error during client initialization

_initclienterr_rm proc

	lss sp,cs:[dwInitSSSP]
if 1
	push cs:dwrmSSSPsave
	pop cs:v86iret.rSP
	pop cs:v86iret.rSS
endif
	popf
	stc
	@drprintf "initclient_rm: init failed, ds-gs=%X %X %X %X, ax=%X, ss:sp=%X:%X",\
		ds, es, fs, gs, ax, ss, sp
	retf
_initclienterr_rm endp

	@ResetTrace

_exitclient_rm proc

if 1
	push cs:dwrmSSSPsave
	pop cs:v86iret.rSP
	pop cs:v86iret.rSS
endif
	@drprintf "exitclient_rm: RMS=%X:%X, ss:sp=%X:%X", cs:v86iret.rSS, cs:v86iret.rSP, ss, sp
	@drprintf "exitclient_rm: ds-gs=%X %X %X %X pmst.DS/ES=%X/%X",ds,es,fs,gs, cs:pmstate.rDS, cs:pmstate.rES

if _LTRACE_
	push ax
	mov ah,51h
	int 21h
	push ds
	mov ds,bx
	assume ds:SEG16
	@drprintf "exitclient_rm: psp=%X, [psp:0A=%X:%X, 16=%X, 2E=%X:%X]", bx,\
		word ptr ds:[000Ch], word ptr ds:[000Ah], word ptr ds:[0016h],\
		word ptr ds:[0030h], word ptr ds:[002Eh]
	mov ds,ds:[0016h]
	@drprintf "exitclient_rm: [prevPSP:2E=%X:%X]",ds:[0030h],ds:[002Eh]
	pop ds
	assume ds:nothing
	pop ax
endif
	@drprintf "exitclient_rm: jmp to DOS, ax=%X",ax
;	@waitesckey

_exitclient_rm endp	;fall through

_dosexit_rm proc
	sti
	mov ah,4Ch
	int 21h
_dosexit_rm endp

if ?TRAPINT06RM

	@ResetTrace

int06rm proc far
if _LTRACE_
	push bp
	mov bp,sp
	mov bx,[bp+2]
	mov ds,[bp+4]
	@drprintf "exception 06 in real mode at %X:%X: %X %X",ds,bx,[bx],[bx+2]
	pop bp
endif
	@jmp_pm _exitclientEx8

_TEXT16 ends

_TEXT32 segment
_exitclientEx8:
	xor eax,eax
	mov ds,eax
	mov es,eax
	mov fs,eax
	mov gs,eax
	mov ax,_EAERR8_
	jmp _exitclientEx
	align 4
_TEXT32 ends

int06rm endp

endif

;*** real mode int 0x2F routine

	@ResetTrace

int2Frm proc far
	pushf
if ?CANTEXIT
	test cs:fMode, FM_CANTEXIT
	jnz tryexitnow
endif
	cmp ah,16h
	jz int2f16
noint2f16:
	popf
int2f_default:
	@jmpoldvec 2F
int2f16:
	test cs:fMode, FM_DISABLED
	jnz noint2f16
	popf
	cmp al,87h
	jz int2f1687
if _LTRACE_
  ifndef _DEBUG			;dont display too much in debug version
	cmp al,8fh
	jz @F
	@drprintf "int 2f rm,ax=%X,bx=%X",ax,bx
@@:
  endif
endif
if ?SUPI2F1600
	cmp al,00h			  ;1600?
	jnz @F
	mov ax,?2F1600VER 	  ;get windows version
	iret            ;real-mode int ret!
@@:
endif
if ?I2FINITEXIT
	cmp al,05h
	jnz @F
	mov cx,0FFFFh
@@:
endif
if ?SUPI2F160A
	cmp al,0Ah			  ;160A?
	jnz @F
;--- v3.18: removed
;	test cs:[bEnvFlags2],ENVF2_NOI2F160A
;	jnz @F
	xor ax,ax
	mov bx,?2F160AVER 	  ;get windows version
	mov cx,?WINMODE 	  ;mode (2=standard/3=enhanced)
	iret		          ;real-mode iret!
@@:
endif
if ?SUPP32RTM
;--- this code isn't active by default;
;--- int 2Fh, ax=168ah, is a DPMI function supposed to be "protected-mode only".
	cmp al,8ah
	jz int2f168a
endif
	jmp int2f_default

int2f1687:
;--- ES:DI = initial switch to protected-mode
	push cs
	pop es				;PM Entry
	mov di,offset _initclient_rm

	mov si,?RMSTKSIZE/10h  ;task bytes in paragraphs
if ?VM
	cmp cs:cApps,0
	jz @F
	db 81h, 0C6h		; add si, imm16
wCloneSize dw 0
@@:
endif

	mov dx,cs:[wVersion]
	mov cl,cs:[_cpu]	;processor
if ?32BIT
	mov bx,1			;32-Bit Apps
else
	mov bx,0			;no 32-Bit Apps
endif
	xor ax,ax           ;ax=0 -> call supported
	iret				;real-mode int ret!
if ?SUPP32RTM
int2f168a:
	push es
	pusha
	push cs
	pop es
	mov di, offset szVirtual
	mov cx, LSIZEVIRT
	repz cmpsb
	popa
	pop es
	jnz @F
	mov al,0
@@:
	iret				;real-mode int ret!
szVirtual db "VIRTUAL SUPPORT",0
LSIZEVIRT equ $ - szVirtual
endif

if ?CANTEXIT
tryexitnow:
	push ds
	push es
	push cs
	pop ds
	call unhookIVTvecs
	jc @F
	call unlinkserver
@@:
	pop es
	pop ds
	jmp noint2f16
endif
	align 4
int2Frm endp

;--- this is Int 96h real-mode proc.
;--- the purpose is to prevent debuggers from stepping into host's mode-switch code.

if ?INTRM2PM
intrm2pm proc far public
 if 1 ; preferably don't modify hiword(ESP); doesn't matter much, since it isn't saved in pm
	push bp
	mov bp,sp
	inc [bp+2].IRETSRM.rIP
;	and byte ptr [bp+2].IRETSRM.rFL+1,not 011b	;clear IF & TF
	pop bp
 else
	movzx esp,sp
	inc [esp].IRETSRM.rIP
;	and byte ptr [esp].IRETSRM.rFL+1,not 011b	;clear IF & TF
 endif
	retf 2	;RETF 2 instead if IRET will leave IF & TF cleared...
intrm2pm endp
endif

ife ?ALLOWR0IRQ

;--- real-mode HLT emulation

emu_hlt proc near
	sti
	hlt
	ret
emu_hlt endp

endif

;*** int 15 interrupt routine
;*** before v3.18 it was used in raw mode only
;--- now it's generally hooked for ctrl-alt-del detection.

	@ResetTrace

int15rm proc far
	pushf
if ?CATCHREBOOT
	cmp ax,4F00h + __DEL_MAKE
	jz int154f53
endif
if ?WATCHDOG
	cmp ax,0C301h				 ;enable watchdog timer?
	jz iretwithC
endif
;--- respond to ah=88 and ax=e801 in "raw" mode only
	test cs:fHost, FH_XMS or FH_VCPI
	jnz stdint15rm
	cmp ah,88h
	jz int1588
if ?TRAPI15E801
	cmp ax, 0E801h
	jz int1588
endif
stdint15rm:
	popf
	@jmpoldvec 15
int1588:
	popf
	call pm_int15rm
iretwithNC:
	push bp
	mov bp,sp
	and byte ptr [bp+6],not _CY
	pop bp
	iret			;real-mode iret!
if ?WATCHDOG
iretwithC:
	popf
	push bp
	mov bp,sp
	or byte ptr [bp+6],_CY
	pop bp
	iret            ;real-mode iret!
endif
if ?CATCHREBOOT
int154f53:
	cmp cs:[cApps],0	;hdpmi idle?
	jz stdint15rm
	push ds
	push ax
	push 0
	pop ds
	mov al,byte ptr ds:[417h]
	and al,0Ch					;ctrl+alt pressed?
	cmp al,0Ch
	pop ax
	pop ds
	jnz stdint15rm
if ?SAVEPSP
;--- if another PSP is active, do NOT try to terminate the client
	push ds
	push eax
	push bx
	mov eax,cs:[dwSDA]
	mov bx,ax
	shr eax,4
	mov ds,ax
	and bx,0fh
	mov ax,[bx].DOSSDA.wPSP
	cmp ax, cs:[wPSPSegm]
	pop bx
	pop eax
	pop ds
	jnz stdint15rm
endif        
	@drprintf "int 15 rm, ctrl-alt-del pressed",ax,bx
	@jmp_pmX catchreboot
endif

int15rm endp


if ?TRAPINT21RM

;--- int 21 hook. not used

	@ResetTrace

int21rm proc far
	@jmpoldvec 21
;	jmp  dword ptr cs:[int21hk.dwOldVec]

int21rm endp

endif ;?TRAPINT21RM

_TEXT16 ends

if ?STACKLAST

;--- if the stack is not the last segment, avoid it being physically
;--- in the binary. To achieve this do not define a stack size.
;--- the linker will then set the SS paragraph offset only, SP is 0,
;--- and tool SetMZHdr will then set the stack size to 0x200.

STACK segment use16 stack 'STACK'
	db 200h dup (?)
STACK ends
endif

end

