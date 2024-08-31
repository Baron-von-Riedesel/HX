;;  _API16 DosSetVec(WORD wClass, PFUNC pNHan, PPFUNC ppOHan);
;;
;;  For HX 16-bit Dos Extender (DPMILD16)
;;
;;  Export from: DOSCALLS.89 [059h]
;;
	.286

DOSXXX segment byte public 'CODE'

	public DOSSETVEC

DOSSETVEC:

;*  All API's are called far, so LCODE assumed and P := 6

P	equ	[bp+06h]

wClass	equ	P+08h
pNHan	equ	P+04h
ppOHan	equ	P+00h

	push bp			;sp = sp+2
	mov bp,sp

	mov ax,wClass
;***
ifndef $NOCHECK
  if 1;def $OS2COMPAT
;*  The following block of code is optional. For full
;*  compatibility it should be included, but as this
;*  for Dos Extender it may be reasonable to omit it.
;
;  Check for validity. OS2V1 allows only Exceptions:
;
;    0 - Divide Fault
;    4 - INTO Overflow
;    5 - Bounds
;    6 - Invalid Op
;    7 - NDP Not Present
;   16 - NDP Exception

	cmp	ax,00h		; 00 - Divide
	je	@2f
	cmp	ax,04h		; 04 - INTO
	jb	@1f
	cmp	ax,07h		; 07 - NDP Not Present
	jbe	@2f
;   cmp	ax,10h		; 16 - NDP Exception
;   je	@2f
@1f:
	mov	ax,0032h	; ERROR_NOT_SUPPORTED
	jmp	@6f
@2f:
  endif
endif
;****
	push DS		;preserve regs
	push ES
	push bx
	push dx
	push si

	mov	ah,35h		; 21,35xx - Get Vector
	int	21h
	lds	si,ppOHan
if 1;ndef $NOCHECK
	mov	dx,DS
	or	dx,si
	jnz	@3f
	mov	ax,0057h	; ERROR_INVALID_PARAMETER
	jmp	@5f
@3f:
endif
	mov	[si+0],bx
	mov	[si+2],ES
	lds	dx,pNHan
ifndef $NOCHECK
;	mov	si,DS		; is it NULL?
;	or	si,dx
;	jnz	@4f
;	or	al,al		; DOS INT 0 can be NULL?!
;	jz	@4f
;	mov	ax,0001h	; ERROR_INVALID_FUNCTION
;	jmp	@5f
@4f:
endif
	mov	ah,25h		; 21,25xx - Set Vector
	int	21h
	xor	ax,ax		; rc 0
@5f:
	pop si		;restore all
	pop dx
	pop bx
	pop ES
	pop DS
@6f:
	pop bp
	retf 10

DOSXXX ends

	end
