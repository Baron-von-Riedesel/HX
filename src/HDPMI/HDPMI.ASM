
;--- HDPMI's main source

;--- Warning: this source is old and possibly hard to understand.
;--- some comments in german language.

;--- what's implemented here:
;--- real-mode initialization/termination
;--- client initialization/termination
;--- exception handlers
;--- stack switching
;--- internal real-mode callbacks (for IRQs, int 1C, 23, 24)
;--- global data
;--- default IDT
;--- host stack

	page,132

	.486P

ifndef ?STUB
?STUB = 0
endif

if ?STUB
?STACKLAST = 1
else
?STACKLAST = 0		;std 0:	1=stack is last segment (behind GROUP32)
endif

;--- GROUP16

BEGTEXT16 segment para use16 public 'CODE'
BEGTEXT16 ends
_TEXT16 segment dword use16 public 'CODE'
_TEXT16 ends
CONST16 segment byte use16 public 'CODE'
CONST16 ends
_DATA16 segment dword use16 public 'CODE'
_DATA16 ends
VDATA16 segment dword use16 public 'CODE'
_StartOfVMData label near
VDATA16 ends
CDATA16 segment dword use16 public 'CODE'
_StartOfClientData label near
CDATA16 ends
GDTSEG segment para use16 public 'CODE'
_EndOfClientData label near
GDTSEG ends
IDTSEG segment para use16 public 'CODE'
externdef startofidtseg:byte
startofidtseg label byte
IDTSEG ends
_ITEXT16 segment byte use16 public 'CODE'
extern mystart:near					;use EXTERN to force include of mystart!
_ITEXT16 ends
ife ?STACKLAST
;STACK segment use16 stack 'CODE'	;with VALX+MS, the stack must be 'CODE'
STACK segment use16 stack 'STACK'	;WLink needs 'STACK' to find the stack seg
STACK ends
endif
ENDTEXT16 segment para use16 public 'CODE'
endof16bit label byte
ENDTEXT16 ends

;--- GROUP32

BEGTEXT32 segment para use32 public 'CODE'
BEGTEXT32 ends
_TEXT32 segment dword use32 public 'CODE'
_TEXT32 ends
CONST32 segment byte use32 public 'CODE'
CONST32 ends
CDATA32 segment dword use32 public 'CODE'
cldata32 label byte
CDATA32 ends
_ITEXT32 segment dword use32 public 'CODE'
endcldata32 label byte
endoftext32 label byte
_ITEXT32 ends
ENDTEXT32 segment para use32 public 'CODE'
endof32bit label byte
ENDTEXT32 ends

GROUP16  group BEGTEXT16, _TEXT16, CONST16, _DATA16, VDATA16, CDATA16, GDTSEG, IDTSEG, _ITEXT16, ENDTEXT16
ife ?STACKLAST
GROUP16 group STACK
endif
GROUP32 group BEGTEXT32, _TEXT32, CONST32, CDATA32, _ITEXT32, ENDTEXT32

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

;------------ macros --------------

;--- get IVT vector (ebx may be modified inside this macro!)
;--- but do not modify flags!

@getrmintvec macro xx
	push ds
	push byte ptr _FLATSEL_
	pop ds
	mov ebx, ds:[ebx*4]
	mov ss:xx, ebx
	pop ds
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

;--- jump to exception handler lpms_call_exc, which does:
;--- + switch to LPMS if not used
;--- + create a stack frame to switch stack back
;--- + jmp to the clients registered exception handler
;---   (or just jump to the default exception handler)

@exception macro excno, bErrorCode, bDisplay
ifnb <bDisplay>
	push eax
	mov eax, excno
	@strout <"entry exception %X",lf>,ax
	pop eax
endif
ifb <bErrorCode>	;correct missing error code
	push 0		;push a DWORD
endif
	push excno&h
	jmp lpms_call_exc
	align 4
endm

;--- @testexception MACRO must be placed BEFORE @simintlpms macro
;--- it's used for INT 08, 0A, 0B, 0C, 0D, 0E to determine if it
;--- is an exception or an IRQ/programmed INT

@testexception macro x
ifnb <x>
	cmp [esp+4*x].IRET32.rCS,_CSSEL_
	jz @F
endif
if ?FIXTSSESP
	cmp esp, offset ring0stack - sizeof R3FAULT32
else
	cmp esp, ss:[dwHostStackExc]
	jbe @F
endif
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

;--- used for ints 00-0F, 70-77 and 1C
;--- route int to real-mode
;--- for int 00 and 07 only if ?MAPINTxx is 1 (default is 0)
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

@callrmproc macro xx,yy,zz
defint&xx&:
ifnb <zz>
	call zz
endif
	push yy
	jmp dormproc
	align 4
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

;--- switch to LPMS, then call ring 3 protected mode int xx

@simintlpms macro xx
	db 68h		;"push" opcode
	dd offset GROUP32:r3vect&xx
	jmp lpms_call_int
	align 4
endm

;------------ begin code/data --------------

BEGTEXT16 segment

logo label byte
if ?STUB
	jmp mystart
else
	db "HDP"
endif
	db "MI", ?VERMAJOR, ?VERMINOR
llogo	equ $ - logo
	db ?32BIT

;--- IDT (vectors 00-7F only)
;--- the IDT usually is moved to extended memory
;--- then the space here is used for the host stack

	align 8

stacktop label near

if ?MOVEGDT
if ?HSINEXTMEM
IDTSEG segment
endif
endif

?IVAL	equ (_IGATE32_ + ?PLVL) shl 8
?TVAL	equ (_TGATE_ + ?PLVL) shl 8

HIBASE	equ 0	;HIGHWORD(offset label32) not accepted by MASM

;--- this is the predefined IDT, which contains 78h gates (Int 00h-77h)

curIDT label near
  GATE <LOWWORD(offset intr00) ,_CSSEL_,?IVAL, HIBASE>;divide error
  GATE <LOWWORD(offset intr01) ,_CSSEL_,?IVAL, HIBASE>;debug exception
  GATE <LOWWORD(offset intr02) ,_CSSEL_,?IVAL, HIBASE>;NMI
  GATE <LOWWORD(offset intr03) ,_CSSEL_,?IVAL, HIBASE>;int 3
  GATE <LOWWORD(offset intr04) ,_CSSEL_,?IVAL, HIBASE>;INTO
  GATE <LOWWORD(offset intr05) ,_CSSEL_,?IVAL, HIBASE>;print screen/bounds check
  GATE <LOWWORD(offset intr06) ,_CSSEL_,?IVAL, HIBASE>;invalid opcode
  GATE <LOWWORD(offset intr07) ,_CSSEL_,?IVAL, HIBASE>;DNA/80x87 not available

  GATE <LOWWORD(offset intr08) ,_CSSEL_,?IVAL, HIBASE>;timer/double fault
  GATE <LOWWORD(offset intr09) ,_CSSEL_,?IVAL, HIBASE>;keyboard/FPU operand
  GATE <LOWWORD(offset intr0A) ,_CSSEL_,?IVAL, HIBASE>;cascade/tss invalid
  GATE <LOWWORD(offset intr0B) ,_CSSEL_,?IVAL, HIBASE>;com2/segment fault
  GATE <LOWWORD(offset intr0C) ,_CSSEL_,?IVAL, HIBASE>;com1/stack fault
  GATE <LOWWORD(offset intr0D) ,_CSSEL_,?IVAL, HIBASE>;lpt2/GPF
  GATE <LOWWORD(offset intr0E) ,_CSSEL_,?IVAL, HIBASE>;floppy disk/page error
  GATE <LOWWORD(offset intr0F) ,_CSSEL_,?IVAL, HIBASE>;lpt1/reserved

if ?INT10SUPP
  GATE <LOWWORD(offset intr10) ,_CSSEL_,?IVAL, HIBASE>
else
  GATE <10h*2		,_INTSEL_,?TVAL, 0>
endif
if ?INT11SUPP
  GATE <LOWWORD(offset intr11) ,_CSSEL_,?IVAL, HIBASE>
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

  GATE <LOWWORD(offset intr20) ,_CSSEL_,?IVAL, HIBASE>
if ?FASTINT21
  GATE <LOWWORD(offset intr21) ,_CSSEL_,?IVAL, HIBASE>
else
  GATE <_INT21_ 	  ,_INTSEL_,?TVAL, 0>
endif  
if ?WINDBG
  GATE <LOWWORD(offset intr22) ,_CSSEL_,?IVAL, HIBASE>
else
  GATE <22h*2		  ,_INTSEL_,?TVAL, 0>
endif
  GATE <23h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <24h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <_INT25_ 	  ,_INTSEL_,?TVAL, 0>
  GATE <_INT26_ 	  ,_INTSEL_,?TVAL, 0>
  GATE <27h*2		  ,_INTSEL_,?TVAL, 0>

  GATE <28h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <29h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <2Ah*2		  ,_INTSEL_,?TVAL, 0>
  GATE <2Bh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <2Ch*2		  ,_INTSEL_,?TVAL, 0>
  GATE <2Dh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <2Eh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <_INT2F_ 	  ,_INTSEL_,?TVAL, 0>

if ?ALLOWR0IRQ
  GATE <LOWWORD(offset intr30) ,_CSSEL_,?TVAL, HIBASE>
else  
  GATE <LOWWORD(offset intr30) ,_CSSEL_,?IVAL, HIBASE>
endif  
if ?FASTINT31
  GATE <LOWWORD(offset intr31) ,_CSSEL_,?IVAL, HIBASE>
else
  GATE <_INT31_ 	  ,_INTSEL_,?TVAL, 0>
endif  
  GATE <32h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <_INT33_ 	  ,_INTSEL_,?TVAL, 0>
  GATE <34h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <35h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <36h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <37h*2		  ,_INTSEL_,?TVAL, 0>

  GATE <38h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <39h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <3Ah*2		  ,_INTSEL_,?TVAL, 0>
  GATE <3Bh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <3Ch*2		  ,_INTSEL_,?TVAL, 0>
  GATE <3Dh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <3Eh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <3Fh*2		  ,_INTSEL_,?TVAL, 0>

  GATE <40h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <LOWWORD(offset intr41) ,_CSSEL_,?IVAL, HIBASE>
  GATE <42h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <43h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <44h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <45h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <46h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <47h*2		  ,_INTSEL_,?TVAL, 0>

  GATE <48h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <49h*2		  ,_INTSEL_,?TVAL, 0>
  GATE <4Ah*2		  ,_INTSEL_,?TVAL, 0>
  GATE <_INT4B_ 	  ,_INTSEL_,?TVAL, 0>
  GATE <4Ch*2		  ,_INTSEL_,?TVAL, 0>
  GATE <4Dh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <4Eh*2		  ,_INTSEL_,?TVAL, 0>
  GATE <4Fh*2		  ,_INTSEL_,?TVAL, 0>

?int	= 50h
  rept 20h
  GATE <?int*2		  ,_INTSEL_,?TVAL, 0>
?int	= ?int + 1
  endm

  GATE <LOWWORD(offset intr70) ,_CSSEL_,?IVAL, HIBASE>
  GATE <LOWWORD(offset intr71) ,_CSSEL_,?IVAL, HIBASE>
  GATE <LOWWORD(offset intr72) ,_CSSEL_,?IVAL, HIBASE>
  GATE <LOWWORD(offset intr73) ,_CSSEL_,?IVAL, HIBASE>
  GATE <LOWWORD(offset intr74) ,_CSSEL_,?IVAL, HIBASE>
  GATE <LOWWORD(offset intr75) ,_CSSEL_,?IVAL, HIBASE>
  GATE <LOWWORD(offset intr76) ,_CSSEL_,?IVAL, HIBASE>
  GATE <LOWWORD(offset intr77) ,_CSSEL_,?IVAL, HIBASE>

	.errnz ($ - curIDT) - (?PREDEFIDTGATES shl 3)

ife ?MOVEIDT

;--- if the IDT is not moved in extended memory,
;--- define the rest of the gates here.

?int = ?PREDEFIDTGATES
  rept 100h - ?PREDEFIDTGATES
  GATE <?int*2		   ,_INTSEL_,?TVAL, 0>
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
;--- in case ?HSINEXTMEM is set, this space is "almost" free;
;--- it's still used temporarily in CreateVM, when a new VM is
;--- about to be created.

if ?MOVEIDT
  if ?HSINEXTMEM
	?R0STACKSIZE = 200h-4
  else
	?R0STACKSIZE = 440h-4	;alloc a smaller stack (IDT space will be reused)
  endif
else
	?R0STACKSIZE = 600h-4
endif

	db ?R0STACKSIZE dup (?)
ring0stack label near

dwSegTLB label dword			;segment translation buffer
wSegTLB	dw 0					;defined here so this variable can be
		dw 0					;accessed by another host instance

;--- task state segment (TSS)
;--- hdpmi will not use the x86 task switching
;--- but one is needed for switching from ring 3 to ring 0

	align 8

taskseg TSSSEG <0, offset ring0stack, _SSSEL_>

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
;---       which leaves this space unused after initialization.

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
	@defdesc <0fffeh,0,0,92h,0CFh,0>,_SSSEL_	;28 SS (=GROUP16)
endif    
tssdesc label DESCRPTR
	@defdesc <0067h,0,0,89h,0,0>,_TSSSEL_		;30 available 386 TSS
	@defdesc <-1,0,0,82h,0,0>,_LDTSEL_			;38 LDT

;--- 40+3 BIOS Data (fix)

	@defdesc <02ffh,0400h,0,92h or ?PLVL,0,0>

;--- 48+3 FLAT data selector

	@defdesc <-1,0,0,92h or ?PLVL,0CFh,0>,_FLATSEL_, ?RING
;	@defdesc <-1,0,0,92h,0CFh,0>,_FLATSEL_

;--- 50+3 selector describing TLB

if ?TLBLATE
?TLBSELATTR equ 0	;make TLB readonly until we have a valid one
else
?TLBSELATTR equ 2
endif
	@defdesc <?TLBSIZE-1,0,0Fh,90h or ?TLBSELATTR or ?PLVL,0,0>,_TLBSEL_, ?RING

;--- 58+3 protected mode breakpoints

pmbrdesc label DESCRPTR    
	@defdesc <_MAXCB_*2-1,0,0,9Ah or ?PLVL,0,0>,_INTSEL_, ?RING

;--- 60 alias for CS (data)

if 1;?MOVEHIGH
	@defdesc <-1,0,0,92h,40h,0>,_CSALIAS_
endif

;--- 68 LDT data selector

	@defdesc <0FFFh,0,0,92h or ?PLVL,0,0>,_SELLDT_, ?RING

;--- 70+3 ring 3 GROUP32 code selector (rarely used!)

	@defdesc <-1,0,0,9Ah or ?PLVL,40h,0>,_CSR3SEL_, ?RING

;--- 78+3 ring 3 GROUP16 (GROUP32?) data selector (rarely used!)

	@defdesc <-1,0,0,92h or ?PLVL,00h,0>,_DSR3SEL_, ?RING

;--- alias for GROUP16 (code) (used 2 times in hdpmi.asm)

if ?MOVEHIGHHLP
	@defdesc <-1,0,0,9Ah,0,0>,_CSGROUP16_
endif

;--- std 64 kB data selector to initialize segments (used 1 time in hdpmi.asm)

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
GDTSEG	ends
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
;	@defx _meventp, _MEVENT_		;mouse event proc (ring 0)
;--- here start PMBREAKs with retf frame
_RETF_ equ ($ - offset spectab) / 2 + 200h
	@defx _srtask, _SRTSK_		;save/restore task state (call)
	@defx _I2f168A, _I2F168A_		;DPMI extensions entry (retf)
if ?SUPI2F16840001
	@defx _vxd_0001, _I2F1684_0001_
endif
if ?SUPI2F16840009
	@defx _vxd_0009, _I2F1684_0009_
endif
if ?SUPI2F16840017
	@defx _vxd_0017, _I2F1684_0017_
endif
if ?SUPI2F16840021
	@defx _vxd_0021, _I2F1684_0021_
endif
if ?SUPI2F1684002A
	@defx _vxd_002A, _I2F1684_002A_
endif
if ?SUPI2F16840442
	@defx _vxd_0442, _I2F1684_0442_
endif
;--- here start PMBREAKs with no frame
_JMPF_ equ ($ - offset spectab) / 2 + 200h
	@defx rpmstacki,_RTINT_		;switch from LPMS to PMS after IRQ
	@defx rpmstackr,_FRTIN_		;return from standard RMCBs
	@defx _retcb,  _RETCB_		;return from client RMCBs
	@defx _pm2rm,  _RMSWT_		;raw mode switch pm -> rm (call)
if ?ALLOWR0IRQ
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

BEGTEXT16 ends

_DATA16 segment

;--- the _DATA16 segment should not contain data which is client-specific
;--- for this segment CDATA16 is to be used

pdGDT	PDESCR <?GDTLIMIT,0>	;pseudo descriptor GDT
	align 4

pdIDT	PDESCR <7FFh,0>			;pseudo descriptor IDT protected mode
selLDT	dw _SELLDT_				;Selector LDT alias (fix)
	align 4
;nullidt PDESCR <3FFh,0>		;pseudo descriptor IDT real mode
;	align 4

ife ?PATCHCODE
rawjmp_rm_vector dd offset rawjmp_rm_novcpi
endif

;--- used for VCPI function DE0C (switch rm to pm)
;--- CR3, address pd GDTR, address pd IDTR, LDTR, TR, EIP, CS
v86topm VCPIRM2PM <0,0,0,_LDTSEL_,_TSSSEL_, offset vcpi_pmentry, _CSSEL_>

wVersion	dw 005ah	;DPMI version 0.90
	align 4

vcpicall label PF32 	;VCPI far32 address to switch to v86-mode
vcpiOfs		dd 0		;offset (got from VCPI host)
vcpiSeg		dw _VCPICS_ ;selector for VCPI code segment
wHostPSP	dw 0        ;PSP of host

	align 4

dwLDTAddr	dd 0				;linear address LDT
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
dwHostBase  dd 0				;linear address host GROUP16
wHostSeg	label word
dwHostSeg	label dword
			dd 0				;segment host (GROUP16)
dwFeatures	dd 0				;features from CPUID
if ?DTAINHOSTPSP
dwHostDTA	dd 0
else
dwDTA		dd 0
endif

if ?SAVERMGDTR
rmgdt	  df 0					;GDT pseudo descriptor for real mode
endif
if ?SAVEMSW
wMSW	dw 0					;real-mode MSW on entry
endif
if ?VM
wCloneSize dw 0
endif

dwOldVec96 dd 0

cApps		db 0				;number of clients
fMode		db 0				;flags (FM_xxx)
fMode2		db 0				;more flags (FM2_xxx)
_cpu		db 0				;CPU (3=386,4=486, ...)
bExcEntry	db -1				;entries default exception handler

fHost		db 0				;1=xms,2=vcpi,4=raw,8=dpmi,...
fXMSQuery	db 8				;default function code for XMS query
fXMSAlloc	db 9				;default function code for XMS alloc
bFPUAnd		db not (CR0_EM or CR0_TS or CR0_NE)
bFPUOr		db CR0_NE

if ?KDSUPP
fDebug	  db 0					;kernel debugger present?
bTrap	  db 0
dbgpminit df 0
endif
if ?LOGINT30
lint30	  dw 0
endif
wEMShandle dw 0

;--- table of real-mode IVT vectors to intercept

@jmpoldvec macro intno
	db 0EAh
dwOldVec&intno dd 0
endm

ivthooktab label byte
if ?INTRM2PM
int96hk IVTHOOK <?XRM2PM, offset dwOldVec96, offset intrrm2pm>
endif
if ?TRAPINT06RM
int06hk IVTHOOK <06h, offset dwOldVec06, offset int06rm>
endif
if ?TRAPINT21RM
int21hk IVTHOOK <21h, offset dwOldVec21, offset int21rm>
endif
int2Fhk IVTHOOK <2Fh, offset dwOldVec2F, offset int2Frm>
;------------------------------- int 15 should be last because it
;------------------------------- is used in raw mode only 
if ?WATCHDOG or ?CATCHREBOOT
int15hk IVTHOOK <15h, offset dwOldVec15, offset int15rm>;watch int 15 in any case
else
int15hk IVTHOOK < -1, offset dwOldVec15, offset int15rm>;watch int 15 conditionally in raw mode
endif
	db -1

	align 4

VDATA16 segment
dwTSSdesc	dd offset tssdesc	;normalized address TSS descriptor
rmsels		dd 0				;normalized start "real mode selector" list
VDATA16 ends

if ?GUARDPAGE0
;pg0ptr	dd -1					;normalized address PTE for page 0
pg0ptr	dd offset taskseg
lastcr2 dd 0
dwAddr	dd 0					;linear address write destination in page 0
dwOrgFL	dd 0
myint01 GATE <LOWWORD(offset backtonormal) ,_CSSEL_,?IVAL, 0>
endif

;*** temporary variables
        
;tmpESIReg dd 0	;used by _rawjmp_pm
;tmpEAXReg dd 0	;used by _rawjmp_pm, _rawjmp_rm

calladdr1 dd 0	;used to store a IVT vector value
calladdr2 dd 0	;used to store a IVT vector value
dwRetAdr  dd 0	;1. store for return address if SP cannot be used
wRetAdrRm2 label word ;saved return address, used by _rawjmp_rm
dwRetAdr2 dd 0	;saved return address, used by _rawjmp_pm
tmpFLRegD label dword
tmpFLReg  dw 0	;temporary storage for FL register
          dw 0

calladdr3 dw 0	;used by callrmprocintern
wRetAdrRm dw 0	;3. store ( used by @jmp_rm )
tmpAXReg  dw 0	;temporary storage for AX
tmpBXReg  dw 0	;temporary storage for BX

dwCurSSSP label dword
wCurSP	  dw 0		;sp real mode on client init
wCurSS	  dw 0		;ss real mode on client init

dwrmSSSPtmp label dword
wrmSPtmp	dw 0	;temp store for rmSP on protected-mode reentry
wrmSStmp	dw 0	;temp store for rmSS on protected-mode reentry

	align 4

;--- internal real-mode callbacks (for IRQ 00-0F, Int 1C, 23, 24, mouse).
;--- unlike the client real-mode callbacks
;--- these callbacks have no real-mode call structure
;--- and DS:E/SI doesn't point to the real-mode stack on entry.
;--- size of INTRMCB is 16 Bytes, this cannot be changed!

;--- for HDPMI < 3.0 this table was in client data
;--- then the "active" flag has been moved to the new wIntRmCb bitfield
;--- and this table is now global

;--- IRQs on standard PCs:
;--- 0=PIT timer 1=kbd 2=slave PIC 3=COM2/COM4 4=COM1/COM3
;--- 5=LPT2/SB 6=floppy 7=LPT1/SB
;--- 8=RTC 9=VGA/free, 10=free, 11=free, 12=PS/2, 13=FPU exc
;--- 14=IDE1, 15=IDE2

?INT1CVAL equ RMVFL_IDT
?INT23VAL equ RMVFL_IDT or RMVFL_SETALWAYS
?INT24VAL equ RMVFL_IDT or RMVFL_SETALWAYS
?MEVNTVAL equ RMVFL_FARPROC

@defvec macro xx
	exitm <LOWWORD(offset GROUP32:r3vect&xx)>
endm

;--- the table of internal realmode callbacks is now in client data again
;--- (it was in _DATA16 for v3.02-3.04)
;--- apparently some clients (DOS4G) don't reset their real-mode vectors
;--- with Int 31h, which causes troubles if HDPMI=1 is *not* set

?INTRMCB_IN_CDATA	equ 1

if ?INTRMCB_IN_CDATA
CDATA16 segment
endif

intrmcbs label INTRMCB
	INTRMCB <0,0, 0,?IRQ00VAL,@defvec(08),(?MPICBASE+0)*4>
	INTRMCB <0,0, 1,0        ,@defvec(09),(?MPICBASE+1)*4>
	INTRMCB <0,0, 2,0        ,@defvec(0A),(?MPICBASE+2)*4>
	INTRMCB <0,0, 3,0        ,@defvec(0B),(?MPICBASE+3)*4>
	INTRMCB <0,0, 4,0        ,@defvec(0C),(?MPICBASE+4)*4>
	INTRMCB <0,0, 5,?IRQ05VAL,@defvec(0D),(?MPICBASE+5)*4>
	INTRMCB <0,0, 6,?IRQ06VAL,@defvec(0E),(?MPICBASE+6)*4>
	INTRMCB <0,0, 7,0        ,@defvec(0F),(?MPICBASE+7)*4>
	INTRMCB <0,0, 8,0        ,@defvec(70),(?SPICBASE+0)*4>
	INTRMCB <0,0, 9,0        ,@defvec(71),(?SPICBASE+1)*4>
	INTRMCB <0,0,10,0        ,@defvec(72),(?SPICBASE+2)*4>
	INTRMCB <0,0,11,0        ,@defvec(73),(?SPICBASE+3)*4>
	INTRMCB <0,0,12,0        ,@defvec(74),(?SPICBASE+4)*4>
	INTRMCB <0,0,13,0        ,@defvec(75),(?SPICBASE+5)*4>
	INTRMCB <0,0,14,?IRQ14VAL,@defvec(76),(?SPICBASE+6)*4>
	INTRMCB <0,0,15,?IRQ15VAL,@defvec(77),(?SPICBASE+7)*4>
	INTRMCB <0,0,16,?INT1CVAL,1Ch*8          ,(1Ch)*4>
	INTRMCB <0,0,17,?INT23VAL,23h*8          ,(23h)*4>
	INTRMCB <0,0,18,?INT24VAL,24h*8          ,(24h)*4>
	INTRMCB <0,0,19,?MEVNTVAL,LOWWORD(offset GROUP32:mevntvec),(0)*4>
SIZEINTRMCB equ ($ - intrmcbs) / sizeof INTRMCB

TESTINTRMCB equ 17	;test IRQs + Int 1Ch
;RMCBMOUSE   equ 13h	;index of mouse event callback

RMCB1C	equ intrmcbs + 16 * sizeof INTRMCB
RMCB24	equ intrmcbs + 18 * sizeof INTRMCB

if ?INTRMCB_IN_CDATA
CDATA16 ends
endif

if _LTRACE_
iirq dw 0		;helper for better int trace msgs
endif

_DATA16 ends

;--- CDATA16: client instance data both modes

CDATA16 segment

ifdef ?QEMMSUPPORT
		dq 0			;QEMM requires 8 bytes more
endif
		dq 0,0			;16 bytes stack space for VCPI-Host
		dq 0			;some space for VCPI, since it is called with CALL FAR

;--- VCPI jump to v86 mode (DE0Ch) expects SS:ESP pointing to a V86IRET
;--- structure (which must be located in 1. MB)
;--- EIP,CS,0,EFL,ESP,SS,0,ES,0,DS,0,FS,0,GS,0

;v86iret	  V86IRET <offset vcpi_rmentry,0,0,0,40h,0,0,0,0,0,0,0,0,0,0>
v86iret	  V86IRET <offset vcpi_rmentry,0,0,0,0,0,0,0,0,0,0,0,0,0,0>

ltaskaddr	dd 0		;addr tcb previous client
ife ?CR0COPY
dwCR0		dd 0		;?CR0COPY=0: current value of CR0 in protected mode
endif                        
spPMS		dq 0		;saved PMS (SS:ESP)
cIntRMCB 	dw 0		;number of open internal rmcbs
cRMCB		dw 0		;number of open rmcbs (not finished with IRET yet)
wLDTLimit 	dw 0		;limit of LDT
cLPMSused	db 0		;count LPMS usage (is just a flag now)
            db 0
if ?CR0COPY
bCR0		db 0		;value of LowByte(CR0)
endif

		align 4

;--- real-mode and protected mode segment register values + esp
tskstate TASKSTATE <>

;--- since the ring0stack is in a 16-bit segment, be careful with
;--- offset calculations done by MASM!

if ?FIXTSSESP
dwHostStack dd 0
else
dwHostStackExc label dword
			dw offset ring0stack - sizeof R3FAULT32, 0
endif
if ?HSINEXTMEM
dwStackTop	dd 0
endif

if ?INT21API
dtaadr		df 0h		;dos DTA
endif
if ?SAVEPSP
wPSPSegm	dw 0		;initial psp segment of client
endif

wIntRmCb	dw 2 dup (0);flags for up to 32 intrmcbs

if ?DPMI10EXX
wExcHdlr	dw 2 dup (0);32 bits for exception handler type
endif

wEnvFlags	label word
bEnvFlags	db 0		;flags of environment string "HDPMI="
bEnvFlags2	db 0		;flags 256-32768 of "HDPMI="


CDATA16 ends

;--- end of client specific data in GROUP16

;--- start client specific data in GROUP32

CDATA32 segment

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

CDATA32 ends

;--- end client specific data in GROUP32

;--------------- start code ------------------

_TEXT32 segment

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

;--- since rpmstacke() isnt called decrement cLPMSused here!

;--- ERRC is removed already!

;--- [esp] on entry: EXC2INT

	@ResetTrace

EXC2INT struct
rEdi	dd ?
rEsi	dd ?
rEbx	dd ?
rEax	dd ?
rDs		dd ?
n   	IRET32 <>
dwExc	dd ?
o   	IRET32 <>
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
	@strout <"entry exc_to_int: cs:ip=%X:%lX fl=%lX ss:sp=%X:%lX proc=%lX:%lX",lf>,\
		[ebp+4].EXC2INT.o.rCS, [ebp+4].EXC2INT.o.rIP,\
		[ebp+4].EXC2INT.o.rFL,\
		[ebp+4].EXC2INT.o.rSS, [ebp+4].EXC2INT.o.rSP,\
		[ebp+4].EXC2INT.n.rCS, [ebp+4].EXC2INT.n.rIP 
	pop ebp
endif

	lds esi,[esp].EXC2INT.o.rSSSP
if ?LPMSCNT
	dec ss:[cLPMSused]
else
	mov eax, ds
	cmp ax,_LPMSSEL_
	jnz @F
	cmp si,?LPMSSIZE - sizeof IRETS
	jnz @F
	mov ss:cLPMSused,0
@@:
endif

if ?32BIT
	mov edi,[esi].IRET32.rIP 		;original EIP
	mov ebx,[esi].IRET32.rCSd
	mov eax,[esi].IRET32.rFL 		;original Flags
	lds esi,[esi].IRET32.rSSSP		;original SS:ESP
else
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

	and ah,not (_NT or _IF or _TF)		;NT,IF,TF reset
	mov [esp].EXC2INT.n.rFL,eax

	pop edi
	pop esi
	pop ebx
	pop eax
	pop ds
	iretd
	align 4

exc2int endp

;*** emulate int xx on PMS
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
if ?HSINEXTMEM
	@checkssattr ds,di
endif
	sub edi,sizeof IRETSPM
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
	mov [edi].IRETSPM.rIP, ax
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
;*** a RET32 stack frame is generated onto the host stack
;*** jump to ring 3 is then done with a RETF, Interrupts disabled
;*** ----------------------------------------------------
;*** another frame (IRETS) is created onto the LPMS:
;*** format:
;***  (E)IP=_RTINT_
;***	 CS=_INTSEL_
;***  (E)FL=Client Flags
;---  client EIP, CS
;--- _RTINT_ will switch the stack back to PMS. PMS is saved
;--- in the client data structure
;---
;--- if LPMS is in use already, use current PMS instead
;--- and don't create the backswitching frame

	@ResetTrace


lpms_call_int proc public

	cmp [esp+4].IRET32.rCS,_CSSEL_ ;interrupt in ring 0?
	jz lpms_call_inr0
	sub esp,sizeof RETF32+4
	push ds
	push eax
	push edx
	push edi

IRQFRAME struct
rEdi	dd ?
rEdx	dd ?
rEax	dd ?
rDs		dd ?
rEfl	dd ?
retfs	RETF32 <>
pR3Proc	dd ?
iret32  IRET32 <>
IRQFRAME ends

	mov edi,[esp].IRQFRAME.pR3Proc
if ?32BIT
	mov eax, cs:[edi].R3PROC._Eip
	mov edx, cs:[edi].R3PROC._Cs
else
	movzx eax, cs:[edi].R3PROC._Eip
	movzx edx, cs:[edi].R3PROC._Cs
endif
	mov [esp].IRQFRAME.retfs.rIP,eax
	mov [esp].IRQFRAME.retfs.rCSd,edx

	cmp ss:[cLPMSused],0			;LPMS free?
	jz lpms_ci_21

	lds edi, [esp].IRQFRAME.iret32.rSSSP
	sub edi,sizeof IRETSPM
	mov [esp].IRQFRAME.retfs.rSP, edi
	mov [esp].IRQFRAME.retfs.rSS, ds

	mov eax, [esp].IRQFRAME.iret32.rIP
	mov edx, [esp].IRQFRAME.iret32.rCSd
if ?32BIT
	mov [edi].IRETSPM.rIP, eax
	mov [edi].IRETSPM.rCSd, edx
	mov eax, [esp].IRQFRAME.iret32.rFL
	mov [edi].IRETSPM.rFL, eax
else
	mov [edi].IRETSPM.rIP, ax
	mov [edi].IRETSPM.rCS, dx
	mov eax, [esp].IRQFRAME.iret32.rFL
	mov [edi].IRETSPM.rFL, ax
endif
	and ah,not 3		;reset TF + IF
	mov [esp].IRQFRAME.rEfl,eax
if 0; _LTRACE_	;this might be called quite frequently, spoiling any useful log file
	push ebp
	mov ebp, esp
	@strout <"lpms_call_int, nosw:ip=%X:%lX fl=%lX nip=%X:%lX nsp=%X:%lX",lf>,\
		[ebp+4].IRQFRAME.iret32.rCS,[ebp+4].IRQFRAME.iret32.rIP,[ebp+4].IRQFRAME.iret32.rFL,\
		[ebp+4].IRQFRAME.retfs.rCS,[ebp+4].IRQFRAME.retfs.rIP,[ebp+4].IRQFRAME.retfs.rSS,[ebp+4].IRQFRAME.retfs.rSP
	pop ebp
endif
	jmp done
	align 4

	@ResetTrace

;*** LPMS is free
;--- build a frame:
;--- + IRETS {_RTINT_, _INTSEL_, E/FL}
;--- + client EIP, CS

lpms_ci_21:
	mov eax, [esp].IRQFRAME.iret32.rSP
	mov edx, [esp].IRQFRAME.iret32.rSSd
	mov dword ptr ss:spPMS+0,eax
	mov dword ptr ss:spPMS+4,edx

	mov ss:[cLPMSused],1

	mov edi,?LPMSSIZE- (2*4 + sizeof IRETSPM)   ;initialwert LPMS
	mov eax,_LPMSSEL_
	mov ds,eax
	mov [esp].IRQFRAME.retfs.rSP, edi
	mov [esp].IRQFRAME.retfs.rSSd, eax

	mov eax, [esp].IRQFRAME.iret32.rFL
	mov [edi].IRETSPM.rIP, _RTINT_
	mov [edi].IRETSPM.rCS, _INTSEL_
if ?32BIT
	mov [edi].IRETSPM.rFL, eax
else
	mov [edi].IRETSPM.rFL, ax
endif
	and ah,not 3		;reset TF + IF
	mov [esp].IRQFRAME.rEfl,eax

	mov eax, [esp].IRQFRAME.iret32.rIP
	mov edx, [esp].IRQFRAME.iret32.rCSd
	mov [edi+sizeof IRETSPM+0], eax
	mov [edi+sizeof IRETSPM+4], edx

if 0; _LTRACE_	;this might be called quite frequently, spoiling any useful log file
	push ebp
	mov ebp,esp
	@strout <"lpms_call_int:ip=%X:%lX sp=%X:%lX fl=%lX ">,\
		[ebp+4].IRQFRAME.iret32.rCS, [ebp+4].IRQFRAME.iret32.rIP,\
		[ebp+4].IRQFRAME.iret32.rSS, [ebp+4].IRQFRAME.iret32.rSP,\
		[ebp+4].IRQFRAME.iret32.rFL
	@strout <" nip=%X:%lX nsp=%X:%lX",lf>,\
		[ebp+4].IRQFRAME.retfs.rCS,[ebp+4].IRQFRAME.retfs.rIP,[ebp+4].IRQFRAME.retfs.rSS,[ebp+4].IRQFRAME.retfs.rSP
	pop ebp
endif   

done:
	pop edi
	pop edx
	pop eax
	pop ds
	popfd
	retf

;*** IRQ in Ring 0 - this is not possible currently
;--- just do a fatal exit

lpms_call_inr0:
if ?ALLOWR0IRQ
	@ResetTrace
	pop ss:[taskseg._Eax]	;pop the client R3PROC ptr
							;now ESP->IRET32
	@strout <"interrupt in ring 0, esp=%lX",lf>,esp
	push ss:[taskseg._Esp0]
	mov ss:[taskseg._Esp0],esp
	sub esp, sizeof IRET32+4

IRQ0FR struct
pR3Proc dd ?
irn     IRET32 <>
dwStk	dd ?
iro     IRET32 <>
IRQ0FR ends

if _LTRACE_
	push ebp
	mov ebp,esp
	@strout <"frame: cs:ip=%X:%lX fl=%lX, ss:sp=%X:%lX",lf>,\
		[ebp+4].IRQ0FR.iro.rCS, [ebp+4].IRQ0FR.iro.rIP,\
		[ebp+4].IRQ0FR.iro.rFL,\
		[ebp+4].IRQ0FR.iro.rSS, [ebp+4].IRQ0FR.iro.rSP
	pop ebp
endif
	push eax
	mov [esp+4].IRQ0FR.irn.rIP, _RTINTR0_
	mov [esp+4].IRQ0FR.irn.rCS, _INTSEL_
	mov eax, [esp].IRQ0FR.iro.rFL
	mov [esp+4].IRQ0FR.irn.rFL, eax
	mov eax, [esp].IRQ0FR.iro.rSP
	mov [esp+4].IRQ0FR.irn.rSP, eax
	mov eax, [esp].IRQ0FR.iro.rSS
	mov [esp+4].IRQ0FR.irn.rSS, eax
	mov eax, ss:[taskseg._Eax]
	mov [esp+4].IRQ0FR.pR3Proc, eax
	pop eax
	jmp lpms_call_int
_retirqr0::
	add esp,sizeof IRET32
	pop ss:[taskseg._Esp0]
	iretd
else
	mov ax,_EAERR3_
	jmp _exitclientEx
endif
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
 	IRET32 <>
RPMIFR ends

	@ResetTrace

rpmstacki proc
	push ds
	mov ss:[cLPMSused],0
ife ?CSIPFROMTOP
	push ebx
	lds ebx,[esp].RPMIFR.rSSSP		;get the LPMS
	push dword ptr ss:spPMS+4		;SS
	push dword ptr ss:spPMS+0		;ESP
	push [esp+8].RPMIFR.rFL			;EFL
	push dword ptr [ebx+4]			;CS
	push dword ptr [ebx+0]			;EIP
	lds ebx,[esp+sizeof IRET32]		;restore DS,EBX
else
	push _LPMSSEL_
	pop ds
	push dword ptr ss:spPMS+4		;SS
	push dword ptr ss:spPMS+0		;ESP
	push [esp+8].RPMIFR.rFL			;EFL
	assume ds:GROUP16
	push dword ptr ds:[?LPMSSIZE-4]	;CS
	push dword ptr ds:[?LPMSSIZE-8]	;EIP
	mov ds,[esp+sizeof IRET32]
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
;*** - build a RETF32 frame on host stack
;*** - execute RETFD

	@ResetTrace

LCEFR struct
r		RETF32 <>
dwExc	dd ?
f		R3FAULT32 <>	;or R0FAULT32 for an exception in ring 0
LCEFR ends

lpms_call_exc proc
	sub esp,sizeof RETF32
	push ebp
	mov ebp,esp
	push eax

	lar eax, [ebp+4].LCEFR.f.rCSd
	and ah,60h			;exception in ring 0?
	jz lpms_call_host_exc

	push edx
	push esi
	push edi
	push ds

if ?LPMSCNT
	cmp ss:[cLPMSused],0	;LPMS free?
else
	cmp ss:[cLPMSused],0
endif
	jnz @F
ife ?LPMSCNT
        mov ss:[cLPMSused],1
endif
	mov ax,_LPMSSEL_
	mov edi,?LPMSSIZE - sizeof DPMIEXC
	jmp lpms_ce_2
@@:								;LPMS in use, no stack switch
	mov edi, [ebp+4].LCEFR.f.rSP
	mov eax, [ebp+4].LCEFR.f.rSSd
	lar esi,eax
	bt esi,22
	jc @F
	movzx edi,di
@@:
	sub edi,sizeof DPMIEXC

lpms_ce_2:
	mov ds,eax
if ?LPMSCNT
	inc ss:[cLPMSused]
endif
if _LTRACE_
	mov esi,[ebp+4].LCEFR.dwExc
	@strout <"entexc: exc=%X errc=%lX cs:ip=%X:%lX ss:sp=%X:%lX",lf>,si,\
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
	mov [edi].DPMI10EXC.rDPMIIPx, _RTEXC_
	mov [edi].DPMI10EXC.rDPMICSx, _INTSEL_
else
	mov [edi].DPMI10EXC.rDPMIIPx, _RTEXC_ + 10000h * _INTSEL_
	mov [edi].DPMI10EXC.rDPMICSx, 0
endif
	mov eax, [ebp+4].LCEFR.f.rErr
	cmp esi,1
	jnz @F
	mov eax, dr6
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
	cmp esi,_INTSEL_ * 10000h + _RTEXCR0_
	setz al
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
	mov esi, cr2
	mov [edi].DPMI10EXC.rCR2, esi
	mov [edi].DPMI10EXC.rPTE, 0
nodpmi10handler:
endif
	mov [ebp+4].LCEFR.r.rSP, edi

	mov [edi].DPMIEXC.rDPMIIP, _RTEXC_
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
	mov edi, [ebp+4].LCEFR.dwExc
  if ?32BIT
	mov eax, cs:[edi*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Eip
	mov esi, cs:[edi*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Cs
  else
	movzx eax, cs:[edi*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Eip
	movzx esi, cs:[edi*sizeof R3PROC+offset GROUP32:excvec].R3PROC._Cs
  endif
	mov [ebp+4].LCEFR.r.rIP, eax
	mov [ebp+4].LCEFR.r.rCSd, esi

	@strout <"jmp handler: cs:ip=%X:%lX ss:sp=%X:%lX",lf>,\
		[ebp+4].RETF32.rCS, [ebp+4].RETF32.rIP,\
		[ebp+4].RETF32.rSS, [ebp+4].RETF32.rSP
;	@waitesckey

	pop ds
	pop edi
	pop esi
	pop edx
	pop eax
	pop ebp
	retf
	align 4
lpms_call_exc endp

	@ResetTrace

lpms_call_host_exc proc

LCEFR0 struct
r	 	RETF32 <>
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
	mov ds:[taskseg._Esi], esi
	pop ds
	popad
	mov eax,[ebp-4]
	mov ebp,[ebp+0]
	push byte ptr _SSSEL_
	pop ss
	mov esp, ss:[taskseg._Esi]
	jmp _exceptZ
ss_is_hoststack:        
	mov eax,[ebp+4].LCEFR0.dwExc

	@strout <"an exception %X occured in ring 0",lf>,ax

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
	add esp, sizeof RETF32
	pop ss:[taskseg._Eax]		;get exception no
	push ds
	push es
if ?FIXTSSESP
	push ss:[dwHostStack]
	mov ss:[dwHostStack],esp
else
	push ss:[taskseg._Esp0]
	mov ss:[taskseg._Esp0],esp
if ?SETEXCHS
	sub esp,sizeof R3FAULT32
	mov ss:[dwHostStackExc], esp
	add esp,sizeof R3FAULT32
endif
endif
	sub esp,sizeof R3FAULT32
	push ss:[taskseg._Eax]
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
	@strout <"frame for exc in ring 0 built, esp=%lX, jmp to lpms_call_exc",lf>,esp
;	@waitesckey
	jmp lpms_call_exc
retexcr0::
if _LTRACE_
	push ebp
	mov ebp,esp
	@strout <"[esp]=%lX %X %lX %lX %X",lf>,[ebp+4].IRET32.rIP,\
		[ebp+4].IRET32.rCS,[ebp+4].IRET32.rFL,\
		[ebp+4].IRET32.rSP,[ebp+4].IRET32.rSS
	pop ebp
endif
	add esp, sizeof IRET32
	@strout <"return from ring 0 exception handler, esp=%lX",lf>,esp
;	@waitesckey
	pop ss:[taskseg._Esp0]
ife ?FIXTSSESP
if ?SETEXCHS
	push ebp
	mov ebp,ss:[taskseg._Esp0]
	lea ebp, [ebp-sizeof R3FAULT]
	mov ss:[dwHostStackExc], ebp
	pop ebp
endif
endif
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
	mov ebx,ss:[taskseg._Esp0]
	sub ebx,4 + sizeof R3FAULT	;5 register + errorcode + ?
	sub word ptr ss:[ebx+4].R3FAULT.rIP,2  ;"int xx"
	mov ax,[ebp+4+1 * ?RSIZE]	;address in table
	mov ss:[ebx+0],ax
	mov ax,[ebp+4+2 * ?RSIZE]	;errcode
	mov ss:[ebx+2],ax
	mov eax,ds
	test al,4
	jnz @F
	push 0
	pop ds
@@:
	mov eax,es
	test al,4
	jnz @F
	push 0
	pop es
@@:
	pop ebx
	pop eax
	pop ebp
	mov esp, ss:[taskseg._Esp0]
	sub esp, sizeof R3FAULT32 + 4
	jmp lpms_call_exc
else

;--- don't try to route ring0 exceptions to client
;--- eax == excnr

	@strout <"ring 0 exc at %X:%lX",lf>,[ebp+4].LCEFR0.f.rCS,\
		[ebp+4].LCEFR0.f.rIP
;	@waitesckey

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
	@strout <"ring 0 exc jmp to _exceptZ",lf>
;	@waitesckey
	jmp _exceptZ
endif

if ?IGNEXC01INR0

;--- might be an exception 01 in VCPI host

lpms_ce_4:
	@strout <"single step exception in ring 0 occured, ignored",lf>
	cmp ss:[cApps],0			;is a client active?
	jz @F
	mov ebp, ss:[taskseg._Esp0]	;set client Trace flag
	or byte ptr [ebp-sizeof IRET32].IRET32.rFL+1,1
@@:
	pop eax
	pop ebp
	add esp,sizeof RETF32 + 4 + 4	;RETF4 + excno + errcode
	and byte ptr [esp].IRET32.rFL+1,not 1
	iretd
endif
	align 4

lpms_call_host_exc endp

;*** client has done a RETF in its exception handler
;--- the errorcode has already been skipped in intr30!
;*** now switch stack back to PMS
;--- [esp]=IRET32 
;--- if we are on top of the LPMS, new SS:ESP is LPMS:FFF8h or LPMS:FFFCh

RPMEFR struct
rEax	dd ?
rEsi	dd ?
rDs		dd ?
		IRET32 <>
RPMEFR ends

	@ResetTrace

rpmstacke proc
	push ds
	push esi
	push eax
if _LTRACE_
	push ebp
	mov ebp, esp
	@strout <"entry rpmstacke: CS:IP=%X:%lX Fl=%lX SS:SP=%X:%lX">,\
		 [ebp+4].RPMEFR.rCS, [ebp+4].RPMEFR.rIP, [ebp+4].RPMEFR.rFL,\
		 [ebp+4].RPMEFR.rSS, [ebp+4].RPMEFR.rSP
	pop ebp
endif
	lds esi,[esp].RPMEFR.rSSSP
if ?LPMSCNT
	dec ss:[cLPMSused]
else
	mov eax, ds
	cmp ax,_LPMSSEL_
	jnz @F
	cmp si,?LPMSSIZE - 2 * ?RSIZE
	jnz @F
	mov byte ptr ss:cLPMSused,0
@@:
endif
if ?32BIT
  if ?HSINEXTMEM
	@checkssattr ds,bx
  endif
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
	@strout <", org SS:SP=%X:%lX",lf>,[ebp+4].RPMEFR.rSS, [ebp+4].RPMEFR.rSP
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
_LTRACE_ = 0

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
	@strout <"int30 simint ip=%X:%lX %lX sp=%X:%lX",lf>,[ebp+8].I30FR.rCS,\
		 [ebp+8].I30FR.rIP, [ebp+8].I30FR.rFL, [ebp+8].I30FR.rSS, [ebp+8].I30FR.rSP
;	@waitesckey
	pop ebp
endif

	shr ebx,1
	push ds
	mov [esp+4].I30FR.dwRes,ebx	;is an intno now
	lds ebx, [esp+4].I30FR.rSSSP
if ?CHECKSSIS32
	lar eax, dword ptr [esp+4].I30FR.rSS
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
	mov [esp+4].I30FR.rCS,ax
	mov ax, [ebx].IRETS.rFL
	mov [esp+4].I30FR.rFL,eax
endif
	add [esp+4].I30FR.rSP,sizeof IRETSPM	;adjust client stack
	pop ds
	pop eax
	pop ebx
;   pop ebp
	jmp dormsint
	align 4

if ?FASTJUMPS
intr30_jmps:
  if _LTRACE_
	push ebp
	mov ebp,esp
	@strout <"int30 jmps ip=%X:%lX %lX sp=%X:%lX",lf>,[ebp+4].IRET32.rCS,\
		 [ebp+4].IRET32.rIP, [ebp+4].IRET32.rFL, [ebp+4].IRET32.rSS, [ebp+4].IRET32.rSP
;	@waitesckey
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
if _LTRACE_
	push ebp
	mov ebp,esp
	@strout <"int30 special ip=%X:%lX %lX sp=%X:%lX",lf>,[ebp+4].I30FR.rCS,\
		[ebp+4].I30FR.rIP, [ebp+4].I30FR.rFL, [ebp+4].I30FR.rSS, [ebp+4].I30FR.rSP
	pop ebp
;	@waitesckey
endif
	mov eax,dword ptr cs:[ebx*2+offset spectab-400h]
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
	cmp ax,_RTEXC_			;return from exceptionhandler?
	jnz @F
	add ebx, ?RSIZE			;remove error code from client stack
	add [esp+4].I30FR.rSP, ?RSIZE
@@:
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
	mov [esp+4].I30FR.rFL,eax
	and ah,not _TF			   ;reset TF
	mov ss:[tmpFLReg],ax
	add [esp+4].I30FR.rSP, ?RSIZE
@@:
	add [esp+4].I30FR.rSP, ?RSIZE * 2
intr30_1:
if _LTRACE_
	push ebp
	mov ebp, esp
	@strout <"int30 special_2 ip=%X:%lX fl=%lX sp=%X:%lX",lf>,[ebp+8].I30FR.rCS,\
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

_LTRACE_ = 1
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

intr20  proc
	push eax
	lar eax,[esp+4].IRET32.rCSd
	test ah,60h
	pop eax
	jnz @F
	or byte ptr [esp].IRET32.rFL,1 ;carry flag setzen
if _LTRACE_
	push ebp
	mov ebp,esp
	push ds
	push esi
	lds esi,[ebp+4].IRET32.rCSIP
	@strout <"i20 (r0): sp=%X:%X ip=%X:%lX fl=%lX [ip]=%X %X",lf>,\
		ss,sp,[ebp+4].IRET32.rCS,[ebp+4].IRET32.rIP,[ebp+4].IRET32.rFL,\
		[esi+0],[esi+2]
	pop esi
	pop ds
	pop ebp
endif
	add [esp].IRET32.rIP,4
	iretd
@@:
	@strout <"i20 (r3), jmp to real mode",lf>
	@callrmsint 20h
intr20  endp

if ?WINDBG

	@ResetTrace

intr22:
	@strout <"Win386 debug API (int 22h) called, ax=%X",lf>,ax
	iretd
	align 4
endif


if ?GUARDPAGE0

;*** run 1 client instruction 

	@ResetTrace

execclientinstr proc
	push [esp+1*4].IRET32.rFL
	pop ss:[dwOrgFL]
	or byte ptr [esp+1*4].IRET32.rFL+1,1	 ;Set TF
	and byte ptr [esp+1*4].IRET32.rFL+1,0FDh ;reset IF
	call xchgint01
	call checkrmivtread			  ;before client instruction
if _LTRACE_
	push eax
	push ecx
	mov cx,[esp+3*4].IRET32.rCS
	mov eax,[esp+3*4].IRET32.rIP
	@strout <"now executing client code at %X:%lX",lf>,cx,eax
	pop ecx
	pop eax
endif
	add esp,4		  ;skip error code
	iretd
	align 4
execclientinstr endp

backtonormal proc
	push eax
	mov eax,ss:[dwOrgFL]
	and ah,03
	and byte ptr [esp+4].IRET32.rFL+1,0FCh
	or byte ptr [esp+4].IRET32.rFL+1,ah ;restore TF + IF

	mov eax,ss:[pg0ptr]
	and byte ptr ss:[eax],not ?GPBIT ;set PTE system reset

	call xchgint01
	cmp ss:[dwAddr],0			;address irrelevant, exit
	jz @F
	call checkrmivtwrite 		;after client instruction
@@:
	mov eax,ss:[dwHostBase] 	;base of host CS
	neg eax
	invlpg ss:[eax]				;works on 80486+ only!
	mov eax,ss:[lastcr2]
	mov cr2,eax
	pop eax
	iretd
	align 4
backtonormal endp

xchgint01 proc near
	push esi
	push eax
	mov esi,ss:[pdIDT.dwBase]
	sub esi,ss:[dwHostBase]
	mov eax,dword ptr ss:[myint01+0]
	xchg eax,ss:[esi+0+8]
	mov dword ptr ss:[myint01+0],eax
	mov eax,dword ptr ss:[myint01+4]
	xchg eax,ss:[esi+4+8]
	mov dword ptr ss:[myint01+4],eax
	pop eax
	pop esi
	ret
	align 4
xchgint01 endp

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

intr01 proc
if ?TESTEXC01
	push eax
	mov eax, dr6
	test ax, 0C00Fh
	jz @F
	mov ah,0
	mov dr6,eax
	pop eax
	jmp isdebugexc
@@:
	pop eax
	@simintpms 01
isdebugexc:
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
	@testexception
	@simintlpms 08
@@:
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
intr09 endp

simint09 proc
	@simintlpms 09
noint09::        
	@exception 09
	@defaultexc 09
simint09 endp

PATCHVALUE2 equ  0EBh + (offset simint09 - (offset intr09 + 2)) * 100h

intr0A proc
	@testexception 1
	@simintlpms 0A
@@:
	@exception 0A, TRUE
	@defaultexc 0A
intr0A endp

intr0B proc
	@testexception 1
	@simintlpms 0B
@@:
	@exception 0B, TRUE
	@defaultexc 0B,1
intr0B endp

intr0C proc
	@testexception 1
	@simintlpms 0C
@@:
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
	@strout <"int 0D: sp=%lX,[sp]=%lX,%lX,%lX,%lX,%lX",lf>,\
		eax, dword ptr [ebp+4], dword ptr [ebp+8],\
		dword ptr [ebp+12], dword ptr [ebp+16],\
		dword ptr [ebp+20]
	pop eax
	pop ebp
endif
	@testexception 1
;	test byte ptr [esp.IRET32.rFL+1],2 ;ints disabled?
;	jz int0dcalled 		   ;then it is a programmed INT
	@simintlpms 0D
@@:
	call checksiminstr		;emulate some priviledged opcodes
	@exception 0D, TRUE
	@defaultexc 0D,1
;int0dcalled:
;	@simintpms 0D
intr0D endp

	@ResetTrace

intr0E proc
	@testexception 1
	@simintlpms 0E
@@:
if ?GUARDPAGE0
	test ss:bEnvFlags,ENVF_GUARDPAGE0
	jz intr0e_1
	push eax
	mov eax,cr2
	cmp eax,1000h
	jnb @F
	mov eax,ss:[pg0ptr]
	or byte ptr ss:[eax],?GPBIT  ;set user bit
	pop eax
	jmp execclientinstr
@@:
	mov ss:[lastcr2],eax
	pop eax
intr0e_1:
endif
if ?CATCHLDTACCESS
	push edx
	push eax
	mov eax,cr2
	mov edx,ss:[dwLDTAddr]
	cmp eax,edx
	jb @F
	add edx,10000h
	cmp eax,edx
	jnb @F
;--- now do something here!
@@:
	pop eax
	pop edx
endif
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
	@testexception 1
	@simintpms 11
@@:
	@exception 11, TRUE
	@defaultexc 11
intr11 endp        
endif

;--- exceptions 11-1F not supported

defexcxx:			;default exceptions 11-1F
	int 3
	iretd
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
	@callrmproc 08,<ss:[intrmcbs+00*size INTRMCB].rm_vec>
if 0;?CATCHREBOOT
	@callrmproc 09,<ss:[intrmcbs+01*size INTRMCB].rm_vec>,myint09proc
else
	@callrmproc 09,<ss:[intrmcbs+01*size INTRMCB].rm_vec>
endif
	@callrmproc 0A,<ss:[intrmcbs+02*size INTRMCB].rm_vec>
	@callrmproc 0B,<ss:[intrmcbs+03*size INTRMCB].rm_vec>
	@callrmproc 0C,<ss:[intrmcbs+04*size INTRMCB].rm_vec>
	@callrmproc 0D,<ss:[intrmcbs+05*size INTRMCB].rm_vec>
	@callrmproc 0E,<ss:[intrmcbs+06*size INTRMCB].rm_vec>
	@callrmproc 0F,<ss:[intrmcbs+07*size INTRMCB].rm_vec>

	@callrmproc 70,<ss:[intrmcbs+08*size INTRMCB].rm_vec>
	@callrmproc 71,<ss:[intrmcbs+09*size INTRMCB].rm_vec>
	@callrmproc 72,<ss:[intrmcbs+10*size INTRMCB].rm_vec>
	@callrmproc 73,<ss:[intrmcbs+11*size INTRMCB].rm_vec>
	@callrmproc 74,<ss:[intrmcbs+12*size INTRMCB].rm_vec>
	@callrmproc 75,<ss:[intrmcbs+13*size INTRMCB].rm_vec>
	@callrmproc 76,<ss:[intrmcbs+14*size INTRMCB].rm_vec>
	@callrmproc 77,<ss:[intrmcbs+15*size INTRMCB].rm_vec>
	@callrmproc 1C,<ss:[intrmcbs+16*size INTRMCB].rm_vec>
;	@callrmproc 23,<ss:[intrmcbs+17*size INTRMCB].rm_vec>

_TEXT32 ends

_TEXT16 segment

;--- common entry for internal real-mode callbacks;
;--- used to route IRQs from real-mode to protected-mode;
;--- also used for int 1ch, 23h, 24h and mouse-event proc
;--- switch to protected mode only if client has modified pm vectors!

;--- the mouse event proc is somewhat different because it is no int;
;--- however, the true real-mode mouse event code in INT33API.ASM
;--- provides for a proper real-mode IRET frame.

	align 4

intrmcb_rm proc public

	@ResetTrace

	push bp
	mov bp,cs
	db 0eah			;jmp far16
	dw offset @F
wPatchDgrp3 dw 0	;will be patched with GROUP16
@@:
	sub bp,cs:wHostSeg
	bt cs:wIntRmCb,bp
	jc callbackisactive
irqrm2pm_3:
	shl bp,4				;sizeof INTRMCB == 16!
irqrm2pm_31:
if 0;_LTRACE_
;--- dont display int 08h/1Ch, this spoils the log
	cmp bp,00h*sizeof INTRMCB	;int 8?
	jz @F
	cmp bp,10h*sizeof INTRMCB	;int 1C?
	jz @F
	@stroutrm <"-intrmcb %X: calling old rm handler %X:%X [bits=%X.%X]",lf>, bp,\
		word ptr cs:[bp+offset intrmcbs].INTRMCB.rm_vec+2,\
		word ptr cs:[bp+offset intrmcbs].INTRMCB.rm_vec+0,\
		word ptr cs:[wIntRmCb+2], word ptr cs:[wIntRmCb+0]
@@:
endif
	push dword ptr cs:[bp+intrmcbs].INTRMCB.rm_vec
	mov bp,sp
	mov bp,[bp+4]
	retf 2	;skip bp on stack

callbackisactive:

	cmp cs:[bExcEntry],-1	;host entry possible?
	jnz irqrm2pm_3			;if no, jump to previous handler
	shl bp,4				;sizeof INTRMCB == 16!

if 0; ?CHECKIFINRMIVT wont work currently
	test byte ptr cs:[bp+offset intrmcbs].INTRMCB.flags, RMVFL_FARPROC
	jnz @F
	push bx
	mov bx,cs:[bp+offset intrmcbs].INTRMCB.wIvtOfs
	push ds
	push 0
	pop ds
	cmp word ptr [bx+2],GROUP16
	@stroutrm <"-intrmcb: rm-vec %X=%X:%X",lf>,bx,[bx+2],[bx+0]
	pop ds
	pop bx
	jnz irqrm2pm_31
@@:
endif
	@rm2pmbreak
	mov cs:[tmpBXReg],bx
	mov cs:[tmpAXReg],ax
	mov bx,bp
	mov bp,sp
	add bx, offset intrmcbs
	mov ax,[bp+2].IRETSRM.rFL
	pop bp

if ?NTCLEAR
	and ah,08Fh 				 ;reset NT,IOPL
	or ah,?PMIOPL				 ;iopl=3
endif
if ?DISINT@RM2PM
	and ah,0FDh
endif
	mov cs:[tmpFLReg],ax

if 0;_LTRACE_
	push bp
	mov bp,sp
	cmp bx,offset intrmcbs	 ;int 8?
	jz @F
	cmp bx,offset RMCB1C	 ;int 1C?
	jz @F
	mov ax,bx
	sub ax,offset intrmcbs
	shr ax,4
	mov cs:[_irq],ax

	mov al,0Bh
	out 0A0h,al
	in al,0A0h
	mov ah,al
	mov al,0Bh
	out 20h,al
	in al,20h
	@stroutrm <"-intrmcb:%X ISR=%X callr=%X:%X fl=%X RMF=%X cLP=%X old=%X:%X",lf>,\
		cs:[_irq], ax, [bp+2].IRETSRM.rCS,[bp+2].IRETSRM.rIP,\
		cs:tmpFLReg, cs:[bx].INTRMCB.flags, cs:[cLPMSused],\
		word ptr cs:[bx].INTRMCB.rm_vec+2, word ptr cs:[bx].INTRMCB.rm_vec+0
	@stroutrm <"-intrmcb: ds=%X es=%X fs=%X gs=%X",lf>, ds, es, fs, gs
@@:
	pop bp
endif

	@savermstk	;save real-mode SS+SP 

;--- raw jump in pm, ss:sp=hoststack
;--- ds,es,fs,gs undefined 

	@rawjmp_pm intrmcb_pm,1	;store real-mode segment registers in v86iret

if _LTRACE_
_irq	dw 0
endif
	align 4

intrmcb_rm endp

_TEXT16 ends

_TEXT32 segment

	@ResetTrace

intrmcb_pm proc

	@pushstate 1	;safe client state, including realmode segm DS/ES/FS/GS

;--- build an IRET32 frame on the host stack for IRETD to ring3.
;--- E/IP, CS and E/FLAGS will be copied to the LPMS/PMS
;--- after this is done, real-mode code can be called again

	push ss:tskstate.rSS	;SS
	push ss:tskstate.rESP	;ESP
	push ss:tmpFLRegD		;EFL
	push _INTSEL_			;CS
	push _FRTIN_			;EIP

;--- now displays (via dos or bios) are possible again

	push 0							;the true value will be set below

	inc ss:[cIntRMCB]

	mov ax,ss:[bx].INTRMCB.pmvec
	test byte ptr ss:[bx].INTRMCB.flags,RMVFL_IDT ;is pmvec a IDT offset?
	jz irqrm2pm_1
	cmp bx,offset RMCB24		;for Int 24 BP must be translated
	mov bx,ax
	jnz @F						;in a selector
	call load_pmsegs			;load client ds,es,fs,gs
	@strout <"#intrmcb: int 24, translation of bp=%X",lf>,bp
	push ebp
	call segm2sel
	pop ebp						;now BP has a selector
@@:
	push byte ptr _FLATSEL_
	pop ds

	push ebx
;;	movzx ebx,word ptr ss:[bx+0]	;offset in IDT
	movzx ebx, bx
	add ebx,ss:[pdIDT.dwBase]
if ?32BIT
	mov ax,[ebx+6]
endif
	mov ebx, [ebx+0]
	push byte ptr _CSALIAS_
	pop ds
	assume ds:GROUP32
if ?32BIT
	mov word ptr ds:[r3vectmp+0],bx
	mov word ptr ds:[r3vectmp+2],ax
	shr ebx,16
	mov word ptr ds:[r3vectmp+4],bx
else
	mov dword ptr ds:[r3vectmp+0],ebx
endif
	pop ebx
	mov ax,LOWWORD(offset GROUP32:r3vectmp)
irqrm2pm_1:
	mov [esp], ax			;set lowword of 32-bit offset of R3PROC
	call load_pmsegs		;load client ds,es,fs,gs

if ?CHECKHOSTSTACK
  if ?HSINEXTMEM
	cmp esp, ss:dwStackTop
  else
	cmp esp, 80h
  endif
	jc _exitclientEx5
endif

if _LTRACE_
	push eax
	movzx eax,ax
if ?32BIT
	@strout <"#intrmcb enter: call=%lX:%lX",lf>, cs:[eax].R3PROC._Cs, cs:[eax].R3PROC._Eip
else
	@strout <"#intrmcb enter: call=%X:%X",lf>, cs:[eax].R3PROC._Cs, cs:[eax].R3PROC._Eip
endif
	pop eax
endif

	mov bx,ss:[tmpBXReg]
	mov ax,ss:[tmpAXReg]

	jmp lpms_call_int		;LPMS switch + jump to ring 3
	align 4

intrmcb_pm endp

	assume ds:nothing

;--- returning from a internal real-mode callback (_FRTIN_)
;--- jump back to real-mode

	@ResetTrace

rpmstackr proc
	mov ss:[tmpBXReg],bx
	mov bx, word ptr [esp].IRET32.rFL
	mov ss:[tmpFLReg],bx	;save flags
if ?COPYTF        
	mov ss:[tmpAXReg],ax
endif
	dec ss:[cIntRMCB]

	@strout <"#intrmcb exit: fl=%X, HSTK=%lX, ss:esp=%lX:%lX",lf>,ss:[tmpFLReg],ss:[taskseg._Esp0], ss, esp

	lea esp, [esp + sizeof IRET32]	;skip the IRET32 frame
	@popstate 1						;restore client state
	@rawjmp_rm rpmstackr_rm
	align 4

rpmstackr endp

_TEXT32 ends

	@ResetTrace

_TEXT16 segment

rpmstackr_rm proc

	@restorermstk		;load rmSS:SP, set tskstate.rSSSP
	call load_rmsegs	;load segment regs from v86iret struct

if ?TRANSFL
  if ?COPYTF		;this is not set usually
	mov ax,cs:[tmpFLReg]
	test byte ptr cs:[bx].INTRMCB.flags,RMVFL_IDT  ;INT 1C, 23, 24?
	mov bx,sp
	jz @F
	mov byte ptr ss:[bx].IRETSRM.rFL,al
@@:
	and ah,01h
	or byte ptr ss:[bx].IRETSRM.rFL+1,ah
	mov ax,cs:[tmpAXReg]
  else
	test byte ptr cs:[bx].INTRMCB.flags,RMVFL_IDT  ;INT 1C, 23, 24?
	jz @F					;if it's a true irq, do nothing
	mov bx,sp
	push ax
	mov ax,cs:[tmpFLReg]	;forget TF, IF and the others 
	mov byte ptr ss:[bx].IRETSRM.rFL,al
	pop ax
@@:
  endif
endif

if _LTRACE_
	mov bx,sp
	@stroutrm <"-intrmcb exit ds=%X es=%X stk: cs:ip=%X:%X fl=%X stk=%X:%X",lf>,\
		ds,es,ss:[bx+2],ss:[bx+0],ss:[bx+4],ss,sp
endif
	mov bx,cs:[tmpBXReg]
	iret					;real mode iret!
	align 4
rpmstackr_rm endp

_TEXT16 ends

	@ResetTrace

_TEXT32 segment

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
;--- esp+0 -> DWORD intno
;--- esp+4 -> IRET32
;--- flags not modified
;--- used by macro @callrmint 

dormint proc
	xchg ebx, [esp]
	@getrmintvec [calladdr1]
	jmp dormproc_1
	align 4
dormint endp

;--- Ints 08-0F and 70-77, 1C
;--- esp+0 -> real-mode far proc to call (must have a IRET frame)
;--- esp+4 -> IRET32
;--- flags not modified
;--- used by macro @callrmproc

dormproc proc
	pop ss:[calladdr1]
	push ebx
dormproc_1::
	mov ebx, [esp+4].IRET32.rFL
	and bh,not _TF		;reset TF
if ?SETRMIOPL
	and bh,0CFh
	or bh,?RMIOPL
endif
	mov ss:[tmpFLReg], bx
	pop ebx
	@jmp_rm dormproc_rm
	align 4

dormproc endp

_TEXT32 ends

_TEXT16 segment

dormproc_rm proc
	push cs:[tmpFLReg]
	call cs:[calladdr1]
	@jmp_pmX dormproc_pm2
	align 4

dormproc_rm endp

_TEXT16 ends

_TEXT32 segment

dormproc_pm2 proc
	iretd
	align 4
dormproc_pm2 endp

;***  call real-mode software interrupt
;---  [esp+0] : DWORD intno
;---  esp+4 -> IRET32
;---  flags are modified!
;---  used by macro @callrmsint

	@ResetTrace

dormsint proc public

	xchg ebx,[esp]
;	@strout <"#dormsint %lX", lf>, ebx
	@getrmintvec [calladdr2]
	mov ebx,[esp+4].IRET32.rFL
	pushfd
	and bh,not _TF		;reset TF
	mov ss:[tmpFLReg],bx
	popfd
	pop ebx				;stack: ip,cs,fl,sp,ss
	@jmp_rm dormsint_rm
	align 4
dormsint endp

_TEXT32 ends

_TEXT16 segment

dormsint_rm proc

;	@stroutrm <"-dormsint %lX", lf>, cs:[calladdr2]
	push cs:[tmpFLReg]
	call cs:[calladdr2]
	pushf
	@rm2pmbreak
	pop cs:[tmpFLReg]
	@jmp_pm dormsint_pm2
	align 4
dormsint_rm endp

_TEXT16 ends

_TEXT32 segment

dormsint_pm2 proc
	push eax
	mov ax,ss:[tmpFLReg]
	and ah,8Fh				;reset NT, IOPL
	or ah,?PMIOPL
	mov word ptr [esp+4].IRET32.rFL,ax
	pop eax
	iretd
	align 4
dormsint_pm2 endp

;--- call a real-mode near16 proc internally
;--- esp+0 -> return address
;--- esp+4 -> DWORD near16 proc to call
;--- DS+ES may contain ring 0 selectors!

callrmprocintern proc public
	push eax
	mov eax, [esp+2*4]
;	mov ss:[calladdr3], eax
	mov ss:[calladdr3], ax
	pop eax
	pop [esp]	;removes parameter from stack

	push ds
	push es

	push 0		;clear es+ds
	pop es
	push 0
	pop ds
	@jmp_rm callrmprocintern_rm
	align 4
callrmprocintern endp

_TEXT32 ends

_TEXT16 segment
        
callrmprocintern_rm proc

	call cs:[calladdr3]
if 1
	@jmp_pmX callrmprocintern_pm2
else
	pushf				;flags need not be saved, since jmp_pm won't modify them
	@rm2pmbreak			;clears IF,TF+NT
	pop cs:[tmpFLReg]
	@jmp_pm callrmprocintern_pm2
endif
	align 4
callrmprocintern_rm endp

_TEXT16 ends

	@ResetTrace

_TEXT32 segment

callrmprocintern_pm2 proc
	pop es
	pop ds
if 0
	push eax
	mov ah, byte ptr ss:[tmpFLReg]
	sahf
	pop eax
endif
	ret
	align 4
callrmprocintern_pm2 endp

;*** proc called by macro @simrmint 
;--- esp+0 -> return address
;--- esp+4 -> DWORD intno
;--- this proc is to be called internally by host code

	@ResetTrace

dormintintern proc public

	push ebx
	mov ebx,[esp+2*4]
	@getrmintvec [calladdr2]
	pop ebx
	pop [esp]
	@jmp_rm dormintintern_rm
	align 4
dormintintern endp

_TEXT32 ends

_TEXT16 segment

dormintintern_rm proc

;	@stroutrm <"dormintintern_rm enter", lf>
	pushf
	call cs:[calladdr2]


dormintintern_rm_exit::	;<--- entry for int21api.asm

	@jmp_pmX dormintintern_pm2
	align 4
        
dormintintern_rm endp

_TEXT16 ends

_TEXT32 segment

dormintintern_pm2 proc

;	@strout <"dormintintern_pm2 enter", lf>
	ret
	align 4

dormintintern_pm2 endp

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
if 1
if ?SAVEPSP
;--- if another PSP is active, do NOT try to terminate the client
	mov eax,ss:[dwSDA]
	mov ax,[eax].DOSSDA.wPSP
	cmp ax, ss:[wPSPSegm]
	jnz @B
endif        
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
clientexit:
	mov ax,4cffh
	int 21h
	align 4

myint09proc endp

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

;*** emulate HLT and move to/from special registers
;*** emulate sti,cli,in,out if ?PMIOPL == 00

SIMINFR struct
dwESI	dd ?
dwDS	dd ?
		dd ?			;return address
		R3FAULT32 <>
SIMINFR ends        

	@ResetTrace

checksiminstr proc
	push eax
	lar eax, [esp+8].R0FAULT32.rCSd
	test ah, 60h
	pop eax
	jz doneX			;dont try to emulate anything in ring 0
	push ds
	push esi
	lds esi,[esp].SIMINFR.rCSIP
	push eax
	mov eax,ds
	lsl eax,eax
	cmp eax,esi		;EIP > limit?		 
	pop eax
	jc done
	cmp byte ptr [esi],0F4h	;HLT?
	jz simhlt
if ?EMUMOVREGCRX or ?EMUMOVCRXREG or ?EMUMOVCR0REG or ?EMUMOVREGDRX or ?EMUMOVDRXREG
	cmp byte ptr [esi],0Fh
	jnz donespec
if ?EMUMOVREGCRX
	cmp byte ptr [esi+1],20h	;mov xxx,crx?
	jz emuspecregmove
endif
if ?EMUMOVCRXREG or ?EMUMOVCR0REG       
	cmp byte ptr [esi+1],22h	;mov crx,xxx?
	jz emuspecregmove2
endif
if ?EMUMOVREGDRX
	cmp byte ptr [esi+1],21h	;mov xxx,drx?
	jz emuspecregmove
endif
if ?EMUMOVDRXREG
	cmp byte ptr [esi+1],23h	;mov drx,xxx?
	jz emuspecregmove2
endif
donespec:
if ?PMIOPL ne 30h
	call simio
endif
done:
;	@strout <"exception 0d, unknown instr %X",lf>,[esi]
	pop esi
	pop ds
doneX:
	ret
	align 4

emuspecregmove2:
if ?EMUMOVCR0REG
	push eax
	mov al,[esi+2]
	and al,0F8h
	cmp al,0C0h
	pop eax
	jnz done
endif
emuspecregmove:
	push eax
	mov al,[esi+2]
	mov ah,0CBh		;RETF
	shl eax, 16
	mov ax,[esi+0]		;the opcode is 3 bytes long (0F 2x xx)
	push ds
	push _CSALIAS_
	pop ds
	mov ds:[tmpCode], eax
	pop ds
	mov esi,[esp+4].SIMINFR.dwESI	;restore ESI
	@strout <"emulate 'mov eax, crx', eax=%lX", lf>, eax
	pop eax
	add [esp].SIMINFR.rIP,2
;	@waitesckey

	push cs
	push offset tmpCode
	call fword ptr [esp]
	add esp, 3*4		;dont touch esi now, skip far32, esi
	jmp retfromsim2
	align 4
endif

CDATA32 segment
tmpCode dd ?
CDATA32 ends

simhlt:
	@strout <"simulate hlt",lf>
ife ?SIMHLT
  if ?ALLOWR0IRQ
	sti
	hlt
	cli
  else
	pushd offset sim_hlt
	call callrmprocintern
  endif
else
	push eax
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
	pop eax
endif
	pop esi
retfromsim2:
	pop ds
	lea esp,[esp+4+4]		;skip returnaddr + error code
	inc [esp].IRET32.rIP
	iretd					;back to client
	align 4
checksiminstr endp


if ?PMIOPL ne 30h

;--- run the IOPL sensitive instructions in ring 0:
;--- CLI, STI, IN, OUT, INSx, OUTSx

	@ResetTrace

SIMIO struct
		dd ?			;saved EAX
dwExit	dd ?			;offset isioopc
		dd ?			;return to checksiminstr
dwESI	dd ?
dwDS	dd ?
		dd ?			;return address
		R3FAULT32 <>
SIMIO ends

simio proc
	push offset isioopc
	push eax
	lar eax,dword ptr [esp].SIMIO.rCS
	bt eax,16h
	setc ah
nextopc:
	mov al,[esi]
	inc esi
	cmp al,66h
	jnz @F
	xor ah,1
	jmp nextopc
@@:
	cmp al,0F3h
	jnz @F
	or ah,2
	jmp nextopc
@@:
	cmp al,0FAh	;CLI?
	jz simcli
	cmp al,0FBh	;STI?
	jz simsti

	cmp al,0E4h	;in al,const?
	jz siminc
	cmp al,0E6h	;out const,al?
	jz simoutc

	cmp al,6Ch		;INSB?
	jz siminsb
	cmp al,6Dh		;INSW/D?
	jz siminsw
	cmp al,6Eh		;OUTSB?
	jz simoutsb
	cmp al,6Fh		;OUTSW/D?
	jz simoutsw
	cmp al,0ECh	;in al,dx?
	jz siminaldx
	cmp al,0EDh	;in (e)ax,dx?
	jz siminaxdx
	cmp al,0EEh	;out dx,al?
	jz simoutdxal
	cmp al,0EFh	;out dx,(e)ax?
	jz simoutdxax
	pop eax
	add esp,4
	ret
isioopc:
	mov [esp-8].SIMIO.rIP, esi
	pop esi 			   ; skip return to checksiminstr
	pop esi
	pop ds
	add esp,4+4			;skip returnaddr + error code
	iretd					;back to client
simsti:
;	@strout <"#simulate sti",lf>
	or byte ptr [esp].SIMIO.rFL+1,2
	pop eax
	ret
simcli:
	@strout <"#simulate cli",lf>
	and byte ptr [esp].SIMIO.rFL+1,not 2
	pop eax
	ret
siminc:
	pop  eax
	push edx
	mov dl,[esi]
	inc esi
	mov dh,0
	@strout <"#simulate in al,%X",lf>,dx
	in al,dx
	pop edx
	ret
simoutc:
	pop eax
	push edx
	mov dl,[esi]
	inc esi
	mov dh,0
	@strout <"#simulate out %X,al",lf>,dx
	out dx,al
	pop edx
	ret
siminaldx:
	pop eax
	in al,dx
	@strout <"#simulate in al,dx [dx=%X, ax=%X]",lf>,dx,ax
	ret
siminaxdx:								;(66) ED
	test ah,1
	pop eax
	jnz @F
	in ax,dx
	@strout <"#simulate in ax,dx [dx=%X, ax=%X]",lf>,dx,ax
	ret
@@:
	in eax,dx
	@strout <"#simulate in eax,dx [dx=%X, eax=%lX]",lf>,dx,eax
	ret
simoutdxal:
	pop eax
	@strout <"#simulate out dx,al [dx=%X, ax=%X]",lf>,dx,ax
	out dx,al
	ret
simoutdxax: 							;(66) EF
	test ah,1
	pop eax
	jnz @F
	@strout <"#simulate out dx,ax [dx=%X,ax=%X]",lf>,dx,ax
	out dx,ax
	ret
@@:
	@strout <"#simulate out dx,eax [dx=%X, eax=%lX]",lf>,dx,eax
	out dx,eax
	ret
siminsb:
	test ah,2
	pop eax
	jnz @F
	insb
	@strout <"#simulate insb [dx=%X, es:edi=%lX:%lX]",lf>,dx,es,edi
	ret
@@:
	rep insb
	@strout <"#simulate rep insb [dx=%X, es:edi=%lX:%lX]",lf>,dx,es,edi
	ret
siminsw:
	test ah,2
	jnz simrepins
	test ah,1
	pop eax
	jnz @F
	@strout <"#simulate insw [dx=%X, es:edi=%lX:%lX]",lf>,dx,es,edi
	insw
	ret
@@:
	@strout <"#simulate insd [dx=%X, es:edi=%lX:%lX]",lf>,dx,es,edi
	insd
	ret
simrepins:
	test ah,1
	pop eax
	jnz @F
	@strout <"#simulate rep insw [dx=%X, es:edi=%lX:%lX]",lf>,dx,es,edi
	rep insw
	ret
@@:
	@strout <"#simulate rep insd [dx=%X, es:edi=%lX:%lX]",lf>,dx,es,edi
	rep insd
	ret

simoutsb:
	mov [esp].SIMIO.rIP, esi
	lds esi, fword ptr [esp].SIMIO.dwESI
	test ah,2
	pop eax
	jnz @F
	@strout <"#simulate outsb [dx=%X, ds:esi=%lX:%lX]",lf>,dx,ds,esi
	outsb
	jmp exitouts
@@:
	@strout <"#simulate rep outsb [dx=%X, ds:esi=%lX:%lX, ecx=%lX]",lf>,dx,ds,esi,ecx
	rep outsb
	jmp exitouts
simoutsw:
	mov [esp].SIMIO.rIP, esi
	lds esi, fword ptr [esp].SIMIO.dwESI
	test ah,2
	jnz simrepouts
	test ah,1
	pop eax
	jnz @F
	@strout <"#simulate outsw [dx=%X, ds:esi=%lX:%lX]",lf>,dx,ds,esi
	outsw
	jmp exitouts
@@:
	@strout <"#simulate outsd [dx=%X, ds:esi=%lX:%lX]",lf>,dx,ds,esi
	outsd
	jmp exitouts
simrepouts:
	test ah,1
	pop eax
	jnz @F
	@strout <"#simulate rep outsw [dx=%X, ds:esi=%lX:%lX, ecx=%lX]",lf>,dx,ds,esi,ecx
	rep outsw
	jmp exitouts
@@:
	@strout <"#simulate rep outsd [dx=%X, ds:esi=%lX:%lX, ecx=%lX]",lf>,dx,ds,esi,ecx
	rep outsd
exitouts:
	add esp,6*4
	iretd
simio endp
endif


;*** check if interrupt to modify is a IRQ (or 1Ch,23h,24h)
;*** if yes, provide for interrupts in real-mode to be routed to
;*** protected-mode
;*** this routine is called with new PM-IRQ-Vektor in CX:(E)DX
;*** from functions 31h,0205 (set pm vektor), BL=int
;--- dont change any register here

installirqhandler proc near public

	@ResetTrace

if ?IRQMAPPING

if _LTRACE_
	mov byte ptr ss:iirq,bl
endif
	push eax
	push ebx
	cmp bl,1Ch
	jz iirq1c
	cmp bl,23h
	jz iirq2324
	cmp bl,24h
	jz iirq2324
	cmp bl,?MPICBASE
	jb exit
	cmp bl,?MPICBASE+8
	jb mpicirq
	cmp bl,?SPICBASE
	jb exit
	cmp bl,?SPICBASE+8
	jnb exit
	sub bl,?SPICBASE-8		;70-77 -> 08-0F
	jmp iirqxx
iirq1c:
	mov bl,10h
	jmp iirqxx
iirq2324:
	sub bl,12h			;23h->11h, 24h->12h
	jmp iirqxx
mpicirq:
	sub bl,?MPICBASE	;08-0F -> 00-07
iirqxx:
	push ds
	push ss
	pop ds
	assume ds:GROUP16
	movzx ax,bl
	movzx ebx,bl
	shl ebx,4					;16 bytes/int (size INTRMCB!!!)
	add ebx,offset intrmcbs
	test byte ptr [ebx].INTRMCB.flags,RMVFL_IGN;don't route this IRQ?
	jnz done
	test byte ptr [ebx].INTRMCB.flags,RMVFL_IDT;if [bx+6] points in IDT,
									;no restauration is possible
	jnz @F
	test cl,4						;is it a LDT selector?
	jnz @F
	btr [wIntRmCb],ax
	mov eax,[ebx].INTRMCB.orgvec		;then restore rm-vector
	mov [ebx].INTRMCB.rm_vec, eax		;as well
	@strout <"#internal callback %X deactivated, restored to %lX, cx:edx=%X:%lX",lf>,ss:iirq,eax,cx,edx
	jmp done
@@: 									;pm-vector wird neu gesetzt
	@strout <"#internal callback %X activated, cx:edx=%X:%lX",lf>,ss:iirq, cx, edx
	bts [wIntRmCb],ax
	test byte ptr [ebx].INTRMCB.flags, RMVFL_SETALWAYS
	jz done

	push ecx
	mov ax, word ptr dwHostSeg			;GROUP16
	mov cx, [ebx].INTRMCB.myproc		;contains now just a number 0-19
	add ax, cx
	shl eax,16
	shl cx,4
	mov ax, offset intrmcb_rm
	sub ax, cx
	pop ecx

	movzx ebx,[ebx].INTRMCB.wIvtOfs
	push byte ptr _FLATSEL_
	pop ds
	mov [ebx], eax		;set value in IVT

done:
	pop ds
	assume ds:nothing
exit:
	pop ebx
	pop eax
endif
	ret
	align 4

installirqhandler endp

if ?GUARDPAGE0

	@ResetTrace

@watchentry macro wAddr, wSize, wOffs
	dw wAddr, wAddr+wSize, wOffs
endm

watchtab label word
	@watchentry ?SPICBASE*4, 8*4, 8*sizeof INTRMCB
	@watchentry 23h*4, 2*4, 11h*sizeof INTRMCB
	@watchentry 1Ch*4, 1*4, 10h*sizeof INTRMCB
	@watchentry ?MPICBASE*4, 8*4, 0*sizeof INTRMCB

;*** client wants to read RM-IVT directly (address in CR2)
;--- calc intrmcb offset in EAX

checkrmivtread proc
	pushad
	mov ss:[dwAddr],0
	mov eax,cr2
	and al,0FCh
	mov esi, offset watchtab
	mov cl,4
	xor edi, edi
	xor edx, edx
nextitem:
	mov dx, cs:[esi+0]
	mov di, cs:[esi+2]
	cmp eax, edi
	jnb exit
	cmp eax, edx
	jnb found
	add esi, 6
	dec cl
	jnz nextitem
exit:
	popad
	ret
found:
	mov ebx,eax
	@strout <"#checkrmivtread: direct ivt read trapped %X",lf>,bx
	sub eax,edx	;0,4,8,...
	shl eax,2	;0,16,32,... (sizeof INTRMCB)
	add ax, word ptr cs:[esi+4]
	lea esi,[eax + intrmcbs]
	test byte ptr ss:[esi.INTRMCB.flags],RMVFL_IGN
	jnz @F
	push ds
	mov ss:[dwAddr],esi
	push byte ptr _FLATSEL_
	pop ds
	mov eax,ss:[esi].INTRMCB.rm_vec
	mov ds:[ebx],eax	;store value in IVT
	pop ds
@@:
	popad
	ret
	align 4
checkrmivtread endp

;*** client has modified RM-IVT (address in CR2)

checkrmivtwrite proc
	pushad					;determine if it was a read or write
	push ds
	mov eax,cr2
	and al,0FCh
	mov ebx, eax
	push byte ptr _FLATSEL_
	pop ds
	mov ecx, ds:[ebx]		;get modified CS:IP in IVT

	mov esi, ss:[dwAddr]		;get pointer to INTRMCB

	mov ax, word ptr ss:[dwHostSeg]		;GROUP16
	mov dx, ss:[esi].INTRMCB.myproc		;contains now just a number
	add ax, dx
	shl eax,16
	shl dx,4
	mov ax, offset intrmcb_rm
	sub ax, dx
	mov ds:[ebx+0],eax		;store our value in IVT

	mov ss:[esi].INTRMCB.rm_vec,ecx	;store modified CS:IP
;	or byte ptr ss:[esi.INTRMCB.flags],RMVFL_ACTIVE
	@strout <"#checkrmivtwrite: ivt change trapped %X",lf>,bx
	pop ds
	popad
	ret
	align 4
checkrmivtwrite endp

endif

	@ResetTrace

;*** initialization procs ***

	assume ds:GROUP16

;*** server initialization when first client starts
;--- DS=GROUP16, ES=FLAT

	@ResetTrace

_init2server_pm proc near

	pushad
	assume ds:GROUP16

	@strout <"#init2server_pm enter",lf>
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

	mov ecx,10h				 ;alloc 64k for LDT
	mov edx, offset _AllocSysAddrSpace
	test bEnvFlags2, ENVF2_LDTLOW
	jz @F
	mov eax, ecx
	mov edx, offset _AllocUserSpace
@@:
	call edx
	jc exit
	mov [dwLDTAddr],eax
	@strout <"#space for LDT is allocated: %lX",lf>, eax
;	@waitesckey

;---- commit 1. page for LDT

	call EnlargeLDT
	jc exit

	@strout <"#LDT is initialized, allocating LPMS",lf>
;	@waitesckey
							;alloc memory for LPMS
	mov ecx,1
	call _AllocSysPages
	jc exit
	@strout <"#LPMS allocated",lf>

if ?LPMSINGDT
	mov ecx, pdGDT.dwBase
	push ds
	push byte ptr _FLATSEL_
	pop ds
	mov [ecx+(_LPMSSEL_ and 0F8h].DESCRPTR.A0015,ax
	shr eax,16
	mov [ecx+(_LPMSSEL_ and 0F8h].DESCRPTR.A1623,al
	mov [ecx+(_LPMSSEL_ and 0F8h].DESCRPTR.A2431,ah
	pop ds
else
	push ds
	push byte ptr _SELLDT_
	pop ds
	mov esi,80h
	mov [esi].DESCRPTR.A0015,ax
	shr eax,16
	mov [esi].DESCRPTR.A1623,al
	mov [esi].DESCRPTR.A2431,ah
	mov [esi].DESCRPTR.limit,0FFFh
if ?32BIT
	mov word ptr [esi].DESCRPTR.attrib,92h or ?PLVL + 4000h
else
	mov [esi].DESCRPTR.attrib,92h or ?PLVL
endif
	pop ds
endif
if ?INT1D1E1F
	push byte ptr _FLATSEL_
	pop es
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
	push byte ptr _FLATSEL_
	pop es

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
	@strout <"#init2server_pm exit",lf>
exit:
	popad
	ret
	align 4

_init2server_pm endp

if ?TLBLATE

;--- DS=GROUP16, ES=FLAT
;--- EDI must be preserved

	@ResetTrace

settlb_pm proc
	pushad
	@strout <"#settlb_pm: wSegTLB=%X, instance=%X, es=%lX",lf>, wSegTLB, wHostSeg, es
	cmp wSegTLB,0
	jnz exit
	call setstrat
	mov bx,?TLBSIZE/10h
	mov ah,48h
	call rmdosintern
	jc @F
	@strout <"#settlb_pm: new wSegTLB=%X",lf>, ax
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

INITCLRM struct	;real mode stack frame
wGS		dw ?
wFS		dw ?
wES		dw ?
wDS		dw ?
wFlags	dw ?
wIP		dw ?
wCS		dw ?
INITCLRM ends

INITCLPM struct	;protected mode stack frame
		PUSHADS <>
rDS		dd ?
		IRET32	<>
INITCLPM ends

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
;--- to be improved: the task data size is increased even
;--- for the first client, although this space is wasted.
;--- EDI -> linear address client stack (INITCLRM)
;--- EBP -> client standard registers (PUSHADS)
;--- ES = FLATSEL
;--- DS = SS = GROUP16


CreateVM proc

	movzx eax,es:[edi].INITCLRM.wES
	@strout <"#CreateVM enter, task data=%X, client stack=%lX",lf>, ax, edi
	shl eax, 4
if 0
	mov edi, eax
	mov ecx, ?RMSTKSIZE/4
	xor eax, eax
	rep stosd
	@strout <"#CreateVM: new real-mode stack cleared",lf>
else
	lea edi, [eax+?RMSTKSIZE]
endif
	push edi				;new dwHostBase
	xor esi, esi
	mov ecx, offset _StartOfVMData
	shr ecx, 2
	rep movsd
	@strout <"#CreateVM: real-mode code + host data copied (size %lX)",lf>, dword ptr offset _StartOfVMData
	mov esi, ltaskaddr
	mov ecx, offset _EndOfClientData
	sub ecx, offset _StartOfVMData
	@strout <"#CreateVM: prev client VM data=%lX (size %lX)",lf>, esi, ecx
	shr ecx, 2
	push es
	pop ds
	rep movsd
	@strout <"#CreateVM: client + VM data copied",lf>

	mov ecx,(?GDTLIMIT+1)/4
if ?MOVEGDT
	test ss:bEnvFlags2, ENVF2_LDTLOW	;IDT+LDT in user space?
	jz @F
	mov edx, edi		;EDX = new GDT address
	mov esi, offset curGDT
	@strout <"#CreateVM: GDT will be copied (size %lX)",lf>, ecx
	push ss
	pop ds
	rep movsd
	push es
	pop ds
	jmp gdtok
@@:
endif

;--- create new GDT

?TMPGDTOFS equ 10h	;offset in GROUP16 to temporarily move the GDT

	mov edi, [esp]		;get new dwHostBase (just above new RMS)
if 0
;--- the real-mode stack cannot be used, it's active
;--- after _initrms has been called and is then
;--- used by pagemgr.
	sub edi, ?RMSTKSIZE
else
;--- copy GDT temporarily in new host stack area
	add edi, ?TMPGDTOFS
endif
	mov edx, edi		;EDX = new GDT address
	mov esi, ss:pdGDT.dwBase
	rep movsd
	@strout <"#CreateVM: GDT copied to %lX (temp location in host stack area)",lf>, edx
gdtok:

	mov eax, [esp]		;get new dwHostBase
	mov [edx+_SSSEL_].DESCRPTR.A0015,ax
	mov [edx+(_DSR3SEL_ and 0F8h)].DESCRPTR.A0015,ax
if ?MOVEHIGHHLP
	mov [edx+_CSGROUP16_].DESCRPTR.A0015,ax
endif
	shr eax,16
	mov [edx+_SSSEL_].DESCRPTR.A1623,al
	mov [edx+(_DSR3SEL_ and 0F8h)].DESCRPTR.A1623,al
if ?MOVEHIGHHLP        
	mov [edx+_CSGROUP16_].DESCRPTR.A1623,al
endif
	pop eax		;get new dwHostBase
	add eax, offset taskseg
	mov [edx+_TSSSEL_].DESCRPTR.A0015,ax
	shr eax,16
	mov [edx+_TSSSEL_].DESCRPTR.A1623,al

;--- set new GDT, reload SS and DS caches

	push edx
	pushw ?GDTLIMIT
	lgdt fword ptr [esp]
	lea esp,[esp+6]

;--- reload client standard registers
	mov esp, ebp
	popad

;--- set DS to new GROUP16 base
	push ss
	pop ds

;--- set SS to new GROUP16 base;
;--- then recreate a INITCLPM struct on new stack
;--- then readdress client standard registers with EBP
	push ss
	pop ss
	mov esp, offset ring0stack
	mov taskseg._Esp0, esp
ife ?HSINEXTMEM	;if hs will be in extended memory, this is not required
	sub esp, sizeof IRET32 + 4
endif
	pushad
	mov ebp, esp

;--- now base of SS is new host base, GROUP16 variables of clone
;--- may be accessed from now on!
;--- re-access the client's stack with EDI

	movzx edi, wCurSS
	shl edi, 4
	movzx eax, wCurSP
	add edi, eax

	movzx eax, es:[edi].INITCLRM.wES
	shl eax, 4
	lea ecx, [eax + ?RMSTKSIZE + ?TMPGDTOFS]
	add eax, ?RMSTKSIZE

	test bEnvFlags2, ENVF2_LDTLOW
	jz @F
	lea ecx, [eax + curGDT]
@@:
	mov pdGDT.dwBase, ecx
	mov pdGDT.wLimit, ?GDTLIMIT
	mov dwHostBase, eax
	mov ecx, eax
	shr eax, 4

;--- repatch code in new GROUP16

	mov v86iret.rCS, ax	;GROUP16
;	mov v86iret.rSS, ax	;GROUP16
	mov dwHostSeg, eax	;GROUP16
if ?MOVEHIGHHLP
	mov wPatchDgrp1, ax	;GROUP16
endif
	mov wPatchDgrp2, ax	;GROUP16
	mov wPatchDgrp3, ax	;GROUP16

;--- reset FM_RESIDENT and FM_TLBMCB (we use the TLB of the parent)
;--- also, don't assume the real-mode vectors have been saved!
;--- they must be resaved. 

	and fMode, not (FM_RMVECS or FM_RESIDENT or FM_TLBMCB)
	or fMode, FM_CLONE

;--- some functions of filldesc must be reexecuted here

	lea eax,[ecx+ pdGDT]	 ;address GDT pseudo descriptor
	mov v86topm._gdtr,eax

	lea eax,[ecx+ pdIDT]	 ;address IDT pseudo descriptor
	mov v86topm._idtr,eax

	lea eax,[ecx+ v86topm]
	mov dword ptr [linadvs-4],eax	;patch code in rawjmp_pm

	mov wLDTLimit, 0
	mov rmsels,0			;just to be sure
	mov al,-2
	mov int96hk.bInt, al	;do not hook int 96/int 2F
	mov int2Fhk.bInt, al	
	mov eax, pdGDT.dwBase
	add eax, _TSSSEL_
	sub eax, dwHostBase
	mov dwTSSdesc, eax		;this var must be init for real-mode

;--- pg0ptr will be set later in pm_createvm
;--- but it must be valid now if option -i is set
;--- 8 is not the right value, but is a valid address which doesn't crash
;--- update: no longer required, pg0ptr initialized to point to an unused
;--- field in the tss.
;	mov pg0ptr, 8

	call _initrms			;may fail if ?ALLOCRMS is set; so better dont activate this switch!

if _LTRACE_
	mov dl,es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.A1623
	mov dh,0
	shl edx, 16
	mov dx,es:[ecx+(_TLBSEL_ and 0F8h)].DESCRPTR.A0015
endif
	@strout <"#CreateVM: GDT.base=%lX, dwHostBase=%lX, wSegTLB=%X, TLB=%lX",lf>, pdGDT.dwBase, dwHostBase, wSegTLB, edx
ife ?FIXTSSESP
	@strout <"#CreateVM: taskseg.esp0=%lX, dwHostStackExc=%lX",lf>, taskseg._Esp0, dwHostStackExc
endif

;--- let the heap do its reinitialization
	call hp_createvm
	@strout <"#CreateVM: GDT and instance switched, new instance=%X, RMS=%X:%X",lf>, wHostSeg, tskstate.rmSS, tskstate.rmSP

;--- let the page manager do its reinitialization
	@strout <"#CreateVM: calling pm_createvm",lf>
	call pm_createvm
	jc error
	@strout <"#CreateVM: pm_createvm called",lf>

if ?HSINEXTMEM
	mov ecx,1
	call _AllocSysPages		;alloc ECX pages
	jc error
	sub eax, [dwHostBase]
	lea ecx, [eax+80h]
	mov dwStackTop, ecx		;this is stack top
	add eax, 1000h
	mov taskseg._Esp0, eax
	mov esp, ebp
	popad
	mov esp, taskseg._Esp0
	sub esp, sizeof IRET32 + 4
	pushad
	mov ebp, esp
	@strout <"#CreateVM: new host stack=%lX",lf>, taskseg._Esp0
endif

;--- since the return address has been lost,
;--- a new one has to be pushed.
	push offset behindcreatevm

	test fHost, FH_XMS or FH_VCPI	;in raw mode?
	jnz @F
;--- in raw mode hook int 15h again.
;--- this is because our page pool is the current one
	movzx edi, int15hk.wOldVec
	mov eax, dwHostSeg
	shl eax, 16
	mov ax, int15hk.wNewOfs
	mov ebx, 15h*4
	xchg eax, es:[ebx]	;get and set the IVT value
	mov [edi],eax		;save the old value
@@:

;--- now copy CDATA32

	call _getcldata32
	push es
	pop ds				;DS = FLATSEL?
	push byte ptr _CSALIAS_
	pop es				;ES = GROUP32

	mov esi, 0FFBFD000h	;???
	add esi, eax
	mov edi, offset GROUP32:cldata32
	mov ecx, offset GROUP32:endcldata32
	sub ecx, edi
	@strout <"#CreateVM: cldata32 src=%lX, dst=%lX siz=%lX [%lX %lX]",lf>,\
		esi, edi, ecx, dword ptr [esi], dword ptr [esi+4]
	shr ecx, 2
	rep movsd
	push ds
	pop es			;ES = FLATSEL
	push ss
	pop ds			;DS = DGROUP16

;--- the IDT has to be moved high in any case, either in
;--- system space (ff8xxxxx) or user space (11xxxx)
	call _movehigh_pm		;allocates+inits CD30s + IDT
	jc error
	@strout <"#CreateVM: movehigh_pm called, edi=%lX",lf>, edi

;--- again: re-access the client's stack with EDI

	movzx edi, wCurSS
	shl edi, 4
	movzx eax, wCurSP
	add edi, eax

	call _init2server_pm		;host initialization on first client
	@strout <"#CreateVM: init2server_pm called",lf>

	call savermvecs			;clears CF
	@strout <"#CreateVM: real-mode vectors saved for internal rmcbs",lf>
	mov ltaskaddr, 0		;avoid to restore task state
	@strout <"#CreateVM exit",lf>
	ret
error:
	jmp behindcreatevm
CreateVM endp

endif

;--- init RMS.
;--- expects es:edi -> INITCLRM struct

_initrms proc
if ?ALLOCRMS					;alloc new RMS
	mov bx,?RMSTKSIZE/16
	mov ah,48h
	call rmdosintern
	jc exit
else
	mov ax,es:[edi].INITCLRM.wES
endif
	shl eax,16
	mov ax, ?RMSTKSIZE
	mov tskstate.rmSSSP, eax	;set new RMS
	@strout <"#initrms: new rmSS:SP=%X:%X",lf>, tskstate.rmSS, tskstate.rmSP
exit:
	ret
_initrms endp

_initclientstate proc
	call _initrms
if ?MOU33RESET
	cmp word ptr cs:mevntvec._Cs, 0
	jz @F
	call mouse33_reset			;event proc, reset it now
@@:
endif
	ret
_initclientstate endp


;--- client initialization protected mode

	@ResetTrace

_initclient_pm proc
	push ss
	pop ds
	assume ds:GROUP16
	push byte ptr _FLATSEL_
	pop es
;--- build a INITCLPM frame
	sub esp, sizeof IRET32 + 4
	pushad
	mov ebp, esp
	xor eax,eax
	mov fs,eax
	mov gs,eax

	@strout <"#initclient_pm: hdpmi instance=%X, RMS=%X:%X tss.esp0=%lX",lf>,\
		ss:wHostSeg, ss:tskstate.rmSS, ss:tskstate.rmSP, ss:taskseg._Esp0

	test byte ptr [fMode],FM_INIT
	jnz @F
	call _init2server_pm		;host initialization on first client
	jc initclerr1
	@strout <"#initclient_pm: initserver_pm returned",lf>
	or byte ptr [fMode],FM_INIT
@@:
					;save all rm IRQ vectors to intrmcbs
	call savermvecs	;if not done already. remains in prot-mode

	movzx edi, wCurSS
	shl edi, 4
	movzx eax, wCurSP
	add edi, eax
if ?VM
	test bEnvFlags, ENVF_VM
	jz @F
	cmp cApps,0
	jz @F
	call CreateVM		;expects EDI->client stack, EBP=client registers (PUSHADS )
behindcreatevm::        
	jc initclerr10
	jmp vmok
@@:
endif
	@strout <"#initclient_pm: call saveclientstate, task mem=%X",lf>,ax
	call _saveclientstate	;increments cApps
	jc initclerr11			;no memory
	call _initclientstate
vmok:
if ?TLBLATE
	call settlb_pm
	jc initclerr12
endif

if 0;?CR0COPY	;now done for first client only        
	mov eax,cr0				;use CR0, lmsw cannot set NE bit!
	and al, bFPUAnd
	or al, bFPUOr
	mov cr0,eax
endif
if ?CLEARDR6
	xor eax, eax
	mov dr6, eax
endif

if 0	;v2.18 useless moves
	mov ax,es:[edi].INITCLRM.wES
	mov bx,es:[edi].INITCLRM.wDS
	mov cx,es:[edi].INITCLRM.wFS
	mov dx,es:[edi].INITCLRM.wGS
	mov v86iret.rES,ax
	mov v86iret.rDS,bx
	mov v86iret.rFS,cx
	mov v86iret.rGS,dx
else
	mov bx,es:[edi].INITCLRM.wDS
endif

							;get selector for DS
	@strout <"#initclient_pm: call getmyseldata(big)",lf>
if ?32BIT
	call getmyseldatabig	;get descriptor for BX segment
else
	call getmyseldata
endif
	jc initclerr2
	@strout <"#initclient_pm: DS=%X, real mode DS=%X",lf>,bx,es:[edi].INITCLRM.wDS
	mov [ebp].INITCLPM.rDS,ebx
	mov [ebp].INITCLPM.rSS,bx
	movzx eax, wCurSP
	add ax, sizeof INITCLRM
	mov [ebp].INITCLPM.rSP, eax
	mov ax, es:[edi].INITCLRM.wIP
	mov [ebp].INITCLPM.rIP, eax
	mov ax, es:[edi].INITCLRM.wFlags
	and ax, 3FEh			;clear CF, IOPL, NT
	or ah, ?PMIOPL			;set protected-mode IOPL
	mov [ebp].INITCLPM.rFL, eax

	mov bx,es:[edi].INITCLRM.wCS
	mov dx,0008 			;attrib CODE
	call getmyselx
	jc initclerr4
	@strout <"#initclient_pm: CS=%X, real mode CS=%X",lf>,bx, es:[edi].INITCLRM.wCS
	mov [ebp].INITCLPM.rCS,bx
								;get selector for SS
	mov bx,[wCurSS]
	cmp bx,es:[edi].INITCLRM.wDS
	jz @F
if ?32BIT
	call getmyseldatabig
else
	call getmyseldata
endif
	jc initclerr3
	@strout <"#initclient_pm: SS=%X, real mode SS=%X",lf>,bx,[wCurSS]
	mov [ebp].INITCLPM.rSS,bx
@@:
if 0
	@strout <"#first dos call, disp '#'",lf>
;	@waitesckey
	mov ah,02h
	mov dl,'#'
	call rmdosintern
endif
if ?SAVEPSP
	mov eax,[dwSDA]
	mov bx,es:[eax].DOSSDA.wPSP
	@strout <"#initclient_pm: PSP from real-mode dos=%X",lf>,bx
;	@waitesckey
	mov [wPSPSegm],bx
	call getpspsel
else
	@strout <"#initclient_pm: first dos call, get PSP",lf>
;	@waitesckey
	mov ah,51h
	@int_21
	@strout <"#initclient_pm: protected mode PSP=%X",lf>,bx
;	@waitesckey
endif
	mov es,ebx
	assume es:SEG16
	mov bx,es:[002ch]		;environment segment
	and bx,bx
	jz @F
	call getmyseldata
	jc initclerr5
	mov es:[002ch],bx		;set environment selector
@@:
	@strout <"ENV=%X",lf>,bx

if ?GUARDPAGE0
	test [bEnvFlags],ENVF_GUARDPAGE0 	;should page0 be guarded?
	jz @F
	mov v86topm._Eip, offset vcpi_pmentry2
	mov eax,[pg0ptr]
	and byte ptr [eax],not ?GPBIT ;page 0 auf "system"
@@:
endif
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
	call allocxsel
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
if ?DBGSUPP
	test bEnvFlags2, ENVF2_DEBUG	;HDPMI=8192 set?
	jz @F
	or byte ptr [ebp].INITCLPM.rFL+1,1	;set TF
@@:
endif
	@strout <"#initclient_pm: client status ok, ebp=%lX, ss:esp=%lX:%lX",lf>, ebp, ss, esp
	@strout <"#initclient_pm: client: CS:IP=%X:%lX, SS:SP=%X:%lX, DS=%lX",lf>,[ebp].INITCLPM.rCS, [ebp].INITCLPM.rIP, [ebp].INITCLPM.rSS, [ebp].INITCLPM.rSP,[ebp].INITCLPM.rDS
	@strout <"#initclient_pm: GDT: %lX (%X), IDT: %lX (%X), LDT: %lX (%X)",lf>, pdGDT.dwBase, pdGDT.wLimit, pdIDT.dwBase, pdIDT.wLimit, dwLDTAddr, wLDTLimit
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
if ?32BIT
;	mov al,1
endif
	iretd

	assume ds:GROUP16

initclerr1:						;error global init PM
	@strout <"#init err1: cannot init",lf>
	mov al,13h
	jmp termserver
initclerr10:
	@strout <"#init err10: createvm failed",lf>
if _LTRACE_
	jmp initclerr1x
endif
initclerr11:					;saveclientstate failed
	@strout <"#init err11: saveclientstate failed",lf>
if _LTRACE_
	jmp initclerr1x
endif
initclerr12:					;settlb_pm failed
	@strout <"#init err12: settlb_pm failed",lf>
if _LTRACE_
	jmp initclerr1x
endif
initclerr1x:
	mov al,14h
	test [fMode],FM_RESIDENT
	jnz termclient2
	cmp [cApps],0
	je termserver
	jmp termclient2
initclerr2:						;cant alloc DS sel
	@strout <"#init err2: can't alloc DS sel",lf>
if _LTRACE_
	jmp @F
endif
initclerr3:						;cant alloc SS sel
	@strout <"#init err3: can't alloc SS sel",lf>
if _LTRACE_
	jmp @F
endif
initclerr4:						;cant alloc CS sel
	@strout <"#init err4: can't alloc CS sel",lf>
if _LTRACE_
	jmp @F
endif
initclerr5:						;cant alloc ENV/PSP sel
	@strout <"#init err5: can't alloc ENV/PSP sel",lf>
@@:
	mov al,11h
initclerr:
	test [fMode],FM_RESIDENT
	jnz termclient
	cmp [cApps],1
	jbe termserver
termclient:
	call _restoreclientstate	;important: rms restore
termclient2:
	mov ah,80h
	mov [ebp].PUSHADS.rAX, ax
	mov esp, ebp
	popad
	@rawjmp_rm _initclienterr_rm	;jmp rm, rm stack "undefined"

;--- no client running as of yet

termserver:
	mov ah,80h
	mov [ebp].PUSHADS.rAX, ax
	mov esp, ebp
	popad

	@printf <"hdpmi: cannot initialize",lf>

	push byte ptr _FLATSEL_
	pop es
	call resetrmvecs

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

if ?CHECKHOSTSTACK
_exitclientEx5 proc public
	mov ax,_EAERR5_
if ?HSINEXTMEM
	mov esp,ss:dwStackTop
	lea esp, [esp+0F80h]
else
	mov esp,offset ring0stack
endif
	mov ss:[taskseg._Esp0], esp
if ?FIXTSSESP
	mov ss:[dwHostStack], esp
else
;	mov ss:[dwHostStackExc], offset ring0stack - sizeof R3FAULT32
	lea esp, [esp - sizeof R3FAULT32]
	mov ss:[dwHostStackExc], esp
	lea esp, [esp + sizeof R3FAULT32]
endif
	jmp _exitclientEx
_exitclientEx5 endp
endif

ife ?RMCBSTATICSS
_exitclientEx4 proc public
	mov ax,_EAERR4_		;real-mode callback: no more descriptors for rm ss
_exitclientEx4 endp ;fall through
endif

_exitclientEx proc near public

ife ?DOSOUTPUT
	call forcetextmode
endif
	@printf <lf,"hdpmi: fatal exit %X",lf,lf>,ax

_exitclientEx endp ;fall through

	@ResetTrace

;--- client terminated with int 21h, ah=4Ch
;--- also jumped to from exception handler to terminate client

_exitclient_pm proc public
	@DebugBreak 0
	push eax					;save return code
	push ss
	pop ds
	assume DS:GROUP16
	push byte ptr _FLATSEL_
	pop es
	@strout <"#exitclient enter, cApps=%X, task=%lX RMS=%X:%X",lf>,<word ptr cApps>, ltaskaddr, tskstate.rmSS, tskstate.rmSP
	call closeinterrupts
	cmp [cApps],0			;fatal error on host initialization?
	jz exitclient_1
if 1
;--- make sure host is not reentered now (VCPI free memory)
	push dword ptr wIntRmCb
	mov dword ptr wIntRmCb,0
endif
	@strout <"#exitclient: call freeclientmemory",lf>
	call _freeclientmemory	;no register modified
	@strout <"#exitclient: call pm_exitclient",lf>
	call pm_exitclient		;no register modified
if 1
	pop dword ptr wIntRmCb
endif
if ?ALWAYSRESTORE
	mov bx,tskstate.rmSP		;needed for _exitclient_rm
	mov dx,tskstate.rmSS
	@strout <"#exitclient: call restoreclientstate",lf>
	call _restoreclientstate	;no register modified
endif
	@strout <"#exitclient: last task check",lf>
if ?ALWAYSRESTORE
	cmp [cApps],0
	jz exitclient_1
else
	cmp [cApps],1
	jbe exitclient_1
endif
exitclient_2:
	@strout <"#exitclient: client about to terminate",lf>
ife ?ALWAYSRESTORE
	@strout <"#exitclient: call restoreclientstate",lf>
	mov bx,tskstate.rmSP		;needed for _exitclient_rm
	mov dx,tskstate.rmSS
	call _restoreclientstate	;no registers modified
endif
	@strout <"#exitclient: jump to exitclient_rm, RMS=%X:%X, dx:bx=%X:%X",lf>, tskstate.rmSS, tskstate.rmSP, dx, bx
	pop eax			;get return code
	@rawjmp_rm _exitclient_rm	;raw jump to rm, rm stack "undefined"
        
;--- either last client terminates
;--- or server terminates without client (fatal exit on init)
;--- ES=FLAT, DS=GROUP16
        
exitclient_1:
if ?CR0COPY
	mov eax,cr0
	@strout <"#current CR0=%lX",lf>,eax
	and al, bFPUAnd
	or al, bCR0
	mov cr0,eax
	@strout <"#restored CR0=%lX",lf>,eax
endif        
if ?TLBLATE
	call resettlb_pm
endif
	@strout <"#no more clients, call resetrmvecs (can server terminate?)",lf>
	call resetrmvecs 		;check rm IVT
	jc exitclient_2		;keep resident on errors
	@strout <"#server termination would be ok",lf>
if ?RESIDENT
	test fMode, FM_RESIDENT
	jnz exitclient_2
endif
	@strout <"#server *will* terminate",lf>
	pop eax					;get return code
	pushd offset _dosexit_rm
	jmp _exitserver_pm 	;will return to real mode
	align 4

_exitclient_pm endp

if ?TLBLATE

	@ResetTrace

;--- is called when server goes idle (no clients)
;--- DS=GROUP16, ES=FLAT
        
resettlb_pm proc

	@strout <"#resettlb_pm, tlbseg=%X",lf>, wSegTLB
	test fMode2,FM2_TLBLATE
	jz exit
	test fMode,FM_TLBMCB
	jz exit
	cmp wSegTLB,0
	jz exit
	pushad
	mov eax,[dwSDA]
	mov bx,es:[eax].DOSSDA.wPSP
	@strout <"#resettlb_pm: set owner TLB to current PSP %X",lf>, bx
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
        
;*** modify all irq IVT vectors to our handler
;--- this proc is called by initclient_pm & CreateVM
;--- DS=GROUP16, ES=FLAT!
;--- preserve EDI, EBP!

savermvecs proc

	assume DS:GROUP16

	test byte ptr [fMode],FM_RMVECS
	jnz exit
	or byte ptr [fMode],FM_RMVECS
	mov cl,SIZEINTRMCB
	mov ebx,offset intrmcbs
nextvec:
	test byte ptr [ebx].INTRMCB.flags, RMVFL_IGN or RMVFL_FARPROC
	jnz @F
	movzx esi, [ebx].INTRMCB.wIvtOfs
	mov eax,es:[esi]
	mov [ebx].INTRMCB.rm_vec, eax
	mov [ebx].INTRMCB.orgvec, eax

	mov ax, word ptr [dwHostSeg]	;GROUP16
	mov dx,[ebx].INTRMCB.myproc		;contains now just a number
	add ax,dx
	shl eax, 16
	shl dx,4
	mov ax, offset intrmcb_rm
	sub ax, dx
	mov es:[esi+0],eax				;set CS:IP in IVT

@@:
	add ebx,sizeof INTRMCB
	dec cl
	jnz nextvec
exit:
	ret
	align 4
savermvecs endp

;--- this proc will first check all vectors if they can be restored
;--- if yes, they will be restored
;--- in: DS=GROUP16, ES=FLAT
;--- out: C if vectors cannot be restored

	@ResetTrace

resetrmvecs proc 

	assume DS:GROUP16

	pushad
	@strout <"#resetrmvecs: try to restore rm vectors",lf>
	mov ah, 00
	test fMode,FM_RMVECS				;IRQ vectors modified by HDPMI?
	jz exit
	mov di, wHostSeg				;GROUP16
	mov cl,TESTINTRMCB				;check IRQs and i1c

	test fMode,FM_CLONE
	jnz l2
	cmp es:[2Fh*4+2], di			;check vector 2Fh in IVT
	jz l2
	@strout <"#resetrmvecs: rm int 2Fh cannot be restored",lf>
	mov ah,2
	jmp exit
truereset:
	mov cl,SIZEINTRMCB
	mov ah,01
	and byte ptr [fMode],not FM_RMVECS
l2:
	mov di, wHostSeg				;GROUP16
	mov esi,offset intrmcbs
nextvec:
	test byte ptr [esi].INTRMCB.flags,RMVFL_IGN or RMVFL_FARPROC
	jnz l1
;;	and byte ptr [esi].INTRMCB.flags,not RMVFL_ACTIVE
	mov edx,[esi].INTRMCB.orgvec	;restore rm vectors in table
	mov [esi].INTRMCB.rm_vec, edx
	movzx ebx,[esi].INTRMCB.wIvtOfs	;that's harmless, since table
									;will be restored immediately
									;if there is another client
	test ah,01h						;test mode?
	jnz @F
	cmp es:[ebx+2], di				;there might be the case
	jz l1							;that the app itself has restored
									;the IVT vector
	cmp edx,es:[ebx]
	jz l1
	@strout <"#resetrmvecs: rm int %X cannot be restored",lf>,[esi].INTRMCB.myproc
	or ah,2							;save this in AH
	jmp l1
@@:
	mov es:[ebx],edx
l1:
	inc di
	add esi,sizeof INTRMCB
	dec cl
	jnz nextvec
	cmp ah, cl
	jz truereset
exit:
	shr ah,2						;return with C if not ok
	popad
	ret
	align 4
resetrmvecs endp

;--- exit the dpmi server
;--- this routine is actually never called without an active client;
;--- the hdpmi -u switch launches a temp client to remove the host.
;--- DS=GROUP16, ES=FLAT
;--- [esp]=routine to jump to (offset32) after switch to real-mode.

	@ResetTrace	;@SetTrace may require to set ?USEBIOS=0 in putchr.asm

_exitserver_pm proc

	push eax
if ?WDEB386
	test fDebug,FDEBUG_KDPRESENT
	jz @F
	mov ax,DS_ExitCleanup
	int Debug_Serv_Int
@@:
endif
	@strout <"#exitserver enter, ds=%lX es=%lX esp=%lX",lf>, ds, es, esp
	or [fMode],FM_DISABLED		;disable int 2Fh real-mode interface
;	@strout <"#call mouse33_exit, esp=%lX",lf>, esp
;	call mouse33_exit
	@strout <"#call pm_exit_pm, ds=%lX es=%lX esp=%lX",lf>, ds, es, esp
	call pm_exit_pm				;modifies no general purpose register
	@strout <"#final jump to real-mode, ds=%lX es=%lX esp=%lX",lf>, ds, es, esp
;	@waitesckey
	pop eax
	pop ss:[taskseg._Esi]
	@rawjmp_rm _exitserver_rm		;jmp rm, rm stack "undefined"
	align 4
_exitserver_pm endp

_TEXT32 ends

_TEXT16 segment

;--- restore some real mode software ints ( 2Fh, 96h, ...)
;--- DS = GROUP16
;--- out: C if real-mode vecs cannot be restored
;--- ES modified

	@ResetTrace

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
	or fMode,FM_CANTEXIT
endif
	or cl,1
	@stroutrm <"-cannot restore rm vec at %X [%X %X]",lf>, bx, ax, di
	jmp nextitem
@@:
	push dword ptr [di]
	pop dword ptr es:[bx]
	@stroutrm <"-restored rm vec at 0000:%X",lf>, bx
	mov byte ptr [si-5],-2
	jmp nextitem
exit:
	shr cl,1
	popa
	ret
	align 4
unhookIVTvecs endp

_TEXT16 ends

_TEXT16 segment

;--- final host termination code
;--- AX=exit code

	@ResetTrace

_exitserver_rm proc
	lss sp, cs:tskstate.rmSSSP
	call load_rmsegs			;restore FS, GS
	@stroutrm <"-now permanently in real-mode, ss:sp=%X:%X",lf>, ss, sp
	push cs
	pop ds
	push word ptr [taskseg._Esi]	;push the final real-mode dest
	push ax
if ?SAVEMSW
	smsw ax
	test al,1		;VM86?
	jnz @F
	mov ax,wMSW
	@stroutrm <"-restoring old MSW=%X",lf>,ax
	lmsw ax
@@:
endif
	@stroutrm <"-call pm_exit_rm",lf>
	call pm_exit_rm
	@stroutrm <"-call unhookivtvecs",lf>
	call unhookIVTvecs		;reset IVT 2F,15 and 96 vectors
if ?CANTEXIT
	test fMode,FM_CANTEXIT	;could host be terminated?
	jnz @F
endif
	@stroutrm <"-call unlinkserver",lf>
	call unlinkserver
@@:
	@stroutrm <"-call disablea20",lf>
	call _disablea20
if ?I2FINITEXIT
	mov ax,1606h
	mov dx,0001h
	int 2Fh
endif
	pop ax
	@stroutrm <"-exitserver exit, ax=%X, sp=%X",lf>, ax, sp
	ret
	align 4

_exitserver_rm endp

;*** we have been started as task making ourself resident
;*** now we want to terminate with the exiting app

unlinkserver proc
	pusha
if ?VM
	test [fMode], FM_CLONE	;nothing to be done if this is a clone
	jnz @exit
endif
	mov dx,[wEMShandle]
	and dx,dx
	jz @F
	mov ah,45h
	int 67h
@@:
ife ?STUB
	@stroutrm <"-calling int 21h, ah=51h [sp=%X]",lf>,sp
	mov ah,51h				;get current psp in BX
	int 21h
	mov ax,[wHostPSP]
	dec ax
	mov es,ax
	mov es:[1],bx				;set owner of host segment to cur psp
	@stroutrm <"-set psp of mcb %X to %X",lf>,ax,bx
	test [fMode], FM_TLBMCB		;is TLB an extra MCB?
	jz @exit
	mov ax,[wSegTLB]
if ?TLBLATE
	and ax,ax
	jz @exit
endif
	dec ax
	mov es,ax
	mov es:[1],bx
	@stroutrm <"-set psp of mcb %X to %X",lf>,ax,bx
endif
@exit:
	popa
	ret
unlinkserver endp

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

	@stroutrm <"-init2server_rm entry, first client starting",lf>
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

	align 4

	@ResetTrace

req_bad:
if ?CALLPREVHOST
	test cs:[fHost],FH_HDPMI	;is another instance of HDPMI installed?
	jz @F
	jmp cs:[dwHost16]		;then route the request to it
@@:
endif
	@stroutrm <"-initclient_rm: bad client request, ax=%X",lf>,ax
	mov ax,8021h
	stc
	retf

_initclient_rm proc 

	assume DS:nothing

	test al,1
if ?32BIT
	jz req_bad
else
	jnz req_bad
endif
	pushf
	@rm2pmbreak
	push ds
	push es
	push fs
	push gs

;--- now a INITCLRM is build on the realmode stack

	push cs
	pop ds

	assume ds:GROUP16

;	@savermstk
	mov [wCurSP],sp
	mov [wCurSS],ss

	@stroutrm <"-initclient_rm: new client starting, host=%X, es=%X, ss:sp=%X:%X",lf>,cs,es,ss,sp

if ?I2FINITEXIT        
	test byte ptr [fMode],FM_INIT
	jnz @F
	call _init2server_rm		;server initialization on first client
;;  jc initclerrx
	@stroutrm <"_init2server_rm ok",lf>
@@:
endif

;	@rawjmp_pm _initclient_pm, 1;save real-mode segments, SP unchanged
	@rawjmp_pm _initclient_pm	;do no save real-mode segments

_initclient_rm endp

;--- error during client initialization

_initclienterr_rm proc

if 1
	lss sp,cs:[dwCurSSSP]
else
	@restorermstk
endif
	pop gs
	pop fs
	pop es
	pop ds
	popf
	stc
	@stroutrm <"client init failed, ss:sp=%X:%X, ds-gs=%X %X %X %X, ax=%X",lf>,\
		ss, sp, ds, es, fs, gs, ax
;	@waitesckey
	retf
_initclienterr_rm endp

	@ResetTrace

_exitclient_rm proc

;--- switch to RMS (since task state has been restored, in tskstate now is
;--- the RMS of the previous client!!!)

	mov ss,dx
	mov sp,bx
	@stroutrm <"-exitclient_rm enter: ss:sp=%X:%X, RMS=%X:%X",lf>,ss,sp,cs:tskstate.rmSS,cs:tskstate.rmSP

	call load_rmsegs	;restore rm segs from v86iret
	@stroutrm <"-exitclient_rm: ds-gs=%X %X %X %X",lf>,ds,es,fs,gs

if _LTRACE_
	push ax
	mov ah,51h
	int 21h
	push ds
	mov ds,bx
	assume ds:SEG16
	@stroutrm <"-exitclient_rm: psp=%X, [psp:0A=%X:%X, 16=%X, 2E=%X:%X]",lf>, bx,\
		word ptr ds:[000Ch], word ptr ds:[000Ah], word ptr ds:[0016h],\
		word ptr ds:[0030h], word ptr ds:[002Eh]
	mov ds,ds:[0016h]
	@stroutrm <"-exitclient_rm: [prevPSP:2E=%X:%X]",lf>,ds:[0030h],ds:[002Eh]
	pop ds
	assume ds:nothing
	pop ax
endif
	@stroutrm <"-exitclient_rm: jmp to DOS, ax=%X",lf>,ax

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
	@stroutrm <"exception 06 in real mode at %X:%X: %X %X",lf>,ds,bx,[bx],[bx+2]
	pop bp
endif
	@jmp_pm _exitclientEx8

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
	test cs:fMode,FM_CANTEXIT
	jnz tryexitnow
endif
	cmp ah,16h
	jz int2f16
noint2f16:
	popf
int2f_default:
	@jmpoldvec 2F
int2f16:
	test cs:[fMode],FM_DISABLED
	jnz noint2f16
	popf
	cmp al,87h
	jz int2f1687
if _LTRACE_
  ifndef _DEBUG			;dont display too much in debug version
	cmp al,8fh
	jz @F
	@stroutrm <"int 2f rm,ax=%X,bx=%X",lf>,ax,bx
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
	test cs:[bEnvFlags2],ENVF2_NOI2F160A
	jnz @F
	xor ax,ax
	mov bx,?2F160AVER 	  ;get windows version
	mov cx,?WINMODE 	  ;mode (2=standard/3=enhanced)
	iret		          ;real-mode iret!
@@:
endif
if ?SUPP32RTM
	cmp al,8ah
	jz int2f168a
endif
	jmp int2f_default

int2f1687:
	push cs
	pop es				;PM Entry
	mov di,offset _initclient_rm
if ?ALLOCRMS
	mov si,0000 		;task bytes
else
	mov si,?RMSTKSIZE/10h  ;task bytes
;PatchRMStkSize label word
endif
if ?VM
	cmp cs:cApps,0
	jz @F
	add si,cs:wCloneSize
@@:
endif
	mov dx,cs:[wVersion]
	mov cl,cs:[_cpu]	;processor
if ?32BIT
	mov bx,1			;32-Bit Apps
else
	mov bx,0			;no 32-Bit Apps
endif
	xor ax,ax
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

;--- this is Int 96h real-mode proc
;--- the purpose is to prevent debuggers to step in host's mode-switch code
;--- which cannot work

if ?INTRM2PM
intrrm2pm proc far public
if 1
	push bp
	mov bp,sp
	and byte ptr [bp+2].IRETSRM.rFL+1,0BCh	;clear NT, IF, TF
	inc [bp+2].IRETSRM.rIP
	pop bp
	iret
else
	movzx esp,sp
	and byte ptr [esp].IRETSRM.rFL+1,0BCh	;clear NT, IF, TF
	inc [esp].IRETSRM.rIP
endif
	iret                            ;real-mode iret!
intrrm2pm endp
endif

;--- real-mode HLT emulation

sim_hlt proc near
	sti
	hlt
	ret
sim_hlt endp

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
	iret            ;real-mode int ret!
if ?WATCHDOG
iretwithC:
	popf
	push bp
	mov bp,sp
	or byte ptr [bp+6],_CY
	pop bp
	iret            ;real-mode int ret!
endif
if ?CATCHREBOOT
int154f53:
	cmp cs:[cApps],0
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
	@stroutrm <"int 15 rm, ctrl-alt-del pressed",lf>,ax,bx
	@jmp_pmX catchreboot
endif

int15rm endp


if ?TRAPINT21RM

;--- int 21 hook. not used

	@ResetTrace

int21rm proc far
	push ax
if ?CHECKIRQRM
	cmp ah,25h
	jz @F
	cmp ah,35h
	jz @F
endif
normint21:
	pop ax
	@jmpoldvec 21
;	jmp  dword ptr cs:[int21hk.dwOldVec]


if ?CHECKIRQRM
@@:
	cmp al,?MPICBASE+0
	jb normint21
	cmp al,?MPICBASE+8
	jb specialint21_1
	mov ah,10h
	cmp al,1Ch
	jz specialint21_2
	inc ah
	cmp al,23h
	jz specialint21_2
	inc ah
	cmp al,24h
	jz specialint21_2
	cmp al,?SPICBASE+0
	jb normint21
	cmp al,?SPICBASE+8
	jnb normint21
	sub al,?SPICBASE-8
	jmp specialint21_3
specialint21_1:
	sub al,8
	jmp specialint21_3
specialint21_2:
	mov al,ah
specialint21_3:
	mov ah,00
	shl ax,4					;assume size INTRMCB == 16!!!
	add ax,offset intrmcbs
	movzx esp,sp
	xchg ax,[esp]
	cmp ah,25h
	jz setint
	pop bx
	@stroutrm <"rm get int %X %X %X",lf>,ax,cs:[bx],cs:[bx+2]
	push dword ptr cs:[bx]
	pop bx
	pop es
	iret            ;real-mode int ret!
setint:
	xchg bx,[esp]
	@stroutrm <"rm set int %X %X %X %X",lf>,ax,bx,ds,dx
	mov cs:[bx+0],dx
	mov cs:[bx+2],ds
	pop bx
	iret            ;real-mode int ret!
endif

int21rm endp

endif

_TEXT16 ends

if ?STACKLAST

;--- if the stack is not the last segment, avoid it being physically
;--- in the binary. To achieve this do not define a stack size.
;--- the linker will then set the SS paragraph offset only, SP is 0,
;--- and tool SETMZHDR will then set the stack size to 0x200.

STACK segment use16 stack 'STACK'
	db 200h dup (?)
STACK ends
endif

end

