
		.286
		public	VIOGETCURTYPE
        
DOSXXX	segment word public 'CODE'

VIOGETCURTYPE:
		push	BP
		mov	BP,SP
		push	DS
		push	SI
		push	BX
		push	CX
		push	DX
		lds	SI,[BP+8]
		mov	AH,3
		xor	BH,BH
		int	10h
		xor	AH,AH
		mov	AL,CH
		and	AL,01Fh
		mov	[SI+0],AX
		mov	AL,CL
		and	AL,01Fh
		mov	[SI+2],AX
		xor	AX,AX
		mov	[SI+4],AX
		mov	AX,0
		mov	[SI+6],AX
		pop	DX
		pop	CX
		pop	BX
		pop	SI
		pop	DS
		pop	BP
		retf 6

DOSXXX	ends

	end
