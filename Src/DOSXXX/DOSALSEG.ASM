
;--- alloc memory (max 64 kB)
;--- DosAllocSeg(wSize, lpwSelector, wFlags);

		.286

		public	DOSALLOCSEG
    
DOSXXX	segment word public 'CODE'

DOSALLOCSEG proc far pascal uses bx cx wSize:word, lpwSelector:far16 ptr word, wFlags:word

		mov	BX,wSize
		add	BX,0Fh
		shr	BX,4
		or	BX,BX
		jne	@F
		mov	BX,01000h
@@:	
		mov	AH,048h
		int	21h
		jb	exit
		push DS
		lds	BX,lpwSelector
		mov	[BX],AX
		pop	DS
		xor	AX,AX
exit:	
		ret
        
DOSALLOCSEG endp

DOSXXX	ends

	end
