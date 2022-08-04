
;--- this code is obsolete

;*** call a real mode Proc from protected mode
;*** called by exception handler
;*** EBP -> EXCFR ( PUSHA(D), DPMIEXC )
;--- ES:SI = segment descriptor

ExecRMProc proc
if ?32BIT

	push esi
	push ds
	lds esi,[ebp].EXCFR._cseip	; CS:EIP of exception address
	cmp word ptr [esi],9A66h	; far16 call?
	pop ds
	pop esi
	jnz error2			;anything else is invalid

;--- copy the DWORD at SS:ESP to BX:CX ( supposed to be CS:IP )

	mov dx,ds
	mov ebx,[ebp].EXCFR._esp
	mov ds,[ebp].EXCFR._ss
	mov cx,[ebx+0]
	mov bx,[ebx+2]
	mov ds,dx

else
	push si
	push ds
	lds si,[bp].EXCFR._csip		;CS:IP of exception
	cmp byte ptr [si],9Ah
	pop ds
	pop si
	jnz error2

;--- copy the DWORD at SS:SP to BX:CX ( supposed to be CS:IP )

	mov dx,ds
	mov bx,[bp].EXCFR._sp
	mov ds,[bp].EXCFR._ss
	mov cx,[bx+0]
	mov bx,[bx+2]
	mov ds,dx

endif
	push cx
	call Sel2Segment	;translate BX to segment
	pop cx
	jc error1			;error: not a valid segment
if ?32BIT
	push edi
	sub esp, sizeof RMCS
	mov edi, esp
else
	push di
	sub sp, sizeof RMCS
	mov di, sp
endif
	mov ax,es:[si+XDOSSEG]
	push es

	push ss
	pop es
if ?32BIT
	mov es:[edi].RMCS.rSSSP,0
	mov es:[edi].RMCS.rIP,?
	mov es:[edi].RMCS.rCS,ax
else
	mov es:[ed].RMCS.rSSSP,0
	mov es:[di].RMCS.rIP,?
	mov es:[di].RMCS.rCS,ax
endif
	push bx
	push cx
	mov cx,0002 		;copy 2 words ( BX:CX ) to RMS
	xor bx,bx
	mov ax,0301h		;call Real Mode far Proc
	call dpmicall
	jc error3
	add sp,+04
if ?32BIT
	mov ax,word ptr es:[edi].RMCS.rEAX
	mov dx,word ptr es:[edi].RMCS.rEDX
	add [ebp].EXCFR._eip, 7	;adjust EIP (7 = sizeof call far32)
	add esp,sizeof RMCS
else
	mov ax,word ptr es:[di].RMCS.rEAX
	mov dx,word ptr es:[di].RMCS.rEDX
	add [bp].EXCFR._ip, 5	;adjust IP (5 = sizeof call far16)
	add sp,sizeof RMCS
endif
	clc
exit:
	pop es
if ?32BIT
	pop edi
else
	pop di
endif
	ret

error1:
	mov ax,offset errstr41	;error 'cant get base address'
	stc
	ret
error2:
	mov ax,offset errstr43	;error 'invalid call instr'
	stc
	ret
error3:
	mov ax,offset errstr42	;error 'CallRealModeProc Error'
if ?32BIT
	add esp,4 + sizeof RMCS
else
	add sp,4 + sizeof RMCS
endif
	stc
	jmp exit

ExecRMProc endp

;--- selector -> segment
;--- in: BX=selector
;--- out: C if error; NC ok, BX=segment

Sel2Segment proc
	mov ax,0006h		;get base
	call dpmicall
	jc exit
	test dl, 0fh
	stc
	jnz exit
if ?32BIT
	push cx
	push dx
	pop eax
	shr eax,4
	test eax,0FFFF0000h
	stc
	jnz exit
else
	mov ax, dx
	shr ax, 4
	test cx, 0fff0
	stc
	jnz exit
	shl cx, 12
	or ax, cx
endif
	mov bx,ax
	clc
exit:
	ret

Sel2Segment endp

