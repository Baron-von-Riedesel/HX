
		.286
		public	DOSERROR
    
DOSXXX	segment word public 'CODE'

DOSERROR:
		xor		ax,ax
		retf	2

DOSXXX	ends

	end
