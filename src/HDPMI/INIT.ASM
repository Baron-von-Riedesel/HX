
;--- initialization code

	.486P

	include hdpmi.inc
	include external.inc
	include keyboard.inc
	include debugsys.inc

	option proc:private

ifndef ?STUB
?STUB=0
endif

ife ?STUB
?DELAYLOAD    = 1		;1=load 32part on my own (requires ?STACKLAST==0)
?STACKLAST    = 0		;std 0:	1=stack is last segment (behind GROUP32)
else
?DELAYLOAD    = 0
?STACKLAST    = 1
endif

	@seg _ITEXT16
	@seg _ITEXT32
	@seg _TEXT32
	@seg SEG16

IDTSEG	segment para use16 public 'CODE'
externdef startofidtseg:byte
GROUP16 group IDTSEG
IDTSEG	ends

	public mystart

;*** initialization code, not resident

_ITEXT16 segment

wHostSeg32 dw 0		;GROUP32 segment on startup

	@ResetTrace

;--- set some real-mode IVT vectors

hookIVTvecs proc
ife ?WATCHDOG
	test cs:fHost, FH_XMS or FH_VCPI	;are we in raw mode?
	jnz @F
	mov cs:int15hk.bInt,15h
@@:
endif
	push es
	push 0
	pop es
	mov si,offset ivthooktab
	cld
	mov ax,cs
	shl eax,16
nextitem:
	lodsb					;get int #
	cmp al,-1
	jz done
	movzx bx, al
	lodsw
	mov di, ax
	lodsw
	cmp bl,-2
	jz nextitem
	shl bx,2
	mov ecx,es:[bx]		;get old real mode vector
	mov [di],ecx		;save it
	and ax,ax
	jz nextitem
	mov es:[bx+0],eax	;set vector in one move
	jmp nextitem
done:
	pop es
	ret
hookIVTvecs endp

	@ResetTrace

;--- this is real-mode code after the 32bit code has been loaded

handleenvflags proc        

	assume ds:GROUP16

	mov ax,wEnvFlags
	@stroutrm <"wEnvFlags=%X",lf>,ax
	test al, ENVF_DPMI10
	jz @F
	mov wVersion, 0100h
if ?EXC10FRAME
	or dword ptr wExcHdlr, -1
endif
	@stroutrm <"dpmi version set to 1.0",lf>
@@:
	test ah, ENVF2_NOMEM10
	jz @F
	call disablemem10
@@:
if ?CR0_NE
	test ah, ENVF2_NOCR0NE
	jz @F
	call disablene
@@:
endif
if ?VM
	test al, ENVF_VM
	jz novm
	call getendpara
	add dx,?RMSTKSIZE/16
	mov PatchRMStkSize-2,dx
novm:
endif
	ret
handleenvflags endp

;*** alloc TLB
;--- called by _initsvr_rm
;--- DS=GROUP16

	@ResetTrace

settlb_rm proc

	@stroutrm <"settlb_rm enter",lf>
if ?GLOBALTLBUSAGE				;get TLB of a previously installed instance
	mov ax,word ptr [dwHost16+2]
	test [fHost],FH_HDPMI
	jnz @F
	call IsHDPMIDisabled
	jc nohdpmi
@@:
	push ds
	mov ds, ax
	mov ax,[wSegTLB]
	@stroutrm <"TLB %X in previous HDPMI host %X ",lf>, ax, ds
	pop ds
  if ?TLBLATE
	and ax,ax
	jnz settlb_1
  else
	jmp settlb_1
  endif
nohdpmi:
endif
if ?TLBLATE
	test [fMode2],FM2_TLBLATE
	jnz exit
endif
	call getendpara
	mov ax,cs
	add ax,dx
	test bEnvFlags, ENVF_TLBLOW	;must TLB be in low memory?
	jz settlb_0
	cmp ax,0A000h			;is HDPMI loaded high?
	jc settlb_0
	mov ax,5801h			;then set fit best strategie
	mov bx,0000h			;low memory, first fit
	int 21h
allocnewmcb:					;get memory for translation buffer
	mov bx,?TLBSIZE/10h
	mov ah,48h
	int 21h
	jc exit
	@stroutrm <"TLB memory block allocated: %X",lf>,ax
	or fMode, FM_TLBMCB
	jmp settlb_1
settlb_0:
if ?DELAYLOAD
	push ax
	add ax,?TLBSIZE/10h
	add ax,10h
	mov cx,wHostPSP
	sub ax,cx
	@stroutrm <"realloc memory block %X to size %X",lf>,cx,ax
	mov bx,ax
	mov es,cx
	mov ah,4Ah
	int 21h
	pop ax
	jc allocnewmcb
endif
settlb_1:
	mov [wSegTLB],ax
	movzx eax,ax
	shl eax,4
	@stroutrm <"TLB is %lX",lf>,eax
;	mov [atlb],eax			;not used currently
	mov bx,_TLBSEL_
	and bx,not 7
	mov [curGDT+bx].A0015,ax
	shr eax,16
	mov [curGDT+bx].A1623,al
;;	mov [curGDT+bx].A2431,ah
	clc
exit:
	ret
settlb_rm endp

	@ResetTrace
        
filldesc proc near

	assume ds:GROUP16

	xor eax,eax	
	mov ax, ds				;GROUP16
	shl eax,4
	mov dwHostBase,eax
	mov ecx,eax
	mov bx,_SSSEL_
	mov si,_DSR3SEL_
	and si,not 7
	mov [curGDT+bx].A0015,ax
	mov [curGDT+si].A0015,ax
if ?MOVEHIGHHLP
	mov di,_CSGROUP16_
	mov [curGDT+di].A0015,ax
endif
	shr eax,16
	mov [curGDT+bx].A1623,al
	mov [curGDT+si].A1623,al
if ?MOVEHIGHHLP
	mov [curGDT+di].A1623,al
endif
	xor eax,eax
	mov ax, wHostSeg32		;GROUP32
	shl eax,4
	mov bx,_CSSEL_
	mov si,_CSR3SEL_
	and si,not 7
	mov [curGDT+bx].A0015,ax
	mov [curGDT+si].A0015,ax
;	mov [curGDT+(_DSR3SEL_ and 0F8h)].A0015,ax
	shr eax,16
	mov [curGDT+bx].A1623,al
	mov [curGDT+si].A1623,al
;	mov [curGDT+(_DSR3SEL_ and 0F8h)].A1623,al

ife ?DYNBREAKTAB
	mov ax,offset inttable
	add eax,ecx
	mov bx,_INTSEL_
	and bl,not 7
	mov [curGDT+bx].A0015,ax
	shr eax,16
	mov [curGDT+bx].A1623,al
;	mov [curGDT+bx].A2431,ah
endif

	lea eax,[ecx+offset taskseg]
	mov bx,_TSSSEL_
	and bl,not 7
	mov [curGDT+bx].A0015,ax
	shr eax,16
	mov [curGDT+bx].A1623,al
;	mov [curGDT+bx].A2431,ah

;--- fill GDT pseudo descriptor

	lea eax,[ecx+offset curGDT]
	mov pdGDT.dwBase,eax

if ?KDSUPP
	mov bx,_GDTSEL_
	mov [curGDT+bx].A0015,ax
	shr eax,16
	mov [curGDT+bx].A1623,al
;	mov [curGDT+bx].A2431,ah
endif

	lea eax,[ecx+offset curIDT]
	mov pdIDT.dwBase,eax

	test [fHost], FH_VCPI
	jnz host_is_vcpi

	mov word ptr [rawjmp_pm_patch], RAWJMP_PM_PATCHVALUE
if ?PATCHCODE
	mov word ptr [rawjmp_rm_patch], RAWJMP_RM_PATCHVALUE
endif
	jmp patch_done
host_is_vcpi:  
	lea eax,[ecx+offset pdGDT]	 ;address GDT pseudo descriptor
	mov v86topm._gdtr,eax

	lea eax,[ecx+offset pdIDT]	 ;address IDT pseudo descriptor
	mov v86topm._idtr,eax

	lea eax,[ecx+offset v86topm]
	mov dword ptr [linadvs-4],eax	;patch code in rawjmp_pm

if ?INTRM2PM
if 1
	test bEnvFlags2, ENVF2_DEBUG
	jnz @F
	mov ax,90FAh
	mov word ptr _gotopmEx,ax	;deactivate RM2PM int
externdef rm2pm_brk:near
	mov word ptr rm2pm_brk,ax	;deactivate RM2PM int
@@:
endif
endif
ife ?PATCHCODE
	mov rawjmp_rm_vector, offset rawjmp_rm_vcpi_2
	test [bEnvFlags], ENVF_GUARDPAGE0
	jz @F
	mov rawjmp_rm_vector, offset rawjmp_rm_vcpi_1
@@:
endif
patch_done:
	push ds
	mov ax,5D06h		;returns SDA in DS:SI
	int 21h
	mov ax,ds
	pop ds
	movzx eax,ax
	shl eax,4
	movzx ebx,si
	add eax,ebx
	mov [dwSDA],eax

if ?DYNTLBALLOC
	mov ah,52h			;get LoL
	int 21h
	xor eax,eax
	mov ax,es
	shl eax,4
	movzx ebx,bx
	add eax,ebx
	mov [dwLoL],eax
endif
	clc
	ret
filldesc endp

;--- a 80386/80486 is required
;--- returns cpu in CL

getcpu proc near

	assume ds:GROUP16

	mov si,sp
	and sp,not 3		; make sure there is no alignment exception

	mov cl,3			; default: 80386
	pushfd				; save EFlags

	cli
	push 24h			; set AC bit in eflags
	pushf
	popfd

	pushfd				; push extended flags
	pop ax
	pop ax				; get HiWord(EFlags) into AX

	popfd				; restore EFlags
	mov sp,si

	test al,04
	je @F
	inc cl				; is at least a 80486
	test al,20h
	jz @F
	xor eax,eax
	inc eax				; get register 1
	@cpuid
	mov cl,ah
	mov	[dwFeatures],edx
@@:
	mov [_cpu],cl
	cmp cl,4
	jnc @F
	or [fMode2],FM2_NOINVLPG
@@:
	ret
getcpu endp

;*** kernel debugger (wdeb386/386swat) init real mode
;--- IDT must be in conventional memory
;--- no return value

if ?386SWAT

initdebugger1_rm proc
	push ds
	xor eax, eax
	mov ds, ax
	cmp eax, ds:[67h*4]
	pop ds
	jz nokerneldebugger
	mov ax,0DEF0h
	int 67h
	cmp ah,00
	jnz nokerneldebugger
	or fDebug,FDEBUG_KDPRESENT
if ?INTRM2PM
	mov word ptr _gotopmEx,90FAh	;deactivate RM2PM int
endif
nokerneldebugger:
	ret
initdebugger1_rm endp

;--- modifies AX, BX, EDX, DI, ES

initdebugger2_rm proc
	test fDebug,FDEBUG_KDPRESENT
	jz done
	push cs
	pop es
	mov bx,_KDSEL_             ;BX=initial selector
	lea di,[bx+offset curGDT]  ;ES:DI=debugger GDT entries
	mov ax,0DEF2h
	int 67h
	and ah,ah
	jnz err
	mov dword ptr [dbgpminit+0],edx ;BX:EDX=protected-mode entry
	mov word ptr [dbgpminit+4],bx

	push es
	push cs
	pop es
	xor bx,bx		;interrupt number
	mov di,offset curIDT
@@:
	mov ax,0DEF3h
	int 67h
	add di,8
	inc bx
	cmp bx,20h
	jb @B
	pop es
done:
	ret
err:
	and fDebug, not FDEBUG_KDPRESENT
	ret
initdebugger2_rm endp

endif

if ?WDEB386

initdebugger_rm proc

	push ds
	xor eax, eax
	mov ds, ax
	cmp eax, ds:[D386_RM_Int*4]
	pop ds
	jz nokerneldebugger
	mov ah,D386_Identify
	@stroutrm <"int 68 Identify (ax=%X)",lf>,ax
	int D386_RM_Int
	@stroutrm <"int 68 ret, ax=%X",lf>,ax
	cmp ax,D386_Id			;0F386h?
	jnz nokerneldebugger
	@stroutrm <"WDEB386 present",lf>
if ?USEDEBUGOUTPUT
	or fDebug,FDEBUG_KDPRESENT or FDEBUG_OUTPFORKD
else
	or fDebug,FDEBUG_KDPRESENT
endif
if ?INTRM2PM
	mov word ptr _gotopmEx,90FAh	;deactivate RM2PM int
endif
;------------------------------------ prepare kernel debugger for PM

	mov ax,D386_Prepare_PMode * 100h + 00h
	mov cx, _KDSEL_
	mov bx, _FLATSEL_
	mov dx, _GDTSEL_
	push cs
	pop es
	mov si,offset curGDT
	mov di,offset curIDT
	@stroutrm <"int 68 Prepare PMode, ax=%X,bx=%X,cx=%X,dx=%X,es:di=%X:%X,ds:si=%X:%X",lf>,ax,bx,cx,dx,es,di,ds,si
	int D386_RM_Int
	mov dword ptr [dbgpminit+0],edi
	mov word ptr [dbgpminit+4],es
	@stroutrm <"int 68 ret, es:edi=%X:%lX,ds=%X",lf>,es,edi,ds
	ret
nokerneldebugger:
	mov ax,8B66h		;MOV AX,AX or MOV EAX,EAX
	mov cl,0C0h
	mov word ptr kdpatch1+0,ax
	mov byte ptr kdpatch1+2,cl
	mov word ptr kdpatch2+0,ax
	mov byte ptr kdpatch2+2,cl
	ret
initdebugger_rm endp

endif

;*** kernel debugger init prot mode ***
;--- DS=GROUP16, ES=FLAT

_ITEXT32 segment

if ?WDEB386

initdebugger_pm proc 
	assume DS:GROUP16
	test fDebug,FDEBUG_KDPRESENT
	jz done
	pushad
	mov edi,[pdIDT.dwBase]
	mov al,PMINIT_INIT_IDT
	@strout <"calling debugger pm proc,ax=%X,es:edi=%X:%lX",lf>,ax,es,edi
	call fword ptr [dbgpminit]
	mov ax,DS_DebLoaded
	@strout <"int 41h call,ax=%X",lf>,ax
	int Debug_Serv_Int
	@strout <"int 41h ret,ax=%X (is F386?)",lf>,ax	;should return F386 in AX
	mov ax,0f001h
	int Debug_Serv_Int
	popad
done:
	ret
initdebugger_pm endp

endif        

_ITEXT32 ends

	@ResetTrace

;*** very first host initialization
;*** there is no client at this stage
;*** real-mode initialization
;*** page mgr initialized in real and protected-mode
;*** out: al=error/return code
;--- C = error?
;*** be aware: SS != GROUP16 here
;--- ES and all 32bit general purpose registers will be modified

_ret2:
	mov al,EXIT_NO_DOS4
_ret:
	ret

_initsvr_rm proc near

	assume ds:GROUP16

	@stroutrm <"initsvr_rm: enter, ds=%X, es=%X, ss:sp=%X:%X",lf>, ds, es, ss, sp
	mov ah,30h
	int 21h
if ?SUPPDOS33
	xchg al,ah
	cmp ax,031Eh		;dos 3.3?
	jb _ret2
	cmp ah,4
	jnc @F
externdef wDPBSize:word
	mov [wDPBSize],32
@@:
else
	cmp al,4			;dos 4+?
	jb _ret2
endif
	call getcpu 		;get cpu type
	mov ax,1687h		;get dpmi entry point (ES:DI)
	int 2fh
	and ax,ax
	jnz nodpmi
	or fHost,FH_DPMI
if ?CALLPREVHOST
	mov word ptr [dwHost16+0],di
	mov word ptr [dwHost16+2],es
endif
	mov di,offset logo	;test if HDPMI is already loaded
	mov si,di
	mov cx,llogo
	repz cmpsb
	jnz nohdpmi
	or fHost,FH_HDPMI
	assume es:GROUP16
	@stroutrm <"initsvr_rm: instance of HDPMI found, inst=%X, flags=%X",lf>,es, es:[wEnvFlags]
	cmpsb				;is it the same mode (16/32)?
	jnz @F
	mov al, EXIT_DPMIHOST_RUNNING
	jmp initsvr_ex		;then it can be used
	assume es:nothing
@@:
	@stroutrm <"but mode is different",lf>
	and fHost,not FH_DPMI	;make previous instance invisible
nohdpmi:
nodpmi:
	mov ax,4300h		;check for XMS host
	int 2fh
	test al,80h
	jz @F
	mov ax,4310h
	int 2fh
	mov word ptr [xmsaddr+0],bx
	mov word ptr [xmsaddr+2],es
	or [fHost], FH_XMS
	test bEnvFlags, ENVF_NOXMS30
	jnz @F
	mov ah,00
	call [xmsaddr]
	cmp ah,3			;XMS host is 3+?
	jb @F
	or [fHost],FH_XMS30
	or [fXMSAlloc],80h
	or [fXMSQuery],80h
@@:
	mov ax,3567h		;get int 67h vector
	int 21h
	mov ax,es
	or ax,bx
	jz vcpidone

if 1;this code avoids a message in a win9x dos box
	;caused by the following VCPI query
	mov ax,1600h
	int 2fh
	cmp al,00
	jnz vcpidone
endif
	mov ax,0DE00h		;check for VCPI host
	int 67h
	cmp ah,00
	jnz vcpidone
	or [fHost], FH_VCPI
if ?VCPIPICTEST
	mov ax,0DE0Ah		;get VCPI PIC mapping
	int 67h
	and ah,ah
	jnz picok
	cmp bx,?MPICBASE
	jnz invalidvcpihost
	cmp cx,?SPICBASE
	jnz invalidvcpihost
picok:
endif
ife ?CR0COPY
	mov ax,0DE07h		;get CR0
	int 67h
	mov eax, ebx
endif
	xor dx,dx
	mov ax,5A00h		;alloc a EMS handle to ensure
	mov bx,0			;the EMM does not uninstall and remains ON
	int 67h
	mov wEMShandle,dx
	jmp initdpmi_1

;--- no VCPI host found

vcpidone:

	test fHost,FH_DPMI	;if DPMI server found
	jz @F
	mov al,EXIT_DPMIHOST_RUNNING	;exit (nothing to do)
	jmp initsvr_ex
@@: 						;neither VCPI nor DPMI found
	smsw ax				;cpu must be in real-mode
if ?SAVEMSW
	mov wMSW, ax
endif
	test al,1
	jnz nopmhost		;else we cannot run
ife ?CR0COPY
	mov eax, cr0
initdpmi_1:
	and al,bFPUAnd
	or al,bFPUOr
	or eax, CR0_PE or CR0_PG
	mov dwCR0, eax
else
initdpmi_1:
endif
	call _enablea20
	and ax,ax
	jz a20err
if ?ALLOCRMS
	@DosFMalloc <?RMSTKSIZE/10h>;alloc real mode stack
	jc nodosmem
	mov rmSS,ax
endif

;--- settlb_rm may allocate a permanent TLB. it should be called before
;--- pm_initserver_rm, which temporarily allocates DOS mem for pagemgr.

	@stroutrm <"initsvr_rm: call settlb_rm",lf>
if ?USEUMBS
	mov ax,5800h		;get alloc strat
	int 21h
	movzx si,al
	mov ax,5802h		;get umb link status
	int 21h
	movzx di,al
	mov bx,0001h		;link umbs
	mov ax,5803h		;set umb link status
	int 21h
	mov bx,0081h		;+ search first in UMBs
	mov ax,5801h		;select fit best strategie
	int 21h
endif
	call settlb_rm		;set translation buffer
if ?USEUMBS
	pushf
	mov bx,di			;restore umb link status
	mov ax,5803h
	int 21h
	mov bx,si			;restore alloc strategy
	mov ax,5801h
	int 21h
	popf
endif
	jc nodosmem

if ?DELAYLOAD

;--- the protected mode code still is not loaded. load it now *after*
;--- the permanent TLB has been allocated

	mov bx,LOWWORD(offset endof32bit)
	shr bx,4
	mov ah,48h
	int 21h
	jc nodosmem
	mov wHostSeg32, ax
	call load32bit
	jc nodosmem
endif
	cmp _cpu,4
	jb @F
	mov es,wHostSeg32
	assume es:GROUP32
	mov word ptr es:[intr09], PATCHVALUE2
	assume es:nothing
@@:
	call handleenvflags		;may modify GROUP32 content

	call filldesc			;set descriptors for pagemgr init

if ?386SWAT
	call initdebugger1_rm
endif

	@stroutrm <"initsvr_rm: call pm_initserver_rm",lf>
	call pm_initserver_rm	;page manager init rm (before hookIVTvecs)
	jc nodosmem

if ?WATCHDOG
	mov ax,0C300h			;disable watchdog timer
	int 15h
endif
if ?DTAINHOSTPSP
	mov ax, wHostPSP
	movzx eax,ax
	add ax,8
	shl eax, 4
	mov dwHostDTA, eax
endif

	@stroutrm <"initsvr_rm: set rm vectors",lf>
	call hookIVTvecs

if ?386SWAT
	call initdebugger2_rm
endif
if ?WDEB386
	call initdebugger_rm	;modifies ax,bx,cx,dx!
endif

;--- now do call protected-mode the first time
;--- to initialize paging

	cli
	push ds
	push fs
	push gs
if ?SINGLESETCR3
	mov eax,v86topm._cr3
	mov cr3,eax
endif

;--- make sure we have a valid real-mode stack

	mov tskstate.rmSP,sp
	mov tskstate.rmSS,ss

	@rawjmp_pm _initsvr_pm
_initsvr_rm endp

_ITEXT32 segment

	@ResetTrace

_initsvr_pm proc
	push ss
	pop ds

	assume ds:GROUP16

	push byte ptr _FLATSEL_
	pop es
	xor eax,eax				;make sure all seg regs are valid
	mov fs,eax
	mov gs,eax
	@strout <"initsvr_pm: ...",lf>
if ?WDEB386
	call initdebugger_pm
endif
	@strout <"initsvr_pm: call pm_initserver",lf>
	call pm_createvm			;preserves all registers
	jc pmfirst_done
if ?MOVEHIGH
	@strout <"initsvr_pm: call pm_CloneGroup32",lf>
	xor eax, eax
	call pm_CloneGroup32
	mov taskseg._Ebp, eax
	jc initsvr_pm_failed
endif
	@strout <"initsvr_pm: call _movehigh",lf>
	call _movehigh_pm		;allocates+inits CD30s + IDT
	jc initsvr_pm_failed

if ?HSINEXTMEM
	@strout <"initsvr_pm: alloc memory for host stack",lf>
	mov ecx,1
	call _AllocSysPages		;alloc ECX pages
	jc initsvr_pm_failed
	add eax, 1000h
	sub eax, [dwHostBase]
	@strout <"initsvr_pm: new host stack bottom %lX",lf>, eax
 if ?FIXTSSESP
	mov [dwHostStack], eax
 else
	mov taskseg._Esp0, eax
	sub eax, sizeof R3FAULT32
	mov [dwHostStackExc], eax
 endif
endif

if ?MOVEHIGH
	mov eax, taskseg._Ebp
	@strout <"initsvr_pm: adjust GDT descriptors, new base=%lX",lf>, eax
	mov edx, pdGDT.dwBase
	push es
	pop ds
	shld ebx,eax,16
	shl eax,16
	mov ax, LOWWORD(offset endoftext32)-1
	mov dword ptr [edx+_CSSEL_].DESCRPTR.limit,eax
	mov [edx+_CSSEL_].DESCRPTR.A1623,bl
	mov [edx+_CSSEL_].DESCRPTR.A2431,bh
	mov dword ptr [edx+_CSALIAS_].DESCRPTR.limit,eax
	mov [edx+_CSALIAS_].DESCRPTR.A1623,bl
	mov [edx+_CSALIAS_].DESCRPTR.A2431,bh
	mov ecx,_CSR3SEL_
	and ecx,not 7
	mov dword ptr [edx+ecx].DESCRPTR.limit,eax
	mov [edx+ecx].DESCRPTR.A1623,bl
	mov [edx+ecx].DESCRPTR.A2431,bh
;	mov dword ptr [edx+(_DSR3SEL_ and 0F8h)].DESCRPTR.limit,eax
;	mov [edx+(_DSR3SEL_ and 0F8h)].DESCRPTR.A1623,bl
;	mov [edx+(_DSR3SEL_ and 0F8h)].DESCRPTR.A2431,bh
;	@strout <"initsvr_pm: copy done",lf>
endif

	jmp initsvr_pm_done
initsvr_pm_failed2:
initsvr_pm_failed:
	call pm_exitserver_pm
	stc
initsvr_pm_done:
pmfirst_done:
	@rawjmp_rm _initsvr_rm2		;raw jump rm, no stack switch
_initsvr_pm endp

_ITEXT32 ends

	@ResetTrace

_initsvr_rm2 proc
	lss sp,cs:tskstate.rmSSSP
	pop gs
	pop fs
	pop ds
	sti
	pushf
	call pm_initserver2_rm
	popf
	jc nodosmem3

	mov tskstate.rmSS, cs		;make sure the old value is not
	mov tskstate.rmSS, ?RMSTKSIZE	;used on next initial switch to pm

	@stroutrm <"initsvr_rm: back in real mode, ss:sp=%X:%X",lf>,ss,sp
	mov al,EXIT_HDPMI_IN_VCPIMODE
	test byte ptr [fHost], FH_VCPI
	jnz initsvr_ex
	dec al
	test byte ptr [fHost], FH_XMS
	jnz initsvr_ex
	dec al
initsvr_ex::
	@stroutrm <"initsvr_rm: exits with ax=%X",lf>,ax
	ret
nodosmem3::
	@stroutrm <"initsvr_rm: calling pm_exitserver_rm ds=%X, ss:sp=%X:%X",lf>, ds, ss, sp
	call pm_exitserver_rm
	@stroutrm <"initsvr_rm: calling unhookIVTvecs ds=%X, ss:sp=%X:%X",lf>, ds, ss, sp
	call unhookIVTvecs
nodosmem::						;no (DOS) memory
	@stroutrm <"initsvr_rm: memory error ds=%X, ss:sp=%X:%X",lf>, ds, ss, sp
	call _disablea20
	mov dx,[wEMShandle]
	and dx,dx
	jz @F
	mov ah,45h
	int 67h
@@:
	mov al,EXIT_OUT_OF_DOSMEMORY
	jmp initsvr_ex
a20err::						;A20 cannot be switched
	mov al,EXIT_CANNOT_ENABLE_A20
	jmp initsvr_ex
if ?VCPIPICTEST
invalidvcpihost::				;vcpi host not compatible with hdpmi
	mov al,EXIT_INCOMPAT_VCPI_HOST
	jmp initsvr_ex
endif
nopmhost::						;neither VCPI nor DPMI, but in v86-mode
	mov al,EXIT_UNKNOWN_PM_HOST
	jmp initsvr_ex

_initsvr_rm2 endp

;*** set memory strategy, then call initsvr_rm 
;--- out (overlay): AX=server instance (=CS)
;---                BX=size in paragraphs
;--- si,di preserved

_initserver_rm proc
	assume ds:GROUP16
;	push si
;	push di
	pushad
	call _initsvr_rm		;returns with code in AL!
	mov bp,sp
	mov [bp+1Ch],ax
	popad
;	pop di
;	pop si
	cmp al,EXIT_DPMIHOST_RUNNING
	jb done
	je initerr
	push ax
	mov ah,0
	add ax,ax
	mov bx,ax
	mov dx,offset textX
	mov ah,9
	int 21h
	mov dx,[bx+texttab-4*2]
	call display_string
	pop ax
initerr:
	stc
	ret
done:
	clc
	ret
_initserver_rm endp


texttab label word
	dw offset text4    ;4
	dw offset text5    ;5
	dw offset text6    ;6
	dw offset text7    ;7
	dw offset text8    ;8
ife ?STUB        
	dw offset text9    ;9
endif        

if ?32BIT
HDPMI textequ <"HDPMI32">
else
HDPMI textequ <"HDPMI16">
endif

textX   db HDPMI,": $"
szHDPMIx db HDPMI,"$"
text4	db "insufficient memory",0
text5	db "A20 gate cannot be enabled",0
text6	db "VCPI host has remapped PICs",0
text7	db "CPU is in V86 mode, but no VCPI/DPMI host detected",0
if ?SUPPDOS33
text8	db "DOS v3.3+ needed",0
else
text8	db "DOS v4+ needed",0
endif
if ?RESIDENT
ife ?STUB
text9	db "CPU is not 80386 or better",0
error1	db "% not installed or disabled",0 	   
error5	db "% already installed",0
error2	db "% is busy",0
error3	db "% uninstalled",0
error6	db "% now resident",0
error7	db "% *not* uninstalled because real-mode interrupts were modified",0
;error8	db "not enough memory",0
if ?SUPPDISABLE
error9	db "% disabled",0
error10 db "no disabled instance of % found",0
error11 db "% enabled again",0
endif
endif
endif
if ?DELAYLOAD
text41  db "%.EXE open error",0
text42  db "%.EXE read error",0
endif
ife ?STUB
error4	db "% v",?VERMAJOR+'0',".",@CatStr(!",%?VERMINOR/10,%?VERMINOR mod 10,!")," (c) japheth 1993-2009",cr,lf
?OPTIONS textequ <" [ -options ]">
		db "usage: %",?OPTIONS,lf
 if ?VM
		db "  -a: run clients in separate address contexts [32]",lf
 endif
if ?RESIDENT
 if ?TLBLATE
		db "  -b: keep TLB only while a client is running",lf
 endif
 if ?SUPPDISABLE
		db "  -d: disable a running instance of %",lf
		db "  -e: reenable a disabled instance of %",lf
 endif
endif
if ?NOINVLPG
		db "  -g: don't use INVLPG opcode",lf
endif
		db "  -i: hide host's IVT hooks for IRQ 0-15 [1]",lf
if ?FORCETEXTMODE
		db "  -k: ensure a text mode is set for host's displays",lf
endif
		db "  -l: allocate TLB in low DOS memory [8]",lf
		db "  -m: disable DPMI 1.0 memory functions [1024]",lf
if ?MEMBUFF
		db "  -n: report a smaller amount of free physical pages",lf
endif
if ?LOADHIGH
		db "  -p: move resident part of % to upper memory",lf
endif
if ?RESIDENT
		db "  -r: install as TSR permanently. Without this option %",lf
		db "      remains installed until the next client terminates.",lf
endif
		db "  -s: 'safe' mode. Prohibits client to modify system tables [4096]",lf
if ?CR0_NE
		db "  -t: don't touch CR0 NE bit [32768]",lf
endif
if ?RESIDENT
		db "  -u: uninstall a running instance of %",lf
endif
if ?VCPIPREF
		db "  -v: use VCPI memory if both XMS and VCPI hosts were detected",lf
endif
if ?CR0_EM
		db "  -w: don't clear CR0 EM bit",lf
endif
if ?RESTRICTMEM
		db "  -x: restrict reported free memory to 256MB",lf
endif
if ?INT15XMS
		db "  -y: use extended memory not managed by XMS host",lf
endif
		db 0
endif

if ?RESIDENT

;--- check if an instance of HDPMI is already running
;--- OUT: NC=yes, is running, AX=instance
;---      C=no

IsHDPMIRunning proc uses es si cx
	mov ax,1687h
	int 2fh
	and ax,ax
	jnz notrunning
	mov di,offset logo	 ;test if an instance is running
	mov si,di
	mov cx,llogo+1
	repz cmpsb
	mov ax,es
	jz running
notrunning:
	stc
running:
	ret
IsHDPMIRunning endp

if ?SUPPDISABLE

;--- find a disabled version of HDPMI
;--- OUT: C=not disabled or not found
;---      NC=disabled, AX=instance

IsHDPMIDisabled proc uses es
	call IsHDPMIRunning		;find a running instance of HDPMI
	jnc nothidden			;jump if a running instance found
if 0
	mov ax,5802h			;get umb link status
	int 21h
	xor ah,ah
	push ax
	mov ax,5803h			;link umbs
	mov bx,0001h
	int 21h
	mov ah,52h
	int 21h
	mov es,es:[bx-2]
	xor bx,bx
	.while (byte ptr es:[bx] != 'Z')
		mov ax,es
		inc ax
		.if (ax == es:[bx+1])	;PSP MCB?
			add ax,10h
			mov cx,cs
			.if (ax != cx)		;skip our instance!
				mov es,ax
				mov di,offset logo
				mov si,di
				mov cx,llogo+1
				repz cmpsb
				jz done
				sub ax,11h
				mov es,ax
			.endif
		.endif
		mov ax,es:[bx+3]
		mov cx,es
		add ax,cx
		inc ax
		mov es,ax
	.endw
	stc						;return "not hidden"
done:
	pop bx				;restore umb link status
	pushf
	mov ax,5803h
	int 21h
	popf
else
	push 0
	pop es
	assume es:SEG16
	cmp word ptr es:[?XRM2PM*4+0],offset intrrm2pm
	jnz nothidden
	pusha
	mov es,es:[?XRM2PM*4+2]
	assume es:nothing
	mov di,offset logo
	mov si,di
	mov cx,llogo+1
	repz cmpsb
	popa
	jnz nothidden
endif
	mov ax, es
	ret
nothidden:
	stc
	ret
endif
IsHDPMIDisabled endp
endif

disablemem10 proc
	push ds
	mov ds, wHostSeg32	;GROUP32
	assume ds:GROUP32
	mov dpmi5functions, 4	;allow int 31h, ax=0500-503 only
	pop ds
	assume ds:GROUP16
	retn
disablemem10 endp

;--- get end of resident part (paragraph) in DX

getendpara proc
if ?MOVEGDT
	mov dx, offset curGDT		;start GDTSEG		;is para aligned already
	test bEnvFlags2, ENVF2_LDTLOW
	jz @F
endif
	mov dx, offset startofidtseg
@@:
	shr dx,4
	ret
getendpara endp        

szHDPMI db "HDPMI="
lHDPMI	equ $ - offset szHDPMI

;--- inp: ES=PSP

scanforhdpmistring proc

	assume es:SEG16
	mov cx, es:[2Ch]
	assume es:nothing
	@stroutrm <"scan for HDPMI variable, psp=%X, env=%X",lf>,es,cx
	jcxz exit
	mov es, cx
	xor di, di
next:
	mov dx, di
	mov si,offset szHDPMI
	mov cx,lHDPMI
	repz cmpsb
	jz found
	mov di, dx
	mov cx, -1
	mov al,0
	repnz scasb
	cmp al, es:[di]
	jnz next
exit:
	ret
found:
	@stroutrm <"HDPMI='%s' found",lf>,es,di
	xor ax,ax
@@:
	mov cl,es:[di]
	sub cl,'0'
	jc @F
	cmp cl,9+1
	jnc @F
	mov ch,0
	mov dx,10
	mul dx
	add ax,cx
	inc di
	jmp @B
@@:
	mov wEnvFlags,ax
	ret
scanforhdpmistring endp


if ?DELAYLOAD

;--- load the 32bit GROUP32 part of the hdpmi binary
;--- it contains no relocations.

load32bit proc uses ds

;--- first get the path of the binary

	assume es:SEG16
	mov es, wHostPSP
	mov es, es:[2Ch]
	assume es:nothing
	xor di, di
	mov al,0
	or cx,-1
@@:
	repnz scasb
	cmp al,es:[di]
	jnz @B
	add di,3
	mov dx,di
	push es
	pop ds
	mov ax,3D00h
	int 21h
	jc error_1
	mov bx,ax
	mov cx,20h	;read the header
	xor dx,dx
	mov ds,cs:[wHostSeg32]
	mov ah,3Fh
	int 21h
	jc error_2

	mov dx,ds:[8]	;size of header
	shl dx,4
	add dx,offset endof16bit
	xor cx,cx
	mov ax,4200h
	int 21h
	jc error_2

	mov cx,LOWWORD(offset endof32bit)
	xor dx,dx
	mov ah,3Fh
	int 21h
error_2:
	pushf
	mov ah,3Eh
	int 21h
	popf
	jnc exit
	mov dx, offset text42
	jmp @F
error_1:
	mov dx, offset text41
@@:
	call display_string
	stc
exit:
	ret
load32bit endp

endif

;--- display string in DX
;--- keep this routine bi-modal !!!
;--- this routine should be placed at the end because
;--- it is also called when hdpmi runs with option -u.
;--- currently GROUP16 is then used as task data, which may
;--- be quite large if hdpmi has been installed with -a

display_string proc
	mov si,dx
nextchar:
	lodsb
	cmp al,'%'
	jnz @F
	mov dx,offset szHDPMIx
	mov ah,9
	int 21h
	jmp nextchar
@@:
	cmp al,10
	jnz @F
	call newline
	jmp nextchar
@@:
	and al,al
	jz @F
	mov dl,al
	mov ah,2
	int 21h
	jmp nextchar
@@:
	cmp dl,10		;if last char was newline, no extra newline
	jnz newline
	ret
newline:
	mov dl,13
	mov ah,2
	int 21h
	mov dl,10
	mov ah,2
	int 21h
	ret
display_string endp

if ?CR0_NE
disablene:
	or bFPUAnd, CR0_NE
	and bFPUOr, not CR0_NE
	ret
endif
if ?CR0_EM
disableem:
	or bFPUAnd, CR0_EM
	and bFPUOr, not CR0_EM
	ret
endif

	@ResetTrace

mystart proc
if _LTRACE_
;	int 3
endif
	@stroutrm <"hdpmi startup code, CS=%X",lf>,cs
	cld
	push cs
	pop ds
if 1
	pushf
	pushf
	pop ax
	or ah,70h			;a 80386 will have bit 15 cleared
	push ax				;if bits 12-14 are 0, it is a 80286
	popf				;or a bad emulation
	pushf
	pop ax
	popf
	and ah,0f0h
	js no386			;bit 15 set? then its a 8086/80186
	jnz is386
no386:
 ife ?STUB
	mov dx,offset text9
	call display_string
	mov ax,4C00h + EXIT_NO_80386
	int 21h
 else
	mov ax, EXIT_NO_80386
	retf
 endif
is386:
endif
ife ?STUB
;--- free unused dos mem 
	mov bx,ss
	mov cx,es
	sub bx,cx
	mov cx,sp
	shr cx,4
	add bx,cx
 ife ?STACKLAST
  ife ?DELAYLOAD
	mov cx,LOWWORD(offset endof32bit)
	shr cx, 4
	add bx,cx
  endif
 endif
	mov ah,4Ah
	int 21h
endif
	mov wHostPSP, es
if ?STUB
	mov word ptr ds:[0],"DH"
	mov byte ptr ds:[2],"P"
	or [fMode2],FM2_TLBLATE
endif
	push es
	call scanforhdpmistring	;assumes es=PSP
	pop es

	mov ax,cs
	mov v86iret.rCS, ax	;GROUP16
	mov v86iret.rSS, ax	;GROUP16
	mov wHostSeg, ax		;GROUP16
	mov wPatchDgrp1, ax	;GROUP16
	mov wPatchDgrp2, ax	;GROUP16
ife ?DELAYLOAD
	mov dx, offset endof16bit
	shr dx, 4
	add ax, dx
	mov wHostSeg32, ax
endif

ife ?STUB
	mov si,80h
	db 26h
	lodsb
	mov cl,al
nextchar:
	and cl,cl
	jz scanok
	db 26h			;es prefix
	lodsb
	dec cl
	cmp al,'-'
	jz isoption
	cmp al,'/'
	jz isoption
	cmp al,' '
	jbe nextchar
	jmp ishelp
isoption:
	and cl,cl
	jz ishelp
	db 26h
	lodsb
	dec cl
	or al,20h

?USEOPTTAB equ 0

if ?USEOPTTAB
	mov di, offset opttab
nextopt:
	cmp al,[di].OPTENTRY.bOption
	jnz @F
	movzx ax,[di].OPTENTRY.bProc
	add ax, offset opttab
	call ax
	jmp nextchar
@@:
	add di,sizeof OPTENTRY
	cmp [di].OPTENTRY.bOption,-1
	jnz nextopt
else
	push offset nextchar
if ?NOINVLPG
	cmp al,'g'
	jz noinvlpg
endif
	cmp al,'i'
	jz hideivthooks
	cmp al,'m'
	jz ismem10disable
	cmp al,'l'
	jz tlbinlowdos
if ?RESIDENT
	cmp al,'r'
	jz isresident
	cmp al,'u'
	jz isuninstall
  if ?SUPPDISABLE
	cmp al,'d'
	jz disableserver
	cmp al,'e'
	jz enableserver
  endif
  if ?TLBLATE
	cmp al,'b'
	jz tlblate
  endif
endif
if ?LOADHIGH
	cmp al,'p'
	jz loadhigh
endif
	cmp al,'s'
	jz safemode
if ?CR0_NE
	cmp al,'t'
	jz disablene
endif
if ?VM
	cmp al,'a'
	jz vmsupp
endif
if ?VCPIPREF
	cmp al,'v'
	jz vcpipref
endif
if ?CR0_EM
	cmp al,'w'
	jz disableem
endif
if ?RESTRICTMEM
	cmp al,'x'
	jz restrictmem
endif
if ?INT15XMS
	cmp al,'y'
	jz int15xms
endif
if ?MEMBUFF
	cmp al,'n'
	jz membuff
endif
if ?FORCETEXTMODE
	cmp al,'k'
	jz setforcetext
endif
endif
	jmp ishelp

if ?USEOPTTAB

OPTENTRY struct
bOption db ?
bProc   db ?
OPTENTRY ends

@OPTENTRY macro bOpt, bProc
	OPTENTRY <bOpt, offset bProc - offset opttab>
	endm

opttab  label OPTENTRY
if ?RESIDENT
	@OPTENTRY 'r', isresident
	@OPTENTRY 'u', isuninstall
  if ?SUPPDISABLE 	   
	@OPTENTRY 'd', disableserver
	@OPTENTRY 'e', enableserver
  endif
  if ?TLBLATE
	@OPTENTRY 'b', tlblate
  endif
endif
if ?VM
	@OPTENTRY 'a', vmsupp
endif
if ?NOINVLPG
	@OPTENTRY 'g', noinvlpg
endif
	@OPTENTRY 'i', hideivthooks
if ?FORCETEXTMODE        
	@OPTENTRY 'k', setforcetext
endif
	@OPTENTRY 'l', tlbinlowdos
	@OPTENTRY 'm', ismem10disable
if ?MEMBUFF
	@OPTENTRY 'n', membuff
endif
if ?LOADHIGH
	@OPTENTRY 'p', loadhigh
endif
	@OPTENTRY 's', safemode
if ?CR0_NE
	@OPTENTRY 't', disablene
endif
if ?VCPIPREF
	@OPTENTRY 'v', vcpipref
endif
if ?CR0_EM
	@OPTENTRY 'w', disableem
endif
if ?RESTRICTMEM
	@OPTENTRY 'x', restrictmem
endif
if ?INT15XMS
	@OPTENTRY 'y', int15xms
endif
	db -1
endif

ismem10disable:
	or bEnvFlags2, ENVF2_NOMEM10
	retn
if ?FORCETEXTMODE
setforcetext:
	or fMode2, FM2_FORCETEXT
	retn
endif
hideivthooks:
	or bEnvFlags, ENVF_GUARDPAGE0
	retn
if ?NOINVLPG
noinvlpg:
	or fMode2, FM2_NOINVLPG
	retn
endif
tlbinlowdos:
	or bEnvFlags, ENVF_TLBLOW
	retn
if ?VM
vmsupp:
	or bEnvFlags, ENVF_VM
	retn
endif
if ?VCPIPREF
vcpipref:
	or fMode2, FM2_VCPI
	retn
endif
if ?RESTRICTMEM
restrictmem:
	or fMode2, FM2_RESTRMEM
	retn
endif
if ?INT15XMS
int15xms:
	or fMode2, FM2_INT15XMS
	retn
endif
if ?MEMBUFF
membuff:
	or fMode2, FM2_MEMBUFF
	retn
endif
safemode:
	or bEnvFlags2, ENVF2_SYSPROT
	retn
if ?RESIDENT
isresident:
	call IsHDPMIRunning
	mov dx, offset error5
	jnc errorexit
	or fMode, FM_RESIDENT
	retn
  if ?TLBLATE
tlblate:
;;	or fMode, FM_TLBMCB
	or fMode2, FM2_TLBLATE
	retn
  endif
  if ?SUPPDISABLE
disableserver:
	call IsHDPMIRunning			;C=not running
	mov dx, offset error1
	jc errorexit
	mov es, ax					;set ES to running instance
	assume es:GROUP16
	or es:[fMode],FM_DISABLED
	mov dx, offset error9
	jmp errorexit	
enableserver:
	call IsHDPMIDisabled			;C=no disabled instance found
	mov dx, offset error10
	jc errorexit
	mov es, ax					;set ES to running instance
	assume es:GROUP16
	and es:[fMode],not FM_DISABLED
	mov dx, offset error11
	jmp errorexit
  endif
  if ?LOADHIGH
loadhigh:
;--- not implemented
	retn
  endif
isuninstall:
	call IsHDPMIRunning
	mov dx, offset error1
	jc errorexit
	mov es, ax
	assume es:GROUP16
if _LTRACE_
	movzx ax,es:[cApps]
	@stroutrm <"currently active clients %X",lf>,ax
endif
	cmp byte ptr es:[cApps],0
	mov dx,offset error2
	jnz errorexit				;instance is busy
	push ds
	push 0
	pop ds
	mov ax,es
	cmp ax,ds:[2Fh*4+2]			;get SEG(int 2f)
	pop ds
	mov dx,offset error7
	jnz errorexit
	and es:[fMode], not FM_RESIDENT
	mov ax,1687h
	int 2fh						;get PM entry
	push es
	push di
	mov bp,sp
if 0
	mov bx,si
	mov ah,48h
	int 21h
	mov dx,offset text4
	jc errorexit
	mov es,bx
else
	push ds				;just use GROUP16 for RMS here!
	pop es				;this should still work for all cases
endif
	@stroutrm <"RMS=%X",lf>,es
	assume es:nothing
	mov ax,?32BIT
	call dword ptr [bp]
;	mov dx,offset error8	;memory error (doesn't matter, HDPMI	
;	jc errorexit			;should be uninstalled nevertheless)
	mov edx,offset error3	;'HDPMI uninstalled'
	call display_string
	mov ax,4c00h				;return with rc=00
	int 21h
endif ;?RESIDENT

ishelp:
	mov dx,offset error4		;HDPMI version
errorexit:						;<--- error 
	call display_string
@@:
	mov ax,4C00h + EXIT_CMDLINE_INVALID
	int 21h
        
endif	;?STUB

scanok:
	call _initserver_rm
if ?STUB
;--- return resident size (paragraphs) in DX
	call getendpara
	mov ah,0
	retf
else
	mov ah,4Ch
	jc done
	@stroutrm <"start: _initserver_rm returned ok, ax=%X",lf>, ax

	push ax	;save exit code
	test [fMode],FM_RESIDENT
	jz @F
	mov dx,offset error6	;"HDPMI now resident"
	call display_string
@@:

;--- close all files before going resident. this is NOT redundant
;--- because HDPMI's PSP will not be closed by an int 21, ah=4Ch

	mov es,wHostPSP
	assume es:SEG16
	mov bx,word ptr es:[32h]	;size file handle table
@@:
	dec bx
	js @F
	mov ah,3Eh
	int 21h
	jmp @B
@@:
	xor cx, cx
	xchg cx, es:[2Ch]
	mov es, cx
	mov ah,49h
	int 21h

  if ?DELAYLOAD
	mov es, wHostSeg32
	mov ah,49h
	int 21h
  endif

	call getendpara
  if 0
	test fHost, FH_HDPMI	;do we own the TLB?
	jnz @F
	test fMode, FM_TLBMCB	;is TLB an extra MCB?
	jnz @F
  else
	mov ax,cs
	add ax,dx
	cmp ax, wSegTLB
	jnz @F
  endif
	add dx,?TLBSIZE/16

;--- the TLB is just behind the 16-bit code. This worked in any case
;--- before ?DELAYLOAD, but this is now the default. So just ensure 
;--- that the memory segment can be enlarged. If no, alloc a new MCB
;--- as TLB

@@:
	add dx,10h
	pop ax				;restore exit code
	mov ah,31h
done:
	int 21h
endif
mystart endp

_ITEXT16 ends

	end mystart

