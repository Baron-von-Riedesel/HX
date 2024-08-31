
		.286
		
        public	DOSQHANDTYPE
        
DOSXXX  segment word public 'CODE'

DOSQHANDTYPE:
		push	BP
		mov	BP,SP
		push	ES
		push	DI
		push	DX
		mov	BX,[BP+0Eh]
		les	DI,[BP+0Ah]
		xor	AX,AX
		mov	AH,044h
		int	21h
		mov	AX,1
		jb	exit
		test DL,080h	;device or file?
		jne	@F
		dec	AX
@@:
		stosb
		xor	AX,AX
exit:
		pop	DX
		pop	DI
		pop	ES
		pop	BP
		retf	0Ah
DOSXXX  ends

	end
