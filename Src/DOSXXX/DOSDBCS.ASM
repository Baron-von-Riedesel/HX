

		.286
        
        public  DOSGETDBCSEV

DOSXXX  segment word public 'CODE'

;--- parameter:
;--- bp+0E: [inp] WORD size of DBCS table
;--- bp+0A: [inp] FAR16 ptr to country code/code page
;--- bp+06: [out] FAR16 ptr to DBCS table

;--- returns AX=0 if ok

DOSGETDBCSEV:
        push    BP
        mov     BP,SP
        push    BX
        push    CX
        push    DI
        push    DS
        push    DX
        push    ES
        push    SI

;--- int 21h, ax=6300h returns DBCS ptr in DS:SI
;--- so save these values before call
;--- and then check if they have been modified.
;--- Carry Flag is not an indicator for success/failure for this function

		mov		BX,DS
        mov		CX,SI

        mov     AX,06300h
        int     21h
        
        les     DI,[BP+6]
        
        mov     DX,DS
        cmp     BX,DX
        je      nosupp
        cmp     CX,SI
        je      nosupp
        
        mov     CX,[BP+0Eh]
        shr		cx,1
        jcxz	done
@@:     
        lodsw
        stosw
        and		ax,ax
        loopnz  @B
        jmp		done
nosupp:
        mov     CX,[BP+0Eh]
        cmp     CX,2
        jb      done
        mov     word ptr es:[DI],0	;a pair of 00,00 marks end of DBCS table

done:
        xor     AX,AX
        
        pop     SI
        pop     ES
        pop     DX
        pop     DS
        pop     DI
        pop     CX
        pop     BX
        pop     BP
        retf    0Ah
DOSXXX  ends

        end

