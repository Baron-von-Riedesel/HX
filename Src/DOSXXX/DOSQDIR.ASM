
		.286

		public	DOSQCURDIR

DOSXXX	segment word public 'CODE'

;-- DosQCurDir(WORD drive, FAR16 lpBuffer, FAR16 lpSize);

;--- lpSize  = BP+06
;--- lpBuffer= BP+0A
;--- drive   = BP+0E

DOSQCURDIR:
		push	BP
		mov		BP,SP
		push	BX
		push	CX
		push	DX
		push	DS
		push	ES
		push	SI
		push	DI
        
        sub		sp,68
        
		lds	BX,[BP+6]
		mov	CX,[BX]			;get size of buffer (may be 0)
		mov	AX,SS
		mov	DS,AX
		mov	SI,SP
		mov	DX,[BP+0Eh]
		mov	AH,47h
		int	21h
		jb	exit
@@:        
        lodsb
        and al,al
        jnz @B
        mov ax,si
        sub ax,sp			;get size of curdir (incl term null)
        mov si,sp
        cmp cx,ax
        jb error
        mov cx,ax
		les	DI,[BP+0Ah]
        rep movsb
        xor ax,ax
        jmp exit
error:
		lds	BX,[BP+6]
		mov	[BX],AX
		mov	AX,2
exit:
		add SP,68
        
		pop	DI
		pop	SI
		pop	ES
		pop	DS
		pop	DX
		pop	CX
		pop	BX
		pop	BP
		retf 0Ah
DOSXXX	ends

	end
