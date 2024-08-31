
		.286
		public	KBDPEEK

DOSXXX	segment word public 'CODE'

KBDPEEK:
		push	BP
		mov		BP,SP
		push	BX
		push	CX
		push	SI
		mov	AH,011h
		int	016h
		jne	@F
		xor	BL,BL
		jmp kp_1
@@:	
		mov	BL,040h
kp_1:	
		push DS
		lds	SI,[BP+8]
		mov	[SI+0],AX
		mov	[SI+2],BL
		mov	AH,12h
		int	16h
		mov	[SI+4],AX
		xor	CX,CX
		xor	DX,DX
		mov	[SI+6],CX
		mov	[SI+8],DX
		pop	DS
		xor	AX,AX
		pop	SI
		pop	CX
		pop	BX
		pop	BP
		retf 6
DOSXXX	ends

	end
