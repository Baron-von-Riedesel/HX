
;--- int 2f, ax=1684, vendor HDPMI code

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

if ?VENDORAPI

@wofs macro ofs
	dw offset ofs - offset start168a
endm

 ifdef _DEBUG
displayhdltab proto near
 endif

_TEXT32 segment

;*** callback for HDPMI extensions

_I2f168A_Hdpmi proc near public

	push offset iret_with_CF_mod
	cmp ax, MAX168A
	jb @F
	stc
	ret
@@:
	push ebx
	movzx ebx, ax
	mov bx, cs:[ebx*2+offset tab168a]
	add ebx, offset start168a
	xchg ebx,[esp]
	ret
	align 2
tab168a label word
 ifdef _DEBUG
	@wofs is0000
	@wofs is0001
	@wofs is0002
	@wofs is0003
 else
	@wofs error
	@wofs error
	@wofs error
	@wofs error
 endif
	@wofs is0004	; "disable" host

 if ?VM
	@wofs is0005	; set/reset HDPMI=32 (VM)
 else
	@wofs error
 endif

 if ?PMIOPL eq 0

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
;--- bit   3: 0=port in DX, 1=port in bits 8-15
;--- bit 4-5: IO size, 00=byte, 01=word, 11=dword
;--- bit   6: string instruction
;--- bit   7: REP prefix detected

	@wofs is0006	; trap port range
	@wofs is0007	; release trapped port range
;	@wofs is0008	; Simulate IO
;	@wofs is0009	; Simulate HW interrupt

 endif
MAX168A equ ($ - offset tab168a) / sizeof word

start168a:
error:
	stc
	ret
 ifdef _DEBUG
is0000:
	and ss:fMode2,not FM2_LOG
	ret
is0001:
	or  ss:fMode2,FM2_LOG
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
	or ss:fMode, FM_DISABLED
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

NUMTRAP equ 4	; max trap ranges, currently static

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

;is0008:
;is0009:
	stc
	ret

;--- get trap proc for a certain port
;--- in:  port in DX
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
 
 endif

_TEXT32 ends

endif

end
