
		.286

_TEXT	segment word public 'CODE'

LSTRLEN proc far pascal

		mov		dx,di
		pop		ax		;IP
		pop		cx		;CS
		pop		di		;offset(string)
		pop		es		;seg(string)
		push	cx		;CS
		push	ax		;IP
		cld
		xor 	ax,ax
		mov 	cx,-1
		repne	scasb
		mov		di,dx
		mov 	ax,cx
		not 	ax
		dec 	ax
		retf
LSTRLEN	endp

_TEXT	ends

        end

