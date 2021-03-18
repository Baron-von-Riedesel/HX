
;*** DosSetSigHandler(farproc routine,             [bp+18]
;                     farproc _far * PrevAddress,  [bp+14]
;                     int _far * PrevAction,       [bp+10]
;                     int Action,                  [bp+8]
;                     int SigNumber)               [bp+6]

;*** Action: 0=install default action
;            1=ignore signal
;            2=routine receives control
;            3=signal will cause an error
;            4=
;*** SigNum: 1=Ctrl-C
;            3=program terminated
;            4=Ctrl-Break

		.286

        public  DOSSETSIGHANDLER

DOSXXX segment word public 'CODE'

externdef   __csalias:word

        assume cs:DOSXXX

tab0    label dword
        dd 0                ;ctrl-c
        dd 0                ;<free>
        dd 0                ;terminate
        dd 0                ;ctrl-break

tab1    label dword
        dd 0
        dd 0
        dd 0
        dd 0

actab   label word          ;action (0,1,2)
        dw offset action0
        dw offset action1
        dw offset action2

DOSSETSIGHANDLER:
        push    BP
        mov     BP,SP
        push    BX
        push	CX
        push    DX
        push    SI
        push	DI
        push    ES
        cmp     word ptr [BP+8],2   ;action (0,1,2)
        jbe     @F
        mov     AX,1
        jmp     exit        ;error 1
@@:
        mov     BX,[BP+6]   ;signumber (1,3,4)
        cmp     BX,1        ;CTRL-C ?
        je      @F
        cmp     BX,3        ;programm terminated ?
        je      @F
        cmp     BX,4        ;CTRL-Break?
        je      @F
        mov     AX,0BBh		;error BBh 
        jmp     exit
@@:
        dec     BX			;convert to 0,2,3	
        shl     BX,2
        les     DI,[BP+0Eh]	;prev address pointer supplied?
        mov     AX,ES
        or      AX,AX
        je      @F
        mov     AX,word ptr cs:[BX+tab0+0]
        stosw
        mov     AX,word ptr cs:[BX+tab0+2]
        stosw
@@:
		les     DI,[BP+0Ah]	;pointer for prev action supplied?
        mov     AX,ES
        or      AX,AX
        je      prevactiondone
        cmp     word ptr cs:[BX+tab1+2],0   ;59
        jne     @F
        xor     AX,AX
        jmp     storeit
@@:
        cmp     word ptr cs:[BX+tab0+2],0   ;65
        jne     @F
        mov     AX,1
        jmp     storeit
@@:
		mov     AX,2
storeit:
		stosw

prevactiondone:
		mov     SI,[BP+8]              ;action
        shl     SI,1
        jmp     word ptr cs:[SI+actab]

action0:                               ;system default action!
        cmp     word ptr cs:[BX+tab1+2],0
        je      ok
        call    resintvec
        jmp     ok
action1:                               ;ignore signal
        cmp     word ptr cs:[BX+tab1+2],0
        jne     @F
        call    setintvec
@@:
        push    ds
        mov     ds,cs:[__csalias]
        mov     word ptr ds:[BX+tab0+0],0
        mov     word ptr ds:[BX+tab0+2],0
        pop     ds
        jmp     ok
action2:                               ;action 2 (receive control)
        cmp     word ptr cs:[BX+tab1+2],0
        jne     @F
        call    setintvec
@@:
		mov     AX,[BP+12h]
        mov     DX,[BP+14h]
        push    ds
        mov     ds,cs:[__csalias]
        mov     word ptr ds:[BX+tab0+0],AX
        mov     word ptr ds:[BX+tab0+2],DX
        pop     ds
ok:
		xor     AX,AX	;ok
exit:
		pop     ES
        pop		DI
        pop     SI
        pop     DX
        pop		CX
        pop     BX
        mov     SP,BP
        pop     BP
        retf    010h

;--- set int vectors
;--- inp: BX=0,8,12

setintvec:
		cli
        call    getintno	;get int no to set in AL
        push	ax
        push	bx
        mov     bl,al
        mov     ax,0204h
        int     31h
        pop		bx
        push    ds
        mov     ds,cs:[__csalias]
        mov     word ptr ds:[BX+tab1+0],DX
        mov     word ptr ds:[BX+tab1+2],CX
        pop     ds
        call    getintval	;get value in DX:AX
        mov		cx,dx
        mov		dx,ax
        pop		ax
        push	bx
        mov		bl,al
        mov		ax,0205h
        int		31h
        pop		bx
        sti
        ret


;--- reset int vectors
;--- inp: BX=0,8,12

resintvec:
		cli
        call    getintno      ;get int in AL
        push    ds
        mov     ds,cs:[__csalias]
        xor		dx,dx
        xor		cx,dx
        xchg    DX,word ptr [BX+tab1+0]
        xchg    CX,word ptr [BX+tab1+2]
        push    bx
        mov     bl,al
        mov     ax,0205h
        int     31h
        pop     bx
        pop		ds
        xor     AX,AX
        sti
        ret

;**************************************************

intnojmptbl:
        dw      int16
        dw      0000
        dw      0000
        dw      0000
        dw      int21
        dw      0000
        dw      int1b

;--- inp: BX == 0, 8, 12
;*** AL = Int No

getintno:
        jmp     word ptr cs:[BX+intnojmptbl]
int16:
        mov     al,16h
        ret
int21:
        mov     al,21h
        ret
int1b:
        mov     al,1Bh
        ret

;***************************************************

intnojmptbl2:
        dw      getdef1
        dw      0000
        dw      0000
        dw      0000
        dw      getdef2
        dw      0000
        dw      getdef3
        
;--- inp: BX == 0, 8, 12
;--- out: DX:AX

getintval:
        jmp     word ptr cs:[BX+intnojmptbl2]
getdef1:
        mov     DX,CS
        mov     AX,offset event1
        ret
getdef2:
        mov     DX,CS
        mov     AX,offset event2
        ret
getdef3:
        mov     DX,CS
        mov     AX,offset event3
        ret

defvec  label dword
        dd 0

event1:
        pushf
        cmp     AL,3
        je      @F
        popf
        jmp     dword ptr cs:[tab1+0*4]

@@:     mov     AX,01C0Dh	;scan+ascii code for RETURN
        push    AX
        push    BX
        mov     BX,0*4
        jmp     dispatchevent

event2:
        pushf
        cmp     AH,04Ch		;program termination?
        je      @F
        popf
        jmp     dword ptr cs:[tab1+2*4]

@@:     push    AX
        push    BX
        mov     BX,2*4
        jmp     dispatchevent
event3:
        pushf
        push    AX
        push    BX
        mov     BX,3*4
        jmp     dispatchevent

;--- event caught, now call event proc

dispatchevent:
        cmp     word ptr cs:[BX+tab0+2],0
        je      defhandler
        push    CX
        push    DX
        push    SI
        push    DI
        push    BP
        push    DS
        push    ES
        push    AX
        mov     AX,BX
        shr     AX,2
        inc     AX
        push    AX
        call    dword ptr cs:[BX+tab0]	
        push    ds
        mov     ds,cs:[__csalias]
        assume  ds:DOSXXX
        mov     AX,word ptr ds:[BX+tab1+0]
        mov     word ptr ds:[defvec+0],AX
        mov     AX,word ptr ds:[BX+tab1+2]
        mov     word ptr ds:[defvec+2],AX
        pop     ds
        assume  ds:nothing
        cmp     BX,8
        jne     @F
        call    resintvec
@@:
		pop     ES
        pop     DS
        pop     BP
        pop     DI
        pop     SI
        pop     DX
        pop     CX
defhandler:
		pop     BX
        pop     AX
        popf
        jmp     dword ptr cs:[defvec]

DOSXXX ends

end

