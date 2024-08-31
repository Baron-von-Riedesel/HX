
		.286

		public	KBDGETSTATUS
        
DOSXXX	segment word public 'CODE'

KBDGETSTATUS:
		push	BP
		mov		BP,SP
		push	BX
		push	CX
		push	DS
		push	SI
		push	ES
		push	DX
		mov	AX,0178h
		lds	SI,[BP+8]
		cmp	word ptr [SI],000Ah
		jb	@F
		mov	AH,012h
		int	016h
		mov	[SI+8],AX
		xor	AX,AX
@@:
		pop	DX
		pop	ES
		pop	SI
		pop	DS
		pop	CX
		pop	BX
		pop	BP
		retf	6

DOSXXX	ends

	end
