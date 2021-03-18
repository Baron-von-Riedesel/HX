
		.286
        
		externdef __0040H:abs
		externdef __B000H:abs

		public	VIOWRTCELLSTR

DOSXXX	segment word public 'CODE'

VIOWRTCELLSTR:
		push	BP
		mov	BP,SP
		xor	AX,AX
		cmp	word ptr [BP+0Ch],0
		je	exit2
		inc	AX
		push	ES
		push	DI
		push	DS
		push	SI
		push	DX
		push	CX
		push	BX
		push offset __0040H
		pop	ES
		mov	DX,8000h
		cmp	word ptr ES:[063h],03B4h
		jne	@F
		xor	DX,DX
@@:	
		add	DX,ES:[04Eh]
		push offset __B000H
		pop	ES
		mov	AX,[BP+0Ah]
		mov	CL,0A0h
		mul	CL
		mov	DI,[BP+8]
		add	DI,DI
		add	DI,AX
		add	DI,DX
		lds	SI,[BP+0Eh]
		mov	CX,[BP+0Ch]
		shr	CX,1
		rep	movsw
		pop	BX
		pop	CX
		pop	DX
		pop	SI
		pop	DS
		pop	DI
		pop	ES
		xor	AX,AX
exit2:	
		pop	BP
		retf 0Ch
DOSXXX	ends

	end
