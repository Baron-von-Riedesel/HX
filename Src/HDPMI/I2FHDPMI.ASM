
;--- int 2f, ax=168Ah, vendor HDPMI code

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

if ?VENDORAPI

@wofs macro ofs
	dw offset ofs - $
endm

 ifdef _DEBUG
displayhdltab proto near
 endif

_TEXT32 segment

;*** callback for HDPMI extensions

_I2f168A_Hdpmi proc near public

	push offset iret_with_CF_mod
	push ebx
	push ecx
	push edx

APIFUNCS = 1 shl 4                   ;4
ifdef _DEBUG
APIFUNCS = APIFUNCS or (1111b shl 0) ;0-3
endif
if ?VM
APIFUNCS = APIFUNCS or (1 shl 5)     ;5
endif
if ?PMIOPL eq 0
APIFUNCS = APIFUNCS or (1111b shl 6) ;6-9 (10 rsvd)
endif
	mov edx,APIFUNCS
	mov ebx,offset tab168a-2
@@:
	bsf ecx,edx
	jz error
	btr edx,ecx
	add ebx,2
	cmp ax,cx
	jnz @B
	movzx ecx, word ptr cs:[ebx]
	add ebx,ecx
	pop edx
	pop ecx
	xchg ebx,[esp]
	ret
error:
	pop edx
	pop ecx
	pop ebx
	stc
	ret
	align 2
tab168a label word
 ifdef _DEBUG
	@wofs is0000
	@wofs is0001
	@wofs is0002
	@wofs is0003
 endif
	@wofs is0004	; "disable" host
 if ?VM
	@wofs is0005	; set/reset HDPMI=32 (VM)
 endif
 if ?PMIOPL eq 0
	@wofs is0006	; trap port range
	@wofs is0007	; release trapped port range
	@wofs simio		; Simulate IO
	@wofs is0009	; trap CLI/STI
;	@wofs is000A	; Simulate HW interrupt (not yet implemented)
 endif
 ifdef _DEBUG
is0000:
	and ss:gbl.fMode2,not FM2_LOG
	ret
is0001:
	or  ss:gbl.fMode2,FM2_LOG
	ret
is0002:
	mov ss:traceflgs,bx	;see HDPMI.INC, ?LOG_xxx for flags details
	ret
is0003:
	push ds
	push ss
	pop ds
	call displayhdltab
	pop ds
	ret
 endif
is0004:
	or ss:gbl.fMode, FM_DISABLED
	ret

 if ?VM

ENVF_VMB equ 5

is0005:
	test ss:[bEnvFlags], ENVF_VM
	setnz al
	push eax
	mov al, bl
	and al, 1
	shl al, ENVF_VMB
	and ss:bEnvFlags, not ENVF_VM
	or ss:bEnvFlags, al
	call updateclonesize
	pop eax
	ret
 endif

_I2f168A_Hdpmi endp

 if ?PMIOPL eq 0

;--- port trapping API.
;--- it's a (vague) copy of the API implemented by NTVDM ( see nt_vdd.inc )

;--- ax= 6: set IO port trap range
;---        ds:e/si = ptr TRAPPROCS
;---        dx = start port range
;---        cx = size port range
;---        out: NC if ok, handle in eax
;--- ax= 7: reset IO port trap range
;---        edx = handle
;---        out: NC if ok
;--- ax= 8: simulate IO (read/write trapped ports)
;--- ax= 9: simulate HW interrupt

;--- exception handler entered with error code:
;--- bit 0-2: size of instruction
;--- bit   3: 0=IN/OUT, 1=INS/OUTS (string instr)
;--- bit 4-5: IO size, 00=byte, 01=word, 11=dword
;--- bit   6: IN/OUT: 0=port in DX, 1=port in bits 8-15
;---          INS/OUTS: 1=ignore hiword ESI/EDI/ECX
;--- bit   7: REP prefix detected

SI_STRING   equ 8
SI_WORD     equ 10h
SI_DWORD    equ 20h
SI_CPORT    equ 40h	; if IN/OUT: 1=port in bits 8-15
SI_ADDR16   equ 40h	; if INS/OUTS: 1=don't use hiwords ESI/EDI/ECX
SI_REPPRE   equ 80h

NUMTRAP equ 10	; max trap ranges, currently static

TRAPPROCS struct
if ?32BIT
pInProc  df ?	; handle proc for IN
pOutProc df ?	; handle proc for OUT
else
pInProc  dd ?
pOutProc dd ?
endif
TRAPPROCS ends

;--- port range item

TRAPH struct
wSize    dw ?	; size range
wStart   dw ?	; start range
	TRAPPROCS <>
TRAPH ends

_DATA32C segment
traphdl TRAPH NUMTRAP dup (<>)
_DATA32C ends

;--- cx=ports to check
;--- edx=start range
;--- eax=check proc

checkrange proc
	mov ebx, offset taskseg
	push eax
	movzx eax, ss:[ebx].TSSSEG.wOffs
	add ebx, eax
	pop eax
@@:
	call eax
	jc @F
	inc edx
	loopw @B
@@:
	ret
checkport::
	bt ss:[ebx], edx
	retn
setport::
	bts ss:[ebx], edx
	retn
resetport::
	btr ss:[ebx], edx
	clc
	retn

checkrange endp

;--- set IO port trap range

;--- errors:
;--- a) no free TRAPH entry
;--- b) cx = 0
;--- c) dx+cx > 10000h
;--- d) not all ports untrapped

is0006 proc
	pushad
	mov edi, offset traphdl
nextitem:
	cmp cs:[edi].TRAPH.wSize, 0
	jz foundfree
	add edi, sizeof TRAPH
	cmp edi, offset traphdl+sizeof traphdl
	jnz nextitem
	jmp error_0006
foundfree:

;--- free entry found

;--- first check status of all ports -
;--- they must all be "untrapped"

	movzx ecx, cx
	jecxz error_0006
	movzx edx, dx
	lea eax, [ecx+edx]
	cmp eax, 10000h
	ja error_0006
	mov eax, offset checkport
	push ecx
	push edx
	call checkrange
	pop edx
	pop ecx
	jc error_0006

;--- all ports are untrapped - now set the IOPB bits

	mov eax, offset setport
	call checkrange
	mov [esp].PUSHADS.rEAX, edi

;--- store the handlers

	mov ecx, [esp].PUSHADS.rECX
	mov edx, [esp].PUSHADS.rEDX
	push es
	push byte ptr _CSALIAS_
	pop es
	mov es:[edi].TRAPH.wSize, cx
	mov es:[edi].TRAPH.wStart, dx
	add edi, 4
	cld
ife ?32BIT
	movzx esi, si
endif
	movsd
	movsd
if ?32BIT
	movsd
endif
	pop es
	jmp done_0006
error_0006:
	stc
done_0006:
	popad
	ret
is0006 endp

;--- release IO port trap range
;--- edx=handle
;--- out: NC=ok, C=error

is0007 proc

	pushad
	mov edi, offset traphdl
nextitem:
	cmp edx, edi
	jz found
	add edi, sizeof TRAPH
	cmp edi, offset traphdl+sizeof traphdl
	jnz nextitem
	stc
	jmp exit
found:
	movzx ecx, cs:[edi].TRAPH.wSize
	stc
	jecxz exit
	movzx edx, cs:[edi].TRAPH.wStart
	mov eax, offset resetport
	call checkrange
	push ds
	push byte ptr _CSALIAS_
	pop ds
	mov [edi].TRAPH.wSize, 0
	pop ds
	clc
exit:
	popad
	ret

is0007 endp

;--- get trap proc for a certain port
;--- in:  AH: flags
;---      AL[0]: 0=IN, 1=OUT
;--- out: proc in SI:E/AX

gettrapproc proc public
	push ebx
	push ecx
	mov ebx, offset traphdl
nextitem:
	mov cx, cs:[ebx].TRAPH.wStart
	cmp dx, cx
	jb @F
	add cx, cs:[ebx].TRAPH.wSize
	dec cx
	cmp dx, cx
	jbe found
@@:
	add ebx, sizeof TRAPH
	cmp ebx, offset traphdl+sizeof traphdl
	jnz nextitem
	pop ecx
	pop ebx
	stc
	ret
found:
	add ebx, 4
	test al, 2	; IN[S] or OUT[S]
	jz @F
	add ebx, 4 + ?32BIT * 2
@@:
if ?32BIT
	mov eax, cs:[ebx+0]
	mov  si, cs:[ebx+4]
else
	mov  ax, cs:[ebx+0]
	mov  si, cs:[ebx+2]
endif
	pop ecx
	pop ebx
	ret
gettrapproc endp

;--- Simulate IN[S]/OUT[S] in ring 0
;--- BX holds flags setup by hdpmi

SI_OUT equ 1	; bit 0 of BL: 0=IN[S], 1=OUT[S]

simio proc
	test bl, SI_STRING
	jnz sim_string

;--- IN/OUT: may modify DX and EAX

	test bl, SI_CPORT
	jz @F				; v3.20a: fixed, was "jnz" 
	mov dl, bh
	mov dh, 0
@@:
	mov eax, ecx		; v3.20a: fixed: init EAX not just for OUT, but also for IN!
	test bl, SI_OUT
	jnz sim_out
	test bl, SI_DWORD
	jnz dword_in
	test bl, SI_WORD
	jnz word_in
	in al,dx
	ret
word_in:
	in ax,dx
	ret
dword_in:
	in eax,dx
	ret
sim_out:
	test bl, SI_DWORD
	jnz dword_out
	test bl, SI_WORD
	jnz word_out
	out dx, al
	ret
word_out:
	out dx, ax
	ret
dword_out:
	out dx, eax
	ret

;--- INS/OUTS
;--- modifies ESI/EDI
;--- modifes ECX if REP prefix
;--- may clear hiword ESI/EDI/ECX

sim_string:
	test bl, SI_ADDR16
	jz @F
	movzx esi, si
	movzx edi, di
	movzx ecx, cx
@@:
	test bl, SI_OUT
	jnz sim_outstr
	test bl, SI_REPPRE
	jnz sim_inrep
	test bl, SI_DWORD
	jnz dword_instr
	test bl, SI_WORD
	jnz word_instr
	insb
	ret
word_instr:
	insw
	ret
dword_instr:
	insd
	ret

sim_inrep:
	test bl, SI_DWORD
	jnz dword_inrep
	test bl, SI_WORD
	jnz word_inrep
	rep insb
	ret
word_inrep:
	rep insw
	ret
dword_inrep:
	rep insd
	ret

;--- OUTS: may have a segment prefix!

SIMSOUTFR struct
	dd ?	;sim_sout_ret
	dd ?	;ds
	dd ?	;
	IRET32 <>
SIMSOUTFR ends

sim_sout_ret:
	pop ds
	ret

sim_outstr:
	push ds
	push offset sim_sout_ret
	call outstr_setds
	test bl, SI_REPPRE
	jnz sim_outrep
	test bl, SI_DWORD
	jnz dword_outstr
	test bl, SI_WORD
	jnz word_outstr
	outsb
	ret
word_outstr:
	outsw
	ret
dword_outstr:
	outsd
	ret

sim_outrep:
	test bl, SI_DWORD
	jnz dword_outrep
	test bl, SI_WORD
	jnz word_outrep
	rep outsb
	ret
word_outrep:
	rep outsw
	ret
dword_outrep:
	rep outsd
	ret

outstr_setds:
	mov al, bh
	cmp al, 26h
	jz setes
	cmp al, 2Eh
	jz setcs
	cmp al, 36h
	jz setss
	cmp al, 64h
	jz setfs
	cmp al, 65h
	jz setgs
	ret
setes:
	push es
	pop ds
	ret
setcs:
	mov ds, [esp+4].SIMSOUTFR.rCS
	ret
setss:
	mov ds, [esp+4].SIMSOUTFR.rSS
	ret
setfs:
	push fs
	pop ds
	ret
setgs:
	push gs
	pop ds
	ret

simio endp

  if ?TRAPCLISTI

;--- CLI/STI trap

_DATA32C segment
clihdlr R3PROC <>
stihdlr R3PROC <>
_DATA32C ends

is0009 proc
	pushad
	push es
	push byte ptr _CSALIAS_
	pop es
	cld
	and bl,1
	movzx ebx, bl
	mov eax, edx
if ?32BIT
	lea edi, [ebx*8+offset clihdlr]
	stosd
else
	lea edi, [ebx*4+offset clihdlr]
	stosw
endif
	mov eax, ecx
	stosw
	pop es
	popad
	ret
is0009 endp

  endif ; ?TRAPCLISTI
 
 endif ; ?PMIOPL eq 0

_TEXT32 ends

endif  ; ?VENDORAPI

end
