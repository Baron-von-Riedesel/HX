
;*** this once was a critical part for MS Cobol support.
;*** returning 0 was interpreted: runs in DOS (whatever mode)
;*** - call dossetsighandler/interrupts 16/1b/23
;*** - read command line

		.286

        public  DOSGETMACHINEMODE

DOSXXX  segment word public 'CODE'

DOSGETMACHINEMODE:
        push    BP
        mov     BP,SP
        push    DI
        push    ES
        les     DI,[BP+6]
        mov     AL,00h     ;00=dos,01=os/2,ff=windows
;        mov		al,1		;protected mode
        stosb
        xor     AX,AX
        pop     ES
        pop     DI
        pop     BP
        retf    4
DOSXXX  ends

        end

