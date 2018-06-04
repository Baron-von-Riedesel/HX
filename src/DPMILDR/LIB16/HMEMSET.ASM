
;*** copy huge array

		.286

externdef __AHINCR:far

_TEXT   segment word public 'CODE'

_hmemset proc far pascal uses di ziel:dword, wert:word, count:dword

        les     di,ziel
        mov     bx,word ptr count+0
        mov     dx,word ptr count+2
        cld
sm1:
        mov     ax,di
        neg     ax
        mov     cx,bx      ;CX = min(laenge,0x8000)
        and     dx,dx
        jz      @F
        mov     cx,08000h
@@:
        jcxz    sm2        ;----> fertig
        cmp     ax,cx      ;CX = min(CX,AX)
        jnc     @F
        and     ax,ax
        jz      @F
        mov     cx,ax
@@:
        sub     bx,cx
        sbb     dx,0
        shr     cx,1
        mov     al,byte ptr wert
        mov     ah,al
        rep     stosw
        adc     cl,ch
        rep     stosb
        mov     ax,bx      ;ueberpruefen ob fertig
        or      ax,dx      ;denn die folgenden operationen sind kritisch
        jz      sm2
        and     di,di
        jnz     sm1        ;----> naechster block
        mov     ax,es
        add     ax,offset __AHINCR
        mov     es,ax
        jmp     sm1
sm2:
        mov     ax,word ptr ziel+0
        mov     dx,word ptr ziel+2
        ret

_hmemset endp

_TEXT   ends

        end
