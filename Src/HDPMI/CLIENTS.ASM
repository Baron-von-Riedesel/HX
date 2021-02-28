
;--- implements save/restore dpmi client state

	.386P

	include hdpmi.inc
	include external.inc

	option proc:private

externdef startcldata32:near
ifndef ?PE
externdef endcldata32:near
else
endcldata32 equ <startcldata32 + 400h>
endif

?SAVEHOSTSP equ 1	;std=1, 1=save ring 0 ESP from TSS for client
ifndef ?SAVEIVT
?SAVEIVT	equ 0	;std=0, 1=save/restore IVT
endif
?SAVEDR7	equ 1	;std=1, 1=save DR7 register

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
	mov eax, offset endcldata32
	sub ecx, offset GROUP16:_StartOfClientData
	sub eax, offset startcldata32
	add ecx, eax
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
	mov ecx, offset endcldata32
	sub ecx, offset startcldata32
	add eax, ecx
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
;*** 1a. vmdata in _DATA16C segment
;*** 1b. clientdata in _DATA16C segment
;*** 2. taskseg._Esp0 in TSS (?X1), DR7 (?X3)
;*** 3. clientdata in _DATA32C segment
;*** 4. IDT (800h)
;*** 5. LDT (last used page) (?X4)
;*** 6. IVT (optionally) (?X2)
;--- out: C = error
;--- if a client is started by cloning the host (CreateVM called),
;--- then saveclientstate isn't called at all.

	@ResetTrace

_saveclientstate proc public

	assume ds:GROUP16

	push es
	pushad

	call _getsavelength
	@dprintf "saveclientstate: total size of data to save=%lX", ecx
ife ?USESYSSPACE2
	mov eax, ecx
	mov cl, HDLF_COMMIT
	call _AllocMemEx
	jc exit2
	mov edi,[ebx].MEMITEM.dwBase
else
	shr ecx,12			;bytes -> pages
	inc ecx
	call _AllocSysPagesDn	;alloc space for client state
	jc exit2
	@dprintf "saveclientstate: AllocSysPagesDn()=%lX", eax
	mov edi, eax
endif
	inc byte ptr [cApps]

if ?CR0COPY
	mov eax, cr0
	mov bCR0, al
endif
	push edi
	cld
if ?VM
	mov esi,offset _StartOfVMData
	mov ecx,offset _StartOfClientData
	sub ecx, esi
	rep movsb
endif
	mov esi,offset _StartOfClientData	;save client specific data
	mov ecx,offset _EndOfClientData
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

	mov esi,offset startcldata32
	mov ecx,offset endcldata32
	sub ecx, esi
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
;--- no return value!
                
	@ResetTrace

_restoreclientstate proc public

	assume ds:GROUP16

	push es
	pushad

	dec byte ptr [cApps]

if ?MOU15RESET
	push cs:[mouse15_rmcb]
endif
	mov esi,[ltaskaddr]	;is last client?
	@dprintf "restoreclientstate: enter. ltaskaddr=%lX", esi
	and esi,esi
	jz exit
	push esi				;save memhdl 

	push ds
	pop es					;ES=GROUP16

if 0;_LTRACE_
	mov bx,offset intrmcbrs
	mov cx,0
@@:
	@dprintf "restoreclientstate: rmcb %X rmvec:%lX", cx, ss:[bx].INTRMCBr.rm_vec
	add bx,sizeof INTRMCBr
	inc cl
	cmp cl,SIZEINTRMCB
	jnz @B
endif

if 0
	mov eax, dword ptr v86iret.rESP+2
	mov ax, v86iret.rSP
endif
	push byte ptr _FLATSEL_
	pop ds

	assume ds:nothing

	@dprintf "restoreclientstate, src addr=%lX",esi

if ?VM
	mov ecx,offset _StartOfClientData
	sub ecx,offset _StartOfVMData
	add esi, ecx
endif
	mov edi,offset _StartOfClientData
	mov ecx,offset _EndOfClientData
	sub ecx, edi
	@dprintf "restoreclientstate: load 16bit data, dst=%lX, src=%lX, size=%lX", edi, esi, ecx
	shr ecx, 2

	cld
	rep movsd
if 0
;--- if the last client is terminating, use its real-mode
;--- stack for host real-mode calls.
	cmp ss:[cApps],0
	jnz @F
	mov ss:v86iret.rSP, ax
	shr eax,16
	mov ss:v86iret.rSS, ax
@@:
endif
if ?SAVEHOSTSP
	lodsd
	mov ss:taskseg._Esp0,eax		;dwHSExcR3 is in client area!
endif
	@dprintf "restoreclientstate: restored taskseg._Esp0=%lX", ss:taskseg._Esp0
if ?SAVEDR7
	lodsd
	mov dr7,eax
endif

	push byte ptr _CSALIAS_
	pop es
	mov edi,offset startcldata32
	mov ecx,offset endcldata32
	sub ecx, edi
	@dprintf "restoreclientstaten: load exc vectors, dst=%lX, src=%lX, size=%lX",edi, esi, ecx
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
else
	call _getsavelength
	shr ecx, 12
	inc ecx
	pop eax
	call _FreeSysPagesDn
endif

if _LTRACE_
	jnc @F
	@dprintf "restireclientstate: free client state memory failed"
@@:
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

;--- adjust committed memory for LDT to wLDTLimit
;--- this may invalidate descriptors of current segment registers (FS, GS)

ResizeLDT proc near
	call setldtinfos		;reloads LDTR
	xor eax, eax
	mov ecx, fs
	lar ecx, ecx
	jz @F
	mov fs, eax
@@:
	mov ecx, gs
	lar ecx, ecx
	jz @F
	mov gs, eax
@@:
	movzx eax,wLDTLimit		;FFF,1FFF,...,FFFF
	inc ax 					;ax=1000,2000,...,0000
	sub cx,ax				;ecx=F000,E000,...,0000
	shr cx,12				;ecx=0F,0E,...,00
	add eax,[dwLDTAddr]
	call _UncommitRegion	;free memory starting at eax, ecx pages
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
	call _CommitRegionZeroFill
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

