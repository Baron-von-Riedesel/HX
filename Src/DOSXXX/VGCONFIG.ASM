

		.286
        public  VIOGETCONFIG

DOSXXX  segment word public 'CODE'

VIOGETCONFIG:
        push    BP
        mov     BP,SP
        push    BX
        push    CX
        push    DX
        push    DS
        push    ES
        mov     AH,0Fh	;get mode
        int     10h
        xor     DX,DX
        cmp     AL,7	;80x25 mono?
        je      vgatext
        inc     DX
        cmp     AL,2	;80x25
        je      vgatext
        cmp     AL,3	;80x25
        je      vgatext
        mov     DL,5
        cmp     AL,8	;
        je      vgatext
        cmp     AL,0Eh
        mov     AX,0FFFFh
        jne     exit
vgatext:
		xchg    DH,DL
        mov     AX,01A00h
        int     10h
        cmp     AL,01Ah
        jne     tryega
        cmp     BL,7
        je      isvga
        cmp     BL,8
        je      isvga
        cmp     BL,4
        je      isega
        cmp     BL,5
        jne     ismdacga
isega:
		mov     DL,2
        jmp     setret
isvga:
		mov     DL,3
        jmp     setret
tryega:
		mov     AH,12h
        mov     BL,10h
        int     10h
        cmp     BL,10h
        jne     isega
ismdacga:
		cmp     DH,1
        jne     setret
        inc     DX
setret:
        lds     BX,[BP+8]
        xor     AH,AH
        mov     AL,DL
        mov     [BX+2],AX	;adapter type
        mov     AL,DH
        mov     [BX+4],AX	;display type
if 0        
        mov     AX,1
        mov     [BX+2],AX	;set CGA
        mov     [BX+4],AX	;set color display
endif        
        xor     AX,AX
exit:    
		pop     ES
        pop     DS
        pop     DX
        pop     CX
        pop     BX
        pop     BP
        retf    8
DOSXXX  ends

        end

