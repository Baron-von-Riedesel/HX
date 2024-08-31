
		.286
		public	DOSDELETE

DOSXXX	segment word public 'CODE'

;--- DosDelete(FAR16 PTR lpPath, DWORD reserved);

DOSDELETE:
		push	BP
		mov		BP,SP
		push	DX
		push	DS
		lds	DX,	[BP+0Ah]
		mov	AH,041h
		int	21h
		jb	exit
		xor	AX,AX
exit:   
		pop	DS
		pop	DX
		pop	BP
		retf	8
DOSXXX	ends

	end
