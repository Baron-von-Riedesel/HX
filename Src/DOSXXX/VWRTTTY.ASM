
 		.286

		public	VIOWRTTTY

DOSXXX  segment word public 'CODE'

VIOWRTTTY:
		push	BP
		mov	BP,SP
        push	BX
		push	CX
		push	DX
		push	SI
		push	DS
		lds	SI,[BP+0Ah]
		mov	CX,[BP+8]
		jcxz done
nextitem:
		lodsb
		int	29h
		loop nextitem
done:		
		xor	AX,AX
		pop	DS
		pop	SI
		pop	DX
		pop	CX
        pop BX
		pop	BP
		retf 8
        
DOSXXX	ends

	end
