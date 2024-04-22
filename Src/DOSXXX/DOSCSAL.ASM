
;--- unlike DPMI function 000A, which always returns a data selector,
;--- DosCreateCSAlias() will return a code selector.

	.286

DOSXXX segment word public 'CODE'

DosCreateCSAlias proc far pascal public uses es bx cx di wSrc:word, pwAlias:far16 ptr word

local desc[8]:byte

	mov bx, wSrc
	lea di, desc
	push ss
	pop es
	mov ax, 000Bh		; get descriptor
	int 31h
	jc err
	mov cx, 1
	xor ax, ax			; alloc 1 descriptor
	int 31h
	jc err
	mov bx, ax
	or [desc+5], 8		; change to code
	mov ax, 000Ch
	int 31h
	jc err2
	les bx, pwAlias
	mov es:[bx], ax
	xor ax, ax
	jmp exit
err2:
	mov ax, 1			; free descriptor
	int 31h
err:
	mov ax,5
exit:
	ret
DosCreateCSAlias endp

DOSXXX ends

end

