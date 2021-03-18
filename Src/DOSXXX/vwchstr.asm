
		.286
        
	    externdef __0040H:abs
		externdef __B000H:abs

		public	VIOWRTCHARSTR

DOSXXX	segment word public 'CODE'

VIOWRTCHARSTR:
		push	BP
		mov		BP,SP
		push	DS
		push	SI
		push	DI
		push	CX
		push	offset __0040H
		pop	ES
		mov	AX,[BP+0Ah]
		mov	CL,ES:[04Ah]
		shl	CL,1
		mul	CL
		mov	DI,[BP+8]
		add	DI,DI
		add	DI,AX
		mov	AX,8000h
		cmp	word ptr ES:[063h],03B4h
		jne	@F
		xor	AX,AX
@@:
		add	AX,ES:[04Eh]
		add	DI,AX
		push offset __B000H
		pop	ES
		lds	SI,[BP+0Eh]
		mov	CX,[BP+0Ch]
@@:
		movsb
		inc	DI
		loop @B
		pop	CX
		pop	DI
		pop	SI
		pop	DS
		pop	BP
		retf 0Ch
DOSXXX	ends
	end
