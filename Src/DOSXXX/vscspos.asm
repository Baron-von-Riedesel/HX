
		.286
        
		externdef __0040H:abs

		public	VIOSETCURPOS

DOSXXX	segment word public 'CODE'	;size is 78

setcsr:		
		push DX
		mov	BL,AL
		mov	BH,0
		mov	AL,ES:[04Ah]
		mul	AH
		add	AX,BX
		shl	AX,1
		add	AX,ES:[04Eh]	;page offset
		shr	AX,1
		mov	DX,ES:[063h]	;CRT port
		mov	BL,AL
		mov	AL,0Eh
		out	DX,AX
		mov	AH,BL
		mov	AL,0Fh
		out	DX,AX
		pop	DX
		ret
        
VIOSETCURPOS:
		push BP
		mov	BP,SP
		push BX
		mov	AL,[BP+8]
		mov	AH,[BP+0Ah]
		push offset __0040H
		pop	ES
		mov	BL,ES:[062h]
		mov	BH,0
		shl	BX,1
		mov	ES:[BX+50h],AX
		call near ptr setcsr
		sub	AX,AX
		pop	BX
		mov	SP,BP
		pop	BP
		retf 6
        
DOSXXX	ends
	end
