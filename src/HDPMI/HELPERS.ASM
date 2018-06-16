
;--- API translation helpers (mostly for int 21h translation)

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

if ?32BIT
?CHECKWRITE		equ 1	;std=?, when copying from TLB make sure dst isnt r/o
else
?CHECKWRITE		equ 1	;std=1, when copying from TLB make sure dst isnt r/o
endif

@seg _TEXT32

_TEXT32 segment

if 0

copy_far32_2_tlbxx	;copy xx bytes src FAR32   dst tlb:xx
copy_tlbxx_2_esdi	;copy xx bytes src tlb:yy  dst es:di

copy_tlbdta_2_dta	;copy xx bytes src tlbdta  dst dta
copy_dta_2_tlbdta	;copy xx bytes src dta     dst tlbdta

copy_dsdx_2_tlb 	;copy cx bytes src ds:dx   dst tlb:0,v86-ds=TLB
copy_tlb_2_dsdx 	;copy cx bytes src tlb:0   dst ds:dx
copy_esdi_2_tlb 	;copy cx bytes src es:di   dst tlb:0,v86-es=TLB
copy_tlb_2_esdi 	;copy cx bytes src tlb:0   dst es:di

copy_far32_2_flat	;copy cx bytes src FAR32   dst SEGM
copy_flat_2_far32	;copy cx bytes src SEGM    dst FAR32

copyz_far32_2_tlbxx	;copy asciiz   src FAR32   dst tlb:xx
copyz_tlbxx_2_far32	;copy asciiz   src tlb:xx  dst FAR32

copyz_dsdx_2_tlb	;copy asciiz   src ds:dx   dst tlb:0,v86-ds=TLB,dx=0
copyz_dssi_2_tlb	;copy asciiz   src ds:si   dst tlb:0,v86-ds=TLB,si=0
copyz_tlb_2_dssi	;copy asciiz   src tlb:0   dst ds:si
copy$_dsdx_2_tlb	;copy dosstr   src ds:dx   dst tlb:0

getlinaddr			;get linear address in eax from selector at [esp+4]
getpspsel			;
setpspsel			;save selector in bx,segment in dx in rm selector table

endif

_LTRACE_ = 0

;*** set real-mode DS to TLB

setdsreg2tlb proc public
	push ss:[dwSegTLB]
	pop dword ptr ss:[v86iret.rDS]
	ret
	align 4
setdsreg2tlb endp

;*** set real-mode ES to TLB

setesreg2tlb proc public
	push ss:[dwSegTLB]
	pop dword ptr ss:[v86iret.rES]
	ret
	align 4
setesreg2tlb endp

option prologue:none
option epilogue:none

;*** copy dos string from ds:e/dx to TLB (int 21h, ah=09)
;--- string size must be < sizeof TLB, or a exc 0d will occur

copy$_dsdx_2_tlb proc public
	pushad
	push es
	push byte ptr _TLBSEL_
	pop es
	cld
	xor edi, edi
if ?32BIT
	mov esi, edx
else
	movzx esi, dx
endif
@@:
	lodsb
	stosb
	cmp al,'$'
	jnz @B
	pop es
	popad
	ret
	align 4
copy$_dsdx_2_tlb endp

if ?INT21API

;*** copy xx bytes from global DTA to client DTA
;*** used by int 21, ah=4Eh + 4Fh (43 bytes)

COPYTLBDTA2DTA struct
	PUSHADS <>
	dd ?	;es
	dd ?	;ds
	dd ?	;return
wSize dw ?
	dw ?
COPYTLBDTA2DTA ends

copy_tlbdta_2_dta proc public
	push ds
	push es
	pushad
	les edi,ss:[dtaadr]
if ?DTAINHOSTPSP
	push byte ptr _FLATSEL_
	pop ds
	mov esi, ss:dwHostDTA
else
	push byte ptr _FLATSEL_
	pop ds
	mov esi, ss:dwDTA
;	push byte ptr _TLBSEL_
;	pop ds
;	mov esi,?TLBDTA
endif
	movzx ecx, [esp].COPYTLBDTA2DTA.wSize
	cld
	rep movsb
	popad
	pop es
	pop ds
	ret 4
	align 4
copy_tlbdta_2_dta endp

;*** copy xx bytes from client DTA to global DTA
;*** used by int 21 ah=4Fh

COPYDTA2TLBDTA struct
	dd ?		;es
	dd ?		;ds
	PUSHADS <>
	dd ?		;return
wSize dw ?
	dw ?
COPYDTA2TLBDTA ends

copy_dta_2_tlbdta proc public
	pushad
	push ds
	push es
if ?DTAINHOSTPSP
	push byte ptr _FLATSEL_
	pop es
	mov edi,ss:dwHostDTA
else
	push byte ptr _FLATSEL_
	pop es
	mov edi,ss:dwDTA
;	push byte ptr _TLBSEL_
;	pop es
;	mov edi,?TLBDTA
endif
	cld
	lds esi,ss:[dtaadr]
	movzx ecx,[esp].COPYDTA2TLBDTA.wSize
	rep movsb
	pop es
	pop ds
	popad
	ret 4
	align 4
copy_dta_2_tlbdta endp

endif

;*** copy asciiz from TLB:xx to xx:xx
;--- proto stdcall TLBOFFS:DWORD, dest:QWORD

COPYZTLB2XX struct
		PUSHADS <>
		dd ?	;es
		dd ?	;ds
		dd ?	;return
wSrc	dw ?
		dw ?
dfDst	df ?
		dw ?
COPYZTLB2XX ends

copyz_tlbxx_2_far32 proc public
	push ds
	push es
	pushad

	les edi,[esp].COPYZTLB2XX.dfDst
	movzx esi,[esp].COPYZTLB2XX.wSrc
	push byte ptr _TLBSEL_
	pop ds
	cld
@@:
	lodsb
	stosb
	and al,al
	jnz @B

	popad
	pop es
	pop ds
	ret 3*4
	align 4
copyz_tlbxx_2_far32 endp

;*** copy asciiz from TLB:0 to DS:E/SI

copyz_tlb_2_dssi proc public

	push ds
if ?32BIT
	push esi
else
	push word ptr 0
	push si
endif
	push 0
	call copyz_tlbxx_2_far32
	ret
	align 4
copyz_tlb_2_dssi endp

;*** copy asciiz from TLB:0 to DS:E/DX

copyz_tlb_2_dsdx proc public
	push ds
if ?32BIT
	push edx
else
	push word ptr 0
	push dx
endif
	push 0				;offset in TLB
	call copyz_tlbxx_2_far32
@@:
	ret
	align 4
copyz_tlb_2_dsdx endp

;*** - set v86-es to TLB
;*** - copy cx bytes src ES:E/DI dst TLB:0

copy_esdi_2_tlb proc public
	push es
if ?32BIT
	push edi
else
	push word ptr 0
	push di
endif
	call setesreg2tlb
	push ss:[dwSegTLB]
	call copy_far32_2_flat
	ret
	align 4
copy_esdi_2_tlb endp

;*** - set v86-ds to TLB
;*** - copy cx bytes src DS:E/DX dst TLB:0

copy_dsdx_2_tlb proc public
	push ds
if ?32BIT
	push edx
else
	push word ptr 0
	push dx
endif
	call setdsreg2tlb
	push ss:[dwSegTLB]
	call copy_far32_2_flat
	ret
	align 4
copy_dsdx_2_tlb endp

;--- copy cx bytes from FAR32 to segment

COPYXX2FL struct
	dd ?	;ds
	dd ?	;es
	PUSHADS <>
	dd ?	;return
wDest dw ?	;destination segment
	dw ?
dfSrc df ?
	dw ?
COPYXX2FL ends

copy_far32_2_flat proc public

	pushad
	push es
	push ds
	movzx edi,[esp].COPYXX2FL.wDest
	lds esi,[esp].COPYXX2FL.dfSrc
	mov ax,_FLATSEL_
	mov es,eax
	shl edi,4

	mov al,cl
	movzx ecx,cx
	shr ecx,2
	rep movsd
	mov cl,al
	and cl,3
	rep movsb
	pop ds
	pop es
	popad
	retn 3*4
	align 4

copy_far32_2_flat endp

;--- copy xx bytes from FAR32 to TLB:xx

COPYXX2TLBXX struct
		dd ?	;ds
		dd ?	;es
		PUSHADS <>
		dd ?	;return
wSize	dw ?	;bytes to copy
		dw ?
wDest	dw ?	;destination offset in TLB
		dw ?
dfSrc	df ?
		dw ?
COPYXX2TLBXX ends

copy_far32_2_tlbxx proc public

	pushad
	push es
	push ds
	mov ax,_TLBSEL_
	movzx edi,[esp].COPYXX2TLBXX.wDest
	lds esi,[esp].COPYXX2TLBXX.dfSrc
	movzx ecx,[esp].COPYXX2TLBXX.wSize
	mov es,eax

	mov al,cl
	shr ecx,2
	rep movsd
	mov cl,al
	and cl,3
	rep movsb
	pop ds
	pop es
	popad
	retn 4*4
	align 4

copy_far32_2_tlbxx endp

;*** copy cx bytes src TLB:0, dst ES:(E)DI

copy_tlb_2_esdi proc public
	push es
if ?32BIT
	push edi
else
	push word ptr 0
	push di
endif
	push ss:[dwSegTLB]
	call copy_flat_2_far32
	ret
	align 4
copy_tlb_2_esdi endp

;*** copy cx bytes src TLB:0, dst DS:(E)DX

copy_tlb_2_dsdx proc public

	push ds
if ?32BIT
	push edx
else
	push word ptr 0
	push dx
endif
	push ss:[dwSegTLB]
	call copy_flat_2_far32
	ret
	align 4
copy_tlb_2_dsdx endp

;--- copy from TLB:xx yy bytes to ES:E/DI
;--- 2 word parameters onto the stack:
;--- xx: offset in TLB
;--- yy: bytes to copy from TLB

COPYXX2ESDI struct
	PUSHADS <>
	dd ?		;ds
	dd ?		;return
wOfs dw ?
wNum dw ?
COPYXX2ESDI ends

copy_tlbxx_2_esdi proc public
	push ds
	pushad
	push byte ptr _TLBSEL_
	pop ds
	movzx ecx,[esp].COPYXX2ESDI.wNum
	movzx esi,[esp].COPYXX2ESDI.wOfs
ife ?32BIT
	movzx edi, di
endif
	rep movsb
	popad
	pop ds
	ret 4
	align 4
copy_tlbxx_2_esdi endp


;*** copy cx bytes src SEGM, dst FAR32

COPYFL2XX struct
	dd ?	;es
	dd ?	;ds
	PUSHADS <>
	dd ?	;return
wSrc dw ?	;src segment
	dw ?
dfDest df ?
	dw ?
COPYFL2XX ends

copy_flat_2_far32 proc public
	pushad
	push ds
	push es

	movzx esi, [esp].COPYFL2XX.wSrc
	shl esi,4
	les edi, [esp].COPYFL2XX.dfDest

if ?CHECKWRITE
	mov ebx, es
	and bl,0F8h
	mov ds,ss:[selLDT]
	mov dl,[bx.DESCRPTR.attrib]
	and byte ptr [bx.DESCRPTR.attrib],0F7h	;reset r/o
	push es
	pop es
endif
	mov ax,_FLATSEL_
	mov ds,eax

	mov al,cl
	movzx ecx,cx
	shr ecx,2
	rep movsd
	mov cl,al
	and cl,3
	rep movsb
if ?CHECKWRITE
	mov ds,ss:[selLDT]
	mov [bx.DESCRPTR.attrib],dl
endif
	pop es
	pop ds
	popad
	retn 3*4
	align 4

copy_flat_2_far32 endp

;*** copy asciiz, src ds:(e)dx, dst tlb:0000
;--- set v86-ds to tlb
;--- set dx=0

copyz_dsdx_2_tlb proc public
	push ds
if ?32BIT
	push edx
else
	push word ptr 0
	push dx
endif
	xor dx,dx				;dx=offset 0 (start tlb)
	push edx				;offset 0 in tlb
	call copyz_far32_2_tlbxx
	jmp setdsreg2tlb		;ds=segment tlb
	align 4
copyz_dsdx_2_tlb endp ;fall through

;*** copy asciiz, src ds:(e)si, dst tlb:0
;--- set v86-ds to tlb
;--- set si=0

copyz_dssi_2_tlb proc public
	push ds
if ?32BIT
	push esi
else
	push word ptr 0
	push si
endif
	xor si,si
	push esi				;offset 0 in tlb
	call copyz_far32_2_tlbxx
	jmp setdsreg2tlb		;ds=segment tlb
	align 4
copyz_dssi_2_tlb endp

;*** copy asciiz src FAR32 dst TLB:xxxx

COPYZXX2TLB struct
	dd ?	;es
	dd ?	;ds
	PUSHADS <>
	dd ?	;return
wOfs dw ?
	dw ?
dfSrc df ?
	dw ?
COPYZXX2TLB ends

copyz_far32_2_tlbxx proc public
	pushad
	push ds
	push es

	push byte ptr _TLBSEL_
	pop es
	lds esi,[esp].COPYZXX2TLB.dfSrc
	movzx edi,[esp].COPYZXX2TLB.wOfs
@@:
	lodsb
	stosb
	and al,al
	jnz @B

	pop es
	pop ds
	popad
	retn 3*4
	align 4
copyz_far32_2_tlbxx endp

option prologue:prologuedef
option epilogue:epiloguedef

;*** translate selector in bx to segment
;--- preserve HiWord(EBX)

bx_sel2segm proc public
	push ebx
	call sel2segm
	pop ebx
;	lea esp,[esp+2]		;adjust to dword size
	ret
	align 4
bx_sel2segm endp

;--- translate selector at [esp+4] to segment

sel2segm proc public
	push eax
	push dword ptr [esp+4+4]
	call getlinaddr
	jc getrmsegm_er
	shr eax,4
	test eax,0FFFF0000h
	jnz getrmsegm_er
	mov [esp+4+4],ax
	pop eax
	ret
getrmsegm_er:
	pop eax
	stc
	ret
	align 4
sel2segm endp

;--- translate v86-ds into selector

ds_segm2sel proc public
	push dword ptr ss:[v86iret.rDS]
	call segm2sel
	pop ds
	ret
	align 4
ds_segm2sel endp

;--- translate v86-es into selector

es_segm2sel proc public
	push dword ptr ss:[v86iret.rES]
	call segm2sel
	pop es
	ret
	align 4
es_segm2sel endp

;--- translate segment at [esp+4] into selector
;--- all registers preserved

segm2sel proc public
	push ebx
	push eax
	mov ebx,[esp+3*4]
if 0
	mov ax,0002
	@int_31
else
	mov ax,-1		;limit 0FFFFh
	call allocxsel
endif
	mov [esp+3*4],ax
	pop eax
	pop ebx
	ret
	align 4
segm2sel endp

;*** get base of selector at [esp+4] in EAX
;*** C on errors

GETLAFR struct
rEbx	dd ?
rDs		dd ?
		dd ?
wSel	dw ?
		dw ?
GETLAFR ends

getlinaddr proc public uses ds ebx
	movzx ebx,[esp].GETLAFR.wSel
	test bl,4				  ;LDT selector?
	jz error
	mov ds,ss:[selLDT]
	and bl,0F8h
	cmp byte ptr [ebx].DESCRPTR.attrib,0	;selector allocated?
	jz error
	mov ah,[ebx].DESCRPTR.A2431
	mov al,[ebx].DESCRPTR.A1623
	shl eax,16
	mov ax,[ebx].DESCRPTR.A0015
	clc
	ret 4
error:
	stc
	ret 4
	align 4
getlinaddr endp

;*** 1. descriptor ds -> scratchsel
;*** 2. ds=_SCRSEL_
;*** _SCRSEL_ is always r/w

if ?SCRATCHSEL

copyscratchsel proc public
	push ebx
	mov ebx,ds
	test bl,4
	jz copyscratchsel_er
	push eax
	movzx ebx, bx
	and bl,0F8h
	mov ds,ss:[LDTsel]
	mov eax,[ebx+0]
	push dword ptr [ebx+4]
	and ah,0F7h
	push byte ptr _FLATSEL_
	pop ds
	mov ebx, ss:pdGDT.dwBase
	mov dword ptr ds:[ebx+(_SCRSEL_ and 0F8h)+0],eax
	pop dword ptr ds:[ebx+(_SCRSEL_ and 0F8h)+4]
	push _SCRSEL_
	pop ds
	pop eax
	pop ebx
	clc
	ret
copyscratchsel_er:
	pop ebx
	stc
	ret
	align 4
copyscratchsel endp

endif

_LTRACE_ = 0

if ?32BIT

;--- alloc BIG DATA descriptor for real-mode memory
;*** BX=segment

getmyseldatabig proc public
	mov dx,4000h
	jmp getmyselx
	align 4
getmyseldatabig endp
endif

;--- alloc a DATA descriptor for real-mode memory
;--- BX=segment 

getmyseldata proc public
	mov dx,0000
getmyseldata endp	;fall through

;--- BX=segment, type in DX (code/data big/normal)

getmyselx proc public
	mov cx,0FFFFh
getmyselx endp		;fall through

;--- get a LDT descriptor for a real-mode segment
;--- in: BX=segment address, CX=limit, DX=Attr
;--- out: selector in ebx
;--- eax modified

getrmdesc proc near
	push ds
	push ecx
	mov cx,0001h
	xor eax,eax				 ;alloc selector
	@int_31
	pop ecx
	jc getrmdesc_err
	push eax
	and al,0F8h
	movzx eax,ax
	mov ds,ss:[selLDT]
	movzx ebx, bx
	shl ebx,4
	mov [eax].DESCRPTR.A0015,bx
	shr ebx,16
	mov [eax].DESCRPTR.A1623,bl
	mov [eax].DESCRPTR.limit,cx
	or word ptr [eax.DESCRPTR.attrib],dx  ;Code/Data
	pop ebx
	pop ds
	ret
getrmdesc_err:
	@strout <"no more LDT selectors",lf>
	pop		ds
	ret
	align 4
getrmdesc endp

;*** In: BX=PSP segment / Out: BX=PSP selector

_LTRACE_ = 0

getpspsel proc public
	push eax
	mov ax,00FFh
	call allocxsel
	mov bx,ax		;dont touch highword EBX (just in case)
	pop eax
	jc getpspsel_er
	@strout <"getpsp: selector %X marked as psp",lf>,bx
	ret
getpspsel_er:
	mov ax,_EAERR6_
	jmp _exitclientEx
	align 4
getpspsel endp

_LTRACE_ = 0

;*** In: BX=PSP segment, DX=Selector
;--- used by int 21h, ah=55h

setpspsel proc public

	push ebx
	push edx
	call setrmsel
	ret
	align 4
setpspsel endp

if ?DYNTLBALLOC

	@ResetTrace

;*** scan dos mcb chain for a free memory block (size ?DYNTLBSIZE)
;--- return NC + linear address in EDI
;--- or C on error

_AllocDosMemory proc public
	push ds
	push ecx
	test ss:[bEnvFlags], ENVF_NODYNTLB
	jnz notfound
	push byte ptr _FLATSEL_
	pop ds
	mov eax,ss:[dwLoL]
;	movzx edi,word ptr [eax-4]
	xor edi,edi
	movzx eax,word ptr [eax-2]
next:
	shl eax,4
	add edi,eax
	mov cl,[edi]
	cmp cl,'M'
	jz @F
	cmp cl,'Z'
	jnz notfound
@@:
	movzx eax,word ptr [edi+3]	;get size of block (paragraphs)
	inc eax
	cmp word ptr [edi+1],0
	jnz next
	cmp ax,?DYNTLBSIZE/16 + 1
	jb next
	jz suitsexact
	@strout <"found an mcb at %lX, size %X",lf>, edi, ax
	mov byte ptr [edi],'M'
	mov word ptr [edi+3],?DYNTLBSIZE/16
	mov byte ptr [edi+?DYNTLBSIZE+10h],cl
	mov word ptr [edi+?DYNTLBSIZE+10h+1],0
	sub ax,?DYNTLBSIZE/16 + 2
	mov word ptr [edi+?DYNTLBSIZE+10h+3],ax
suitsexact:
if ?SAVEPSP
	mov ecx, ss:[dwSDA]
	mov ax, [ecx+10h]	;get current PSP
else
	mov ax,GROUP16
	sub ax,10h
endif
	mov [edi+1],ax
	add edi,10h		;clears carry flag
;	clc
exit:
	pop ecx
	pop ds
	ret
notfound:
	stc
	jmp exit
	align 4
_AllocDosMemory endp

;*** free the allocated dos block
;--- register must have been saved by caller
;--- inp: SI=segment

_FreeDosMemory proc public
	push ds
	push byte ptr _FLATSEL_
	pop ds
	movzx edi,si
	shl edi,4
	mov word ptr [edi-10h+1],0
	@strout <"free dyn tlb at %X, size now %X",lf>,si,[edi-10h+3]
	pop ds
	ret
	align 4
_FreeDosMemory endp

endif

;--- helper for selectortile, used internally in helpers.asm
;--- called by:
;--- DOS functions 48h, 4Ah
;--- DPMI function 0100h, 0102h
;--- sets base, limit + access rights of a selector (array)
;--- inp: eax=start selector, esi=length, edi=base
;--- may modify all general purpose registers

selectortile2 proc
	push edi
	pop dx
	pop cx
	mov ebx,eax
	mov ax,0007
	@int_31 				 ;set base
	jc error
	and esi,esi
	jz noerr
	dec esi
	test esi,0FFF00000h	 ;block size > 1MB
	jz @F
	or si,0FFFh
@@:
	push esi
	pop dx
	pop cx
	mov ax,0008h		 ;set limit (of 1. selector)
	@int_31
	jc error
ife ?32BIT
nextsel:
	cmp esi,10000h
	jb noerr
	add ebx,8
	add edi,10000h
	sub esi,10000h
	@strout <"selectortile: base=%lX, limit=%lX",lf>, edi, esi
	push edi
	pop dx
	pop cx
	mov ax,0007h  			;set base
	@int_31
if 0
	lar ecx,ebx
	shr ecx,8
	mov ax,0009h			;set accrights
	@int_31
endif
	mov dx,-1
	cmp esi,10000h
	jnc @F
	mov edx,esi
@@:
	xor ecx,ecx
	mov ax,0008h
	@int_31
	jmp nextsel
endif
noerr:
	clc
error:
	ret
	align 4

selectortile2 endp

STILEFRAME struct
		PUSHADS <>
		dd ?
dwAddr	dd ?
dwSize	dd ?
STILEFRAME ends

	@ResetTrace

;--- selector_alloc proc near stdcall address:dword,size:dword
;*** handle selectors for alloc dos memory block
;--- out: start selector in AX

selector_alloc proc public

	pushad
	mov esi,[esp].STILEFRAME.dwSize
	mov edi,[esp].STILEFRAME.dwAddr
if ?32BIT
	mov cx,1			;just 1 selector for 32-bit clients
else
	mov ebx,esi
	mov ecx,ebx
	shr ebx,16
	jcxz @F
	inc ebx
@@:
	mov ecx,ebx
endif
	xor eax,eax			;alloc cx selector(s)
	@int_31
	jc error
	mov [esp].STILEFRAME.rAX,ax
	call selectortile2
error:
exit:
	popad
	ret 8
	align 4
selector_alloc endp

ife ?32BIT

;--- check if there are enough free selectors for a block
;--- for 16-bit only
;--- EDX=descriptor of block
;--- EBX=new size in bytes
;--- out: C on error

selector_avail proc public
	pushad
	mov eax,ebx
	xor ebp,ebp		;flag: test for sufficient free selectors
	jmp selector_resize_1
	align 4
selector_avail endp

endif

;*** handle selectors for resize memory block
;*** called by int 31h, ax=0102h and int 21h, ah=4Ah
;*** input: dx=selector
;***       eax=new size
;--- for 32-bit this proc should never fail, since
;--- just 1 selector is needed for a block of any size.
;--- for 16-bit it may fail, which is bad because the block
;--- has been increased already.

	@ResetTrace

selector_resize proc public

	@strout <"selector_resize: entry, sel=%X, new size=%lX",lf>,dx,eax
	pushad
ife ?32BIT
	xor ebp,ebp
	inc ebp				;alloc selectors
endif
selector_resize_1::
	mov esi,eax			;esi holds new size
	movzx edi,dx		;di holds base selector
ife ?32BIT
	mov ebx,edi
	lsl eax,edx
	inc eax
	@strout <"selector_resize: old size=%lX, new size=%lX",lf>, eax, esi
	add eax,10000h-1		;align old size to 64 kB
	xor ax,ax
	lea edx,[esi+10000h-1]	;align new size to 64 kB
	xor dx,dx
	cmp eax,edx
	jz selectortilex_1
	jnc smallerblock
	sub edx,eax
	shr edx,16
	shr eax,16-3
	add ebx,eax
	@strout <"selector_resize: need %X new selectors at %X",lf>,dx,bx
	push ds
	mov ds,ss:[selLDT]
	call allocselx			  ;alloc additional selectors
	pop ds
	jc error
	@strout <"selector_resize: alloc of selectors was ok",lf>
	jmp selectortilex_1
smallerblock:
	and ebp,ebp
	jz selectortilex_1
	sub eax,edx
	shr eax,16
	mov ecx,eax
	shr edx,16-3
	add ebx,edx
	@strout <"selector_resize: try to free %X selectors at %X",lf>,cx,bx
	call freeselx
	jc error
	@strout <"selector_resize: freeing of selectors was ok",lf>
selectortilex_1:
	and ebp,ebp
	jz done
endif
	mov ebx,edi
	mov ax,0006
	@int_31
	jc @F
	push cx
	push dx
	pop edi
	mov eax,ebx
	call selectortile2
done:
@@:
	popad
	ret
ife ?32BIT
error:
	@strout <"selector_resize: error, not enough free selectors",lf>
	popad
	ret
endif
	align 4
selector_resize endp

;--- handle selectors for free memory block
;--- called by int 31h, ax=0101h and int 21h, ah=49h
;--- selector in DX
;--- modifies EAX,EBX,ECX

	@ResetTrace

selector_free proc public
	mov ebx, edx
if ?32BIT
	mov ax,1
	@int_31            ;may clear DS/ES/FS/GS
else
	lsl eax,ebx
	stc
	jnz exit
	shr eax,16
	inc eax
	mov ecx,eax
	call freeselx
exit:
endif
	ret
	align 4
selector_free endp

_TEXT32 ends

end
