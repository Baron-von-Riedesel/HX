;;  _API16 DosQFileMode(PBYTE pFpath, PWORD pStatus, DWORD dResv1);
;;
;;  For HX 16-bit Dos Extender (DPMILD16)
;;
;;  Export from: DOSCALLS.75 [04Bh]
;;

	.286

DOSXXX	segment	word public 'CODE'

	public	DOSQFILEMODE

DOSQFILEMODE:

;*  All API's are called far, so LCODE assumed and P := 6

P	equ	[bp+06h]

pFpath	equ	P+08h
pStatus	equ	P+04h
dResv1	equ	P+00h

	push	bp			;sp = sp+2
	mov	bp,sp

	push	DS			;preserve regs
	push	dx
	push	cx
	push	si

	lds	dx,pFpath		;ptr filename/path

	mov	ax,4300h		;21,4300h - Get Attributes
	int	21H	

	lds	si,pStatus		;ptr to return status
	mov	word ptr [si],cx	;shove it in there
	jc	@1f			;error?
	xor	ax,ax			;rc = 0
	jmp	@2f
@1f:
;***
;*  Not checking for DOS 3+ here since I'm *pretty* sure
;*  the target DPMI Extender requires that anyway <g>

	mov	ah,59h			;21,59h - Get Extended Error
	int	21h

;*  Also going to ignore 83:ERROR_FAIL_I24 (critical errors)
;*  though they really should get their own RC values.
;***
@2f:
	pop	si		;restore all
	pop	cx
	pop	dx
	pop	DS

	pop	bp
	retf	12

DOSXXX	ends

	end
