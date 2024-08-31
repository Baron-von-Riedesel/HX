
		.286
		public	DOSQCURDISK

DOSXXX	segment word public 'CODE'

DOSQCURDISK:
		push	BP
		mov	BP,SP
		push	DS
		push	SI
		mov	AH,19h
		int	21h
		cbw
		inc	AX
		lds	SI,[BP+0Ah]
		mov	[SI],AX
		xor	AX,AX
		pop	SI
		pop	DS
		pop	BP
		retf	8
DOSXXX	ends
	end
