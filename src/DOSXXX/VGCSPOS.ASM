
		.286
        
		externdef __0040H:abs

		public	VIOGETCURPOS
    
DOSXXX	segment word public 'CODE'

VIOGETCURPOS:
		push	BP
		mov	BP,SP
		push	BX
		push	DS
		push	SI
		push	offset __0040H
		pop	ES
		mov	BL,ES:[062h]	;current page
		mov	BH,0
		shl	BX,1
		mov	AH,0
		mov	AL,ES:[BX+50h]
		lds	SI,[BP+8]
		mov	[SI],AX
		mov	AL,ES:[BX+51h]
		lds	SI,[BP+0Ch]
		mov	[SI],AX
		sub	AX,AX
		pop	SI
		pop	DS
		pop	BX
		mov	SP,BP
		pop	BP
		retf	0Ah

DOSXXX	ends
	end
