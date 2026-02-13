
;*** implements int 31h, functions ax=03xxh (switch rm<->pm)

;*** 0x300: simulate real mode int
;*** 0x301: call real mode far proc with retf frame
;*** 0x302: call real mode far proc with iret frame
;*** 0x303: alloc real mode callback
;*** 0x304: free real mode callback
;*** 0x305: get state save/restore address
;*** 0x306: get raw mode switch addresses

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

?COPYFLRMS	= 1	;std=1, 1=copy flags on raw mode switch
?DEBUGRMCB	= 0	;std=0, 1=int 3 on entry/exit RMCB (debug)
?CLEARDIR	= 0	;std=0, 1=clear direction flag on RMCBs
?NOREENTRY	= 1	;std=1, 1=dont enter pm if exception handler runs

?SAFE301	equ 1	;v3.23: protect rm call address for function 301h

?RMCBMAX	equ 10h	;std=10h, max number of real mode callbacks

;--- bits in hibyte(flags)
_TF equ 1
_IF equ 2

;*** rmswitch      common entry for real mode callbacks
;*** _retcb        return from real mode callback
;*** simrmint      0300: simulate real mode int
;*** callrmretf    0301: call real mode proc with retf frame
;*** callrmiret    0302: call real mode proc with iret frame
;*** allocrmcb     0303: allocate real mode callback
;*** freermcb      0304: free real mode callback
;*** getsraddr     0305: get save/restore task state address
;*** _srtask       pm save/restore task state proc
;*** saverestore   rm save/restore task state proc
;*** getrmsa       0306: get raw mode switch address
;*** rm2pm         raw mode switch rm to pm
;*** _pm2rm        raw mode switch pm to rm

_DATA16 segment

IRETRM_s struct
union
rCSIP	dd ?
struct
rIP		dw ?
rCS		dw ?
ends
ends
rFlags	dw ?
IRETRM_s ends

tmpRMRegs IRETRM_s <>

_DATA16 ends

_DATA32C segment

;--- client real mode callbacks

;clrmcbs label RMCB
;	rept ?RMCBMAX
;	RMCB {{0,0},0}
;endm
clrmcbs RMCB ?RMCBMAX dup ({{0,0},0})

_DATA32C ends

_TEXT16 segment

	assume ds:nothing

;******************************************************************
;*** real mode call back - jump in PM with switch to LPMS
;******************************************************************

?RMCBLOG equ 0

RMCBSF struct
dwESDS	dd ?
dwFSGS	dd ?
RMCBSF ends

RMSwitch label byte

	@ResetTrace

rmcb_rm proc
if ?DEBUGRMCB
	int 3
endif
	pushf
	push cs				;CS is <> GROUP, dont use as prefix!
	db 0eah				;jmp ssss:oooo
	dw offset @F
wPatchGrp162 dw 0		;will contain GROUP16
@@:

if ?NOREENTRY        
	cmp cs:[bNoRMCBEntry],0	;host entry allowed?
	jnz noentry
endif
	public rmcb_brk
rmcb_brk::
	@rm2pmbrk
	pop cs:[tmpRMRegs.rCS]
	pop cs:[tmpRMRegs.rFlags]

;--- build a RMCBSF frame         
        
	@pushstate_rm		;save real-mode ss:sp
	push gs
	push fs
	push ds
	push es
if _LTRACE_ and ?RMCBLOG
	push bp
	mov bp,sp
	@drprintf "rm cb rmSS:SP=%X:%X, Fl=%X, old RMS=%X:%X ds=%X es=%X fs=%X gs=%X",\
		cs:v86iret.rSS, cs:v86iret.rSP, cs:tmpRMRegs.rFlags,\
		cs:wrmSStmp, cs:wrmSPtmp, ds, es, fs, gs
	pop bp
endif
	@rawjmp_pm rmcb_pm			;ds,es,fs,gs are undefined
if ?NOREENTRY        
noentry:
	add sp,4
	retf
endif
	align 2
rmcb_rm endp

_TEXT16 ends

	@ResetTrace

_TEXT32 segment

rmcb_pm proc

	@pushstate 0;save client state

;--- set an IRET32 frame below dwHostStack
;--- after this is done, real-mode code can be called again
;--- i.e. trace output to dos or bios.

if 0
;--- this code worked in v3.18, but had problems with raw mode switches;
;--- see regression test rawjmp6.asm
	lea esp, [esp-sizeof IRET32]
	mov [esp].IRET32.rIP, _RETCB_
	mov [esp].IRET32.rCS, _INTSEL_
	push ebp
	push eax
	pushfd
	pop eax
	mov [esp+2*4].IRET32.rFL, eax
	mov ebp, [esp+2*4+sizeof IRET32]	;get previous value of dwHostStack
	mov eax, [ebp-sizeof IRET32].IRET32.rSP
	mov ebp, [ebp-sizeof IRET32].IRET32.rSSd
	mov [esp+2*4].IRET32.rSP, eax
	mov [esp+2*4].IRET32.rSSd, ebp
	pop eax
	pop ebp
else
;--- v3.19: use new fields rSSD and rESP in pmstate
	push ss:pmstate.rSSd
	push ss:pmstate.rESP
	pushfd
	pushd _INTSEL_
	pushd _RETCB_
endif

	inc ss:[cRMCB]

	.errnz sizeof RMCB - 16

	push edi
	mov fs, ss:pmstate.rFS
	movzx edi, ss:[tmpRMRegs.rCS]
	mov gs, ss:pmstate.rGS
	sub di, ss:[wHostSeg]		;seg RMSwitch
	shl edi, 4					;RMCB size is 16!

if _LTRACE_
	push 0
	pop ds
	push ds
	pop es
	@dprintf "rmcb, callerCS=%X, rmcb#*16=%X, rmcs=%X:%lX", \
		ss:[tmpRMRegs.rCS], di, word ptr cs:[edi+clrmcbs].rmcs+4, dword ptr cs:[edi+clrmcbs].rmcs+0
endif

	les edi, cs:[edi+clrmcbs].rmcs
	pop es:[edi].RMCS.rEDI
	mov es:[edi].RMCS.rESI, esi
	mov es:[edi].RMCS.rEBP, ebp
	mov es:[edi].RMCS.rEBX, ebx
	mov es:[edi].RMCS.rEDX, edx
	mov es:[edi].RMCS.rECX, ecx
	mov es:[edi].RMCS.rEAX, eax
	mov cx, ss:[tmpRMRegs.rCS]
	mov ax, ss:[tmpRMRegs.rFlags]
	mov es:[edi].RMCS.rCS, cx
	mov es:[edi].RMCS.rFlags, ax

if 0
 if ?CLEARDIR
	and ah,08Bh					;NT+IOPL+D reset
 else
	and ah,08Fh 				;NT+IOPL reset
 endif
	or ah, ?PMIOPL shl 4		;set IOPL
	mov ss:[tmpFLReg], ax
endif
;--- on entry to a real-mode callback, DS:E/SI is
;--- supposed to point to real-mode SS:SP.
;--- if ?RMCBSTATICSS is 1 (standard), such a descriptor
;--- is allocated once when the RMCB is allocated.
;--- problem: the RMCB may be reentered while still active,
;--- with a different real-mode SS. So the pointer DS:E/SI
;--- is not guaranteed to point to the very same location
;--- if real-mode code is called within or interrupts are
;--- enabled.

if ?RMCBSTATICSS
	movzx ebx, ss:[tmpRMRegs.rCS]
	mov ds, ss:[selLDT]
	sub bx, ss:[wHostSeg]		;seg RMSwitch
	movzx edx, ss:v86iret.rSS
	shl ebx, 4                  ;*16 (sizeof RMCB)
	mov es:[edi].RMCS.rSS, dx
	shl edx, 4					;edx = linear address of real-mode SS
	movzx ebx, cs:[ebx+clrmcbs].wSS
	push ebx
	and bl, 0F8h
	mov [ebx].DESCRPTR.A0015, dx
	shr edx, 16
	mov [ebx].DESCRPTR.A1623, dl;max value is 0Fh
	mov [ebx].DESCRPTR.A2431, dh;is always 00
	pop ds
else

;--- get a selector for rm SS (in bx)
;--- limit in AX, = -1

;--- make sure DS is a valid selector before any output
	xor ecx, ecx
	mov ds, ecx

	@dprintf "rmcb: will try to alloc a rm-selector"

	mov bx, ss:v86iret.rSS
	mov ax, -1
	mov es:[edi].RMCS.rSS, bx
	call allocxsel
	jc _exitclientEx4
	mov ds, eax			;now DS -> rm SS
endif

;--- store current real-mode segment values ES,DS,FS,GS in RMCS (ES:EDI)
	movzx esi, ss:v86iret.rSP
	mov eax, [esi-sizeof RMCBSF].RMCBSF.dwESDS
	mov ecx, [esi-sizeof RMCBSF].RMCBSF.dwFSGS
	mov dword ptr es:[edi].RMCS.rES, eax
	mov dword ptr es:[edi].RMCS.rFS, ecx
	mov es:[edi].RMCS.rSP, si

if _LTRACE_ and ?RMCBLOG
	@dprintf "rmcb, rm ES-DS-FS-GS=%X %X %X %X hs=%lX", eax, ecx, esp
endif

	@checkhoststack

;--- calculate real-mode CS:IP of rmcb
;--- this is also done in 0x303/0x304.
	mov ax, es:[edi].RMCS.rCS
	sub ax, ss:[wHostSeg]			;seg RMSwitch
	shl eax, 4						;RMCS size is 16!
	mov cx, ax						;handle nach cx
	neg ax
	add ax, offset RMSwitch
	mov es:[edi].RMCS.rIP, ax		;IP is calculated from CS

	movzx eax, cx					;callback handle
	add eax, offset clrmcbs

if _LTRACE_ and ?RMCBLOG
	push ebp
	mov ebp, esp
	@dprintf "rmcb, IRET32 frame for lpms_call_int: %lX %lX %lX %lX %lX",\
		[ebp+4].IRET32.rIP, [ebp+4].IRET32.rCSd, [ebp+4].IRET32.rFL,\
		[ebp+4].IRET32.rSP, [ebp+4].IRET32.rSSd
	pop ebp

 if ?32BIT
	@dprintf "rmcb, jmp to pm proc=%X:%lX, EDI=%lX:%lX, ESI=%lX:%lX, HS=%lX",\
		word ptr cs:[eax].R3PROC._Cs, cs:[eax].R3PROC._Eip, es, edi, ds, esi, ss:taskseg._Esp0
 else
	@dprintf "rmcb, jmp to pm proc=%X:%X,ES:DI=%lX:%X,DS:SI=%lX:%X,HS=%lX",\
		cs:[eax].R3PROC._Cs, cs:[eax].R3PROC._Eip, es, di, ds, si, ss:taskseg._Esp0
 endif
endif
	push eax
	@NMI_ON ;rmcb_pm
	jmp lpms_call_int		;switch to LPMS
	align 4

rmcb_pm endp

;**************************************
;*** return from real mode callback ***
;**************************************

	@ResetTrace

;--- no need to preserve std registers,
;--- since they will be loaded by the values
;--- in the RMCS pointed to by es:e/di

_retcb proc public						;stack irrelevant?
if _LTRACE_ and ?RMCBLOG
	mov ebp,esp
	@dprintf "ret rmcb: [esp]=%lX,%lX,%lX,%lX,%lX",\
		[ebp+0],[ebp+4],[ebp+8],[ebp+12],[ebp+16]
 if ?32BIT
	@dprintf "ret rmcb %X: ES:EDI=%lX:%lX,HS=%lX",\
		ss:[cRMCB],es,edi,ss:taskseg._Esp0
 else
	@dprintf "rm cb ret: ES:DI=%lX:%X,HS=%lX",\
		es,di,ss:taskseg._Esp0
 endif
endif
	dec ss:[cRMCB]

ife ?32BIT        
	movzx edi,di
endif
	mov si,es:[edi].RMCS.rFlags
	mov ax,es:[edi].RMCS.rES
	mov dx,es:[edi].RMCS.rDS
	mov cx,es:[edi].RMCS.rFS
	mov bx,es:[edi].RMCS.rGS
;	mov ss:tmpRMRegs.rFlags,si
	mov ss:v86iret.rES, ax
	mov ss:v86iret.rDS, dx
	mov ss:v86iret.rFS, cx
	mov ss:v86iret.rGS, bx

;--- modify v86iret.rSS/SP?
;--- if ?NMISAFE=1, it has to be protected!

	@NMI_OFF ;retcb
	mov edx,es:[edi].RMCS.rSSSP
	sub dx,6
	mov ss:v86iret.rSP,dx
	movzx eax,dx
	shr edx,16
	mov ss:v86iret.rSS,dx
	shl edx,4
	add edx,eax
	mov eax,es:[edi].RMCS.rCSIP
	sub edx,ss:[dwSSBase]
;--- v3.24: change "popf" & "retf" to "iret"
;	mov ss:[edx+0],si
;	mov ss:[edx+2],eax
	mov ss:[edx+0],eax
	mov ss:[edx+4],si

;--- set the GPRs

	mov esi, es:[edi].RMCS.rESI
	mov ebp, es:[edi].RMCS.rEBP
	mov ebx, es:[edi].RMCS.rEBX
	mov ecx, es:[edi].RMCS.rECX
	mov edx, es:[edi].RMCS.rEDX
	mov eax, es:[edi].RMCS.rEAX
	mov edi, es:[edi].RMCS.rEDI

;--- can a display be done here (won't it change v86iret?)
;	@dprintf "ret rmcb: rmSS:SP=%X:%X",ss:v86iret.rSS,ss:v86iret.rSP

	lea esp, [esp+ sizeof IRET32]	;skip the IRET32 frame build in rmcb_pm
	@popstate 0						;restore client state (variable pmstate)
	@rawjmp_rm _retcb_rm
	align 4

_TEXT16 segment
_retcb_rm::
	@popstate_rm	;restore v86iret.rSS/SP
	iret			;real-mode iret
	align 2
_TEXT16 ends

_retcb endp

;***********************************************
;*** simulate real mode interrupt            ***
;*** call real mode far proc with retf frame ***
;*** call real mode far proc with iret frame ***
;***********************************************

	@ResetTrace

RMCALLS struct	;stack frame for EBP
rES		dd ?
rDS		dd ?
		PUSHADS <>
RMCALLS ends

;--- int 31h, ax=0300h simulate real-mode interrupt
;--- BL = interrupt
;--- BH = 0
;--- ES:E/DI = RMCS
;--- CX = words to copy to real-mode stack

;--- int 31h, ax=0301h: call real-mode proc with retf frame
;--- BH = 0
;--- ES:E/DI = RMCS
;--- CX = words to copy to real-mode stack

;--- int 31h, ax=0302h: call real mode proc with iret frame
;--- BH = 0
;--- ES:E/DI = RMCS
;--- CX = words to copy to real-mode stack

_callrmproc proc public
	pushad
	push ds
	push es
ife ?32BIT
	movzx edi,di
endif
if _LTRACE_
	mov eax,es
	lar ebp,eax
	lsl eax,eax
	cmp eax,edi
	ja @F
	test bp,400h;expand down segment?
	jnz @F
;--- bug in borland's 32rtm: hiword(edi) isn't cleared in all cases.
;--- set environment variable HDPMI=2048 to catch this error!
	@dprintf "call rm: EDI[=%lX] exceeds ES segment limit %lX !!!", edi, eax
	stc
	jmp error1x
@@:
endif
	@dprintfx ?LOG_RMCALL,"call rm RMS=%X:%X rmcs: a-d=%X %X %X %X, d-e=%X %X, stk=%X:%X", ss:v86iret.rSS, ss:v86iret.rSP,\
		es:[edi].RMCS.rAX, es:[edi].RMCS.rBX, es:[edi].RMCS.rCX, es:[edi].RMCS.rDX,\
		es:[edi].RMCS.rDS, es:[edi].RMCS.rES, es:[edi].RMCS.rSS, es:[edi].RMCS.rSP
	mov ebp, esp
	push ss:v86iret.rSP
	push ss:v86iret.rSS
	push ss:v86iret.rES  ;v3.24: now save/restore all rm segregs (removed from @pushstate/@popstate)
	push ss:v86iret.rDS
	push ss:v86iret.rFS
	push ss:v86iret.rGS

;--- 1. set SS:SP

	@NMI_OFF ;callrmproc
	mov edx, es:[edi].RMCS.rSSSP

	push byte ptr _FLATSEL_
	pop es

	and edx,edx
	jz @F
	mov ss:v86iret.rSP, dx
	shr edx, 16
	mov ss:v86iret.rSS, dx
@@:
	movzx eax,ss:v86iret.rSP
	movzx edx,ss:v86iret.rSS
	shl edx,4

;--- 2 copy words from PMS to real-mode stack

	jcxz @F						;no stack params
	movzx ecx,cx
	shl ecx,1					;2*, since WORDS
	sub eax,ecx
	jc error1
	mov esi,ss:taskseg._Esp0		 ;client stack -> ds:si
	@dprintfx ?LOG_RMCALL, "copy stack parms, %X words src=%X:%lX", cx,\
		[esi-sizeof IRET32].IRET32.rSS, [esi-sizeof IRET32].IRET32.rSP
	lds esi,ss:[esi-sizeof IRET32].IRET32.rSSSP
	shr ecx,1	;byte to words
	push edi
	mov edi, edx
	add edi, eax
	cld
	rep movsw
	pop edi
@@:
;--- 2a. copy flags to realmode stack
;--- for functions 300h & 302h, the flags member from RMCS is copied to the
;--- IRET frame and the procedure is called with IF & TF cleared.
;--- for function 301h, there's just a RETF stack frame and the flags member
;--- from RMCS is copied to the real flags.
;--- For all cases, TF is cleared, in both the flags register and the flags
;--- in the IRET frame; the Windows DPMI host doesn't clear TF in the flags
;--- in IRET frame, but that won't trigger an exc 01, cause v86-mode runs with
;--- IOPL 0, so flags reg access is protected.

	mov ds,[ebp].RMCALLS.rES
	mov cx, [edi].RMCS.rFlags
if ?SETRMIOPL
	and ch,08Eh 					;reset NT,IOPL,TF
	or ch, ?RMIOPL shl 4
else
	and ch,not _TF 					;reset TF (this is NOT specified in the DPMI docs)
endif
	test [ebp].RMCALLS.rAX,1		;function 0300h or 0302h?
	jnz @F
	sub eax,2
	mov es:[edx+eax],cx				;push flags (will become part of real-mode IRET frame)
;--- v3.23: reset IF also for function 0x302h
;@@:
;	test [ebp].RMCALLS.rAX,3		;function 0300h?
;	jnz @F
	and ch,not (_IF or _TF)			;reset IF & TF
@@:

;--- 2b. copy CS:IP & flags (either to tmp reg or onto realmode stack)
;--- edx: linear address rmSS, eax=rmSP

	mov esi, [edi].RMCS.rCSIP
	test [ebp].RMCALLS.rAX,3		;is address to copy from IVT (ax=0300h)?
	jnz havecsip
	movzx ebx, bl
	mov esi, es:[ebx*4]
havecsip:
if ?SAFE301
	sub eax,5*2						;IP,CS,Flags, ofs/seg(callrmproc_rm2)
	mov es:[edx+eax],esi
	mov es:[edx+eax+4],cx			;flags (will be popped by an IRET)
	mov si,ss:[wHostSeg]
	shl esi,16
	mov si,offset callrmproc_rm2
	mov es:[edx+eax+6],esi
else
	sub eax,2
	mov ss:tmpRMRegs.rCSIP,esi
	mov es:[edx+eax],cx				;flags (will be popped in real-mode before callf)
endif

;--- 2c. update realmode stack

	mov ss:v86iret.rSP, ax

;--- 3. copy RMCS in conv. memory and registers

	mov ax, [edi].RMCS.rES
	mov dx, [edi].RMCS.rDS
	mov cx, [edi].RMCS.rFS
	mov bx, [edi].RMCS.rGS
	mov ss:v86iret.rES, ax
	mov ss:v86iret.rDS, dx
	mov ss:v86iret.rFS, cx
	mov ss:v86iret.rGS, bx

	mov esi, [edi].RMCS.rESI
	mov edx, [edi].RMCS.rEDX
	mov ecx, [edi].RMCS.rECX
	mov ebx, [edi].RMCS.rEBX
	mov eax, [edi].RMCS.rEAX
	push [edi].RMCS.rEBP
	mov edi, [edi].RMCS.rEDI

;--- 6. restore DS, ES to ring3 selectors, jump to real-mode

	mov es,[ebp].RMCALLS.rES
	mov ds,[ebp].RMCALLS.rDS
	pop ebp

	@jmp_rm callrmproc_rm
error1:
	pop ss:v86iret.rGS
	pop ss:v86iret.rFS
	pop ss:v86iret.rDS
	pop ss:v86iret.rES
	pop ss:v86iret.rSS
	pop ss:v86iret.rSP
	@NMI_ON ;callrmproc
error1x:
	pop es
	pop ds
	popad
	ret		;exit with C set, error
	align 4

_TEXT16 segment
callrmproc_rm:
if ?SAFE301
	iret
callrmproc_rm2:
else
	popf
	call cs:[tmpRMRegs.rCSIP]
endif
	pushf
	public callrmproc_brk
callrmproc_brk::
	@rm2pmbrk
	pop cs:[tmpFLReg]
	@jmp_pm callrmproc_pm2
	align 2
_TEXT16 ends

callrmproc_pm2:

RMCALLS2 struct
	dd ?	;v86iret.rGS/FS
	dd ?	;v86iret.rDS/ES
	dd ?	;v86iret.rSS/SP
	RMCALLS <?>
RMCALLS2 ends

;--- copy the Registers to the client's RMCS. Dont modify CS:IP and SS:SP in RMCS!

	mov ds,[esp].RMCALLS2.rES	;use DS for client's RMCS to avoid register override
	push edi
	mov edi,[esp+4].RMCALLS2.rEDI
ife ?32BIT
	movzx edi,di
endif
	pop [edi].RMCS.rEDI
	mov [edi].RMCS.rESI, esi
	mov [edi].RMCS.rEBP, ebp
	mov [edi].RMCS.rEBX, ebx
	mov [edi].RMCS.rEDX, edx
	mov [edi].RMCS.rECX, ecx
	mov [edi].RMCS.rEAX, eax
	mov esi, ss:[tmpFLRegD]
	mov eax, ss:v86iret.rESd
	mov edx, ss:v86iret.rDSd
	mov ecx, ss:v86iret.rFSd
	mov ebx, ss:v86iret.rGSd
	mov [edi].RMCS.rFlags, si
	mov [edi].RMCS.rES, ax
	mov [edi].RMCS.rDS, dx
	mov [edi].RMCS.rFS, cx
	mov [edi].RMCS.rGS, bx
	@NMI_OFF ;callrmproc
	pop ss:v86iret.rGS
	pop ss:v86iret.rFS
	pop ss:v86iret.rDS
	pop ss:v86iret.rES
	pop ss:v86iret.rSS
	pop ss:v86iret.rSP
	@NMI_ON  ;callrmproc
	pop es
	pop ds
	popad
	@dprintfx ?LOG_RMCALL,"callrmproc_pm: exit, NC, RMS=%X:%X", ss:v86iret.rSS, ss:v86iret.rSP
	clc
	ret
	align 4

_callrmproc endp

;*** int 31h, ax=0303: alloc real mode callback
;*** inp: ds:(e)si: far16/far32 pm proc to call
;***	  es:(e)di: RMCS structure
;*** out: cx:dx: rm address of callback

	@ResetTrace

allocrmcb proc public

	pushad

	@dprintf "allocrmcb: enter ds:esi=%lX:%lX es:edi=%lX:%lX",ds,esi,es,edi

	mov eax,ds
;	push ss
	push byte ptr _CSALIAS_
	pop ds
;	assume ds:GROUP16
	assume ds:GROUP32
	mov ebx, offset clrmcbs
	mov cx,?RMCBMAX		;ch == 0
alloccb2:
	cmp [ebx].RMCB._Cs,0000
	jz @F
	add ebx,sizeof RMCB
	dec cl
	jnz alloccb2
	popad
	@dprintf "allocrmcb: error, no free rmcbs available"
	stc
	ret
@@:
if ?32BIT
	mov [ebx].RMCB._Eip, esi
	mov word ptr [ebx].RMCB._Cs, ax
else
	mov [ebx].RMCB._Eip, si
	mov [ebx].RMCB._Cs, ax
	movzx edi, di
endif
	mov dword ptr [ebx].RMCB.rmcs+0, edi
	mov word ptr [ebx].RMCB.rmcs+4, es
;	@dprintf "allocrmcb: rmcb allocated: %X:%lX %lX:%lX", ax,esi,es,edi
	mov esi, ecx
if ?RMCBSTATICSS
	mov cx, 1
	xor eax, eax	; alloc 1 descriptor
	@int_31
	jnc @F
	@dprintf "allocrmcb: error, no free descriptor for rmSS"
	mov [ebx].RMCB._Cs,0
	popad
	stc
	ret
@@:
	@dprintf "allocrmcb: allocated selector for rmSS=%X", ax
	mov [ebx].RMCB.wSS, ax
	xchg eax, ebx	; mov bx, ax
	mov dx, -1
	xor ecx, ecx
	mov ax, 8	; set limit
	@int_31
endif

;--- calculate real-mode CS:IP of rmcb
	mov eax,esi
	mov cx, ss:[wHostSeg]			;seg RMSwitch
	sub ax,?RMCBMAX
	neg ax
	add cx,ax
	mov [esp].PUSHADS.rCX, cx
	mov dx, offset RMSwitch
	shl ax, 4
	sub dx, ax
	mov [esp].PUSHADS.rDX, dx

	@dprintf "allocrmcb: returned callback=%X:%X",cx,dx
	popad
	clc
	ret
	align 4
allocrmcb endp

;*** int 31h, ax=0304: free real mode callback
;*** inp: real mode callback in CX:DX
;--- modifies DS

freermcb proc public
	pushad
	@dprintf "freermcb: free real mode callback %X:%X", cx, dx
	push byte ptr _CSALIAS_
	pop ds
	assume ds:GROUP32

;--- calculate real-mode CS:IP of rmcb
	movzx eax,cx
	sub ax, ss:[wHostSeg]	;seg RMSwitch
	cmp eax,?RMCBMAX
	jnb freecberr
	shl eax,4
	mov ecx,eax
	neg ax
	add ax, offset RMSwitch

	cmp ax, dx
	jnz freecberr
	mov eax, ecx
	add eax, offset clrmcbs
	mov ebx, eax
	cmp [ebx].RMCB._Cs, 0	;is it already free?
	jz freecberr
	mov [ebx].RMCB._Cs, 0
if ?RMCBSTATICSS
	mov bx, [ebx].RMCB.wSS
	mov ax, 1				;free static descriptor for real-mode SS
	@int_31					;ignore errors here
endif
	@dprintf "freermcb: ok"
	popad
	clc
	ret
freecberr:
	@dprintf "freermcb: error, invalid cb or cb already free"
	popad
	stc
	ret
	align 4
freermcb endp

;--- 0305h get task state save/restore address
;--- out:
;--- AX = size of state buffer
;--- BX:CX = real-mode entry to save/restore state
;--- SI:E/DI = protected-mode entry to save/restore state

	@ResetTrace

getsraddr proc near public

	mov ax,sizeof pmstate + 6*2	;size of save state buffer
	mov bx, ss:[wHostSeg]		;real mode entry
	mov cx, offset srtask_rm
	mov si,_INTSEL_				;protected-mode entry
if ?32BIT
	mov edi,_SRTSK_
	@dprintf "get save/restore address, bx:cx=%X:%X, si:edi=%X:%lX", bx, cx, si, edi
else
	mov di,_SRTSK_
	@dprintf "get save/restore address, bx:cx=%X:%X, si:di=%X:%X", bx, cx, si, di
endif
	clc
	ret
	align 4
getsraddr endp

;*** prot mode save/restore proc ***
;--- al=0 : save task state
;--- al=1 : restore task state
;--- es:e/di: buffer

?NOPMSTATECONSEC equ 1

;--- buffer consists of pmstate and the real-mode segreg values in v86iret

_srtask proc public
	@dprintf "save/restore enter, ax=%X, es:edi=%lX:%lX", ax, es, edi
	push ds
	push es
ife ?32BIT
	push edi
	movzx edi, di
endif
	call srtask
ife ?32BIT
	pop edi
endif
	pop es
	pop ds
	and byte ptr [esp].IRET32.rFL,not 1	;clear carry flag
	iretd
	align 4
_srtask endp

;	.errnz sizeof PMSTATE - 8
	.errnz sizeof PMSTATE - 16	;v3.19

srtask proc
	push esi
	push edi
	cld
	mov esi, offset v86iret.rSP
	cmp al,0		;save or restore?
	jnz srtask_restore
	push ss
	pop ds
	assume ds:GROUP16
	@dprintf "srtask: task state save, es:edi=%lX:%lX",es,edi
@@:
	movsw
	add esi,2  
;	cmp esi, offset pmstate	; v86iret.rSP+6*4
	cmp esi, offset v86iret+sizeof V86IRET
	jnz @B
if ?NOPMSTATECONSEC	;if pmstate doesn't follow v86iret in memory
	mov esi,offset pmstate
endif
	jmp exit
srtask_restore:
;--- restore task state
	@dprintf "srtask: task state restore, es:edi=%lX:%lX",es,edi
	xchg esi, edi
	push es
	pop ds
	push ss
	pop es
if ?NMISAFE
	push eax
	@NMI_OFF
endif
@@:
	movsw
	add edi,2
;	cmp edi, offset pmstate	; v86iret.rSP+6*4
	cmp edi, offset v86iret+sizeof V86IRET
	jnz @B
if ?NMISAFE
	@NMI_ON
	pop eax
endif
if ?NOPMSTATECONSEC	;if pmstate doesn't follow v86iret in memory
	mov edi, offset pmstate	;pmstate follows v86iret in memory
endif
exit:
	movsd	; pmstate is 8 bytes!
	movsd
	movsd	;v3.19: real size of pmstate is 8+6 bytes
	movsw	;the last item is a segment register
	pop edi
	pop esi
	ret
	align 4
srtask endp

_TEXT32 ends

_TEXT16 segment

;--- there are 2 versions for task state saving in real-mode.
;--- one that does all in real-mode
;--- the other switches to protected-mode, but this is
;--- a critical operation, since the "task state" must not
;--- be modified by the switch.

	@ResetTrace

srtask_rm proc

	pushf

if 0
	public srtask_brk
srtask_brk::
	@rm2pmbrk
;--- this version switches to protected-mode
	push ds	;save all real-mode segment registers onto the rm stack
	push es
	push fs
	push gs
	push dx
	push bx
	push cx
	mov cx,es
	mov bx,ss	;save the value of rm SS:SP in standard registers
	mov dx,sp
	@rawjmp_pm srtask_rm_1

_TEXT32 segment
srtask_rm_1:
	push byte ptr _FLATSEL_
	pop es
	push edi
	push ecx
	movzx ecx, cx
	shl ecx, 4
	movzx edi,di	;hiword edi to be cleared in both modes
	add edi, ecx
	call srtask
	pop ecx
	pop edi
	clc
	@rawjmp_rm srtask_rm_2
	align 4
_TEXT32 ends
srtask_rm_2:
	mov ss,bx		;restore the stack
	mov sp,dx
	pop cx
	pop bx
	pop dx
	pop gs			;and the segment registers
	pop fs
	pop es
	pop ds
	popf
	clc
	retf
else
;--- this version does all in real-mode
	push ds
	push es
	pusha
	cld
	cli
	mov si, offset v86iret.rSP
	push cs
	cmp al,0
	jnz srtask_restore
	@drprintf "srtask_rm: task state save, es:di=%X:%X", es, di
	pop ds
	assume DS:GROUP16
@@:
	movsw
	inc si
	inc si
;	cmp si, offset pmstate	;v86iret.rSP+6*4
	cmp si, offset v86iret + sizeof V86IRET
	jnz @B
if ?NOPMSTATECONSEC	;if pmstate doesn't follow v86iret in memory
	mov si, offset pmstate
endif
	jmp exit
srtask_restore:
	@drprintf "srtask_rm: task state restore, es:di=%X:%X",es,di
	xchg si, di
	push es
	pop ds
	pop es
@@:
	movsw
	inc di
	inc di
;	cmp di, offset pmstate	;v86iret.rSP+6*4
	cmp di, offset v86iret + sizeof V86IRET
	jnz @B
if ?NOPMSTATECONSEC	;if pmstate doesn't follow v86iret in memory
	mov di, offset pmstate
endif
exit:
	movsd
	movsd
	movsd	;v3.19 real size of pmstate is 8 + 6 bytes
	movsw	;the last item is a segment register
	popa
	pop es
	pop ds
	popf
	clc
	retf
	align 2

endif
srtask_rm endp

_TEXT16 ends

_TEXT32 segment

;*******************************************
;*** 0306h get raw mode switch addresses ***
;*******************************************

	@ResetTrace

getrmsa proc near public

	mov bx, ss:[wHostSeg]
	mov cx,offset rm2pm
	mov si,_INTSEL_
if ?32BIT
	mov edi,_RMSWT_
	@dprintf "get raw mode switch addresses, si:edi=%X:%lX, bx:cx=%X:%X",si,edi,bx,cx
else
	mov di,_RMSWT_
	@dprintf "get raw mode switch addresses, si:di=%X:%X, bx:cx=%X:%X",si,di,bx,cx
endif
	clc
	ret
	align 4
getrmsa endp

	@ResetTrace

_TEXT16 segment

;--- ?RAW_SETDEFRMSINPM
;--- = 0 prior to v3.18
;--- = 1 in v3.18
;--- = 0 in v3.19
;--- a value of 0 requires that nothing is (temporarily) pushed onto the current RMS
;--- in the low-level mode switch routines ( see switch.asm, rawjmp_rm_all )
?RAW_SETDEFRMSINPM equ 0

;*** raw mode switch: real mode -> protected mode
;--- inp:
;--- ax=DS
;--- cx=ES
;--- dx:e/bx=ss:e/sp
;--- si:e/di=cs:e/ip

rm2pm proc near
	pushf

	public rm2pm_brk
rm2pm_brk::
	@rm2pmbrk

	pop cs:[tmpFLReg]
ife ?DOSOUTPUT
	@drprintf "rm2pm: si:edi=%X:%lX ax=%X cx=%X", si, edi, ax, cx
endif

ife ?RAW_SETDEFRMSINPM

;--- current real-mode SS:SP becomes default RMS.
;--- old default RMS (v86iret.rSS/rSP) is NOT saved,
;--- it has (should have) been saved in save/restore task state.
	mov cs:v86iret.rSP,sp
	mov cs:v86iret.rSS,ss

endif

;--- switch to pm, leaves ds,es,fs,gs undefined
;--- stack switch to host stack

	@rawjmp_pm rm2pm_pm		;raw switch to pm, rm segs not saved in v86iret
	align 2

_TEXT32 segment

rm2pm_pm:
	mov ds, eax
	mov es, ecx

	sub esp, sizeof IRET32
	xor eax, eax
ife ?32BIT
	movzx edi, di
	movzx ebx, bx
endif
	mov fs, eax
	mov gs, eax
;	@dprintf "rm2pm: in protected mode, DS,ES=%X,%X",ds,es
	mov [esp].IRET32.rIP, edi
	mov ax, ss:[tmpFLReg]
	mov [esp].IRET32.rCSd, esi
	and ah, 08Fh		; reset IOPL,NT
if ?PMIOPL
	or ah, ?PMIOPL shl 4
else
;--- see macro @iopl0vif in hdpmi.asm
 if ?IFALWAYSON
	test byte ptr ss:[dwFeatures], 2	;VME feature?
	jz @F
	.586p
	mov ecx, cr4
	.386p
	test cl, 2			; PVI set?
	jz @F
;--- if CR4.PVI is on, set IF=1 and VIF=rm IF
	bts eax, 9			; set IF
	jnc @F
	bts eax, 19			; set VIF if IF was 1
@@:
 endif
endif
	mov [esp].IRET32.rFL, eax
	mov [esp].IRET32.rSP, ebx
	mov [esp].IRET32.rSSd, edx

	@NMI_ON ;rm2pm

	@checkhoststack

if ?32BIT
	@dprintf "rm2pm: CS:Eip=%X:%lX, SS:Esp=%X:%lX, RMS=%X:%X, HS=%lX",\
		si, edi, dx, ebx, ss:v86iret.rSS, ss:v86iret.rSP, esp
else
	@dprintf "rm2pm: CS:Ip=%X:%X, SS:Sp=%X:%X, RMS=%X:%X, HS=%lX",\
		si, di, dx, bx, ss:v86iret.rSS, ss:v86iret.rSP, esp
endif
	iretd
	align 4

_TEXT32 ends

rm2pm endp

_TEXT16 ends

;*** raw mode switch: protected mode -> real mode
;*** preserve interrupt flag!
;--- inp:
;--- si:di=CS:IP
;--- dx:bx=SS:SP
;--- ax=DS
;--- cx=ES

	@ResetTrace

_pm2rm proc near public
	push [esp].IRET32.rFL
if ?SETRMIOPL	;is 0 by default
	and byte ptr [esp+1],0CFh		;reset IOPL
	or byte ptr [esp+1], ?RMIOPL shl 4
endif
	pop ss:tmpFLRegD
	@dprintf "pm2rm: CS:IP=%X:%X, SS:SP=%X:%X, DS=%X, FL=%X, hs=%lX",\
		si, di, dx, bx, ax, ss:tmpFLReg, esp

	mov ss:v86iret.rES, cx
	mov ss:v86iret.rDS, ax
	mov ss:v86iret.rFS, 0
	mov ss:v86iret.rGS, 0
if ?RAW_SETDEFRMSINPM
	@NMI_OFF
	mov ss:v86iret.rSP, bx
	mov ss:v86iret.rSS, dx
endif

	@store_ssesp
	@rawjmp_rm_savesegm pm2rm_rm

	align 4

_TEXT16 segment
pm2rm_rm:
ife ?RAW_SETDEFRMSINPM
	mov ss,dx
	mov sp,bx
endif
;	@drprintf "pm2rm: cur RMS=%X:%X, SS:SP=%X:%X",\
;		cs:v86iret.rSS, cs:v86iret.rSP, ss, sp 
	push cs:tmpFLReg
	push si			;push CS
	push di			;push IP
	iret			;real-mode iret!
	align 2
_TEXT16 ends

_pm2rm endp

_TEXT32 ends

	end

