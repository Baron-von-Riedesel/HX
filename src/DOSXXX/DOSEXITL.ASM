
        .286

        externdef DOSEXIT:far

        public  DOSEXITLIST

_DATA   segment word public 'DATA'

procad  dd 0                  ;address of exit proc
rc      dw 0                  ;RC
psp     dw 0                  ;PSP

_DATA   ends

DOSXXX  segment word public 'CODE'

stab    label word
        dw offset AddToList
        dw offset Remove
        dw offset Complete

vector  dd 0                  ;previous dos vector (21h)

DOSEXITLIST:
        push    BP
        mov     BP,SP
        push    DX
        push    SI
        push    DI
        push    ES
        push    ds
        mov     ax,_DATA
        mov     ds,ax
        
		assume ds:_DATA

        mov     SI,[BP+10]
        mov     AX,1
        cmp     si,3
        ja      exit            ;error
        dec     SI              ;0,1,2
        shl     SI,1
        jmp     cs:[SI+stab]

AddToList:                      ;add to termination list
        push    BX
        mov     AH,062h         ;get PSP
        int     21h
        mov     [psp],BX
        pop     BX
        cmp     word ptr cs:[vector+2],0
        jnz     @F
        call    setint21
@@:     mov     AX,[BP+6]       ;save address 
        mov     DX,[BP+8]
        mov     word ptr [procad+0],AX
        mov     word ptr [procad+2],DX
        jmp     done
Remove:                         ;remove from termination list
        cmp     word ptr cs:[vector+2],0
        je      done
        call    restoreint21    ;dos vector restore
        jmp     done
Complete:                       ;termination processing complete
        cmp     word ptr cs:[vector+2],0
        je      @F
        call    restoreint21
@@:
        push    1
        push    [rc]
        call    DOSEXIT
done:
		xor     AX,AX
exit:
        pop     ds
        pop     ES
        pop     DI
        pop     SI
        pop     DX
        mov     SP,BP
        pop     BP
        retf    6


savevektor proc near private

        push    bp
        mov     bp,sp
        mov     bx,cs
        mov     ax,000Ah	;get alias for CS
        int     31h
        jc      @F
        push    ds
        mov     ds,ax
        assume  ds:DOSXXX
        mov     ax,[bp+4]
        mov     word ptr [vector+0],ax
        mov     ax,[bp+6]
        mov     word ptr [vector+2],ax
        mov     bx,ds
        pop     ds
        assume  ds:_DATA
        mov     ax,1
        int     31h
@@:
        pop     bp
        ret     4
        
savevektor      endp

;*** add to termination list ***

setint21:
		mov     AX,03521h
        int     21h
        push    es
        push    bx
        call    savevektor
        push    DS
        push    CS
        pop     DS
        mov     DX,offset myint21
        mov     AX,02521h
        int     21h
        pop     DS
        ret

;*** routine raus ***

restoreint21:    
		push    DS
        mov     AX,02521h
        lds     DX,cs:[vector]
        int     21h
        pop     DS
        xor     AX,AX
        push    ax
        push    ax
        call    savevektor
        ret


;*** termination handler int 21 ***

myint21:
        pushf
        cmp     AH,04Ch
        jne     noterm
        push    ds
        push    AX
        mov     ax,_data
        mov     ds,ax
        push    BX
        mov     AH,062h
        int     21h
        cmp     word ptr [psp],BX
        pop     BX
        pop     AX
        je      itsus
        pop     ds
noterm:
		popf
        jmp     dword ptr CS:[vector]
itsus:
        mov     [rc],AX
        pop     ax
        popf
        push    word ptr [procad+2]
        push    word ptr [procad+0]
        mov     ds,ax
        retf
        
DOSXXX  ends

end

