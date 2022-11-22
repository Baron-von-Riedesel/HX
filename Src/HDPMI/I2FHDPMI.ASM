
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

;--- best might be to somewhat copy the API implemented by NTVDM ( see nt_vdd.inc )

;--- ax= 6: alloc IO port trap
;---        cx:e/dx = ring3 exception handler?
;---        si = port start
;---        di = number of ports
;---        out: NC if ok, handle in eax
;--- ax= 7: release IO port trap
;---        edx = handle
;---        out: NC if ok
;--- ax= 8: simulate IO (read/write trapped ports)
;--- ax= 9: virtualize IRQ
;--- ax=10: devirtualize IRQ

	@wofs is0006	; trap port range(s)
	@wofs is0007	; release trapped port range(s)
;	@wofs is0008	; read/write trapped ports
;	@wofs is0009	; virtualize IRQ

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

 if ?PMIOPL eq 0

;--- exception handler entered with error code:
;--- bit 0: 0=in, 1=out
;--- bit 1: 0=port in dx, 1= port in bits 8-15
;--- bit 2-3: access 00=byte, 01=word, 10=dword, 11=string
;--- bit 4-7: size of instruction

is0006:
	pushad
	mov ebx, offset taskseg
	movzx edx, ss:[ebx].TSSSEG.wOffs
	add ebx, edx
	movzx esi, si
	movzx ecx, di
	lea eax, [ecx+esi]
	cmp eax, 10000h
	cmc
	jc done_0006
	mov eax, esi
@@:
	bt ss:[ebx], esi; first check status of all ports -
	jc done_0006	; they must all be "untrapped"
	inc esi
	loop @B
	mov esi, eax	; ok, now repeat the loop, this time
	mov cx, di		; the bits are set.
@@:
	bts ss:[ebx], esi
	inc esi
	loop @B

;--- todo: store handler routines and return handle in eax
;--- in a first step, it might be sufficient to have static storage for 4 port ranges.

done_0006:
	popad
	ret

is0007:
is0008:
is0009:
	stc
	ret
 endif
 
_I2f168A_Hdpmi endp

_TEXT32 ends

endif

end
