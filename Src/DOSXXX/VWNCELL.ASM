
		.286
        
		externdef __0040H:abs
		externdef __B000H:abs

		public	VIOWRTNCELL

;--- fill n cells with a character + attribute pair

DOSXXX	segment word public 'CODE'

VIOWRTNCELL:
		push	BP
		mov		BP,SP
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
		push	offset __0040H
		pop	ES
		mov	AX,[BP+0Ah]
		mov	CL,ES:[04Ah]
		shl	CL,1
		mul	CL
		mov	DI,[BP+8]
		add	DI,DI
		add	DI,AX
		mov	AX,08000h
		cmp	word ptr ES:[063h],03B4h
		jne	@F
		xor	AX,AX
@@:	
		add	AX,ES:[04Eh]
		add	DI,AX
		push offset __B000H
		pop	ES
		lds	SI,[BP+0Eh]
		mov	AX,[SI]
		mov	CX,[BP+0Ch]
		rep stosw
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
