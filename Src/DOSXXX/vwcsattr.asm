
		.286
        
	    externdef __0040H:abs
		externdef __B000H:abs

		public	VIOWRTCHARSTRATT

DOSXXX	segment word public 'CODE'

VIOWRTCHARSTRATT:
		push	BP
		mov	BP,SP
		push	DS
		push	SI
		push	DI
		push	CX
		push	offset __0040H
		pop	ES
		mov	AX,[BP+0Eh]
		mov	CL,ES:[04Ah]
		shl	CL,1
		mul	CL
		mov	DI,[BP+0Ch]
		add	DI,DI
		add	DI,AX
		mov	AX,08000h
		cmp	word ptr ES:[063h],03B4h
		jne	@F
		xor	AX,AX
@@:	
		add	AX,ES:[04Eh]
		add	DI,AX
		lds	SI,[BP+8]
		mov	AH,[SI]
		push offset __B000H
		pop	ES
		lds	SI,[BP+12h]
		mov	CX,[BP+10h]
        jcxz done
@@:	
		lodsb
		stosw
		loop @B
done:
		xor ax,ax
		pop	CX
		pop	DI
		pop	SI
		pop	DS
		pop	BP
		retf 010h
DOSXXX	ends
	end
