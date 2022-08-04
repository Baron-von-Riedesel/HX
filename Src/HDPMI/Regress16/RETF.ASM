
;--- set trace flag, then execute RETF to a CS descriptor with P cleared.
;--- quite a few "emulators" have problems with that.

	.286
	.model small
	.stack 2048

?EXC1 equ 1

	.data

wCS   dw 0

text1 db "exc 01 occured",13,10,'$'
text2 db "exc 0B occured",13,10,'$'
text3 db "DPMI error occured ("
func  db '0'
      db ")",13,10,'$'
text4 db "back in track",13,10,'$'
text5 db "invalid code location reached!",13,10,'$'

IRETS struct
_ip	dw ?
_cs	dw ?
_fl	dw ?
IRETS ends

EXCS struct
	dd ?	;dpmi return addr
err dw ?	;error code
_ip	dw ?
_cs	dw ?
_fl	dw ?
_sp	dw ?
_ss	dw ?
EXCS ends

	.code

if ?EXC1
myexc1 proc
	pusha
	mov dx, offset text1
	mov ah, 9
	int 21h
	popa
	push bp
	mov bp, sp
	mov [bp+2].EXCS._fl, not 100h
	pop bp
	retf
myexc1 endp
endif

myexcb proc
	pusha
	mov dx, offset text2
	mov ah, 9
	int 21h
	mov bx, wCS
	mov cx, cs
	lar cx, cx
	shr cx, 8
	mov ax, 9
	int 31h
	popa
	retf
myexcb endp

main proc
	mov si, sp
	inc func
if ?EXC1
	mov bl, 1
	mov cx, cs
	mov dx, offset myexc1
	mov ax, 203h
	int 31h
	jc errdpmi
endif
	inc func
	mov bl, 0Bh
	mov cx, cs
	mov dx, offset myexcb
	mov ax, 203h
	int 31h
	jc errdpmi

;--- create a 64kB code descriptor, NP

	inc func
	mov cx, 1
	mov ax, 0
	int 31h
	jc errdpmi
	mov bx, ax
	mov wCS, ax

;--- set the same base as the current CS

	inc func
	push bx
	mov bx, cs
	mov ax, 6
	int 31h
	pop bx
	mov ax, 7
	int 31h
	jc errdpmi

	inc func
	mov cx, 0
	mov dx, -1
	mov ax, 8
	int 31h
	jc errdpmi

	inc func
	mov cx, cs
	lar cx, cx
	shr cx, 8
	and cl, 7Fh	;reset P bit
	mov ax, 9
	int 31h
	jc errdpmi

	push bx
	push offset cont1
if ?EXC1
	pushf
	mov bp, sp
	or word ptr [bp], 100h
	popf
endif
	retf
	mov dx, offset text5	; this code should NOT run!
	mov ah, 9
	int 21h
cont1:
	mov dx, offset text4
	mov ah, 9
	int 21h
	jmp exit
errdpmi:
	mov dx, offset text3
	mov ah, 9
	int 21h
exit:
	mov sp, si
	ret
main endp

start:
	mov ax, @data
	mov ds, ax
	mov bx, ss
	sub bx, ax
	shl bx, 4
	mov ss, ax
	add sp, bx
	mov cx, es
	sub ax, cx
	mov bx, sp
	shr bx, 4
	add bx, ax
	mov ah, 4Ah
	int 21h
	call initpm
	call main
	mov ax, 4c00h
	int 21h

	include initpm.inc

	end start
