
		.286

		public	DOSCHGFILEPTR
    
DOSXXX	segment word public 'CODE'

handle	equ <bp+10h>

DOSCHGFILEPTR:
		push	BP
		mov		BP,SP
		push	BX
		push	CX
		push	DX
		push	DS
		mov	BX,[handle]
		mov	CX,[BP+0Eh]
		mov	DX,[BP+0Ch]
		mov	AX,[BP+0Ah]
		mov	AH,042h
		int	21h
		jb	exit
		lds	BX,[BP+6]
		mov	[BX+0],AX
		mov	[BX+2],DX
		xor	AX,AX
exit:
		pop	DS
		pop	DX
		pop	CX
		pop	BX
		pop	BP
		retf	0Ch
DOSXXX	ends

	end
