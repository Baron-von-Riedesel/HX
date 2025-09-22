
;--- implements int 31h, ax=00xxh functions (LDT descriptors)

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

;--- item of linked list of "conv. memory" selectors (int 31h, ax=2)

RMSEL struct
pNext dd ?		;next item
segm  dw ?		;segment value
limit dw ?		;limit
sel   dw ?		;selector
RMSEL ends

_TEXT32 segment

;*** for all functions in the ah=00 group
;--- DS contains the LDT selector
;--- client DS is saved onto stack, can be accessed by [esp].I31FR1.dwDS
;--- ebx may be used, is saved in int31api.asm for this group

	@ResetTrace

	assume DS:NOTHING

alloc1sel proc
	mov cx,1
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
	@dprintf "allocsel: selector %X skipped, not free: (%lX %X %X)",bx, eax, word ptr [ebx+0], word ptr [ebx+5]
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
	@dprintf "allocsel: out of selectors (%X/%X)",bx,dx
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
		@dprintf "allocsel: selector %X allocated",bx
	.else
		@dprintf "allocsel: %X descriptors allocated, first is %X", cx, bx
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
	@dprintf "allocselx: try to alloc %X descs at %X",dx,bx
	movzx eax,ss:[wLDTLimit]
	inc eax
	and bl,0F8h
	mov ecx,edx		;save edx
	shl edx,3
	add edx,ebx
	jc allocselx_err1	;overflow, alloc won't succeed!
	cmp eax,edx
	jnc @F
	@dprintf "allocselx: must enlarge LDT"
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
	@dprintf "allocselx: ok"
	clc
	ret
allocselx_err:
	pop ebx
allocselx_err1:
	@dprintf "allocselx: error"
	stc
	ret
	align 4
allocselx endp

;*** free ECX selectors beginning with EBX
;--- called by desc_free() and desc_resize()

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
if ?NOR3SSREL
	cmp bx,[esp].I31FR1.rSS	;do NOT free current PL3 SS
	jz err
endif
	cmp bx,[esp].I31FR1.wDS
	jnz @F
	mov [esp].I31FR1.dwDS,0
@@:
freesel1::
	call checksel		; check if it's an allocated descriptor (won't return on error)
	mov dword ptr [ebx+0],0
	mov dword ptr [ebx+4],0
	or bl,4+?RING
	push eax
	mov eax, es
	sub ax, bx
	jnz @F
	mov es, eax
@@:
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
	call freermsel
;--- v3.19: debug log after segment register have been cleared - in case DOS is used for output.
	@dprintf "freesel: selector %X released, DS=%X", bx, [esp].I31FR1.wDS
	clc
	ret
if ?NOR3SSREL
err:
	stc
	ret
endif
	align 4
freesel endp

;*** search an entry in real-mode selector list
;--- inp: ax = selector
;--- out: found: NC, ebx= found RMSEL item
;---      not found: C, ebx=last item in list
;--- ds=group16
;--- modifies ebx

	assume ds:GROUP16

getrmentry proc uses edx
	mov ebx, offset pRMSel
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

;*** add an entry in conv. memory selector list
;--- inp: [esp+4]:selector
;---      [esp+8]:segment
;--- out: nothing
;--- called by setpspsel ( helpers.asm )
;--- limit is 255 then!

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
	push sizeof RMSEL			;no free entry, allocate one
	call _heapalloc
	jc error
	mov [ebx].RMSEL.pNext,eax
	mov ebx,eax
	xor eax,eax
	mov [ebx].RMSEL.pNext,eax
@@:
	mov eax, [esp].SETRMFR.dwSel
	@dprintf "setrmsel: entry %lX filled with rm selector %X (segm=%lX)", ebx, ax, [esp].SETRMFR.dwSegm
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
;--- called by freesel (ax=1)

freermsel proc uses ebx eax ds

	push ss
	pop ds
	mov eax,ebx
	call getrmentry
	jc exit
	@dprintf "freermsel: rm selector %X is now invalid",ax
	xor eax,eax
	mov [ebx].RMSEL.sel,ax
	mov [ebx].RMSEL.segm,ax
	mov [ebx].RMSEL.limit,ax
exit:
	ret
	align 4

freermsel endp

;*** check rm selector list, delete invalid entries
;*** called by _restoreclientstate()
;--- ds=GROUP16

checkrmsel proc public
	pushad
	mov ebx, pRMSel
	jmp checkitem
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
checkitem:
	and ebx,ebx
	jnz nextitem
	popad
	ret
	align 4
checkrmsel endp

	assume ds:nothing

;*** allocate a selector for conventional memory.
;*** scan the list of already created selectors to avoid duplicate entries
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
	@dprintf "allocxsel: alloc real mode sel, seg=%X, minlim=%X, pRMSel=%lX",bx,ax,pRMSel
	mov esi, offset pRMSel
nextitem:
;	mov edx, esi
	mov esi,[esi].RMSEL.pNext
	and esi, esi
	jz notfound
	cmp bx,[esi].RMSEL.segm
	jnz nextitem
	cmp ax,[esi].RMSEL.limit
	ja nextitem
	jmp found
notfound:
;	mov esi, edx
;	push ebx
	xor eax,eax
	call getrmentry			;get a free entry (in EBX)!
	mov esi, ebx
;	pop ebx
	jnc @F
	push sizeof RMSEL
	call _heapalloc
	jc error
	@dprintf "new heap entry %lX for rm sel allocated",eax
	mov [esi].RMSEL.pNext,eax
	mov esi,eax
	xor eax,eax
	mov [esi].RMSEL.pNext,eax
@@:
	mov ds,ss:[selLDT]
	call alloc1sel			;alloc new selector
	jc error
	@dprintf "new selector %X as rm sel allocated",ax
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
;--- in: BX=segment
;--- out: AX=selector

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

;*** function 0003
;--- descriptor increment

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

;--- check if selector in BX
;--- is a valid LDT selector.
;--- modifies EBX.

checksel proc
	test bl,4		; in LDT?
	jz error
	cmp bx,ss:[wLDTLimit]	; within LDT limit?
	ja error
	and bl,0F8h
	movzx ebx,bx
	cmp byte ptr [ebx+5],0	; descriptor allocated?
	jz error
	clc
	ret
error:
	add esp,4	; skip return address
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
	and byte ptr [ebx].DESCRPTR.lim_gr,070h	;reset granularity bit and limit[16-19]
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
	or al,80h		;set granularity bit
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
	@dprintf "setdescaccrights(ax=9): sel=%X accrights=%X",bx,cx
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
	and byte ptr [ebx].DESCRPTR.lim_gr,08Fh	;don't modify granularity bit!
	or [ebx].DESCRPTR.lim_gr,ch
	jmp _reloadexit
	align 4
setaccrights endp

;*** function 000D alloc specific LDT descriptor bx
;--- there is no return value
;--- put this function here so carryexit can be reached by a short jump

allocspecific proc public
	@dprintf "allocspecdesc(ax=D): sel=%X",bx
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
;--- BX "should" contain a code selector, but this isn't checked
;--- ( and, according to DPMI v1.0, was a documentation mistake )
;--- might also cause troubles if the Expand Down or Conforming
;--- flags are set.

getcsalias proc public
	@dprintf "getcsalias(ax=A): sel=%X",bx
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
	@dprintf "getdescriptor(ax=B): sel=%X",bx
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
	@dprintf "setdescriptor(ax=C): sel=%X",bx
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

	@ResetTrace

;--- get a LDT descriptor for a real-mode segment
;--- in: BX=segment address, CX=Attr (code/data, big)
;--- out: selector in ax
;--- used in client init to translate CS,DS,SS,ES to protected-mode selectors.

getrmdesc proc public
	pushad
	xor eax,eax				;alloc selector
	xor ecx,ecx
	inc ecx
	@int_31
	jc error
	mov [esp].PUSHADS.rAX, ax
	movzx ebx, bx
	shl ebx, 4
	push ebx
	pop dx
	pop cx
	mov ebx, eax
	mov ax,7
	@int_31
	xor ecx,ecx
	or edx,-1
	inc eax
	@int_31
	mov cx,[esp].PUSHADS.rCX
	or cl,92h or (?RING shl 5)
	inc eax
	@int_31
error:
	popad
	ret
	align 4
getrmdesc endp

_TEXT32 ends

	end

