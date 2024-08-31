
		.286
        
		public	DOSWRITE
    
DOSXXX	segment word public 'CODE'

handle	equ <BP+10h>
buffer	equ <BP+0Ch>
wSize 	equ <BP+0Ah>
lpWritten equ <BP+06h>

DOSWRITE:
		push	BP
		mov		BP,SP
		push	DS
		push	BX
		push	CX
		push	DX
		push	SI
		mov	BX,[handle]
		lds	DX,[buffer]
		mov	CX,[wSize]
		cmp	BX,4		;printer?
		jne	normalfile
		push CX			;save length twice
		push CX
		mov	AL,01Ah		;Ctrl-Z
		mov	SI,DX
nextitem:
		jcxz done
		repne scasb
		jne	done
		pop	CX
		push CX
		mov	AH,040h
		int	21h
		pop	CX
		sub	CX,AX
		mov	DL,01Ah
		mov	AH,5
		int	21h
		dec	CX
		push CX
		mov	DX,SI
		inc	DX
		jmp nextitem
done:
		pop	CX
normalfile:
		mov	AH,040h
		int	21h
		rcl	CX,1
		cmp	BX,4
		rcr	CX,1
		jne	@F
		pop	AX		;if printer, get length
@@:	
		lds	BX,[lpWritten]
		mov	[BX],AX
		jb	@F
		xor	AX,AX
@@:
		pop	SI
		pop	DX
		pop	CX
		pop	BX
		pop	DS
		pop	BP
		retf 0Ch
DOSXXX	ends

	end
