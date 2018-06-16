
;--- ax=0Bxx (hardware breakpoints)

	.386P

	include hdpmi.inc
	include external.inc

	option proc:private

?ENABLEWP	equ 1	;1=enable hardware breakpoints

@seg _TEXT32

_TEXT32 segment

	@ResetTrace

;*** int 31h, ax=0B00h
;--- BX:CX=linear address
;--- dl=size (1,2,4)
;--- dh=type (0=execute,1=write,2=read or write)
;--- out: watchpoint handle in BX

allocwatch proc public
	@strout <"i31: alloc watchpoint, bx:cx=%X:%X, dx=%X",lf>,bx,cx,dx
if ?ENABLEWP
	pushad

	push bx
	push cx		;save linear address on stack

	mov eax,edx
	dec al		;size watchpoint: 4->3,2->1,1->0
	cmp al,3
	ja error
	cmp ah,2	;watchpoint type: 0,1 or 2
	ja error
	jnz @F
	inc ah		;transform 2 to 3
@@:
	shl al,2
	or al,ah 	;mask now in AL [0-3]
	mov dl,al
@@:
	mov eax,dr7
	mov ebx,eax
	shr ebx,16
	mov cl,4
@@:
	test al,3	;watchpoint free?
	jz found
	ror al,2
	ror bx,4
	dec cl 
	jnz @B
error:
	pop eax		;adjust stack
	popad
	stc
	ret
found:
	mov ch,cl 	;save count in CH
	mov dh,cl
	or al,1		;set local bit only
	and bl,0F0h
	or bl,dl
nextitem:
	ror al,2
	ror bx,4
	dec cl
	jnz nextitem
	push bx
	push ax
	pop eax
	or ah,1		;activate LE
	mov dr7,eax

	pop eax		;get linear address of watchpoint
	dec ch
	jz use_dr3
	dec ch
	jz use_dr2
	dec ch
	jz use_dr1
	mov dr0,eax
	jmp exit
use_dr1:
	mov dr1,eax
	jmp exit
use_dr2:
	mov dr2,eax
	jmp exit
use_dr3:
	mov dr3,eax
exit:
	movzx ax,dh
	sub al,4
	neg al
	mov [esp].PUSHADS.rBX, ax
	popad
	clc
	ret
else
	mov ax,8001h
	stc
	ret
endif
	align 4
allocwatch endp

;--- int 31h, ax=0B01h
;--- BX=handle
        
clearwatch proc public
	@strout <"i31: clear watchpoint, bx=%X",lf>,bx
if ?ENABLEWP
	cmp bx,4
	jnb clearwatch_err
	push eax
	push ecx
	mov eax,dr7
	mov cl,bl
	mov ch,3
	shl ch,cl
	shl ch,cl
	not ch
	and al,ch
	cmp al,0
	jnz @F
	and ah,0FCh 	;LE und GE reset
@@:
	mov dr7,eax
	pop ecx
	pop eax
	clc
	ret
else
	stc
	ret
endif
	align 4
clearwatch endp

clearwatch_err:
getwatchstate_err:
resetwatchstate_err:
	stc
	ret

;--- int 31h, ax=0B02h
;--- BX=handle
        
getwatchstate proc public
	@strout <"i31: get watchpoint state, bx=%X",lf>,bx
if ?ENABLEWP
	cmp bx,4
	jnb getwatchstate_err
	push ecx
	push eax
	mov eax,dr6
	mov cl,bl
	shr al,cl
	and al,1
	mov cl,al
	pop eax
	mov al,cl
	mov ah,00
	pop ecx
	ret
else
	stc
	ret
endif
	align 4
getwatchstate endp

;--- int 31h, ax=0B03h
;--- BX=handle

resetwatchstate proc public
	@strout <"i31: reset watchpoint state, bx=%X",lf>,bx
if ?ENABLEWP
	cmp bx,4
	jnb resetwatchstate_err
	push eax
	push ecx
	mov ch,1
	mov cl,bl
	mov eax,dr6
	shl ch,cl
	not ch
	and al,ch
	mov dr6,eax
	pop ecx
	pop eax
	ret
else
	stc
	ret
endif
	align 4
resetwatchstate endp

_TEXT32 ends

	end
