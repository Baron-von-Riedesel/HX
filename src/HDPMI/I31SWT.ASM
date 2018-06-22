
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

?COPYFLRMS	  = 1	;std=1, 1=copy flags on raw mode switch
?STI@RETRMCB  = 0	;std=0, 1=do a sti after a rm cb
?DEBUGRMCB	  = 0	;std=0, 1=int 3 on entry/exit RMCB (debug)
?CLEARDIR     = 0	;std=0, 1=clear direction flag on RMCBs
?NOREENTRY    = 1	;std=1, 1=dont enter pm if exception handler runs

?RMCBMAX	equ 10h	;std=10h, max number of real mode callbacks

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

@seg _DATA16
@seg _TEXT16
@seg _TEXT32
@seg CDATA32

_DATA16 segment

MyRMCS1 RMCS <>
	org MyRMCS1	;use 1 RMCS only
MyRMCS2 RMCS <>
bIret	db 0		;temp variable for int 31h, ax=300,301,302

_DATA16 ends

CDATA32 segment

;--- client real mode callbacks

clrmcbs label RMCB
	rept ?RMCBMAX
	RMCB {{0,0},0}
endm

CDATA32 ends

_TEXT16 segment

	assume ds:nothing

;******************************************************************
;*** real mode call back - jump in PM with switch to LPMS
;******************************************************************

RMCBSF struct
dwESDS	dd ?
dwFSGS	dd ?
dwSSSP	dd ?	;previous real-mode stack
RMCBSF ends

RMSwitch label byte

	@ResetTrace

rmcb_rm proc
if ?DEBUGRMCB
	int 3
endif
	pushf
	@rm2pmbreak
	push cs				;CS is <> GROUP, dont use as prefix!
	db 0eah			;jmp ssss:oooo				
	dw offset rmswitch_1
wPatchDgrp2	dw 0;	seg rmswitch_1
rmswitch_1:
if ?NOREENTRY        
	cmp cs:[bExcEntry],-1	;host entry allowed?
	jnz noentry
endif
	pop cs:[MyRMCS1.rCS]	;now CS can be used as prefix!
	pop cs:[MyRMCS1.rFlags]

;--- build a RMCBSF frame         
        
	@pushrmstate			;saves SS:SP in taskstate
	push gs
	push fs
	push ds
	push es
if _LTRACE_
	push bp
	mov bp,sp
	@stroutrm <"-rm cb rmSS:SP=%X:%X, Fl=%X, old RMS=%X:%X [SP]=%X %X",lf>,\
		cs:tskstate.rmSS,cs:tskstate.rmSP,cs:MyRMCS1.rFlags,\
		word ptr [bp+2].RMCBSF.dwSSSP+2, word ptr [bp+2].RMCBSF.dwSSSP+0,\
		word ptr [bp+2+sizeof RMCBSF+0], word ptr [bp+2+sizeof RMCBSF+2]
	pop bp
endif
	@rawjmp_pm rmcb_pm				;ds,es,fs,gs are undefined
if ?NOREENTRY        
noentry:
	add sp,4
	retf
endif
	align 4
rmcb_rm endp

_TEXT16 ends

	@ResetTrace

_TEXT32 segment

rmcb_pm proc
	inc ss:[cRMCB]
;--- save values in tskstate on host stack
	@pushpmstate

	push edi
	mov fs,ss:tskstate.rFS
	movzx edi, ss:[MyRMCS1.rCS]
	mov gs,ss:tskstate.rGS
	sub di, ss:[wHostSeg]		;seg RMSwitch
	shl edi,4					;RMCB size is 16!
	.errnz sizeof RMCB - 16
;--- Masm silently ignores second override, JWasm gives a warning.
;--- Since Masm v6 prefers to use the GROUP for fixup calculation,
;--- the second override isn't necessary anyway.
;	les edi, fword ptr cs:[edi+offset GROUP32:clrmcbs].RMCB.rmcs
	les edi, fword ptr cs:[edi+offset clrmcbs].RMCB.rmcs
	pop es:[edi].RMCS.rEDI
	mov es:[edi].RMCS.rESI,esi
	mov es:[edi].RMCS.rEBP,ebp
	mov es:[edi].RMCS.rEBX,ebx
	mov es:[edi].RMCS.rEDX,edx
	mov es:[edi].RMCS.rECX,ecx
	mov es:[edi].RMCS.rEAX,eax
	mov cx,ss:[MyRMCS1.rCS]
	mov ax,ss:[MyRMCS1.rFlags]
	mov es:[edi].RMCS.rCS,cx
	mov es:[edi].RMCS.rFlags,ax
if ?CLEARDIR
	and ah,08Bh					;NT+IOPL+D reset
else
	and ah,08Fh 				;NT+IOPL reset
endif
	or ah,?PMIOPL				;set IOPL
	mov ss:[tmpFLReg],ax

;--- set an IRET32 frame below taskseg.esp0
;--- after this is done, real-mode code can be called again
;--- i.e. trace output to dos or bios.
	push dword ptr ss:[tskstate.rSS]
	push dword ptr ss:[tskstate.rESP]
	push ss:[tmpFLRegD]		;EFL
	push _INTSEL_			;CS
	push _RETCB_			;EIP

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
	movzx ebx, ss:[MyRMCS1.rCS]
	mov ds,ss:[selLDT]
	sub bx, ss:[wHostSeg]		;seg RMSwitch
	movzx edx,ss:tskstate.rmSS
	shl ebx, 4                  ;*16 (sizeof RMCB)
	mov es:[edi].RMCS.rSS,dx
	shl edx, 4					;edx = linear address of real-mode SS
;--- Masm silently ignores second override, JWasm gives a warning
;	movzx ebx, cs:[ebx+offset GROUP32:clrmcbs].RMCB.wSS
	movzx ebx, cs:[ebx+offset clrmcbs].RMCB.wSS
	push ebx
	and bl,0F8h
	mov [ebx].DESCRPTR.A0015,dx
	shr edx, 16
	mov [ebx].DESCRPTR.A1623,dl	;max value is 0Fh
	mov [ebx].DESCRPTR.A2431,dh	;is always 00
	pop ds
else

;--- get a selector for rm SS (in bx)
;--- limit in AX, = -1

;--- make sure DS is a valid selector before any output
	xor ecx,ecx
	mov ds,ecx

	@strout <"#rmcb: will try to alloc a rm-selector",lf>

	mov bx,ss:tskstate.rmSS
	mov ax,-1
	mov es:[edi].RMCS.rSS,bx
	call allocxsel
	jc _exitclientEx4
	mov ds,eax			;now DS -> rm SS
endif

	movzx esi,ss:[tskstate.rmSP]
	add esi, ?RMPUSHSIZE

	mov eax, [esi-sizeof RMCBSF].RMCBSF.dwESDS
	mov ecx, [esi-sizeof RMCBSF].RMCBSF.dwFSGS
	mov dword ptr es:[edi].RMCS.rES,eax
	mov dword ptr es:[edi].RMCS.rFS,ecx
	mov es:[edi].RMCS.rSP,si

if ?CHECKHOSTSTACK
	cmp esp, 180h
	jc _exitclientEx5
endif
	@strout <"#rmcb, taskstate ss:esp=%X:%lX",lf>,\
		ss:[tskstate.rSS], ss:[tskstate.rESP]

	@strout <"#rmcb, rm DS-GS=%X %X %X %X",lf>, eax, ecx

	mov ax, es:[edi].RMCS.rCS
	sub ax, ss:[wHostSeg]			;seg RMSwitch
	shl eax,4						;RMCS size is 16!
	mov cx,ax						;handle nach cx
	neg ax
	add ax,offset RMSwitch
	mov es:[edi].RMCS.rIP,ax		;IP wird aus CS ermittelt


	movzx eax,cx						;callback handle
	add eax,offset GROUP32:clrmcbs

;--- build an IRET32 stack frame

	@strout <"#rmcb, frame for lpms_call_int: %lX %lX %lX %lX %lX",lf>,\
		dword ptr _RETCB_, dword ptr _INTSEL_, dword ptr ss:[tmpFLRegD],\
		ss:[tskstate.rESP], dword ptr ss:[tskstate.rSS]

if 0	;this is now done above, before any displays
	push dword ptr ss:[tskstate.rSS]
	push dword ptr ss:[tskstate.rESP]
	push ss:[tmpFLRegD]		;EFL
	push _INTSEL_			;CS
	push _RETCB_			;EIP
endif
if ?32BIT
	@strout <"#rmcb, jmp to pm proc=%X:%lX, EDI=%lX:%lX, ESI=%lX:%lX, HS=%lX",lf>,\
		word ptr cs:[eax].R3PROC._Cs,cs:[eax].R3PROC._Eip,es,edi,ds,esi,ss:[taskseg._Esp0]
else
	@strout <"#rmcb, jmp to pm proc=%X:%X,ES:DI=%lX:%X,DS:SI=%lX:%X,HS=%lX",lf>,\
		cs:[eax].R3PROC._Cs,cs:[eax].R3PROC._Eip,es,di,ds,si,ss:[taskseg._Esp0]
endif
;	@waitesckey
	push eax
	jmp lpms_call_int		;switch to LPMS
	align 4

rmcb_pm endp

;**************************************
;*** return from real mode callback ***
;**************************************

	@ResetTrace

_retcb proc public							  ;stack irrelevant?
if _LTRACE_
	push ebp
	mov ebp,esp
	@strout <"#ret rmcb: [esp]=%lX,%lX,%lX,%lX,%lX",lf>,\
		[ebp+4],[ebp+8],[ebp+12],[ebp+16],[ebp+20]
	pop ebp
endif
if ?32BIT
	@strout <"#ret rmcb %X: ES:EDI=%lX:%lX,HS=%lX",lf>,\
		ss:[cRMCB],es,edi,ss:[taskseg._Esp0]
else
	@strout <"rm cb ret: ES:DI=%lX:%X,HS=%lX",lf>,\
		es,di,ss:[taskseg._Esp0]
endif
;	@waitesckey
	dec ss:[cRMCB]

	cld
	mov eax,es
	push ss
	mov ds,eax
	pop es
	assume ds:nothing
if ?32BIT        
	mov esi,edi
else
	movzx esi,di
endif
	mov edi,offset MyRMCS1
	mov ecx,30h/4
	rep movsd
	movsw
	@strout <"#ret rmcb: rmSS:SP=%X:%X",lf>,ss:MyRMCS1.rSS,ss:MyRMCS1.rSP
	add esp,sizeof IRET32
;--- restore values in tskstate
	@poppmstate
	@rawjmp_rm _retcb_rm	;raw jump rm, SP unchanged
	align 4
_retcb endp

_TEXT32 ends

_TEXT16 segment

_retcb_rm proc
	@poprmstate
	mov ax, cs
	mov ss, ax
	mov sp,offset MyRMCS1
	popad
	add sp,2 ;skip flags
	pop es
	pop ds
	pop fs
	pop gs
	lss sp,cs:[MyRMCS1.rSSSP]

if _LTRACE_
	push bp
	mov bp,sp
	@stroutrm <"-ret rmcb: rm SP=%X:%X FL=%X IP=%X:%X [SP]=%X,%X",lf>,\
		cs:[MyRMCS1.rSS],cs:[MyRMCS1.rSP],cs:[MyRMCS1.rFlags],\
		cs:[MyRMCS1.rCS],cs:[MyRMCS1.rIP],[bp+2],[bp+4]
;	@waitesckey
	pop bp
endif
if ?STI@RETRMCB
	or byte ptr cs:[MyRMCS1.rFLags+1],2
endif
	push word ptr cs:[MyRMCS1.rFlags]
if ?DEBUGRMCB
	int 3
endif
if 0
	push dword ptr cs:[MyRMCS1.rIP]
	iret	;real-mode iret!
else
	popf
	jmp dword ptr cs:[MyRMCS1.rIP]
endif
	align 4
_retcb_rm endp

_TEXT16 ends

_TEXT32 segment

;***********************************************
;*** simulate real mode interrupt            ***
;*** call real mode far proc with retf frame ***
;*** call real mode far proc with iret frame ***
;***********************************************

	@ResetTrace

;--- modifies DS, ES, esi, edi, ecx

copystackparms proc uses ebp

	mov ebp,ss:[taskseg._Esp0]		 ;client stack -> ds:si
	@strout <"copy stack parms, %X words src=%X:%lX",lf>,cx,\
		[ebp-sizeof IRET32].IRET32.rSS,[ebp-sizeof IRET32].IRET32.rSP

	lds esi,[ebp-sizeof IRET32].IRET32.rSSSP
	push ecx
	movzx ecx,cx
	movzx eax,word ptr ss:tskstate.rmSP
	movzx edi,word ptr ss:tskstate.rmSS
	shl ecx,1						;2*, since WORDS
	sub eax,ecx
	jc error
	shr ecx,1

	shl edi,4
	add edi,eax
	push byte ptr _FLATSEL_
	pop es
;--- now es:edi -> rms
	rep movsw
	pop ecx
	@strout <"%X words copied to RMS [%X:%X]",lf>, cx, ss:tskstate.rmSS, ss:tskstate.rmSP
	add cx,cx
	sub word ptr ss:[tskstate.rmSP],cx
	ret
error:
	@strout <"stack param error!!!",lf>
	pop ecx
	ret
	align 4
copystackparms endp

;--- please note: values CS:IP and SS:SP in RMCS must NOT be modified!
;--- since we first copy the RMCS to our internal one, this should
;--- not happen
;--- as well, client's real-mode segment registers should not be modified
;--- by the RMCS used here. why???

	@ResetTrace

RMCALLS struct
rES		dd ?
rEdi2   dd ?
;rmES	dw ?
;rmDS	dw ?
;rmFS	dw ?
;rmGS	dw ?
rDS		dd ?
		PUSHADS <>
RMCALLS ends

;*** int 31h, ax=0300h simulate real-mode interrupt
;--- BL = interrupt
;--- BH = 0
;--- ES:E/DI = RMCS
;--- CX = words to copy to real-mode stack

simrmint proc public
	mov ss:[bIret],2+1	;flag: get address from IVT, push flags
	jmp callrmproc
	align 4
simrmint endp	;fall through

;--- int 31h, ax=0301h: call real-mode proc with retf frame
;--- BH = 0
;--- ES:E/DI = RMCS
;--- CX = words to copy to real-mode stack

callrmretf proc public
	mov ss:[bIret],0
	jmp callrmproc
	align 4
callrmretf endp

;*** int 31h, ax=0302h: call real mode proc with iret frame
;--- BH = 0
;--- ES:E/DI = RMCS
;--- CX = words to copy to real-mode stack

callrmiret proc public
	mov ss:[bIret],1	;flags: push flags
callrmiret endp	;fall through

callrmproc proc
if ?32BIT
	@strout <"rm call, ax=%X bx=%X RNS=%X:%X rmcs: a-d=%X %X %X %X, d-e=%X %X",lf>, ax, bx,\
		ss:tskstate.rmSS, ss:tskstate.rmSP, es:[edi].RMCS.rAX, es:[edi].RMCS.rBX, es:[edi].RMCS.rCX, es:[edi].RMCS.rDX,\
		es:[edi].RMCS.rDS, es:[edi].RMCS.rES
else
	@strout <"rm call, ax=%X bx=%X RMS=%X:%X rmcs: a-d=%X %X %X %X, d-e=%X %X",lf>, ax, bx,\
		tskstate.rmSS, tskstate.rmSP, es:[di].RMCS.rAX, es:[di].RMCS.rBX, es:[di].RMCS.rCX, es:[di].RMCS.rDX,\
		es:[di].RMCS.rDS, es:[di].RMCS.rES
endif
	pushad
	push ds

;--- 1. save real-mode segments

;	push ss:[v86iret.rGS]
;	push ss:[v86iret.rFS]
;	push ss:[v86iret.rDS]
;	push ss:[v86iret.rES]

ife ?32BIT
	movzx edi,di
endif
	push edi
	push es
	mov ebp,esp

;--- 2. copy RMCS in conv. memory

	push es
	pop ds				;DS = RMCS selector

	push ss
	pop es
	mov edx,ecx
	mov esi,edi
	mov edi,offset MyRMCS2
	cld
	mov ecx,8			;copy the standard regs
	rep movsd
	lodsw				;flags
	and ah,08Eh 					  ;reset NT,IOPL,TF
	or ah,?RMIOPL
	mov ss:tmpFLReg,ax
	lodsw				;ES
	mov ss:v86iret.rES, ax
	lodsw				;DS
	mov ss:v86iret.rDS, ax
	lodsw				;FS
	mov ss:v86iret.rFS, ax
	lodsw				;GS
	mov ss:v86iret.rGS, ax
	lodsd
	mov ss:MyRMCS2.rCSIP, eax
	lodsd

	push ss:tskstate.rmSSSP

	and eax,eax
	jz @F
	mov ss:[tskstate.rmSSSP], eax
@@:
	mov ecx,edx			;restore CX

;--- 3. get real-mode address if it is a simulate int call

	test ss:[bIret],2	;is address to copy from IVT (ax=0300h)?
	jz @F
	push byte ptr _FLATSEL_
	pop ds
if ?CHECKIRQRM
	call checkirqrm		;modifies ds,ebx if int is routed to pm
else
	movzx ebx,bl
	shl ebx,2
endif
	mov eax, ds:[ebx]
	mov ss:[MyRMCS2.rCSIP], eax
if 0;_LTRACE_
	shr bx,2
  if ?32BIT
	@strout <"sim rm int %X, ax=%X, bx=%X, fl=%X",lf>,bx,\
		word ptr es:[edi.RMCS.rEAX], word ptr es:[edi.RMCS.rEBX],\
		word ptr es:[edi.RMCS.rFlags]
  endif
endif
@@:

;--- 5. copy words to real-mode stack

	jcxz @F						 ;no stack params
	call copystackparms
	jnc @F
	pop ss:tskstate.rmSSSP
	pop es
	lea esp,[ebp].RMCALLS.rDS
	pop ds
	popad
	ret		;exit with C set, error
@@:

;--- 6. restore DS, ES to ring3 selectors, jump to real-mode

	mov es,[ebp].RMCALLS.rES
	mov ds,[ebp].RMCALLS.rDS
	@jmp_rm callrmproc_rm
	align 4

callrmproc endp

_TEXT32 ends

_TEXT16 segment

callrmproc_rm proc

;--- 7. restore real-mode SP (must be done *after* the switch)

;	add cs:[tskstate.rmSP],cx

;--- 8. fill registers from RMCS

	mov ax,cs
	mov ss,ax
	mov sp,offset MyRMCS2
	popad
	lss sp, cs:tskstate.rmSSSP

	test cs:[bIret],1
	jz @F
	push cs:[tmpFLReg]
@@:        
	and byte ptr cs:[tmpFLReg+1],not (1+2)	;reset IF + TF
	push cs:[tmpFLReg]
;	@stroutrm <"-call rm proc/int, cs:ip=%X:%X, ss:sp=%X:%X fl=%X,ax=%X",lf>,\
;		cs:[MyRMCS2.rCS],cs:[MyRMCS2.rIP],ss,sp,ax,cs:[MyRMCS2.rAX]
	popf
	call cs:[MyRMCS2.rCSIP]

	pushf
	@rm2pmbreak
	pop cs:[tmpFLReg]

	@jmp_pm callrmproc_pm2
	align 4

callrmproc_rm endp

_TEXT16 ends

_TEXT32 segment

callrmproc_pm2 proc

;--- copy the RMCS back to the client's one. Dont modify CS:IP and SS:SP!
;--- SP -> client ES,EDI, rmsegs

	pop ss:tskstate.rmSSSP
	pop es
	pushad
	push ss
	pop ds
	assume ds:GROUP16
	cld
	mov edi,[esp+sizeof PUSHADS-4].RMCALLS.rEdi2
	mov ecx,8
	mov esi,esp
	rep movsd
	mov ax,[tmpFLReg]
	stosw
	mov eax,dword ptr [v86iret.rES]
	stosw
	mov eax,dword ptr [v86iret.rDS]
	stosw
	mov eax,dword ptr [v86iret.rFS]
	stosw
	mov eax,dword ptr [v86iret.rGS]
	stosw
	lea esp,[esp + sizeof PUSHADS + 4]
;	pop [v86iret.rES]
;	pop [v86iret.rDS]
;	pop [v86iret.rFS]
;	pop [v86iret.rGS]

	pop ds
	popad

	@strout <"#callrmproc_pm: exit, NC, RMS=%X:%X",lf>, ss:tskstate.rmSS, ss:tskstate.rmSP
	clc
	ret
	align 4
callrmproc_pm2 endp

;*** int 31h, ax=0303: alloc real mode callback
;*** inp: ds:(e)si: far16/far32 pm proc to call
;***	  es:(e)di: RMCS structure
;*** out: cx:dx: rm address of callback

	@ResetTrace

allocrmcb proc public

	pushad
	@strout <"#allocrmcb: enter ds:esi=%lX:%lX es:edi=%lX:%lX",lf>,ds,esi,es,edi
	mov eax,ds
;	push ss
	push byte ptr _CSALIAS_
	pop ds
;	assume ds:GROUP16
	assume ds:GROUP32
	mov ebx,offset GROUP32:clrmcbs
	mov cx,?RMCBMAX		;ch == 0
alloccb2:
	cmp [ebx].RMCB._Cs,0000
	jz @F
	add ebx,size RMCB
	dec cl
	jnz alloccb2
	popad
	@strout <"#allocrmcb: error, no free rmcbs available",lf>
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
;	@strout <"#allocrmcb: rmcb allocated: %X:%lX %lX:%lX",lf>, ax,esi,es,edi
	mov esi, ecx
if ?RMCBSTATICSS
	mov cx,1
	xor eax,eax
	@int_31
	jnc @F
	@strout <"#allocrmcb: error, no free descriptor for rmSS",lf>
	mov [ebx].RMCB._Cs,0
	popad
	stc
	ret
@@:
	@strout <"#allocrmcb: allocated selector for rmSS=%X",lf>, ax
	mov [ebx].RMCB.wSS, ax
	mov bx, ax
	mov dx,-1
	mov cx, 0
	mov ax, 8
	@int_31
endif
	mov eax,esi
	mov cx, ss:[wHostSeg]			;seg RMSwitch
	sub ax,?RMCBMAX
	neg ax
	add cx,ax
	mov [esp].PUSHADS.rCX, cx
	mov dx,offset RMSwitch
	shl ax,4
	sub dx,ax
	mov [esp].PUSHADS.rDX, dx
	@strout <"#allocrmcb: returned callback=%X:%X",lf>,cx,dx
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
	@strout <"#freermcb: free real mode callback %X:%X",lf>, cx, dx
	push byte ptr _CSALIAS_
	pop ds
	assume ds:GROUP32
	movzx eax,cx
	sub ax, ss:[wHostSeg]	;seg RMSwitch
	cmp eax,?RMCBMAX
	jnb freecberr
	shl eax,4
	mov ecx,eax
	neg ax
	add ax,offset RMSwitch
	cmp ax,dx
	jnz freecberr
	mov eax,ecx
	add eax,offset GROUP32:clrmcbs
	mov ebx,eax
	cmp [ebx].RMCB._Cs, 0	;is it already free?
	jz freecberr
	mov [ebx].RMCB._Cs, 0
if ?RMCBSTATICSS
	mov bx, [ebx].RMCB.wSS
	mov ax, 1
	@int_31	;ignore errors here
endif
	@strout <"#freermcb: ok",lf>
	popad
	clc
	ret
freecberr:
	@strout <"#freermcb: error, invalid cb or cb already free",lf>
	popad
	stc
	ret
	align 4
freermcb endp

;*************************************************
;*** 0305h get task state save/restore address ***
;*************************************************

	@ResetTrace

getsraddr proc near public

	mov ax,sizeof tskstate + 2*4;groesse des puffers

	mov bx, ss:[wHostSeg]
	mov cx, offset srtask_rm

	mov si,_INTSEL_
if ?32BIT
	mov edi,_SRTSK_
else
	mov di,_SRTSK_
endif
	clc
	ret
	align 4
getsraddr endp

;*** prot mode save/restore proc ***
;--- al=0 : save task state
;--- al=1 : restore task state
;--- es:e/di: buffer

_srtask proc public
;	@strout <"#task state save/restore pm, ax=%X, es:edi=%lX:%lX",lf>, ax, es, edi
	push ds
	push es
	pushad
	cld

	mov esi,offset tskstate
	mov ecx,sizeof tskstate/2
ife ?32BIT
	movzx edi, di
endif
	cmp al,0
	jnz @F
	push ss
	pop ds
	assume ds:GROUP16
	@strout <"#srtask: task state save, es:edi=%lX:%lX",lf>,es,edi
	rep movsw
	mov ax, [v86iret.rES]
	shl eax, 16
	mov ax, [v86iret.rDS]
	stosd
	mov ax, [v86iret.rGS]
	shl eax, 16
	mov ax, [v86iret.rFS]
	stosd
	jmp exit
@@:
;--- restore task state
	@strout <"#srtask: task state restore, es:di=%lX:%lX",lf>,es,edi
	xchg esi, edi
	push es
	pop ds
	push ss
	pop es
	rep movsw
	lodsd
	mov es:[v86iret.rDS], ax
	shr eax, 16
	mov es:[v86iret.rES], ax
	lodsd
	mov es:[v86iret.rFS], ax
	shr eax, 16
	mov es:[v86iret.rGS], ax
exit:
;	clc			;useless!
	popad
	pop es
	pop ds
	and byte ptr [esp].IRET32.rFL,not 1	;clear carry flag
	iretd
	align 4
_srtask endp

_TEXT32 ends

_TEXT16 segment

	@ResetTrace

;--- don't loose TF!

srtask_rm proc
	clc
	pushf
	@rm2pmbreak

	push ds
	pusha
	cld

	mov si,offset tskstate
	mov cx,sizeof tskstate/2
	cmp al,0
	jnz @F
	@stroutrm <"-srtask_rm: task state save, es:di=%X:%X",lf>,es,di
	push cs
	pop ds
	assume DS:GROUP16
	rep movsw
	mov ax, [v86iret.rDS]
	stosw
	mov ax, [v86iret.rES]
	stosw
	mov ax, [v86iret.rFS]
	stosw
	mov ax, [v86iret.rGS]
	stosw
	jmp exit
@@:
;--- restore task state
	@stroutrm <"-srtask_rm: task state restore, es:di=%X:%X",lf>,es,di
	push es
	xchg si, di
	push es
	pop ds
	push cs
	pop es
	rep movsw
	lodsw
	mov es:[v86iret.rDS], ax
	lodsw
	mov es:[v86iret.rES], ax
	lodsw
	mov es:[v86iret.rFS], ax
	lodsw
	mov es:[v86iret.rGS], ax
	pop es
exit:
	popa
	pop ds
	popf
	retf
	align 4
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
else
	mov di,_RMSWT_
endif
	@strout <"#get raw mode switch addresses, si:di=%X:%X, bx:cx=%X:%X",lf>,si,di,bx,cx
	clc
	ret
	align 4
getrmsa endp

_TEXT32 ends

	@ResetTrace

_TEXT16 segment

;*** raw mode switch: real mode -> protected mode
;--- inp:
;--- ax=DS
;--- cx=ES
;--- dx:e/bx=ss:e/sp
;--- si:e/di=cs:e/ip

rm2pm proc near
	pushf

	public rm2pm_brk	;if in VCPI mode, this break is removed
rm2pm_brk::
	@rm2pmbreak

	pop cs:[tmpFLReg]

	@stroutrm <"-rm2pm, ">

;--- setting current real-mode SS:SP as new RMS
;--- is dangerous, because SS:SP may be used as pm application
;--- stack. Better do this only if standard RMS is in use.

  if ?RMSCNT
	cmp cs:bRMScnt,0
	jz @F
;	mov cs:bRMScnt,0	;this does *not* work currently
  endif
	mov cs:tskstate.rmSS,ss
	mov cs:tskstate.rmSP,sp
@@:

;--- should the v86-rDS ... v86-rGS values be set here?

;--- switch to pm, leaves ds,es,fs,gs undefined
;--- stack switch to host stack, tskstate untouched

	@rawjmp_pm rm2pm_pm
	align 4

rm2pm endp

_TEXT16 ends

_TEXT32 segment

rm2pm_pm proc
	mov ds,eax
	mov es,ecx
	sub esp, sizeof IRET32
	xor eax,eax
ife ?32BIT
	movzx edi, di
	movzx ebx, bx
endif
	mov fs,eax
	mov gs,eax
;	@strout <"now in protected mode, DS,ES=%X,%X",lf>,ds,es
	mov [esp].IRET32.rIP, edi
	mov ax,ss:[tmpFLReg]
	mov [esp].IRET32.rCSd, esi
	and ah,08Fh					;reset IOPL,NT
	or ah,?PMIOPL
	mov [esp].IRET32.rFL, eax
	mov [esp].IRET32.rSP, ebx
	mov [esp].IRET32.rSSd, edx
if ?32BIT
	@strout <"CS:Eip=%X:%lX,SS:Esp=%X:%lX,HS=%lX",lf>,si,edi,dx,ebx,ss:[taskseg._Esp0]
else
	@strout <"CS:Ip=%X:%X,SS:Sp=%X:%X,RMS=%X:%X,HS=%lX",lf>,si,di,dx,bx,\
		ss:[tskstate.rmSS],ss:[tskstate.rmSP],ss:[taskseg._Esp0]
endif
	iretd
	align 4

rm2pm_pm endp

;*** raw mode switch: protected mode -> real mode
;*** preserve interrupt flag!
;--- inp:
;--- si:di=CS:IP
;--- dx:bx=SS:SP
;--- ax=DS
;--- cx=ES

_pm2rm proc near public
	push word ptr [esp].IRET32.rFL
	pop ss:[tmpFLReg]
	@strout <"#pm2rm: CS:IP=%X:%X, SS:SP=%X:%X, DS=%X, FL=%X, cur RMS=%X:%X",lf>,\
		si,di,dx,bx,ax,ss:[tmpFLReg],ss:[tskstate.rmSS],ss:[tskstate.rmSP]

	@savepmstate			;store segment and stack values in tskstate
	@rawjmp_rm _pm2rm_rm	;raw jump rm, SP unchanged
	align 4
_pm2rm endp

_TEXT32 ends

_TEXT16 segment

_pm2rm_rm proc
	mov ds,ax
	mov ss,dx
	mov sp,bx		;set SP only
	xor ax,ax
	mov es,cx
	mov fs,ax
	mov gs,ax
	mov ax,cs:[tmpFLReg]
	push si			;push CS
	and ah,08Fh		;reset IOPL,NT
	push di			;push IP
	or ah,?RMIOPL
	push ax
	popf
	retf			;real-mode retf!
	align 4
_pm2rm_rm endp

_TEXT16 ends

	end

