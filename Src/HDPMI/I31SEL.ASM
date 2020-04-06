
;--- implements int 31h, ax=00xxh functions (LDT descriptors)

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

?CACHERMSEL = 1

_TEXT32 segment

;*** for all functions in the ah=00 group
;--- DS contains the LDT selector
;--- client DS is saved onto stack, can be accessed by [esp].I31FR1.dwDS
;--- ebx may be used, is saved in int31api.asm for this group

	@ResetTrace

	assume DS:NOTHING

alloc1sel proc
        mov     cx,1
alloc1sel endp		;fall throu
        
;--- int 31h, ax=0000 - alloc CX selectors

allocsel proc public

	pushad
	movzx ecx,cx
	mov edi,ecx
	mov ebx,0080h			;begin with offset 80h in LDT
tryagain:
	movzx edx,ss:[wLDTLimit]
	inc edx
nextsel:
	mov esi, [ebx+0]
	or esi, [ebx+4]
	jz allocsel_1
	mov ecx,edi 			;reset counter
if 0;_LTRACE_
	mov ah,[ebx+7]
	mov al,[ebx+4]
	shl eax, 16
	mov ax,[ebx+2]
	@strout <"#allocsel: selector %X skipped, not free: (%lX %X %X)",lf>,bx, eax, <word ptr [ebx+0]>, <word ptr [ebx+5]>
endif
allocsel3:
	add ebx,8
	cmp ebx,edx
	jnz nextsel

;--- before the LDT is increased, check if the additional descriptors
;--- may fullfil the request. If no, fail!

	mov eax,edx
	neg eax
	shr ax, 3
	cmp ax,cx
	jb exit

	call EnlargeLDT			;all registers preserved!
	jnc tryagain
	@strout <"#allocsel: out of selectors (%X/%X)",lf>,bx,dx
	jmp exit

;--- free selector found

allocsel_1:
	dec ecx
	jnz allocsel3
	mov ecx,edi
@@:
	mov [ebx].DESCRPTR.attrib,92h or ?PLVL ;data descriptor einstellen
	sub ebx,8
	dec ecx
	jnz @B
	add bx,8+4+?RING
	mov [esp].PUSHADS.rAX, bx
if _LTRACE_
	mov cx,[esp].PUSHADS.rCX
	cmp cx,1
	.if ZERO?
		@strout <"#allocsel: selector %X allocated",lf>,bx
	.else
		@strout <"#allocsel: %X descriptors allocated, first is %X",lf>, cx, bx
	.endif
endif
	clc
exit:
	popad
	ret
	align 4
allocsel endp

ife ?32BIT

;--- internal function used for selector tiling
;--- alloc a selector array at a certain location in LDT
;--- inp: ebx=selector, edx=number of descriptors to allocate
;--- ebp==0 -> just check, dont allocate
;--- highwords of EBX/EDX are cleared
;--- ds=LDTSEL
;--- modifies eax, ebx, ecx, dx

	@ResetTrace

allocselx proc public
	@strout <"#allocselx: try to alloc %X descs at %X",lf>,dx,bx
	movzx eax,ss:[wLDTLimit]
	inc eax
	and bl,0F8h
	mov ecx,edx		;save edx
	shl edx,3
	add edx,ebx
	jc allocselx_err1	;overflow, alloc won't succeed!
	cmp eax,edx
	jnc @F
	@strout <"#allocselx: must enlarge LDT",lf>
	call EnlargeLDT
	jc allocselx_err1	;enlarging LDT failed (out of memory?)
@@:
	mov edx,ecx		;restore edx
	push ebx
@@:
	cmp byte ptr [ebx+5],0	;is descriptor free?
	jnz allocselx_err		;no -> error
	add ebx,8
	dec ecx
	jnz @B
	pop ebx
	and ebp,ebp
	jz done
	mov ecx,edx
@@:
	mov byte ptr [ebx+5],92h or ?PLVL ;init as DATA descriptor
	add ebx,8
	dec ecx
	jnz @B
done:
	@strout <"#allocselx: ok",lf>
	clc
	ret
allocselx_err:
	pop ebx
allocselx_err1:
	@strout <"#allocselx: error",lf>
	stc
	ret
	align 4
allocselx endp

;*** free ECX selectors beginning with EBX
;--- called by selector_free and selector_resize

freeselx proc public

	push ds
	mov ds,ss:[selLDT]
@@:
	call freesel1		;here client ds is unknown
	jc @F				;stop if there is a "hole"
	add ebx,8
	or bl,4
	loopd @B
@@:
	pop ecx
	lar eax,ecx
	jz @F
	xor ecx,ecx
@@:
	mov ds,ecx
	ret
	align 4
freeselx endp

endif

;*** DPMI function 0001 ***

	@ResetTrace

freesel proc public
	or bl,?RING
	cmp bx,[esp].I31FR1.wDS
	jnz @F
	mov [esp].I31FR1.dwDS,0
@@:
freesel1::
	call checksel		;will pop return addr if error
	mov dword ptr [ebx+0],0
	mov dword ptr [ebx+4],0
	or bl,4+?RING
	call resetrmsel

	push eax
	mov eax, es
	sub ax, bx
	jnz @F
	mov es, eax
@@:
	@strout <"#freesel: selector %X released, DS=%X",lf>,bx, [esp+4].I31FR1.wDS
	mov eax, fs
	sub ax, bx
	jnz @F
	mov fs, eax
@@:
	mov eax, gs
	sub ax, bx
	jnz @F
	mov gs, eax
@@:
	pop eax
	clc
	ret
	align 4
freesel endp

;*** search an entry in real-mode selector list
;--- inp: ax = selector
;--- modifies ebx

getrmentry proc uses edx
	mov ebx, offset rmsels
nextitem:
	mov edx, ebx
	mov ebx,[ebx].RMSEL.pNext
	and ebx, ebx
	jz notfound
	cmp ax,[ebx].RMSEL.sel
	jnz nextitem
	ret
notfound:
	mov ebx, edx
	stc
	ret
	align 4
getrmentry endp

;*** add an entry in real mode selector list
;--- inp: [esp+4]:selector
;---      [esp+8]:segment
;--- called by setpspsel

	@ResetTrace

SETRMFR struct
		dd ?	;ebx
		dd ?	;eax
		dd ?	;ds
		dd ?	;returnaddr
dwSel	dd ?
dwSegm	dd ?
SETRMFR	ends

setrmsel proc public uses ebx eax ds

	push ss
	pop ds
	mov eax, [esp].SETRMFR.dwSel
	call getrmentry				;check if already in there	
	jnc found					;yes, do nothing
	xor eax,eax
	call getrmentry				;get a free entry
	jnc @F						;found one
	mov eax,sizeof RMSEL		;no free entry, allocate one
	call _heapalloc
	jc error
	mov [ebx].RMSEL.pNext,eax
	mov ebx,eax
	xor eax,eax
	mov [ebx].RMSEL.pNext,eax
@@:
	mov eax, [esp].SETRMFR.dwSel
	@strout <"#setrmsel: entry %lX filled with rm selector %X (segm=%lX)",lf>, ebx, ax, [esp].SETRMFR.dwSegm
	mov [ebx].RMSEL.sel,ax
	lsl eax,eax
	mov [ebx].RMSEL.limit,ax
	mov eax, [esp].SETRMFR.dwSegm
	mov [ebx].RMSEL.segm, ax
found:
error:
	ret 8
	align 4
setrmsel endp

;*** delete selector from real mode selector list
;*** inp: selector in bx

resetrmsel proc uses ebx eax ds

	push ss
	pop ds
	mov eax,ebx
	call getrmentry
	jc exit
	@strout <"#resetrmsel: rm selector %X is now invalid",lf>,ax
	xor eax,eax
	mov [ebx].RMSEL.sel,ax
	mov [ebx].RMSEL.segm,ax
	mov [ebx].RMSEL.limit,ax
exit:
	ret
	align 4

resetrmsel endp

;*** check rm selector list, delete invalid entries
;*** called on client exit
;--- ds=GROUP16

checkrmsel proc public
	pushad
	mov ebx,offset rmsels
	jmp skipitem
nextitem:
	mov ax,[ebx].RMSEL.sel
	lsl ecx,eax
	jnz @F
	cmp cx,[ebx].RMSEL.limit
	jz skipitem
@@:
	xor eax,eax
	mov [ebx].RMSEL.sel,ax
	mov [ebx].RMSEL.limit,ax
	mov [ebx].RMSEL.segm,ax
skipitem:
	mov ebx,[ebx].RMSEL.pNext
	and ebx,ebx
	jnz nextitem
	popad
	ret
	align 4
checkrmsel endp

;*** allocate a selector for conventional memory (dos rm sel)
;*** scan a list of already created selectors to avoid duplicate entries
;*** inp: segment in BX, min limit in AX
;*** out: selector in AX
;--- C set if function failed

;*** also called by dosapi for allocating PSP selectors
;--- and on real-mode callbacks to get a selector for real-mode ss

	@ResetTrace

allocxsel proc public uses ds

	pushad
	push ss
	pop ds
	assume ds:GROUP16
	@strout <"#allocxsel: alloc real mode sel, seg=%X, minlim=%X, rmsels=%lX",lf>,bx,ax,rmsels
	mov esi,offset rmsels
nextitem:
	mov edx, esi
	mov esi,[esi].RMSEL.pNext
	and esi, esi
	jz notfound
	cmp bx,[esi].RMSEL.segm
	jnz nextitem
	cmp ax,[esi].RMSEL.limit
	ja nextitem
	jmp found
notfound:
	mov esi, edx
	push ebx
	xor eax,eax
	call getrmentry			;get a free entry (in EBX)!
	mov esi, ebx
	pop ebx
	jnc @F
	mov eax,sizeof RMSEL
	call _heapalloc
	jc error
	@strout <"#new entry %lX for rm sel allocated",lf>,eax
	mov [esi].RMSEL.pNext,eax
	mov esi,eax
	xor eax,eax
	mov [esi].RMSEL.pNext,eax
@@:
	mov ds,ss:[selLDT]
	call alloc1sel			;alloc new selector
	jc error
	@strout <"#new selector %X for rm sel allocated",lf>,ax
	movzx ebx,ax
	mov dx,ax
	and bl,0F8h
	mov cx, [esp].PUSHADS.rAX
	movzx eax, [esp].PUSHADS.rBX
	mov di,ax
	mov [ebx].DESCRPTR.limit,cx
	shl eax,4
	mov [ebx].DESCRPTR.A0015,ax
	shr eax,16
	mov [ebx].DESCRPTR.A1623,al
	push ss
	pop ds
	mov [esi].RMSEL.sel,dx
	mov [esi].RMSEL.limit,cx
	mov [esi].RMSEL.segm,di
found:
	mov ax,[esi].RMSEL.sel
	mov word ptr [esp].PUSHADS.rEAX,ax
	clc
error:
	popad
	ret
	align 4
	assume ds:nothing
allocxsel endp

	@ResetTrace

;*** DPMI function 0002 (alloc real mode sel)

allocrmsel proc public
	mov ax,-1
	call allocxsel
	jc @F
	ret
@@:
	mov ax,0002		;restore value of AX
;	mov ax,8011h	;set DPMI v1.0 error code
	ret
	align 4
allocrmsel endp

;*** function 0003 ***

getincvalue proc public
	mov ax,0008h
	ret
	align 4
getincvalue endp

;*** function 0005 ***

unlocksel proc public
unlocksel endp	;fall through

;*** function 0004 ***

locksel proc public
	clc
	ret
	align 4
locksel endp


checksel proc
	test bl,4
	jz error
	cmp bx,ss:[wLDTLimit]
	ja error
	and bl,0F8h
	movzx ebx,bx
	cmp byte ptr [ebx+5],0
	jz error
	clc
	ret
error:
	add esp,4
	stc
	ret
	align 4
checksel endp

;*** function 0006 ***

getbase proc public
	call checksel
	mov dx,[ebx].DESCRPTR.A0015
	mov cl,[ebx].DESCRPTR.A1623
	mov ch,[ebx].DESCRPTR.A2431
	ret
	align 4
getbase endp
        
;--- function 0007

setbase proc public
	call checksel
	mov [ebx].DESCRPTR.A0015,dx
	mov [ebx].DESCRPTR.A1623,cl
	mov [ebx].DESCRPTR.A2431,ch
_reloadexit::
	push es
	pop es
	push fs
	pop fs
	push gs
	pop gs
	ret
	align 4
setbase endp

;--- function 0008, set limit of BX in CX:DX

setlimit proc public
	call checksel
	and byte ptr [ebx].DESCRPTR.lim_gr,070h
	test cx,0FFF0h		  ;> 1 MB?
	jnz setlim2
	mov [ebx].DESCRPTR.limit,dx
	or [ebx].DESCRPTR.lim_gr,cl
	jmp _reloadexit
setlim2:
;--- bits 0-11 of dx must be 1 for big segments
	pushad
	mov eax,edx
	and ah,0Fh
	cmp ax,0fffh
	stc
	jnz @F
	shr edx,12		;skip the lowest 12 bits
	mov eax,ecx
	shl ecx,4
	or edx,ecx
	mov [ebx].DESCRPTR.limit,dx
	shr ax,12
	or al,80h
	or [ebx].DESCRPTR.lim_gr,al
@@:
	popad
	jnc _reloadexit
carryexit::
	stc
	ret
	align 4
setlimit endp

;--- int 31h, function 0009
;--- set descriptior access rights
;--- bx=selector, cx=new access rights

setaccrights proc public
	call checksel
	test byte ptr [ebx].DESCRPTR.attrib,10h ;memory segment?
	jz @F
	push ecx
	and cl,?PLVL+10h
	cmp cl,?PLVL+10h
	pop ecx
	jnz carryexit
@@:
	mov [ebx].DESCRPTR.attrib,cl
	and ch,070h
	and byte ptr [ebx].DESCRPTR.lim_gr,08Fh
	or [ebx].DESCRPTR.lim_gr,ch
	jmp _reloadexit
	align 4
setaccrights endp

;*** function 000D alloc specific LDT descriptor bx
;--- there is no return value
;--- put this function here so carryexit can be reached by a short jump

allocspecific proc public
	test bl,4
	jz carryexit
if 0
	test bx,0FF80h			;just handle selectors 0004-007C!
	jnz carryexit
endif
	and bl,0F8h
	movzx ebx, bx
	cmp byte ptr [ebx+5],0	;is it free?
	jnz carryexit
	mov byte ptr [ebx+5],92h or ?PLVL ;set data descriptor
	or bl,4+?RING
	ret
	align 4
allocspecific endp

;--- int 31h, ax=000A - get cs alias of selector in BX
;--- BX should contain a code selector, but this isn't checked
;--- (isn't checked by other popular DPMI hosts as well)
;--- might also cause troubles if the Expand Down or Conforming
;--- flags are set.

getcsalias proc public
	call checksel
	pushad
	call alloc1sel
	jc @F
	mov [esp].PUSHADS.rAX,ax
	and al,0F8h
	movzx esi,ax
	mov eax,[ebx+0]
	mov [esi+0],eax
	mov eax,[ebx+4]
	and ah,0F7h			;reset the CODE bit
	mov [esi+4],eax
@@:
	popad
	ret
	align 4
getcsalias endp

;--- int 31h, ax=000B - get descriptor

getdesc proc public
	call checksel
	push eax
if ?32BIT
	mov eax,[ebx+0]
	mov es:[edi+0],eax
	mov eax,[ebx+4]
	mov es:[edi+4],eax
else
	mov eax,[ebx+0]
	mov es:[di+0],eax
	mov eax,[ebx+4]
	mov es:[di+4],eax
endif
	pop eax
	ret
	align 4
getdesc endp

;*** function 000C - set descriptor bx ***

setdesc proc public
	call checksel
	push eax
if ?32BIT
	mov eax,es:[edi+4]
else
	mov eax,es:[di+4]
endif
	test byte ptr [ebx].DESCRPTR.attrib,10h ;memory segment?
	jz @F
	push eax
	and ah,?PLVL+10h
	cmp ah,?PLVL+10h
	pop eax
	jnz error
@@:
	mov [ebx+4],eax
if ?32BIT
	mov eax,es:[edi+0]
else
	mov eax,es:[di+0]
endif
	mov [ebx+0],eax
	pop eax
	clc
	jmp _reloadexit
error:
	pop eax
	stc
	ret
	align 4
setdesc endp

DESCITEM struct
wSel	dw ?
desc	DESCRPTR <>
DESCITEM ends

;--- int 31h, ax=000F
;--- cx=number of descriptors
;--- es:e/di = DESCITEM array

setmultdesc proc public
setmultdesc endp			;fall through

;--- int 31h, ax=000E
;--- cx=number of descriptors
;--- es:e/di = DESCITEM array

getmultdesc proc public
	pushad
	movzx ecx, cx
ife ?32BIT
	movzx edi, di
endif
	mov edx, setdesc
	cmp al,0Fh
	jz @F
	mov edx, getdesc
@@:
nextitem:
	jecxz done
	mov bx, es:[edi].DESCITEM.wSel
	inc edi
	inc edi
	call edx
	jc error
	add edi, sizeof DESCRPTR
	dec ecx
	jmp nextitem
error:
	sub [esp].PUSHADS.rCX,cx
	mov [esp].PUSHADS.rAX,8022h
	stc
done:
	popad
	ret
	align 4
getmultdesc endp

_TEXT32 ends

	end

