
;--- ax=0Bxx (hardware breakpoints)

	.386P

	include hdpmi.inc
	include external.inc

	option proc:private

?ENABLEWP equ 1	;1=enable hardware breakpoints

_TEXT32 segment

	@ResetTrace

;*** int 31h, ax=0B00h
;--- BX:CX=linear address
;--- dl=size (1,2,4)
;--- dh=type (0=execute,1=write,2=read or write)
;--- out: BX=handle

allocwatchp proc public
	@dprintf "allocwatchp: bx:cx(linadd)=%X:%X, dx=%X (dl=size,dh=type)",bx,cx,dx
if ?ENABLEWP
	pushad

	push bx
	push cx		;save linear address on stack

;--- size watchpoint, accepted 1,2 or 4
;--- translated to: 1->0, 2->1, 4->3
;--- translation of 3->2 is "undefined"
	mov eax, edx
	dec al
	cmp al, 3
	ja error

;--- type: 2 must be translated to 3;
;--- I/O watchpoints have the "new" type 2, this isn't
;--- covered by DPMI specs. Also, bit DE in CR4 must be enabled for
;--- I/O watchpoints.
	cmp ah, 2	;watchpoint type: 0,1 or 2
	ja error
	jnz @F
	inc ah		;transform 2 to 3
@@:
	shl al, 2
	or al, ah 	;mask now in AL [0-3]
	mov dl, al
@@:

;--- use dr7 to see if watchpoint is free to use

	mov eax, dr7
	shld ebx, eax, 16	; upper 16-bits into bx
	mov cl, 4
@@:
	test al, 11b;watchpoint free?
	jz found
	ror al, 2
	ror bx, 4
	dec cl 
	jnz @B
error:
	pop eax		;adjust stack
	popad
	stc
	ret
found:
	mov ch, 4
	sub ch, cl	; CH = no of DRx reg

	or al, 1	; set "local bp enable" bit only
	and bl, 0F0h; reset type
	or bl, dl	; set type

;--- shift everything back to the right position
@@:
	ror al, 2
	ror bx, 4
	dec cl
	jnz @B

	push bx		; move upper 16-bits back to eax
	push ax
	pop eax
	or ah, 1	; activate LE ("exact breakpoints", legacy)
	mov dr7, eax

	pop eax		; get linear address of watchpoint
	movzx ecx, ch
	mov [esp].PUSHADS.rBX, cx
	shl ecx, 2
	add ecx, offset use_drx
	call ecx
	popad
	clc
	ret
use_drx:
	mov dr0, eax
	retn
	mov dr1, eax
	retn
	mov dr2, eax
	retn
	mov dr3, eax
	retn
else
	mov ax, 8001h
	stc
	ret
endif
	align 4
allocwatchp endp

;--- int 31h, ax=0B01h
;--- in: BX=handle (0-3)
;--- out: -
;--- modifies bits 0-7 ( and LE/GE ) in DR7 only, type of bp isn't "cleared"
        
clearwatchp proc public
	@dprintf "clearwatchp: bx=%X",bx
if ?ENABLEWP
	cmp bx, 4
	jnb clearwatchp_err
	push eax
	push ecx
	mov eax, dr7
	mov cl, bl
	mov ch, 11b		; 2 bits for each watchpoint in dr7
	shl ch, cl
	shl ch, cl
	test al, ch
	stc
	jz invalid		; v3.22: if watchpoint isn't active
	not ch
	and al, ch
	jnz @F
	and ah, 0FCh 	; else also reset LE and GE
@@:
	mov dr7, eax
invalid:
	pop ecx
	pop eax
	ret
else
	stc
	ret
endif
	align 4
clearwatchp endp

clearwatchp_err:
getwatchpstate_err:
resetwatchpstate_err:
	stc
	ret

;--- int 31h, ax=0B02h
;--- in: BX=handle (0-3)
;--- out: AX=1 if wp triggered, else 0
        
getwatchpstate proc public
	@dprintf "getwatchpstate: bx=%X",bx
if ?ENABLEWP
	cmp bx, 4
	jnb getwatchpstate_err
	push eax
	mov eax, dr6	; state in bits 0-3 of dr6
	bt ax, bx
	setc al
	xor ah, ah		; also clears CF
	inc esp
	inc esp
	push ax
	pop eax
	ret
else
	stc
	ret
endif
	align 4
getwatchpstate endp

;--- int 31h, ax=0B03h
;--- in: BX=handle (0-3)
;--- out: -

resetwatchpstate proc public
	@dprintf "resetwatchpstate: bx=%X",bx
if ?ENABLEWP
	cmp bx, 4
	jnb resetwatchpstate_err
	push eax
	mov eax, dr6
	btr ax, bx
	mov dr6, eax
	pop eax
	clc
	ret
else
	stc
	ret
endif
	align 4
resetwatchpstate endp

_TEXT32 ends

	end
