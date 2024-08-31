
;*** startup code for DOSCALLS.DLL

?CSALIAS	equ 1	;alloc a CS alias selector on init
?CRTEXITS	equ 0

		.286
        .DOSSEG

if ?CRTEXITS
        public  __NMSG_TEXT
        public  __NMSG_WRITE
        public  __cintDIV
        public  __fptrap
        public  __amsg_exit
endif        
        public  __nullcheck
        public  __osexit

if 0
        public  __acrtused2
__acrtused2     equ 9876h
endif

DOSXXX  segment word public 'CODE'

if ?CSALIAS

	public  __csalias
    
__csalias dw 0

endif

if ?CRTEXITS
dummy   proc

__cintdiv::
        mov     AL,0FEh
        db      0BBh
__fptrap::
        mov     AL,0FDh
        db      0BBh
__amsg_exit::
        mov     AL,0FCh
        mov     ah,4Ch
        int		21h
__NMSG_TEXT::
__NMSG_WRITE::
        xor     AX,AX
        ret     2

dummy   endp

endif

;*** windows entry

LibEntry	proc far pascal

if ?CSALIAS
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
endif
        mov     ax,1
        ret
LibEntry	endp

__nullcheck:
___aDBretaddr:
if 1
        retf
else
        ret
endif
__osexit:
		mov ax,4cffh
        int 21h

;*** windows exit

WEP		proc far pascal wCode:WORD

if ?CSALIAS
        mov     bx,cs:[__csalias]
        and     bx,bx
        jz      @F
        mov     ax,1
        int     31h
@@:
endif
        mov     ax,1
        ret
WEP		endp

DOSXXX  ends

end     LibEntry

