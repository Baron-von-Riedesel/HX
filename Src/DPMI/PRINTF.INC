
;--- print macros and routines

;--- define and print a string

@stroutc macro xx
	push CStr(<xx>)
	call _strout
endm

; @printf: print formated strings
; understands %x, %lx, %u, %lu, %s, %ls, %b

@printf macro xx,a1,a2,a3,a4,a5,a6,a7,a8
	ifnb <a8>
	  echo too many parameters for @printf
	  .err1
	endif
	ifnb <a7>
	  push a7
	endif
	ifnb <a6>
	  push a6
	endif
	ifnb <a5>
	  push a5
	endif
	ifnb <a4>
	  push a4
	endif
	ifnb <a3>
	  push a3
	endif
	ifnb <a2>
	  push a2
	endif
	ifnb <a1>
	  push a1
	endif
	push CStr(<xx>)
	call _printf
endm

CONST segment
szlf	db 13,10,0
CONST ends

_BSS segment
buff1 db 10h dup (?)
_BSS ends

_TEXT segment

	assume CS:DGROUP, DS:DGROUP, SS:DGROUP

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

_strout proc
	push bp
	mov bp,sp
	push bx
	mov bx,[bp+4]
nextchar:
	mov al,[bx]
	and al,al
	jz done
	call _putchar
	inc bx
	jmp nextchar
done:
	pop bx
	pop bp
	ret 2
_strout endp

;--- display dword in EAX, hexadecimal

_dwordout proc uses di
	mov di, offset buff1
	push di
	call dw_2_str
	mov byte ptr [di],0
	call _strout
	ret
_dwordout endp

;--- display word in AX, hexadecimal

_wordout proc uses di
	mov di, offset buff1
	push di
	call w_2_str
	mov byte ptr [di],0
	call _strout
	ret
_wordout endp

;--- display byte in AL, hexadecimal

_byteout proc uses di
	mov di, offset buff1
	push di
	call b_2_str
	mov byte ptr [di],0
	call _strout
	ret
_byteout endp

;--- print number in AX, decimal

_wordout_d proc

	push ax
	push bx
	push cx
	push dx
	mov bx,0001
	push bx
	mov bx,0010
	push bx
	mov bx,0100
	push bx
	mov bx,1000
	push bx
	mov bx,10000
	push bx
	mov ch,0
nextdigit:
	mov cl,'0' - 1
	pop bx
@@:
	inc cl
	sub ax,bx
	jnc @B
	add ax,bx
	cmp cl,'0'		;current digit <> 0?
	jnz print
	cmp ch,0		;already printed a digit?
	jnz print
	cmp bx,1
	jnz noprint		;is it the last digit?
print:
	push ax
	mov al,cl
	call _putchar
	pop ax
	mov ch,01		;a digit was printed
noprint:
	cmp bx,0001
	jnz nextdigit
	pop dx
	pop cx
	pop bx
	pop ax
	ret
_wordout_d endp

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
	sub eax,cs:[si]
	jnc @B
	add eax,cs:[si]
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

tab1 dd 1000000000,100000000,10000000,1000000,100000,10000,1000,100,10,1
MAXDWDIGITS equ ($ - tab1) shr 2

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
	jnz _putchar

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
@@:
	push ax
	mov al,'%'
	call _putchar
	pop ax
	jmp _putchar
printf_s:						;%s : near16 string
	@getwordfromstack ax
	push ax
	call _strout
	retn
printf_ls:						;%ls display far16 string
	push ds
	@getwordfromstack ds
	@getwordfromstack ax
	push ax
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
printf_u:						;%x : word
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

_crout proc
	push offset szlf
	call _strout
	ret
_crout endp

_TEXT ends

