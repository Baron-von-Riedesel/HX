
;--- implements support for Int 41h in protected mode (debugging)

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

_TEXT32 segment

;_LTRACE_ = 0

;*** this routine is a IDT handler proc
;*** which should call the ring3 procs if called by ring3

intr41 proc public
	push eax
	lar eax, [esp+4].IRET32.rCSd
	and ah,60h
	pop eax
	jnz @F
	@strout <"#intr41: called from ring0, AX=%X",lf>,ax
	iretd
@@:
	@strout <"#intr41: called from ring3, AX=%X",lf>,ax
	@simintpms 41
intr41 endp

;*** ring3 int41 default proc, called by int30 dispatcher
;*** it has to ensure that the int is not routed to real-mode

;_LTRACE_ = 0

intr41_ proc public
	@strout <"#intr41_: AX=%X",lf>,ax
if ?I41SUPPORT
	cmp ax,0000
	jnz @F
	push eax
	mov al,dl
	call _putchrx
	pop eax
	iretd
@@:
	cmp ax,0001
	jnz @F
	call _getchrx
	iretd
@@:
	cmp ax,0012h	;display string in es:esi
	jnz @F
	push ds
	push eax
	mov eax,es
	mov ds,eax
	call OutStr
	pop eax
	pop ds
	iretd
@@:
endif
	iretd
intr41_ endp

if ?I41SUPPORT
OutStr:
	cld
nextitem:
	lodsb
	and al,al
	jz done
	call _putchrx
	jmp nextitem
done:
	ret
endif

_TEXT32  ends

end

