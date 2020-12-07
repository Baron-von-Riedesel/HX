
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
	push CStr(<xx>)
	call _printf
endm

	.data?
buff1 db 10h dup (?)

	.code

;--- dword/word/byte to string

dw_2_str:
	push eax
	shr  eax, 16
	call w_2_str
	pop eax
w_2_str:
	push ax
	mov al,ah
	call b_2_str	;convert high byte
	pop ax
b_2_str:
	mov ah,al
	shr al,4
	call n_2_str	;convert high nibble
	mov al,ah
n_2_str:
	and al,0Fh
	add al,'0'
	cmp al,'9'
	jle @F
	add al,07h
@@:
	mov [di],al
	inc di
	ret

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

skipzeros proc uses di
	mov di,ax
	dec di
nextitem:
	inc di
	mov al,[di]
	cmp al,'0'
	jz nextitem
	cmp al,0
	jnz @F
	dec di
@@:
	mov ax,di
	ret
skipzeros endp

;--- display dword in EAX, hexadecimal

_dwordout proc uses di
	mov di, offset buff1
	push di
	call dw_2_str
	mov byte ptr [di],0
	pop ax
	call skipzeros
	call _strout
	ret
_dwordout endp

_dwordout2 proc uses di
	mov di, offset buff1
	push di
	call dw_2_str
	mov byte ptr [di],0
	pop ax
	call _strout
	ret
_dwordout2 endp

;--- display word in AX, hexadecimal

_wordout proc uses di
	mov di, offset buff1
	push di
	call w_2_str
	mov byte ptr [di],0
	pop ax
	call skipzeros
	call _strout
	ret
_wordout endp

;--- display byte in AL, hexadecimal

_byteout proc uses di
	mov di, offset buff1
	push di
	call b_2_str
	mov byte ptr [di],0
	pop ax
	call _strout
	ret
_byteout endp

;--- print number in AX, decimal

_wordout_d:
	movzx eax,ax

	;fall thru!

;--- print number in EAX, decimal

_dwordout_d proc

	push bx
	push cx
	push si

	mov bl,cl
	mov si,offset tab1
	mov bh,00
	mov ch,MAXDWDIGITS	;max no of digits
nextdigit:
	mov cl,'0' - 1
@@:
	inc cl
	sub eax,[si]
	jnc @B
	add eax,[si]
	add si,4
	cmp cl,'0'			;current digit a 0?
	jnz print
	cmp ch,1			;last possible digit reached?
	jz print
	cmp bh,00			;any digit displayed?
	jz noprint
print:
	push eax
	mov al,cl
	call _putchar
	pop eax
	mov bh,1
noprint:
	dec ch
	jnz nextdigit
	pop si
	pop cx
	pop bx
	ret

	.const
	align word
tab1 dd 1000000000,100000000,10000000,1000000,100000,10000,1000,100,10,1
MAXDWDIGITS equ ($ - tab1) shr 2

	.code

_dwordout_d endp

@getwordfromstack macro reg
	mov reg,word ptr [bp]
	add bp,2
endm

@getdwordfromstack macro reg
	mov reg,dword ptr [bp]
	add bp,4
endm

;--- print formated string
;--- understands %x, %lx, %u, %lu, %s, %ls, %b
;--- no register modified

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
	cmp al,'X'
	jz printf_lX
@@:
	push ax
	mov al,'%'
	call _putchar
	pop ax
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
	call _wordout
	retn
printf_lx:						;%lx : dword
	@getdwordfromstack eax
	call _dwordout
	retn
printf_lX:						;%lX : fword
	@getwordfromstack ax
	call _wordout
	@getdwordfromstack eax
	call _dwordout2
	retn
printf_u:						;%u : word
	@getwordfromstack ax
	call _wordout_d
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
	call _dwordout_d
	retn
printf_b:						;%b
	@getwordfromstack ax
	call _byteout
	retn
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
_printf endp
