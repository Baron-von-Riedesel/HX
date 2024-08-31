
		.286
		public	DOSFILELOCKS
    
DOSXXX	segment word public 'CODE'

;--- DosFileLocks(wHandle, lpqwUnlockRange, lpqwLockRange);

DOSFILELOCKS:
		push	BP
		mov		BP,SP
		push	BX
		push	CX
		push	DX
		push	DI
		push	SI
		push	DS
		lds		SI,[BP+0Ah]	;lpqwUnlockRange
        mov		ax,ds
		or		AX,SI
		je	unlockdone
		mov	BX,[BP+0Eh]
		mov	DX,[SI+0]
		mov	CX,[SI+2]
		mov	DI,[SI+4]
		mov	SI,[SI+6]
		mov	AX,05C01h
		int	21h
		jb	exit
unlockdone:	
		lds	SI,[BP+6]	;lpqwLockRange
        mov ax,ds
		or	AX,SI
		je	exit
		mov	BX,[BP+0Eh]
		mov	DX,[SI+0]
		mov	CX,[SI+2]
		mov	DI,[SI+4]
		mov	SI,[SI+6]
		mov	AX,05C00h
		int	21h
		jb	exit
		xor	AX,AX
exit:	
		pop	DS
		pop	SI
		pop	DI
		pop	DX
		pop	CX
		pop	BX
		mov	SP,BP
		pop	BP
		retf	0Ah
DOSXXX	ends

	end
