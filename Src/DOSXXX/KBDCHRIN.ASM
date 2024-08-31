
		.286
		public	KBDCHARIN

DOSXXX	segment word public 'CODE'

KBDCHARIN:
		push	BP
		mov	BP,SP
		push	BX
		push	CX
		push	SI
		mov	CX,[BP+8]
		jcxz @F
		mov	AH,11h
		int	016h
		jne	@F
		xor	BX,BX
		jmp store
@@:
		mov	AH,10h
		int	16h
		mov	BX,40h
store:	
		push DS
		lds	SI,[BP+0Ah]
		mov	[SI+0],AX
		mov	[SI+2],BL
		mov	AH,12h		;get shift key state
		int	16h
		mov	[SI+4],AX
		mov	AH,2Ch		;get time (possibly better to get it with int 1A)
		int	21h
		mov	[SI+6],CX
		mov	[SI+8],DX
		pop	DS
		xor	AX,AX
		pop	SI
		pop	CX
		pop	BX
		pop	BP
		retf	8
DOSXXX	ends

	end
