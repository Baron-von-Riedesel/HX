
;--- implements save/restore dpmi client state

	.386P

	include hdpmi.inc
	include external.inc

	option proc:private

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

if ?SAVELDTPTE
?X4		equ 4
else
?X4		equ 1000h
endif

?SAVELENGTH	equ 800h + ?X1 + ?X2 + ?X3 + ?X4

_TEXT32 segment

;--- out: ECX= size of client's save region
;--- out: EAX= size of vm data (?VM only)

_getsavelength proc
	mov ecx, offset GROUP16:_EndOfClientData
	mov eax, offset GROUP32:endcldata32
	sub ecx, offset GROUP16:_StartOfClientData
	sub eax, offset GROUP32:cldata32
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

;--- out: EAX=offset of saved IDT in client's save region

_getidtaddr proc public
	call _getsavelength
	mov eax, ecx
	sub eax, ?X2 + ?X4 + 800h
	ret
_getidtaddr endp

;--- out: EAX=size client data32

_getcldata32 proc public
	call _getidtaddr
	mov ecx,offset GROUP32:endcldata32
	sub ecx,offset GROUP32:cldata32
	sub eax, ecx
	ret
	align 4
_getcldata32 endp

endif

;*** a new client is starting, save current state
;*** inp: DS=GROUP16, ES=FLAT
;*** in detail:
;*** 1. CDATA segment
;*** 2. CDATA32 segment
;*** 3. taskseg._Esp0 in TSS (?X1), DR7 (?X3)
;*** 4. IDT (800h)
;*** 5. LDT (first page) (?X4)
;*** 6. IVT (optionally) (?X2)
;--- out: C = error
;--- if a client is started by cloning the host (CreateVM called),
;--- then saveclientstate isn't called at all.

	@ResetTrace

_saveclientstate proc public

	assume ds:GROUP16

	push es
	pushad

if ?SAVELDTPTE
	@strout <"#saveclientstate: calling _ClonePage for 1. LDT page",lf>
	mov edx,[dwLDTAddr]
	mov ecx,1
	call _ClonePage
	jc exit		;out of memory?
	@strout <"#saveclientstate: 1. LDT page copied, old PTE=%lX",lf>, ecx
	mov ebp, ecx
	call _SetPage
endif
	call _getsavelength
	@strout <"#saveclientstate: total size of data to save=%lX",lf>, ecx
ife ?USESYSSPACE2
	mov edx, ecx
	shr edx,12			;bytes -> pages
	inc edx
	mov cl, HDLF_COMMIT
	call _AllocMem
	jc exit2
	mov edi,[ebx].HDLELM.dwBase
else
	shr ecx,12			;bytes -> pages
	inc ecx
	call _AllocSysPagesDn	;alloc space for client state
	jc exit2
	@strout <"#saveclientstate: AllocSysPagesDn()=%lX",lf>, eax
	mov edi, eax
endif
	inc byte ptr [cApps]

if ?CR0COPY
	mov eax, cr0
	mov bCR0, al
endif
	push edi
if ?VM
	mov esi,offset _StartOfVMData
	mov ecx,offset _StartOfClientData
	sub ecx, esi
	rep movsb
endif
	mov esi,offset _StartOfClientData	;save client specific data
	mov ecx,offset _EndOfClientData
	sub ecx, esi
	@strout <"#saveclientstate, save 16bit data dst=%lX, src=%lX, size=%lX",lf>, edi, esi, ecx
	shr ecx, 2
	cld
	rep movsd
	pop dword ptr [ltaskaddr]

if ?SAVEHOSTSP
	mov eax,[taskseg._Esp0]
	stosd
endif
if ?SAVEDR7
	mov eax,dr7
	stosd
endif

	push cs
	pop ds

	mov esi,offset GROUP32:cldata32
	mov ecx,offset GROUP32:endcldata32
	sub ecx, esi
	@strout <"#saveclientstate: save 32bit data, dst=%lX, src=%lX, size=%lX",lf>,edi, esi, ecx
	shr ecx, 2
	rep movsd

	push es
	pop ds

	mov esi,ss:[pdIDT.dwBase]	   ;save IDT
	mov ecx,800h/4
	@strout <"#saveclientstate: save IDT, dst=%lX, src=%lX",lf>,edi, esi
	rep movsd

if ?SAVELDTPTE
	mov eax, ebp
	stosd
else
	mov esi,ss:[dwLDTAddr]
	mov ecx,1000h/4 			   ;save (1. page of) LDT
	@strout <"#saveclientstate: save LDT, dst=%lX, src=%lX",lf>,edi, esi
	rep movsd
endif

if ?SAVEIVT
	xor esi,esi					;save IVT
	@strout <"#saveclientstate: save IVT, dst=%lX, src=%lX",lf>,edi, esi
	mov cx,400h/4
	rep movsd
endif
	push ss
	pop ds

	@strout <"#saveclientstate exit",lf>

	clc
ife ?SAVELDTPTE
exit2:
endif
exit:
	popad
	pop es
	ret
if ?SAVELDTPTE
exit2:
	mov eax, ebp
	call _SetPage
	stc
	jmp exit
endif
	align 4
_saveclientstate endp

;*** called on _exitclient (AH=4CH)
;*** DS=GROUP16, ES=FLAT
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
	and esi,esi
	jz exit
	push esi				;save memhdl 

	push ds
	pop es					;ES=GROUP16

if _LTRACE_
	mov bx,offset intrmcbrs
	mov cx,0
@@:
	@strout <"#restoreclientstate: rmcb %X rmvec:%lX",lf>, cx, ss:[bx].INTRMCBr.rm_vec
	add bx,sizeof INTRMCBr
	inc cl
	cmp cl,SIZEINTRMCB
	jnz @B
endif

if 1
	mov eax, tskstate.rmSSSP
endif
	push byte ptr _FLATSEL_
	pop ds

	assume ds:nothing

	@strout <"#restoreclientstate, src addr=%lX",lf>,esi

if ?VM
	mov ecx,offset _StartOfClientData
	sub ecx,offset _StartOfVMData
	add esi, ecx
endif
	mov edi,offset _StartOfClientData
	mov ecx,offset _EndOfClientData
	sub ecx, edi
	@strout <"#restoreclientstate: load 16bit data, dst=%lX, src=%lX, size=%lX",lf>, edi, esi, ecx
	shr ecx, 2

	cld
	rep movsd
if 1
;--- if the last client is terminating, use its real-mode
;--- stack for host real-mode calls.
	cmp ss:[cApps],0
	jnz @F
	mov ss:tskstate.rmSSSP, eax
@@:
endif
if ?SAVEHOSTSP
	lodsd
	mov ss:[taskseg._Esp0],eax		;wHostStackExc is in client area!
endif
if ?SAVEDR7
	lodsd
	mov dr7,eax
endif

	push byte ptr _CSALIAS_
	pop es
	mov edi,offset GROUP32:cldata32
	mov ecx,offset GROUP32:endcldata32
	sub ecx, edi
	@strout <"#restoreclientstaten: load exc vectors, dst=%lX, src=%lX, size=%lX",lf>,edi, esi, ecx
	shr ecx, 2
	rep movsd

	push byte ptr _FLATSEL_
	pop es
	mov edi,ss:[pdIDT.dwBase]	;restore IDT
	@strout <"#restoreclientstate: load IDT, dst=%lX, src=%lX",lf>,edi, esi
	mov ecx,800h/4
	rep movsd

if ?SAVELDTPTE
	lodsd
	push ds
	push ss
	pop ds
	assume ds:GROUP16
	mov edx,[dwLDTAddr]
	call _SetPage
	pop ds
	assume ds:nothing
else
	mov edi,ss:[dwLDTAddr] 	;restore LDT (1. page)
	@strout <"#restoreclientstate: load LDT, dst=%lX, src=%lX",lf>,edi, esi
	mov cx,1000h/4
	rep movsd
endif

if ?SAVEIVT
	xor edi,edi				;restore IVT	
	@strout <"#restoreclientstate: load IVT, dst=%lX, src=%lX",lf>,edi, esi
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
	@strout <"#restoreclientstate: freeing client state memory %lX",lf>,di,si
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
	@strout <"#restireclientstate: free client state memory failed",lf>
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
;--- ECX = 0
;--- this may invalidate descriptors of current segment registers (FS, GS)

ResizeLDT proc near
	movzx eax,[wLDTLimit]	;FFF,1FFF,...,FFFF
	inc ax 				;ax=1000,2000,...,0000
	sub cx,ax				;ecx=F000,E000,...,0000
	shr cx,12				;ecx=0F,0E,...,00
	add eax,[dwLDTAddr]
	call _UncommitRegion	;free memory starting at eax, ecx pages
	call setldtinfos
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
	ret
	align 4
ResizeLDT endp


setldtinfos proc public
	pushad
	mov eax,[dwLDTAddr]
	mov ecx, pdGDT.dwBase
	mov dx, [wLDTLimit]
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
	mov ax,_LDTSEL_ 	   ;reload LDTR cache
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
	@strout <"#EnlargeLDT, base=%lX, old limit=%X",lf>, dwLDTAddr, wLDTLimit
	mov eax,[dwLDTAddr]
	movzx ecx,wLDTLimit
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

	@strout <"#EnlargeLDT, new limit=%X",lf>, wLDTLimit
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

