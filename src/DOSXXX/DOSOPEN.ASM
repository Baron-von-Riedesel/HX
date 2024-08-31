
		.286

		public	DOSOPEN
        
DOSXXX	segment word public 'CODE'

DOSOPEN:
		push	BP
		mov	BP,SP
		push	BX
		push	CX
		push	DS
		push	DX
		lds	DX,[BP+1Ch]
		mov	AL,[BP+0Ch]
		test	AL,012h
		jne	@F
		cmp	AL,1
		je	openfile
		mov	AX,0Ch
		jmp exit2
@@:	
		xor	CX,CX
		mov	AX,03C00h	;create file
		int	21h
		jb	error
		mov	BX,AX
		mov	AH,03Eh		;close file
		int	21h
		jb	exit2
openfile:
		mov	AL,[BP+0Ah]
		and	AL,077h
		mov	AH,03Dh		;open file
		int	21h
		jb	error
		lds	BX,[BP+18h]
		mov	[BX],AX
		xor	AX,AX
		jmp exit2
error:		
		push	SI
		push	DI
		push	ES
		push	DS
		mov	SI,CX
		mov	AH,030h		;get dos version
		int	21h
		cmp	AL,3
		mov	AX,SI
		jb	@F
		mov	AH,059h
		xor	BX,BX
		int	21h
@@:	
		pop	DS
		pop	ES
		pop	DI
		pop	SI
exit2:	
		pop	DX
		pop	DS
		pop	CX
		pop	BX
		pop	BP
		retf 01Ah
DOSXXX	ends

	end
