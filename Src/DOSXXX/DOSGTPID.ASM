
		.286

		public	DOSGETPID
        
DOSXXX	segment word public 'CODE'

DOSGETPID:
		push	BP
		mov		BP,SP
		push	ES
		push	DI
        push	BX
        mov		ah,62h	;get PSP
        int		21h
        mov		ax,bx
		les		DI,[BP+6]
		stosw			;process id
		xor		AX,AX
		stosw			;thread id
		stosw			;parent process id
        pop BX
		pop	DI
		pop	ES
		pop	BP
		retf	4
DOSXXX	ends

	end
