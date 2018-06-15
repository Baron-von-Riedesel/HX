
;--- this code is obsolete

;*** call a real mode Proc from protected mode
;*** called by exception handler
;*** EBP -> PUSHA(D), Errorcode, CS:IP, flags

ExecRMProc proc
if ?32BIT

	push esi
	push ds
	lds esi,[ebp+0Eh]	   ;CS:EIP of exception address
	cmp byte ptr [esi],9Ah ;far call?
	pop ds
	pop esi
	jnz error2			   ;anything else is invalid

	push ebp
	mov dx,ss
	mov bx,[ebp+20h]	   ;get SS:ESP
	mov ebp,[ebp+1Ch]
	mov ss,bx
	mov ecx,[ebp+00h]	   ;and then CS:EIP
	mov bx,[ebp+04h]?
	mov ss,dx
	pop ebp

else
	push si
	push ds
	lds si,[bp+08h]		;CS:IP of exception
	cmp byte ptr [si],9Ah
	pop ds
	pop si
	jnz error2

	push bp
	mov dx,ss
	mov bx,[bp+10h] 	;SS
	mov bp,[bp+0Eh] 	;SP
	mov ss,bx
	mov cx,[bp+00h] 	;IP
	mov bx,[bp+02h] 	;CS
	mov ss,dx
	pop bp

endif
	push cx
	call Sel2Segment	;get base of BX
	pop cx
	jc error1			;error: no in 1. MB
if ?32BIT
	push edi
	sub esp,sizeof RMCS
	mov edi,esp
else
	push di
	sub sp,sizeof RMCS
	mov di,sp
endif
	mov ax,es:[si+XDOSSEG]
	push es

	push ss
	pop es
if ?32BIT
	mov es:[edi.RMCS.rCS],ax   ;what's with (E)IP?
else
	mov es:[di.RMCS.rCS],ax
endif
	push bx
	push cx
	mov cx,0002 		;copy 2 words???
	xor bx,bx
	mov ax,0301h		;call Real Mode Proc
	call dpmicall
	jc error3
	add sp,+04
if ?32BIT
	mov eax,word ptr es:[edi.RMCS.rEAX]
	mov edx,word ptr es:[edi.RMCS.rEDX]
	add dword ptr [ebp+0Eh],+07  ;adjust EIP (call far32)
else
	mov ax,word ptr es:[di.RMCS.rEAX]
	mov dx,word ptr es:[di.RMCS.rEDX]
	add word ptr [bp+08h],+05  ;adjust EIP (call far16)
endif
	add sp,sizeof RMCS
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
	add sp,4 + sizeof RMCS
	stc
	jmp exit

ExecRMProc endp

;*** selector -> segment (BX=selector) ***
;*** RC: Carry on errors, else SEGMENT in BX ***

Sel2Segment proc
	mov ax,0006h		;get base
	call dpmicall
	jc exit
if ?32BIT
	push cx
	push dx
	pop eax
	shr eax,4
	test eax,0FFFF0000h
else
	mov ax,dx
	mov dx,cx
	mov bx,0010h		;shr 4
	div bx
	cmp dx,+00			;im 1. MB?
endif
	stc
	jnz exit
	mov bx,ax
	clc
exit:
	ret

Sel2Segment endp

