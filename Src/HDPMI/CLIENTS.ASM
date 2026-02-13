
;--- implements save/restore dpmi client state

	.386P

	include hdpmi.inc
	include external.inc

	option proc:private

externdef startcldata32:byte
ifndef ?PE
externdef endcldata32:byte
else
?SIZECLDATA32 equ 400h	;also defined in hdpmi.asm
endif

?SAVEHOSTSP equ 1	;std=1, 1=save ring 0 ESP from TSS for client
ifndef ?SAVEIVT
?SAVEIVT	equ 0	;std=0, 1=save/restore IVT
endif
?SAVEDR7	equ 1	;std=1, 1=save/restore DR7 register
?NODR7RSTIFKD equ 1	;std=?, 1=don't restore DR7 if kernel debugger detected (v3.22)

SIZEINTRMCB	equ 19	;must match value in hdpmi.asm!

if ?SAVEHOSTSP
?X1		equ 4
else
?X1		equ 0
endif

if ?SAVEIVT
?X2		equ 400h
else
?X2		equ 0h
endif

if ?SAVEDR7
?X3		equ 4
else
?X3		equ 0
endif

?SAVELENGTH	equ 800h + ?X1 + ?X2 + ?X3

_TEXT32 segment

;--- out: ECX= size of client's save region
;--- out: EAX= size of vm data (?VM only)

	assume ds:GROUP16

_getsavelength proc
	mov ecx, offset GROUP16:_EndOfClientData
	sub ecx, offset GROUP16:_StartOfClientData
ifndef ?PE
	mov eax, offset endcldata32
	sub eax, offset startcldata32
	add ecx, eax
else
	add ecx, ?SIZECLDATA32
endif
	movzx eax, wLDTLimit
	inc eax
	shr eax, 6	;1000h -> 40h
	add ecx, eax
if ?VM
	mov eax, offset GROUP16:_StartOfClientData
	sub eax, offset GROUP16:_StartOfVMData
	add ecx, eax
endif
	add ecx, ?SAVELENGTH
	ret
	align 4
_getsavelength endp

if ?VM

;--- out: EAX=offset of IDT in a client save region

_getidtofs proc public
	call _getcldata32
ifndef ?PE
	mov ecx, offset endcldata32
	sub ecx, offset startcldata32
	add eax, ecx
else
	add eax, ?SIZECLDATA32
endif
	ret
	align 4
_getidtofs endp

;--- out: EAX=offset cldata32 in a client save region

_getcldata32 proc public
	mov eax, offset GROUP16:_EndOfClientData + ?X1 + ?X3
	sub eax, offset GROUP16:_StartOfVMData
	ret
	align 4
_getcldata32 endp

endif

;*** a new client is starting, save current state
;*** inp: DS=GROUP16, ES=FLAT
;*** in detail:
;*** 1a. VMData (_DATA16V segment)
;*** 1b. ClientData (_DATA16C segment)
;*** 2a. taskseg._Esp0 (=dwHostStack) in TSS (?X1)
;--- 2b. DR7 (?X3)
;*** 3.  clientdata in _DATA32C segment
;*** 4.  IDT (800h)
;*** 5.  LDT (last used page) (?X4)
;*** 6.  IVT (optionally) (?X2)
;--- out: C = error ( out of phys mem, addr space )
;--- saveclientstate is called whenever a client starts, even the first one.
;--- the exception is when a clone is started ( HDPMI=32, option -a )
;--- then CreateVM is called instead of saveclientstate.

;--- in the binary, GROUP16 starts with
;--- + BEGDATA16
;--- + _DATA16
;--- + _DATA16V
;--- + _DATA16C

	@ResetTrace

_saveclientstate proc public

	assume ds:GROUP16

	push es
	pushad

	call _getsavelength
	@dprintf "saveclientstate: total size of data to save=%lX", ecx
ife ?USESYSSPACE2
;v3.19: use allocmem, _AllocMemEx no longer public
	shld ebx,ecx,16
	call allocmem
	jc exit2
	push bx
	push cx
	pop edi
else
	shr ecx,12			;bytes -> pages
	inc ecx
	call pm_AllocSysPagesDn	;alloc space for client state
	jc exit2
	@dprintf "saveclientstate: AllocSysPagesDn()=%lX", eax
	mov edi, eax
endif
	inc byte ptr [gbl.cApps]

if ?CR0COPY
	mov eax, cr0
	mov bCR0, al
endif
	push edi
	cld
if ?VM
	mov esi, offset _StartOfVMData
	mov ecx, offset _StartOfClientData
	sub ecx, esi
	rep movsb
endif
	mov esi, offset _StartOfClientData	;save client specific data
	mov ecx, offset _EndOfClientData
	sub ecx, esi
	@dprintf "saveclientstate, save 16bit data dst=%lX, src=%lX, size=%lX", edi, esi, ecx
	shr ecx, 2
	rep movsd
	pop dword ptr [ltaskaddr]

if ?SAVEHOSTSP
	mov eax,ds:taskseg._Esp0
	stosd
endif
if ?SAVEDR7
	mov eax,dr7
	stosd
endif

	push cs
	pop ds

	mov esi, offset startcldata32
ifndef ?PE
	mov ecx, offset endcldata32
	sub ecx, esi
else
	mov ecx, ?SIZECLDATA32
endif
	@dprintf "saveclientstate: save 32bit data, dst=%lX, src=%lX, size=%lX",edi, esi, ecx
	shr ecx, 2
	rep movsd

	push es
	pop ds

	mov esi,ss:[pdIDT.dwBase]	   ;save IDT
	mov ecx,800h/4
	@dprintf "saveclientstate: save IDT, dst=%lX, src=%lX",edi, esi
	rep movsd

	mov esi,ss:[dwLDTAddr]
if 1
	call createldtbitfield
else
	mov ecx,1000h/4 			   ;save (1. page of) LDT
	@dprintf "saveclientstate: save LDT, dst=%lX, src=%lX",edi, esi
	rep movsd
endif

if ?SAVEIVT
	xor esi,esi					;save IVT
	@dprintf "saveclientstate: save IVT, dst=%lX, src=%lX",edi, esi
	mov cx,400h/4
	rep movsd
endif
	push ss
	pop ds

	@dprintf "saveclientstate exit"

	clc
exit2:
exit:
	popad
	pop es
	ret
	align 4
_saveclientstate endp

;--- in esi=linear address ldt
;--- DS,ES=FLAT

createldtbitfield proc
	movzx ebx,ss:wLDTLimit
	inc ebx
	push ebx
	mov ecx,ebx
	shr ecx,8	;example: size of ldt 1000h -> 200h descriptors -> 40h size bitfield -> 10h dwords
	push edi
	xor eax,eax
	rep stosd
	pop edi
	pop ebx
	shr ebx, 3	;no of descriptors in ebx
	xor ecx, ecx
nextitem:
	cmp ecx, ebx
	jz done
	cmp [esi+ecx*8].DESCRPTR.attrib, 0
	jz @F
	bts [edi], ecx
@@:
	inc ecx
	jmp nextitem
done:
	shr ecx, 5
	add edi, ecx
	ret
	align 4
createldtbitfield endp

;--- in edi=linear address ldt
;--- esi = descriptor bitfield
;--- DS,ES=FLAT

readldtbitfield proc
	movzx ebx,ss:wLDTLimit
	inc ebx
	shr ebx, 3
	xor ecx, ecx
nextitem:
	cmp ecx, ebx
	jz done
	bt [esi], ecx
	jc @F
	mov dword ptr [edi+ecx*8],0
	mov dword ptr [edi+ecx*8+4],0
@@:
	inc ecx
	jmp nextitem
done:
	shr ecx, 5
	add esi, ecx
	ret
	align 4
readldtbitfield endp

;*** called on _exitclient (AH=4CH)
;*** DS=GROUP16
;--- restores IDT/LDT, remove invalid entries in rmsel list.
;--- restores _DATA16C, that contains INTRMCBs
;--- no return value!
                
	@ResetTrace

_restoreclientstate proc public

	assume ds:GROUP16

	push es
	pushad

	dec byte ptr [gbl.cApps]

if ?MOU15RESET
	push cs:[mouse15_rmcb]
endif
	mov esi,[ltaskaddr]	;is last client?

	call restoreV86Hooks

	@dprintf "restoreclientstate: enter. ltaskaddr=%lX", esi
	and esi,esi
	jz exit
	push esi				;save memhdl 

	push ds
	pop es					;ES=GROUP16

if 0;_LTRACE_
	xor ebx, ebx
@@:
	@dprintf "restoreclientstate: rmcb %X rmvec:%lX", bx, ss:[ebx*4][intrmcbrs].rm_vec
	inc ebx
	cmp bx,SIZEINTRMCB
	jnz @B
endif

	push byte ptr _FLATSEL_
	pop ds

	assume ds:nothing

	@dprintf "restoreclientstate, src addr=%lX",esi

if ?VM
	mov ecx, offset _StartOfClientData
	sub ecx, offset _StartOfVMData
	add esi, ecx
endif
	mov edi, offset _StartOfClientData
	mov ecx, offset _EndOfClientData
	sub ecx, edi
	@dprintf "restoreclientstate: load 16bit data, dst=%lX, src=%lX, size=%lX", edi, esi, ecx
	shr ecx, 2

	cld
	rep movsd
if 0
;--- if the last client is terminating, use its real-mode
;--- stack for host real-mode calls.
	cmp ss:[gbl.cApps],0
	jnz @F
	mov ss:v86iret.rSP, ax
	shr eax,16
	mov ss:v86iret.rSS, ax
@@:
endif
if ?SAVEHOSTSP
	lodsd
	mov ss:taskseg._Esp0, eax
endif

;--- v3.20: if a client terminates, reenable host
;--- (so only idle host can be disabled permanently)
	and ss:[gbl.fMode], not FM_DISABLED

	@dprintf "restoreclientstate: restored taskseg._Esp0=%lX", ss:taskseg._Esp0
if ?SAVEDR7
	lodsd
 if ?NODR7RSTIFKD and ?KDSUPP
	test ss:[fDebug], FDEBUG_KDPRESENT
	jnz @F
 endif
	mov dr7,eax
@@:
endif

	push byte ptr _CSALIAS_
	pop es
	mov edi, offset startcldata32
ifndef ?PE
	mov ecx, offset endcldata32
	sub ecx, edi
else
	mov ecx, ?SIZECLDATA32
endif
	@dprintf "restoreclientstate: load exc vectors, dst=%lX, src=%lX, size=%lX",edi, esi, ecx
	shr ecx, 2
	rep movsd

	push byte ptr _FLATSEL_
	pop es
	mov edi,ss:[pdIDT.dwBase]	;restore IDT
	@dprintf "restoreclientstate: load IDT, dst=%lX, src=%lX",edi, esi
	mov ecx,800h/4
	rep movsd

	mov edi,ss:[dwLDTAddr] 	;restore LDT (1. page)
if 1
	call readldtbitfield
else
	@dprintf "restoreclientstate: load LDT, dst=%lX, src=%lX",edi, esi
	mov cx,1000h/4
	rep movsd
endif

if ?SAVEIVT
	xor edi,edi				;restore IVT	
	@dprintf "restoreclientstate: load IVT, dst=%lX, src=%lX",edi, esi
	mov cx,400h/4
	rep movsd
endif
	push ss
	pop ds
	assume ds:GROUP16

	call ResizeLDT

ife ?USESYSSPACE2
	pop di 					;get task handle
	pop si
	@dprintf "restoreclientstate: freeing client state memory %lX",di,si
	call freemem
 if _LTRACE_
	jnc @F
	@dprintf "restoreclientstate: free client state memory failed"
@@:
 endif
else
	call _getsavelength
	shr ecx, 12
	inc ecx
	pop eax
;	@dprintf "restoreclientstate: calling pm_FreeSysPagesDn( eax=%lX, ecx=%lX )", eax, ecx
	call pm_FreeSysPagesDn
	@dprintf "restoreclientstate: back from pm_FreeSysPagesDn"
endif

if ?CR0COPY
	mov eax, cr0
	mov al, bCR0
	mov cr0, eax
endif
exit:
	call checkrmsel 		;check real mode selectors

if ?MOU33RESET
	call mouse33_reset		;expects DS=GROUP16
endif

if ?MOU15RESET
	pop eax
	call mouse15_reset
endif
	popad
	pop es
	ret
	align 4
_restoreclientstate endp

;--- adjust committed memory for LDT to wLDTLimit;
;--- called by _restoreclientstate();
;--- this may invalidate descriptors of current segment registers (FS, GS)

ResizeLDT proc near
	call setldtinfos		;reloads LDTR
	xor eax, eax
	mov ecx, fs
	lar ecx, ecx			;if ZR is set, selector is ok
	jz @F
	mov fs, eax				;clear FS register
@@:
	mov ecx, gs
	lar ecx, ecx
	jz @F
	mov gs, eax				;clear GS register
@@:
	mov ecx, eax			;v3.22: ensure ecx is zero!
	movzx eax,wLDTLimit		;FFF,1FFF,...,FFFF
	inc ax 					;ax=1000,2000,...,0000
	sub cx,ax				;ecx=F000,E000,...,0000
	shr cx,12				;ecx=0F,0E,...,00
	add eax,[dwLDTAddr]
	@dprintf "ResizeLDT: calling pm_UncommitRegion( eax=%lX, ecx=%lX )", eax, ecx
	call pm_UncommitRegion	;free memory starting at eax, ecx pages
	ret
	align 4
ResizeLDT endp


setldtinfos proc
	pushad
	mov eax,[dwLDTAddr]
	mov ecx, pdGDT.dwBase
	mov dx, wLDTLimit
	push ds
	push byte ptr _FLATSEL_
	pop ds
	push byte ptr _LDTSEL_
	pop ebx
	push byte ptr _SELLDT_
	pop esi
	and esi,not 7
	mov [ecx+ebx].DESCRPTR.limit,dx
	mov [ecx+ebx].DESCRPTR.A0015,ax
	mov [ecx+esi].DESCRPTR.limit,dx
	mov [ecx+esi].DESCRPTR.A0015,ax
if ?LDTROSEL
	mov edi,_SELLDTSAFE_
	and edi,not 7
	mov [ecx+edi].DESCRPTR.limit,dx
	mov [ecx+edi].DESCRPTR.A0015,ax
endif
	shr eax,16
	mov [ecx+ebx].DESCRPTR.A1623,al
	mov [ecx+ebx].DESCRPTR.A2431,ah
	mov [ecx+esi].DESCRPTR.A1623,al
	mov [ecx+esi].DESCRPTR.A2431,ah
if ?LDTROSEL
	mov [ecx+edi].DESCRPTR.A1623,al
	mov [ecx+edi].DESCRPTR.A2431,ah
endif
	pop ds
	mov ax,_LDTSEL_		;reload LDTR cache
	lldt ax
	popad
	ret
	align 4
setldtinfos endp

;--- DS=GROUP16, ES=FLAT

EnlargeLDT proc near public

	push es
	push ds
	pushad
	push ss
	pop ds
	@dprintf "EnlargeLDT, base=%lX, old limit=%X", dwLDTAddr, wLDTLimit
	mov eax,[dwLDTAddr]
	movzx ecx, wLDTLimit
	jecxz @F
	inc cx					;use CX, not ECX here!
	stc
	jz exit				;size 64 kb?
	add eax,ecx
@@:
	mov ecx,1				;1 page
	mov dl,PTF_PRESENT or PTF_WRITEABLE
	test bEnvFlags2, ENVF2_SYSPROT
	jnz @F
	or dl,PTF_USER
@@:
	call pm_CommitRegionZeroFill
	jc exit

	cmp wLDTLimit,1
	cmc
	adc wLDTLimit,0FFFh

	@dprintf "EnlargeLDT, new limit=%X", wLDTLimit
	call setldtinfos
	clc
exit:
	popad
	pop ds
	pop es
	ret
	align 4
EnlargeLDT endp

_TEXT32 ends

end

