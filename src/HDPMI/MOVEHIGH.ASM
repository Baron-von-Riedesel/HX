
;*** moves some structures in extended memory if ?DYNBREAKTAB==1
;*** IDT, PM breaks

	.386P

	page,132

	include hdpmi.inc
	include external.inc

	option proc:private

@seg _ITEXT32

ife ?DYNBREAKTAB
?MOVEIDT = 0
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
;--- 7. init old IDT with "STAC" (it will become the host stack)

;--- inp: DS=GROUP16, ES=FLAT
;--- preserves registers

_movehigh_pm proc public

	pushad
	@strout <"#movehigh_pm enter, bEnvFlags=%X",lf>, <word ptr bEnvFlags>
if ?DYNBREAKTAB
	mov ebp,offset _AllocSysPages
	test bEnvFlags2, ENVF2_SYSPROT
	jz @F
	mov ebp,offset _AllocSysPagesRo
@@:
	mov ecx,1		;alloc PM BREAK table
	call ebp		;doesnt modify ES
	jc error
	mov edi,eax
	@strout <"#movehigh_pm: setting pm breakpoint descriptor (%lX)",lf>,eax
	mov edx, pdGDT.dwBase
	mov ecx, _INTSEL_
	and cl,0F8h
	add edx, ecx
	mov es:[edx].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[edx].DESCRPTR.A1623,al
	mov es:[edx].DESCRPTR.A2431,ah
	push edi
	mov ax,30CDh
	mov ecx,_MAXCB_
	cld
	rep stosw
	pop edi

if ?MOVEGDT
	test bEnvFlags2, ENVF2_LDTLOW
	jnz nogdtmove
	push edi
if ?IDTPAGE
	lea edi, [edi+800h]
	mov dx,7FFh
else
	lea edi, [edi+400h]
	mov dx,3FFh
endif
	mov esi, pdGDT.dwBase
	@strout <"#movehigh_pm: move GDT to %lX, src=%lX",lf>, edi, esi
	mov pdGDT.dwBase,edi
	lea eax, [edi+_TSSSEL_]
	sub eax, [dwHostBase]
	mov [dwTSSdesc],eax		;update TSS descriptor linear address
  if ?KDSUPP
	mov eax, edi
	lea ecx, [esi + _GDTSEL_]
	mov es:[ecx].DESCRPTR.limit,dx
	mov es:[ecx].DESCRPTR.A0015,ax
	shr eax,16
	mov es:[ecx].DESCRPTR.A1623,al
	mov es:[ecx].DESCRPTR.A2431,ah
  endif
	movzx ecx, pdGDT.wLimit
	mov pdGDT.wLimit,dx			;set new limit for GDT
	inc ecx
	push es
	pop ds
	rep movsb
	push ss
	pop ds
	lgdt pdGDT
	pop edi
  if 0
	push ds
	pop es
	mov edi, offset curGDT		;clear current GDT with -1
	movzx ecx, pdGDT.wLimit		;(not needed, since it isn't resident)
	inc ecx
	mov al,-1
	rep stosb
  endif

nogdtmove:
endif

if ?MOVEIDT
	mov ecx,1
  if ?USERIDT
	test bEnvFlags2, ENVF2_LDTLOW
	jz @F
	call _AllocUserPages			;alloc page for IDT
	jc error
	mov edi, eax
	jmp alloc_done
@@:
  endif
  if ?IDTPAGE
	call ebp
	jc error
	mov edi, eax
  else
	add edi,800h
  endif
alloc_done:

;--- copy IDT from conventional to extended memory (vectors 00-77h)

if ?VM

	mov pdIDT.dwBase, edi
	test fMode, FM_CLONE
	jz @F
	call _getidtaddr
	mov esi, 0FFBFD000h
	add esi, eax
	push es
	pop ds
	mov ecx, 800h/4
	rep movsd
	push ss
	pop ds
	@strout <"#movehigh_pm: IDT copied, pdIDT=%X:%lX, pdGDT=%X:%lX",lf>, pdIDT.wLimit, pdIDT.dwBase, pdGDT.wLimit, pdGDT.dwBase
  if _LTRACE_
	mov edi, pdIDT.dwBase
  endif
	lidt pdIDT
	jmp exit
@@:
endif	;?VM
	mov esi, offset curIDT

;--- the predefined IDT contains just 78h entries
	mov ecx,?PREDEFIDTGATES * sizeof DESCRPTR/4
	@strout <"#movehigh_pm: copy IDT from GROUP16:%lX to %lX",lf>, esi, edi
	rep movsd

;--- initialize the rest of the IDT

	mov ax,_INTSEL_
	shl eax, 16
	mov ax, ?PREDEFIDTGATES * 2
	xor edx, edx
	mov dh, _TGATE_ or ?PLVL
@@:
	mov es:[edi+ecx*8+0],eax
	mov es:[edi+ecx*8+4],edx
	inc eax
	inc eax
	inc cl
	cmp cl,100h - ?PREDEFIDTGATES
	jnz @B

idtcopied:

;--- the memory where the IDT was stored in conv memory will now be
;--- used as host stack. initialize it with "STAC"

	lidt pdIDT
	mov eax,"CATS"
	mov ecx,esp
	sub ecx,offset stacktop
	shr ecx,2
	mov edi,esp
@@:
	push eax
	loop @B
	mov esp,edi
endif

endif
exit:
	@strout <"#movehigh_pm exit, esp=%lX",lf>, esp
	clc
error:
	popad
	ret
_movehigh_pm endp

_TEXT32  ends

end

