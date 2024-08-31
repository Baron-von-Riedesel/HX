
		.286
		public	DOSDUPHANDLE

;--- DosDupHandle(WORD wHandle, FAR16 PTR lpHandle);

DOSXXX	segment word public 'CODE'

DOSDUPHANDLE:
		push	BP
		mov		BP,SP
		push	BX
		mov		BX,	[BP+0Ah]
		mov	AH,45h
		int	21h
		jb	exit
        push DS
        lds BX,[BP+6]
        mov [BX],AX
        pop DS
		xor	AX,AX
exit:   
		pop	BX
		pop	BP
		retf 6
DOSXXX	ends

	end
