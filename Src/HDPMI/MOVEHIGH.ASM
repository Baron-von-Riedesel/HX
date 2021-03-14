
;*** moves some structures in extended memory
;*** IDT, GDT, PM breaks

	.386P

	page,132

	include hdpmi.inc
	include external.inc

	option proc:private

ifndef ?PE
_DATA32C$Z segment dword ?USE32 public 'CODE'
externdef startof32bitr3:near
_DATA32C$Z ends
GROUP32 group _DATA32C$Z
endif

?USERIDT	equ 1	;std 1, 1=optionally alloc IDT in user address space
?IDTPAGE	equ 1	;std 1, 1=give IDT its own page

_TEXT32  segment

	assume ds:GROUP16

	@ResetTrace

;--- what's done?
;--- 1. alloc 1 page for PM breaks
;--- 2. set GDT descriptor for PM breaks
;--- 3. init the tab with "int 30h" opcode
;--- 4. optionally move GDT at offset 800h/400h of this same page
;--- 5. alloc 1 page for IDT
;--- 6. move IDT to this page
;--- 7. init old IDT with "STAC"; it will become the host stack,
;       unless ?HSINEXTMEM is set.

;--- inp: DS=GROUP16, ES=FLAT
;--- preserves registers

_movehigh proc public

	pushad
	cld
	@dprintf "movehigh_pm enter, bEnvFlags=%X, ltaskaddr=%lX", word ptr bEnvFlags, ltaskaddr
if ?DYNBREAKTAB
;--- alloc PM BREAK table
	mov ecx,1
	call _AllocSysPages
	jc error
	mov edi,eax
	@dprintf "movehigh_pm: setting pm breakpoint descriptor to base %lX",eax
	mov edx, pdGDT.dwBase
	mov ecx, _INTSEL_
	and cl,0F8h
	mov es:[edx+ecx].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[edx+ecx].DESCRPTR.A1623,al
	mov es:[edx+ecx].DESCRPTR.A2431,ah
ifndef ?PE
	mov cx, _CSR3SEL_
	and cl, 0F8h
	lea eax,[edi+400h]
	mov es:[edx+ecx].DESCRPTR.A0015,ax
	mov es:[edx+ecx+8].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[edx+ecx].DESCRPTR.A1623,al
	mov es:[edx+ecx].DESCRPTR.A2431,ah
	mov es:[edx+ecx+8].DESCRPTR.A1623,al
	mov es:[edx+ecx+8].DESCRPTR.A2431,ah
endif
	mov ax,30CDh
	mov ecx,_MAXCB_
	push edi
	rep stosw

ifndef ?PE
	and di,0F000h
	add di,400h
	mov esi,offset startof32bitr3
	mov ecx,offset endoftext32
	sub ecx, esi
	@dprintf "movehigh_pm: copy r3 code size=%lX, src=%lX, dst=%lX",ecx, esi, edi
	shr ecx, 2
	push ds
	push cs
	pop ds
	rep movsd
	pop ds
endif

	pop eax
ifdef ?PE
	mov ecx,1
	call _makeregionreadonly
endif
endif ;?DYNBREAKTAB

	xor edi, edi
	mov ebp,offset _AllocSysPages
	test bEnvFlags2, ENVF2_SYSPROT
	jz @F
	mov ebp,offset _AllocSysPagesX
@@:
if ?MOVEGDT
	test bEnvFlags2, ENVF2_LDTLOW
	jnz nogdtmove
	mov ecx,1
	call ebp
	jc error
	mov edi, eax
	mov esi, pdGDT.dwBase
	@dprintf "movehigh_pm: move GDT to %lX, src=%lX", edi, esi
	mov pdGDT.dwBase,edi

	lea eax, [edi+_TSSSEL_]
	sub eax, [dwSSBase]
	mov [dwTSSdesc],eax		;update TSS descriptor linear address

  if ?KDSUPP
	mov eax, edi
	lea ecx, [esi + _GDTSEL_]
	mov es:[ecx].DESCRPTR.limit,7ffh
	mov es:[ecx].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[ecx].DESCRPTR.A1623,al
	mov es:[ecx].DESCRPTR.A2431,ah
  endif
	movzx ecx, pdGDT.wLimit
	mov pdGDT.wLimit,7ffh	;set new limit for GDT
	push edi
	inc ecx
	push es
	pop ds
	rep movsb
	push ss
	pop ds
	lgdt pdGDT
	pop edi
	lea edi,[edi+800h]
nogdtmove:
endif	;?MOVEGDT

if ?MOVEIDT
  if ?USERIDT
	test bEnvFlags2, ENVF2_LDTLOW
	jz @F
   if 1 ;todo: check if allocmem() can be safely called at this stage
if 0
	mov cx,1000h
	xor ebx,ebx
	call allocmem	;alloc page for IDT
	jc @F
	push bx			;if NC, SI:DI and BX:CX are modified!
	push cx
	pop edi
endif
	xor ebx,ebx
	mov ecx,1
	call _allocaddrspaceX	;returns linear address in EAX
	jc @F
	call _CommitRegion
	jc @F
	mov edi,eax
   else
	mov eax,1		;alloc 1 page
	call pm_AllocUserSpace
	jc @F
	mov ecx,1
	call _CommitRegion	;ES set to FLAT inside this function
	jc @F
	mov edi,eax
   endif
@@:
  endif
ife ?MOVEGDT
;--- if ?MOVEGDT is off and ENVF2_LDTLOW=0, there's no page allocated yet
	and edi,edi
	jnz @F
	mov ecx,1	;in case the GDT wasn't moved
	call ebp
	jc error
	mov edi,eax
@@:
endif
	mov esi, pdIDT.dwBase
	mov pdIDT.dwBase, edi
	push es
	pop ds
  if ?VM
	test ss:fMode, FM_CLONE
	jz @F
;--- copy IDT from its location where it was saved in _saveclientstate
	call _getidtofs
	mov esi, ss:ltaskaddr
	add esi, eax
	mov ecx, 800h/4
	rep movsd
	jmp idtcopied
@@:
  endif	;?VM

;--- copy IDT from conventional to extended memory (vectors 00-77h)

;--- the predefined IDT contains just 78h entries
	mov ecx,?PREDEFIDTGATES * sizeof DESCRPTR/4
	@dprintf "movehigh_pm: copy IDT from %lX to %lX", esi, edi
	rep movsd

;--- initialize the rest of the IDT

	mov ax,_INTSEL_
	shl eax, 16
	mov ax, ?PREDEFIDTGATES * 2
	xor edx, edx
	mov dh, _TGATE_ or ?PLVL
@@:
	mov [edi+ecx*8+0],eax
	mov [edi+ecx*8+4],edx
	inc eax
	inc eax
	inc cl
	cmp cl,100h - ?PREDEFIDTGATES
	jnz @B

;--- the memory where the IDT was stored in conv memory will now be
;--- used as host stack, unless host stack is in extended memory;
;--- initialize it with "STAC"
;--- if host stack is in extended memory, the IDT had it's own segment
;--- and won't become host stack area.

  ife ?HSINEXTMEM
	mov edi,esp
	mov eax,"CATS"
	mov ecx,esp
	sub ecx,offset stacktop
	shr ecx,2
@@:
	push eax
	loop @B
	mov esp,edi
  endif

idtcopied:
	push ss
	pop ds
	lidt pdIDT
	@dprintf "movehigh_pm: IDT copied, pdIDT=%X:%lX, pdGDT=%X:%lX", pdIDT.wLimit, pdIDT.dwBase, pdGDT.wLimit, pdGDT.dwBase

endif ;?MOVEIDT

exit:
	@dprintf "movehigh_pm exit, esp=%lX", esp
	clc
error:
	popad
	ret
_movehigh endp

_TEXT32  ends

end

