
		.286

		public	DOSGETENV

DOSXXX  segment word public 'CODE'

DOSGETENV:
		push	BP
		mov	BP,SP
		push	BX
		push	CX
		push	DI
		push	DS
		push	ES
		mov	AH,062h
		int	21h
		mov	ES,BX
		mov	ES,ES:[02Ch]
		xor	DI,DI
		xor	AL,AL
		mov	CX,0FFFFh
nextline:		
		repne scasb
		scasb
		jne	nextline
		lds	BX,[BP+0Ah]
		mov	[BX],ES
		lds	BX,[BP+6]
		add	DI,2
		mov	[BX],DI
		xor	AX,AX
		pop	ES
		pop	DS
		pop	DI
		pop	CX
		pop	BX
		pop	BP
		retf	8

DOSXXX  ends

	end
