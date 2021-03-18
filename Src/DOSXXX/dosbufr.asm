
		.286
		public	DOSBUFRESET
        
DOSXXX	segment word public 'CODE'

DOSBUFRESET:
		push	BP
		mov		BP,SP
		push	BX
		push	CX
		mov	AH,030h		;get version
		int	21h
		mov	BX,[BP+6]	;handle == -1?
		inc	BX
		je	diskreset
		dec	BX
		cmp	AL,3
		ja	dos33
		je	dos3
diskreset:	
		mov	AH,0Dh		;disk reset
		int	21h
		jmp done
dos3:
		cmp	AH,30		;dos 3.3?
		jae	dos33
		mov	AH,045h		;dup file handle
		int	21h
		jb	diskreset
        mov bx,ax		
		mov	AH,03Eh		;close duplicate handle
		int	21h
		jmp done
dos33:					;Dos 3.3+
		mov	AH,068h
		int	21h
        jc  exit
done:	
		xor	AX,AX
exit:	
		pop	CX
		pop	BX
		pop	BP
		retf	2
DOSXXX	ends
	end
