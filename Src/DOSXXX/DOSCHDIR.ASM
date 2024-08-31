
		.286
		public	DOSCHDIR

DOSXXX	segment word public 'CODE'

DOSCHDIR:
		push	BP
		mov		BP,SP
		push	DX
		push	DS
		lds		DX,[BP+0Ah]
		mov	AX,03B00h
		int	21h
		jb	exit
		xor AX,AX
exit:
		pop	DS
		pop	DX
		mov	SP,BP
		pop	BP
		retf	8
DOSXXX	ends

	end
