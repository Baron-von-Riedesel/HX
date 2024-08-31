
	.286
	public DOSNEWSIZE

DOSXXX segment word public 'CODE'

DOSNEWSIZE:
	push BP
	mov	BP,SP
	push BX
	push CX
	push DX
	mov	BX,[BP+0Ah]
	mov	CX,[BP+8]
	mov	DX,[BP+6]
	mov	AX,04200h
	int	21h
	jb	exit
	mov	CX,0		;write 0 bytes
	mov	AH,040h
	int	21h
	jb	exit
	xor	AX,AX
exit:
	pop	DX
	pop	CX
	pop	BX
	pop	BP
	retf 6
DOSXXX ends
	end
