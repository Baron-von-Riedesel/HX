
		.286
        
		externdef __0040H:abs
		externdef __B000H:abs

		public	VIOWRTNATTR

;--- fill n cells with an attribute

DOSXXX	segment word public 'CODE'

VIOWRTNATTR:
		push	BP
		mov	BP,SP
		push	ES
		push	DI
		push	DS
		push	SI
		push	DX
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
		mov	AX,08000h
		cmp	word ptr ES:[063h],03B4h
		jne	@F
		xor	AX,AX
@@:	
		add	AX,ES:[04Eh]	;add video page offset
		add	DI,AX
		push	offset __B000H
		pop	ES
		lds	SI,[BP+0Eh]
		mov	AL,[SI]			;get attribute to write
		mov	CX,[BP+0Ch]
        jcxz done
@@:
		inc	DI
		stosb
		loop @B
done:        
		pop	CX
		pop	DX
		pop	SI
		pop	DS
		pop	DI
		pop	ES
		xor	AX,AX
		pop	BP
		retf	0Ch
DOSXXX	ends
	end
