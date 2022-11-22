
;--- implements support for Int 41h in protected mode (debugging)

	.386

	include hdpmi.inc
	include external.inc
	include debugsys.inc

	option proc:private

_TEXT32 segment

;_LTRACE_ = 0

;*** this routine is a IDT handler proc
;*** which should call the ring3 procs if called by ring3

intr41 proc public
	push eax
	lar eax, [esp+4].IRET32.rCSd
	and ah,60h	; ring 0?
	pop eax
	jnz int41r3
	@dprintf "intr41: called from ring0, AX=%X",ax
	push eax		; v3.20: check if SS is ours
	mov eax, ss
	cmp ax, _SSSEL_
	pop eax
	jz intr41_		; if yes, handle it
	iretd
int41r3:
	@dprintf "intr41: called from ring3, AX=%X",ax
	@simintpms 41
intr41 endp

;*** ring3 int41 default proc, called by int30 dispatcher
;*** it has to ensure that the int is not routed to real-mode

;_LTRACE_ = 0

intr41_ proc public
	@dprintf "intr41_: AX=%X",ax
if ?I41SUPPORT
	cmp ax,DS_Out_Char
	jnz @F
	push eax
	mov al,dl
	call _putchrx
	pop eax
	iretd
@@:
	cmp ax,DS_In_Char
	jnz @F
	call _getchrx
	iretd
@@:
 if 1	;changed 12/2020: function 0002 is the correct one
	cmp ax,DS_Out_Str	;display string in ds:esi
	jnz @F
	call OutStr
 else
	cmp ax,DS_Out_Str16	;display string in es:si
	jnz @F
	push ds
	push es
	pop ds
	movzx esi,si
	call OutStr
	pop ds
 endif
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

