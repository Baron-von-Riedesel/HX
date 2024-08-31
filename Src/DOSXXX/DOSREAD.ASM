
	.286

	public	DOSREAD

_DATA	segment word public 'DATA'

linebuff label byte
	db	0ffh
bCnt db  0h
    db  100h dup (0)
wOfs dw  0
_DATA	ends

DOSXXX	segment para public 'CODE'

DOSREAD:
		push	BP
		mov	BP,SP
		push	BX
		push	CX
		push	DX
		push	DS
		push	SI
		mov	BX,[BP+10h]
		mov	CX,[BP+0Ah]
		or	BX,BX		;stdin?
		jne	nobuffer
		cmp	CX,1		;more than 1 char?
		ja	nobuffer
		mov	AX,seg linebuff
		mov	DS,AX
        assume DS:_DATA
		mov	AL,[bCnt]
		or	AL,AL
		jne	@F
		mov	DX,offset linebuff
		mov	AH,0Ah
		int	21h
		mov	AX,offset linebuff
		mov	[wOfs],AX
		inc	[bCnt]
@@:	
		mov	SI,[wOfs]
		mov	AL,[si+2]
		cmp	AL,0Dh
		jne	@F
		mov	AL,0Ah
@@:	
		dec	[bCnt]
		inc	[wOfs]
		lds	SI,[BP+0Ch]
		mov	[SI],AL
		mov	AX,1
		jmp ok
nobuffer:
		lds	DX,[BP+0Ch]
		mov	AH,03Fh
		int	21h
		jb	exit
ok:	
		lds	SI,[BP+6]
		mov	[SI],AX
		xor	AX,AX
exit:	
		pop	SI
		pop	DS
		pop	DX
		pop	CX
		pop	BX
		pop	BP
		retf 0Ch
DOSXXX	ends

	end
