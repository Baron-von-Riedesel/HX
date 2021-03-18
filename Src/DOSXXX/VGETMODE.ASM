
        .286

		externdef __0000H:ABS

        public  VIOGETMODE

DOSXXX  segment word public 'CODE'

VIOGETMODE:
        push    BP
        mov     BP,SP
        push    BX
        push    CX
        push    DX
        push    SI
        push    DS
        push    ES

        lds     SI,[BP+8]
        push    __0000H
        pop     es
        mov     ax,es:[044ah]
        mov     [SI+4],AX      ;Columns
        mov     al,es:[0484h]
        xor     ah,ah
        mov     [SI+6],AX      ;Rows 
        mov     al,1
        mov     [SI+2],AL      ;Type: 1=text mode/3=graph mode
        mov     al,4
        mov     [SI+3],AL      ;Color: 16 colors
        
        xor     AX,AX

        pop     ES
        pop     DS
        pop     SI
        pop     DX
        pop     CX
        pop     BX
        mov     SP,BP
        pop     BP
        retf    6
DOSXXX  ends

end

