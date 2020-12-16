
;--- print macros and routines

;--- define and print a string

; @printf: print formated strings
; understands %x, %lx, %u, %lu, %s, %ls, %b

@printf macro xx,a1,a2,a3,a4,a5,a6,a7,a8
	ifnb <a8>
	  echo too many parameters for @printf
	  .err1
	endif
	for arg, <a7,a6,a5,a4,a3,a2,a1>
	  ifnb <arg>
		push arg
	  endif
	endm
	push CStr(xx)
	call _printf
endm

	.code

_putchar proc

	push dx
	mov ah,02
	mov dl,al
	int 21h
	pop dx
	ret

_putchar endp

;--- display a near16 string
;--- modifies AX

_strout proc uses bx
	mov bx, ax
nextchar:
	mov al,[bx]
	and al,al
	jz done
	cmp al,10
	jnz @F
	mov al,13
	call _putchar
	mov al,10
@@:
	call _putchar
	inc bx
	jmp nextchar
done:
	ret
_strout endp


_byteout_0x:	; display byte in AL, hexadecimal, leading zeros
	push 16
	push 2
	movzx eax,al
	jmp dwordout_0x
_wordout_x:		; display word in AX, hexadecimal
	movzx eax,ax
_dwordout_x:	; display dword in EAX, hexadecimal
	push 16
	jmp dwordout
_dwordout_0x:	; display dword in EAX, hexadecimal, leading zeros
	push 16
	push 8
	jmp dwordout_0x

_wordout_u:		; display word in AX, decimal
	movzx eax,ax
_dwordout_u:	; display dword in EAX, decimal
	push 10
dwordout:		; display dword in EAX, base x
	push 0
dwordout_0x:	; display dword in EAX, base x, leading zeros
	push ebx
	push cx
	push bp
	mov bp,sp	; +0=bp, +2=cx, +4=ebx +8=size, +10=base
	mov cx,[bp+8]
	movzx ebx,word ptr [bp+10]
nextdigit:
	xor edx,edx
	div ebx
	add dl,'0'
	cmp dl,'9'
	jbe @F
	add dl,7
@@:
	push dx
	and eax,eax
	jnz nextdigit
	mov ax,bp
	sub ax,sp
	shr ax,1
	sub cx,ax
	.while sword ptr cx > 0
		mov al,'0'
		call _putchar
		dec cx
	.endw
	.repeat
		pop ax
		call _putchar
	.until bp == sp
	pop bp
	pop cx
	pop ebx
	add sp,2+2
	ret

@getwordfromstack macro reg
	mov reg,word ptr [bp]
	add bp,2
endm

@getdwordfromstack macro reg
	mov reg,dword ptr [bp]
	add bp,4
endm

;--- print formated string
;--- understands:
;--- %x:  word hex
;--- %lx: dword hex
;--- %u:  word dec
;--- %lu: dword dec
;--- %s:  string near
;--- %ls: string far16
;--- %b:  byte hex
;--- %lp: fword hex
;--- registers modified: edx, hiword eax

_printf proc

	push bp
	mov bp,sp

	add bp,4
	cld
	push ax
	push bx
	push si
	@getwordfromstack si
nextitem:
	lodsb
	and al,al
	jz done
	push offset nextitem
	cmp al,'%'
	jz special
	cmp al,lf
	jnz _putchar
	mov al,13
	call _putchar
	mov al,lf
	jmp _putchar
done:
	pop si
	mov bx,sp
	mov bx,ss:[bx+2+2+2]	;get return address
	mov [bp-2],bx
	sub bp,2
	mov bx,sp
	xchg bp,ss:[bx+2+2]
	pop bx
	pop ax
	pop sp
	ret

special:
	lodsb
	cmp al,'x'
	jz printf_x
	cmp al,'u'
	jz printf_u
	cmp al,'s'
	jz printf_s
	cmp al,'b'
	jz printf_b
	cmp al,'l'
	jnz @F
	lodsb
	cmp al,'x'
	jz printf_lx
	cmp al,'u'
	jz printf_lu
	cmp al,'s'
	jz printf_ls
	cmp al,'p'
	jz printf_lp
@@:
	jmp _putchar
printf_s:						;%s : near16 string
	@getwordfromstack ax
	call _strout
	retn
printf_ls:						;%ls display far16 string
	push ds
	@getwordfromstack ds
	@getwordfromstack ax
	call _strout
	pop ds
	retn
printf_x:						;%x : word
	@getwordfromstack ax
	call _wordout_x
	retn
printf_lx:						;%lx : dword
	@getdwordfromstack eax
	call _dwordout_x
	retn
printf_lp:						;%lp : fword
	@getwordfromstack ax
	call _wordout_x
	@getdwordfromstack eax
	call _dwordout_0x
	retn
printf_u:						;%u : word
	@getwordfromstack ax
	call _wordout_u
	retn
printf_lu:						;%lu : dword
	@getdwordfromstack eax
	cmp eax,-1                  ;display 0xffffffff
	jnz @F                      ;as -1
	mov al,'-'
	call _putchar
	mov al,'1'
	jmp _putchar
@@:
	call _dwordout_u
	retn
printf_b:						;%b
	@getwordfromstack ax
	call _byteout_0x
	retn
_printf endp

