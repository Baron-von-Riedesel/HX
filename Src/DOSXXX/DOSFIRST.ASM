
		.286

	public	DOSFINDFIRST
	public	SETFINDBUF
	public	DOSFINDNEXT
	public	DOSFINDCLOSE

_DATA 	segment word public 'DATA'
FindBuffer 	db 43 dup (0)
_DATA 	ends

DOSXXX	segment word public 'CODE'

DOSFINDFIRST proc
		push	bp
        mov		bp,sp
        sub		sp,4
		push	DS
		push	ES
		push	SI
		push	DI
		push	BX
		push	CX
		push	DX
		mov	AX,[BP+6]
		les	BX,[BP+0Ah]
		xor	AX,AX
		xchg AX,ES:[BX]
		cmp	AX,1
		mov	AX,057h
		jne	exit
		lds	SI,[BP+16h]
		cmp	word ptr [SI],1
		jne	@F
		mov	DX,seg FindBuffer	;use default buffer
		mov	BX,offset FindBuffer
		jmp defbuff
@@:
		mov	BX,3		;alloc another 43 byte buffer
		mov	AH,048h
		int	21h
		mov	DX,AX
		mov	AX,071h
		jb	exit
		mov	[SI],DX
		xor	BX,BX
defbuff:
		mov	[BP-4],BX
		mov	[BP-2],DX
		lds	DX,[BP-4]
		mov	AH,01Ah		;set DTA
		int	21h
		lds	DX,[BP+1Ah]
		mov	CX,[BP+14h]
		mov	AH,04Eh		;dos findfirst
		int	21h
		jb	exit
		lds	SI,[BP-4]
		les	DI,[BP+10h]
		mov	CX,[BP+0Eh]
		call near ptr SETFINDBUF
		les	BX,[BP+0Ah]
		mov	word ptr ES:[BX],1
		xor	AX,AX
exit:
		pop	DX
		pop	CX
		pop	BX
		pop	DI
		pop	SI
		pop	ES
		pop	DS
		leave
		retf	018h
DOSFINDFIRST endp

DOSFINDNEXT proc
		push bp
        mov bp,sp
		push	DS
		push	ES
		push	SI
		push	DI
		push	BX
		push	CX
		push	DX
		les	BX,[BP+6]
		xor	AX,AX
		xchg AX,ES:[BX]
		cmp	AX,1
		mov	AX,057h
		jne	exit
		mov	AX,[BP+010h]
		xor	DX,DX
		cmp	AX,1
		jne	@F
		mov	AX,seg FindBuffer
		mov	DX,offset FindBuffer
@@:	
		mov	DS,AX
		mov	AH,01Ah
		int	21h
		mov	AH,04Fh
		int	21h
		jb	exit
		mov	SI,DX
		les	DI,[BP+0Ch]
		mov	CX,[BP+0Ah]
		call	near ptr SETFINDBUF
		les	BX,[BP+6]
		mov	word ptr ES:[BX],1
		xor	AX,AX
exit:
		pop	DX
		pop	CX
		pop	BX
		pop	DI
		pop	SI
		pop	ES
		pop	DS
		leave
		retf	0Ch
DOSFINDNEXT endp

DOSFINDCLOSE proc
		push bp
        mov bp,sp
		push	ES
		push	BX
		push	CX
		push	DX
		xor	DX,DX
		mov	AX,[BP+6]
		cmp	AX,1
		je	@F
		mov	ES,AX
		mov	AH,049h
		int	21h
		jae	@F
		mov	DX,6
@@:	
		xchg AX,DX
		pop	DX
		pop	CX
		pop	BX
		pop	ES
		leave
		retf	2
DOSFINDCLOSE endp

SETFINDBUF proc
		mov	AX,[SI+16h]
		mov	ES:[DI+0Ah],AX
		mov	AX,[SI+18h]
		mov	ES:[DI+08h],AX
		mov	AX,[SI+1Ah]
		mov	ES:[DI+0Ch],AX
		mov	AX,[SI+1Ch]
		mov	ES:[DI+0Eh],AX
		mov	AL,[SI+15h]
		xor	AH,AH
		mov	ES:[DI+14h],AX
		lea	SI,[SI+1Eh]
		lea	BX,[DI+16h]
		mov	CX,13
		lea	DI,[BX+1]
nextchar:
		lodsb
		stosb
		or	AL,AL
		loopne	nextchar
		lea	AX,[DI-1]
		sub	AX,BX
		dec	AX
		mov	ES:[BX],AL
		ret
SETFINDBUF endp
        
DOSXXX	ends

	end
