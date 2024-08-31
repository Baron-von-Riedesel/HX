
		.286
        
		public	DOSGETVERSION
    
DOSXXX  segment word public 'CODE'

DOSGETVERSION:
		push	BP
		mov	BP,SP
		push	DS
		push	SI
		mov	AH,030h
		int	21h
		xchg	AH,AL
		lds	SI,[BP+6]
		mov	[SI],AX
		xor	AX,AX
		pop	SI
		pop	DS
		pop	BP
		retf 4
DOSXXX	ends

	end
