
        .286

        public  DOSALLOCSHRSEG
        public  DOSGETSHRSEG
if 0        
        public  FREESELECT
endif        

_data   segment word public 'DATA'
shrseg dw 0
_data   ends

DOSXXX  segment word public 'CODE'

        assume cs:DOSXXX

DOSALLOCSHRSEG:
        push    BP
        mov     BP,SP
        push    DS
        push    DI
        push    bx
        mov     AX,_data
        mov     ds,ax
        assume  ds:_data
        cmp     word ptr shrseg,0
        jz      @F
        mov     ax,00B7h
        jmp     sm1
@@:
        mov     bx,[bp+14]
        shr     bx,4
        inc     bx
        mov     ah,48h
        int     21h
        mov     bx,ax
        mov     ax,8
        jc      sm1
        mov     ax,_data
        mov     ds,ax
        mov     shrseg,bx
        lds     DI,[BP+6]
        mov     [DI],bx
        xor     AX,AX
sm1:
        pop     bx
        pop     DI
        pop     DS
        pop     BP
        retf    0Ah


DOSGETSHRSEG PROC FAR

        push    BP
        mov     BP,SP
        push    DS
        push    DI
        push    bx
        mov     AX,_data
        mov     ds,ax
        assume  ds:_data
        mov     bx,[shrseg]
        mov     ax,0002h
        and     bx,bx
        jz      @F
        lds     DI,[BP+6]
        mov     [DI],BX
        xor     AX,AX
@@:
        pop     bx
        pop     DI
        pop     DS
        pop     BP
        retf    8

DOSGETSHRSEG    ENDP

if 0
FREESELECT PROC FAR
        push    ds
        push    es
        mov     ax,_DATA
        mov     ds,ax
        assume  ds:_DATA
        mov     ax,[shrseg]
        and     ax,ax
        jz      @F
        mov     es,ax
        mov     ah,49h
        int     21h
@@:
        xor     ax,ax
        pop     es
        pop     ds
        retf
FREESELECT ENDP
endif

DOSXXX  ends

end

