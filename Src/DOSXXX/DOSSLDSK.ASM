
		.286
		public	DOSSELECTDISK

DOSXXX segment word public 'CODE'

DOSSELECTDISK:
		push	BP
		mov	BP,SP
		push	DX
		mov	DX,[BP+6]
		dec	DX
		mov	AH,0Eh
		int	21h
		mov	AH,19h
		int	21h
		cmp	AL,DL
		jne	failed
		xor	AX,AX
		jmp exit
failed:
		mov	AX,0Fh
exit:
		pop	DX
		pop	BP
		retf 2

DOSXXX ends

	end
