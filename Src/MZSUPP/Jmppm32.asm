
;*** startup routine, which will do
;*** 1. check if DPMI is available
;*** 2. if no, optionally try to load HDPMI32
;*** 3. try to switch to protected mode as 32 bit DPMI client
;*** 4. optionally move image into extended memory
;*** 5. allocate stack + heap (default 512 MB/ 512 MB)
;*** 6. jmp to external proc mainCRTStartup

ifndef ?LOADSERVER
?LOADSERVER    = 1		;try to load HDPMI server
endif
?USECRT 	   = 1		;be C runtime compatible
?DEFSTKSIZ	   = 180h	;default stack size in real mode   
?HDPMINOP0G    = 0		;obsolete, no longer used
?NORELOCS	   = 0		;dont generate relocations
?CLEARCOMMAREA = 1		;clear comm area with zeros
?FREEOLDCS	   = 1		;free old CS after switch to 32 bit segment
?FLATGS 	   = 1		;GS is set with zero-based flat 4GB selector
?PMSTORE	   = 1		;wait until in protected mode before storing
						;anything in _DATA segment


		.386

;*** now coming a lot of segment definitions
;*** this is simply to allow some init/term procedures to be defined.
;*** since OMF format doesnt sort segments alphabetically, they
;*** have to be defined here, cause this module should always be placed
;*** as first module for the OMF linker

HDPMI	segment use16 para public '16_CODE'
HDPMI	ends

_TEXT16 segment use16 word public '16_CODE'
_TEXT16 ends

_ETEXT16 segment use16 para public '16_CODE'
endof16bit label near
_ETEXT16 ends

CGROUP16 group HDPMI, _TEXT16, _ETEXT16

;		 .MODEL SMALL, stdcall

		include jmppm32.inc

		option dotname

BEGTEXT segment dword public 'CODE'
BEGTEXT	ends

_TEXT	segment dword public 'CODE'
_TEXT	ends

_TEXT32	segment dword public 'CODE'
_TEXT32	ends

_NULL	segment dword public 'BEGDATA'
_NULL	ends

_DATA	segment dword public 'DATA'
_DATA	ends

if ?WIN32
;--- the segments beginning with .BASE$ may be used by
;--- the WIN32 API emulation code for some init/term procs
;--- source code of KERNEL32 is now available so watch this
;--- for details.

.BASE$	segment dword public 'DATA'
startinitprocs label dword
.BASE$	ends
.BASE$0	segment dword public 'DATA'
endinitprocs label byte
		dd 0
.BASE$0	ends

.BASE$D		segment dword public 'DATA'
.BASE$D		ends
.BASE$DA	segment dword public 'DATA'
.BASE$DA	ends
.BASE$DZ	segment dword public 'DATA'
.BASE$DZ	ends
.BASE$I		segment dword public 'DATA'
.BASE$I		ends
.BASE$IA	segment dword public 'DATA'
.BASE$IA	ends
.BASE$IC	segment dword public 'DATA'
.BASE$IC	ends
.BASE$IZ	segment dword public 'DATA'
.BASE$IZ	ends
.BASE$X		segment dword public 'DATA'
.BASE$X		ends
.BASE$XA	segment dword public 'DATA'
.BASE$XA	ends
.BASE$XC	segment dword public 'DATA'
.BASE$XC	ends
.BASE$XZ	segment dword public 'DATA'
.BASE$XZ	ends
endif

;--- segments beginning with .CRT$ may be used by
;--- C runtime modules.

.CRT$XIA segment dword public 'DATA'
.CRT$XIA ends
.CRT$XIC segment dword public 'DATA'
.CRT$XIC ends
.CRT$XIZ segment dword public 'DATA'
.CRT$XIZ ends
.CRT$XCA segment dword public 'DATA'
.CRT$XCA ends
.CRT$XCC segment dword public 'DATA'
.CRT$XCC ends
.CRT$XCL segment dword public 'DATA'
.CRT$XCL ends
.CRT$XCU segment dword public 'DATA'
.CRT$XCU ends
.CRT$XCZ segment dword public 'DATA'
.CRT$XCZ ends
.CRT$XPA segment dword public 'DATA'
.CRT$XPA ends
.CRT$XPX segment dword public 'DATA'
.CRT$XPX ends
.CRT$XPZ segment dword public 'DATA'
.CRT$XPZ ends
.CRT$XTA segment dword public 'DATA'
.CRT$XTA ends
.CRT$XTC segment dword public 'DATA'
.CRT$XTC ends
.CRT$XTZ segment dword public 'DATA'
.CRT$XTZ ends

CONST	segment dword public 'CONST'
CONST	ends
_STRING segment dword public 'STRING'
_STRING ends
_BSS	segment dword public 'BSS'
_edata	label near
_BSS	ends

if ?NORELOCS eq 0
STACK	segment para  stack 'STACK'
		db ?DEFSTKSIZ dup (?)
STACK	ends
endif

;--- put all 32-bit segments in DGROUP 

;DGROUP  group BEGTEXT, _TEXT, _TEXT32,_NULL,_DATA,.BASE$,.BASE$0
DGROUP	group _TEXT, _TEXT32,_NULL,_DATA
if ?WIN32
DGROUP	group .BASE$,.BASE$0,.BASE$D,.BASE$DA,.BASE$DZ
DGROUP	group .BASE$I,.BASE$IA,.BASE$IC,.BASE$IZ
DGROUP	group .BASE$X,.BASE$XA,.BASE$XC,.BASE$XZ
endif
DGROUP	group .CRT$XIA,.CRT$XIC,.CRT$XIZ,.CRT$XCA,.CRT$XCC,.CRT$XCL,.CRT$XCU,.CRT$XCZ
DGROUP	group .CRT$XPA,.CRT$XPX,.CRT$XPZ,.CRT$XTA,.CRT$XTC,.CRT$XTZ
DGROUP	group CONST,_STRING,_BSS

if ?NORELOCS eq 0
DGROUP	group STACK
endif

_DATA	segment

externdef  stdcall __pMoveHigh:dword

__baseadd	dd 0
__dossize	dd 0
__psp		dd 0
__ressize	dd 0	;resident size in paragraphs

_DATA	ends

_TEXT32	segment

		assume DS:DGROUP

;--- mymain is executed after CS has been switched to a 32bit code segment
;--- and has to do:
;--- 1. move from conventional DOS memory to extended memory (optional)
;--- 2. alloc a memory block for stack + heap
;--- 3. call init proc defined in .BASE$ segment
;--- 4. jump to external mainCRTStartup

mymain	proc far private

		@trace	<"milestone 3",13,10>

		mov 	[__dossize],ebp
if ?PMSTORE
		movzx	esi,si
		shl		esi, 4
		mov 	[__baseadd],esi 				;store base address of image
endif
if ?FLATGS
		xor		edx, edx
		xor		ecx, ecx
		mov 	ax,0007h		;set base of old CS selector to 0
		int 	31h
		dec		edx
		dec		ecx
		mov 	ax,0008h		;set limit to 0FFFFFFFFh
		int 	31h
		mov 	eax,ds
		lar		ecx, eax
		shr		ecx, 8
		mov 	ax,0009h
		int 	31h				;set access rights (CODE, BIG)
		mov		gs, ebx
else
if ?FREEOLDCS
		mov 	ax,1			;free old cs
		int 	31h
endif
endif
if ?CLEARCOMMAREA
		mov 	edi,_edata
		mov 	ecx,esp
		sub 	ecx,edi
		xor 	eax,eax
		rep 	stosb
endif
		@trace	<"milestone 4",13,10>
		
		mov 	ebp,__HEAPSIZE
		mov 	ecx,__pMoveHigh
		jecxz	@F
		call	ecx 			;move executable in extended memory
		mov		eax,esp
		jnc		clearheap		;binary has been moved, stack+heap allocated
@@:
		mov		edi,__STACKSIZE
		mov 	eax, ebp		;if another amount of stack/heap space is required
		add 	eax, edi		;define publics __STACKSIZE/__HEAPSIZE in your app
		and		eax, eax
		jz		noheap
		push	eax
		pop 	cx				;alloc stack/heap
		pop 	bx
		mov 	ax,0501h
		int 	31h
		jc		error3
		push	bx
		push	cx
		pop 	eax
		sub 	eax,[__baseadd]
clearheap:
		add 	eax,__STACKSIZE
		mov		esp,eax
		@trace	<"milestone 5",13,10>
		cld
		mov 	edi,esp
		xor 	eax,eax
		mov 	ecx,ebp
		shr		ecx,2
		rep 	stosd				; clear heap
		mov		edi,__STACKSIZE
noheap: 	   
;----------------------------------- if an initialization is needed
if ?WIN32
		.if (dword ptr startinitprocs)
			call dword ptr startinitprocs
		.endif
endif		 
		mov 	ecx,ebp 			; ecx will have heapsize on program entry
		xor 	ebp,ebp
		@trace	<"milestone 6",13,10>
		jmp 	mainCRTStartup
error3:
		mov		edx,offset errstr3
		mov		ah,9
		int		21h
		mov		ax,4CFFh
		int		21h
mymain	endp

errstr3 db "out of memory",13,10,'$'

_TEXT32	ends

		assume DS:nothing

_TEXT16 segment

ifdef ?TRACE

_trace16	proc
		pusha
		mov bp,sp
		pushf
		mov si, [bp+16]
		.while (1)
			db 2Eh
			lodsb
			.break .if (!al)
			mov dl,al
			mov ah,2
			int 21h
		.endw
		mov [bp+16],si
		popf
		popa
		ret
_trace16 endp

@trace macro string
local	xxx
		invoke _trace16
xxx		db string,0
		endm
else
@trace	macro string
		endm
endif

loadserver proto near stdcall

;--- this is the real mode entry with functions
;--- 1. check if DPMI is there
;--- 2. if not, try to load HDPMI32 (in UMBs if available)
;--- 3. switch to PM as 32bit dpmi client
;--- 4. create a 32 bit code segment and jump to it (proc mymain)

		assume ss:nothing

start:

status1	equ [bp-2]
status2	equ [bp-4]
lpproc	equ [bp-8]
if ?NORELOCS
dspara	equ [bp-10]
dssize	equ [bp-12]
else
dssize	equ [bp-10]
endif

_JmpPM	proc stdcall

		PUSHF
		mov 	AH,70h
		PUSH	AX
		POPF					; on a 80386 in real-mode, bits 15..12
		PUSHF					; should be 7, on a 8086 they are F,
		POP 	AX				; on a 80286 they are 0
		POPF
		and		ah,0F0h
		JS		@F
		JNZ 	IS386
@@: 	   
		mov 	dx,offset dNo386
		mov		ah,9
		int		21h
		mov		ax,4CFFh
		int		21h
dNo386	db "a 80386 is needed",13,10,'$'
IS386:
		mov 	ax,sp
		mov		bp,sp
		shr 	ax,4
		mov 	bx,ss
		add 	bx,ax
		mov 	ax,es
		sub 	bx,ax
		mov 	ah,4Ah
		int 	21h

if ?NORELOCS
		mov 	ax,ds
		add 	ax,10h			;psp
		mov 	cx,offset endof16bit
		shr 	cx,4
		add 	ax,cx
		push	ax				;dspara
else
		mov 	ax,DGROUP
endif
		mov 	ds,ax
		assume ds:DGROUP

		mov 	ax,5802h		;save status umb
		int 	21h
		xor 	ah,ah
		push	ax				;status 1
		mov 	ax,5800h		;save memory alloc strategy
		int 	21h
		xor 	ah,ah
		push	ax				;status 2
		mov 	bx,0081h		;first high,then low
		mov 	cx,0001h		;include umbs
		call	setumbstatus

		mov 	ax,1687h		;is DPMI existing?
		int 	2fh
		and 	ax,ax
if ?LOADSERVER
		jz		@F
		call	loadserver
		add		cs:[ressize],dx
		mov 	ax,1687h
		int 	2fh
		and 	ax,ax
		jnz 	nodpmi1
@@:
else
		jnz 	nodpmi1 		;error: no switch to pm possible
endif
		push	es
		push	di				;lpproc

		and 	si,si
		jz		sm2
								;alloc req real mode mem
		mov 	ah,48h
		mov 	bx,si
		int 	21h
		jc		nodpmi2

		mov 	es,ax
sm2:

		call	restoreumbstatus

		mov		ax,ds
if ?PMSTORE
;-------------- offset __baseadd may be > 10000h, which doesnt work
;-------------- in real mode. so save it in si and wait until we are
;-------------- in protected mode

		mov 	si, ax
else
		movzx	ecx,ax
		shl 	ecx,4
		mov 	[__baseadd],ecx ;store base address of image
endif

		mov 	bx,ss			;works with TLINK only
		sub 	bx,ax			;not with MSLINK 
		push	bx				;dssize

		mov 	ax,0001 		;32 bit application
		call	dword ptr [lpproc]	;jump to PM
		jc		nodpmi3 		;error: jmp to pm didnt work

;--- here es=PSP, ds=DGROUP, cs=TEXT16, ss=STACK
;--- limits are 0FFFFh, except for PSP

		@trace	<"in protected mode now",13,10>
		mov 	dx,-1
		mov 	cx,dx
		mov 	bx,ds
		mov 	ax,0008 		;set limit DS to 0FFFFFFFFh
		int 	31h
		jc		nodpmi2

if ?PMSTORE
;		movzx	esi,si
;		shl		esi, 4
;		mov 	[__baseadd],esi ;store base address of image
endif
		movzx	ebx,word ptr dssize
		shl 	ebx,4
		movzx	ebp,bp
		add 	ebp,ebx
		mov 	bx,ss			;save SS Selector in BX,  will be reused later
		push	ds
		pop 	ss				;now SS=DS
		mov 	esp,ebp

		mov 	[__psp], es
		push	ds
		pop 	es				;DS=ES=SS
		
		mov		ax,cs:[ressize]
		mov		word ptr [__ressize],ax

ife ?USECRT
		mov 	cx,1
		xor 	ax,ax
		int 	31h 			;alloc a selector
		mov 	bx,ax
endif
if ?PMSTORE
		movzx	eax,si
		shl		eax, 4
		push	eax
else
		push	[__baseadd]
endif
		pop 	dx
		pop 	cx
		mov 	ax,0007h		;set base of old SS descriptor to DGROUP
		int 	31h
		jc		nodpmi5

		@trace	<"milestone 1",13,10>

		mov 	ax,ds
		lar 	ecx,eax
		shr 	ecx,8
		or		cl,8			;data->code
		mov 	ax,0009h
		int 	31h				;set access rights (CODE, BIG)
		jc		nodpmi6
		or		dx,-1
		mov 	cx,dx
		mov 	ax,0008h		;set limit to 0FFFFFFFFh
		int 	31h
		jc		nodpmi7

		@trace	<"milestone 2",13,10>
		
		push	ebx				;push selector onto stack (retf will jump to it)

if 1;?FREEOLDCS
		mov 	bx,cs			;save old CS in BX
endif

		push	offset mymain
		db		66h				;do a RETFD
		retf

restoreumbstatus:
		mov 	cx,status1
		mov 	bx,status2
setumbstatus:
		push	cx
		mov 	ax,5801h		;memory alloc strat restore
		int 	21h
		pop 	bx
		mov 	ax,5803h		;umb link restore
		int 	21h
		retn
nodpmi1:
		call	restoreumbstatus
		mov 	dx,offset errstr1
		jmp 	errexit
nodpmi2:
		call	restoreumbstatus
nodpmi3:
nodpmi4:
nodpmi5:
nodpmi6:
nodpmi7:
		mov 	dx,offset errstr2
errexit:
		push	cs
		pop 	ds
		mov 	ah,09
		int 	21h
		mov 	ax,4CFFh
		int 	21h
_JmpPM	endp

ressize dw 10h
errstr1 db "no DPMI server found",13,10,'$'
errstr2 db "DPMI initialization failed",13,10,'$'

_TEXT16 ends

end start

