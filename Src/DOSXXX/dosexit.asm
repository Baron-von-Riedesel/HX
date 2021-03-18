
		.286

		public	DOSEXIT

DOSXXX	segment word public 'CODE'

DOSEXIT:
		mov	BP,SP
		mov	AX,[BP+4]
		or	AH,AH
		je	@F
		mov	AL,0FFh
@@:
		mov	AH,04Ch
		int	21h
        
DOSXXX	ends

	end
