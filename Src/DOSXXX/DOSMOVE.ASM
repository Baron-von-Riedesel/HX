

		.286
        
		public	DOSMOVE
    
DOSXXX	segment word public 'CODE'

DOSMOVE:
		push	BP
		mov		BP,SP
		push	DX
		push	DI
		push	DS
		push	ES
		lds		DX,[BP+0Eh]
		les		DI,[BP+0Ah]
		mov		AH,056h
		int		21h
		jb		exit
		xor		AX,AX
exit:	
		pop	ES
		pop	DS
		pop	DI
		pop	DX
		pop	BP
		retf	0Ch
DOSXXX	ends

	end
