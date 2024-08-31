
		.286
		public	VIOSETCURTYPE
        
DOSXXX	segment word public 'CODE'

VIOSETCURTYPE:
		push	BP
		mov	BP,SP
		push	DS
		push	SI
		push	DX
		push	BX
		push	CX
		lds	SI,[BP+8]
		mov	AX,[SI+0]
		and	AL,01Fh
		mov	CH,AL
		mov	AX,[SI+2]
		and	AL,01Fh
		mov	CL,AL
		mov	AH,1
		int	010h
		xor	AX,AX
		pop	CX
		pop	BX
		pop	DX
		pop	SI
		pop	DS
		pop	BP
		retf	6
DOSXXX	ends
	end
