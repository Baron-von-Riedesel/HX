
	include version.inc

;--- REQ_MACHINE_DATA flags

X86AC_BIG	equ 1
X86AC_REAL	equ 2

system_config struct ;bld\dig\h\digtypes.h
cpu		db ?	;cpu (0
fpu		db ?
osmajor	db ?
osminor	db ?
os		db ?    ;OS_DOS
huge_shift db ?
mad		db ?    ;MAD_X86
system_config ends

;--- os values
OS_DUNNO	equ 0
OS_DOS		equ 1
OS_RATIONAL	equ 7
OS_NT		equ 10

MAX_X86		equ 1

;--- flags returned by REQ_PROG_LOAD

LD_FLAG_IS_32               = 00001h	;obsolete?
LD_FLAG_IS_PROT             = 00002h	;obsolete?
LD_FLAG_IS_STARTED          = 00004h
LD_FLAG_IGNORE_SEGMENTS     = 00008h
LD_FLAG_HAVE_RUNTIME_DLLS   = 00010h
LD_FLAG_DISPLAY_DAMAGED     = 00020h

;--- values from trapbrk.h
;--- returned by REQ_PROG_GO/STEP

COND_CONFIG         = 00001h
COND_SECTIONS       = 00002h
COND_LIBRARIES      = 00004h
COND_ALIASING       = 00008h
COND_THREAD         = 00010h
COND_THREAD_EXTRA   = 00020h
COND_TRACE          = 00040h
COND_BREAK          = 00080h
COND_WATCH          = 00100h
COND_USER           = 00200h
COND_TERMINATE      = 00400h
COND_EXCEPTION      = 00800h
COND_MESSAGE        = 01000h
COND_STOP           = 02000h

;--- structure to store debuggee state (integer registers)

trap_cpu_regs struct	;bld\dig\h\madx86.h
_Eax	dd ?
_Ebx	dd ?
_Ecx	dd ?
_Edx	dd ?
_Esi	dd ?
_Edi	dd ?
_Ebp	dd ?
_Esp	dd ?
_Eip	dd ?
_Efl	dd ?
_Cr0	dd ?
_Cr2	dd ?
_Cr3	dd ?
_Ds		dw ?
_Es		dw ?
_Ss		dw ?
_Cs		dw ?
_Fs		dw ?
_Gs		dw ?
trap_cpu_regs ends

x86_fpu struct
fcw    dd ?            ;+0
fsw    dd ?            ;+4
ftw    dd ?            ;+8
fip    dd ?            ;+12
fcs    dw ?            ;+16
fop    dw ?            ;+18
fdp    dd ?            ;+20
fds    dd ?            ;+24
reg real10 8 dup (?)   ;+28
x86_fpu ends           ;+108

;--- format of FXSAVE mem area
fxsav_ctrl struct
fcw    dw ?		;+0
fsw    dw ?		;+2
ftw    dw ?		;+4 only lower byte is used
fop    dw ?		;+6
fip    dd ?		;+8
fcs    dd ?		;+12
fdp    dd ?		;+16   
fds    dd ?		;+20
mxcsr  dd ?		;+24
mxcsr_msk dd ?	;+28
fxsav_ctrl ends

mmx_reg struct
	dq ?
	dw ?
mmx_reg ends

xmm_reg struct
	dq 2 dup (?)
xmm_reg ends

x86_mmx struct
_spacer dd 7 dup (?)   ;7*4=28
mm_  mmx_reg 8 dup (<>) ;8*10=80
x86_mmx ends           ;+108

x86_xmm struct
xmm_ xmm_reg 8 dup (<>)  ;8*16=128
mxcsr dd ?              ;+4=132
x86_xmm ends

x86_mad_registers struct
cpu trap_cpu_regs <>
union
fpu  x86_fpu  <>
mmx  x86_mmx  <>
ends
xmm_  x86_xmm  <>
x86_mad_registers ends

PF16 typedef far16 ptr
PF32 typedef far32 ptr

;---- constants/macros which vary between 16bit/32bit clients

if ?DPMI16

?WINSUPP	equ 1	;support running in windows. the windows dpmi host
					;will not allow to set interrupt/exception vectors to
                    ;a 32bit code segment. A small stub is required

INTVEC	typedef PF16
EFRAME	typedef EXCFRAME16

?SEGOFS equ 2

IRETS struct
_Eip	dw ?
_Cs		dw ?
_Efl	dw ?
IRETS ends

EXECPM struct
environ	dw ?
cmdline dd ?
fcb1    dd ?
fcb2    dd ?
EXECPM ends        

@iret macro
	iret
endm

@retf macro
	db 66h
	retf
endm

@switchcs macro
local lbl
if ?WINSUPP
	db 66h,0eah
;	dd $+6            ; jwasm version 2.15 might have problems with $+6
	dd lbl
	dw DGROUP
lbl:
endif        
endm

@loadcs macro reg        
if ?WINSUPP
	mov reg, g_cs16alias
else        
	mov reg, cs
endif        
endm

@callint21 macro
	pushf
	call [oldint21]
endm

@callint31 macro
	pushf
	call [oldint31]
endm

@lodsdflat macro
	db 65h		;GS prefix
	lodsd
endm

@lodswflat macro
	db 65h		;GS prefix
	lodsw
endm

@prologue macro procname,flag,parmbyte,localbyte,reglist,userparms

    if flag
      if parmbyte + localbyte
        push    ebp
        movzx   ebp,sp
      endif
      if localbyte
        add     esp,-localbyte
      endif
    endif
    for r,reglist
       push r
    endm
    exitm %localbyte
endm

OPTION PROLOGUE: @prologue

else	;!?DPMI16

INTVEC	typedef PF32
EFRAME	typedef EXCFRAME        

?SEGOFS equ 4

IRETS struct
_Eip	dd ?
_Cs		dd ?
_Efl	dd ?
IRETS ends

EXECPM struct
cmdline dq ?
fcb1    dq ?
fcb2    dq ?
EXECPM ends        

@iret macro
	iretd
endm

@retf macro
	retf
endm

@switchcs macro
endm

@loadcs macro reg        
	mov reg,cs
endm

@callint21 macro
	pushfd
	call [oldint21]
endm

@callint31 macro
	pushfd
	call [oldint31]
endm

@lodsdflat macro
	lodsd
endm

@lodswflat macro
	lodsw
endm

endif
