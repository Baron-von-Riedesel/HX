
;--- MZ format doesnt use DOSCALLS.ASM and therefore has no __csalias

		.286

		public __csalias

DOSXXX  segment word public 'CODE'
        
__csalias dw 0

_AllocCSAlias proc

        mov     bx,cs
        mov     ax,000Ah
        int     31h
        jc      @F
        push    ds
        mov     ds,ax
        assume  ds:DOSXXX
        mov     ds:[__csalias],ax
        pop     ds
@@:
		ret
_AllocCSAlias endp

DOSXXX  ends
	
    end
