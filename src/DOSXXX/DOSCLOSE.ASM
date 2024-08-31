
		.286

	public	DOSCLOSE
    
DOSXXX	segment word public 'CODE'

DOSCLOSE:
		push BP
		mov	BP,SP
		push BX
		mov	BX,[BP+6]
		mov	AH,03Eh
		int	21h
		pop	BX
		pop	BP
		jb	@F
		xor	AX,AX
@@:
		retf 2
DOSXXX	ends

	end
