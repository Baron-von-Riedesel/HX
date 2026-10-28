
		.286

		public DOSHUGESHIFT, DOSHUGEINCR, DOSGETHUGESHIFT, DosAllocHuge
        
DOSHUGESHIFT equ 0003
DOSHUGEINCR  equ 0008
        
DOSXXX  segment word public 'CODE'

DOSGETHUGESHIFT proc far pascal public uses ds bx pShift:far16 ptr WORD
        lds		bx,pShift
        mov		word ptr [bx],DOSHUGESHIFT
        xor		ax,ax
        ret
DOSGETHUGESHIFT endp

DosAllocHuge proc far pascal public uses bx cx si di wSegmentCount:WORD, wLastCount:WORD,
		pSelector:far16 ptr WORD, wSegMax:WORD, wFlags:WORD

local	wSelectors:WORD
local	dwLA:DWORD

		mov bx,wSegmentCount
        mov cx,wLastCount
        mov ax,501h
        int 31h			;modifies SI,DI
        jc  error
        mov word ptr dwLA+2,bx
        mov word ptr dwLA+0,cx

;--- alloc selector array for linear memory

        mov cx,wSegmentCount
        cmp wLastCount,1
        cmc
        adc cx,0
        mov wSelectors,cx
        cmp cx, wSegMax
        jnc @F
        mov cx, wSegMax
@@:        
        mov ax,0
        int 31h
        jc error2
        push ds
        lds bx,pSelector
        mov [bx],ax
        pop ds
        mov bx,ax
        .while (wSelectors)
            mov cx,word ptr dwLA+2
            mov dx,word ptr dwLA+0
            inc word ptr dwLA+2	; dwLA = dwLA + 10000h
            mov ax,7	;set base to CX:DX
            int 31h
            mov cx,0
            mov dx,-1
            cmp wSelectors,1
            jnz @F
            mov dx,wLastCount
@@:            
            mov ax,8	;set limit to either 0xffff or wLastCount
            int 31h
            add bx,DOSHUGEINCR
            dec wSelectors
        .endw
        xor ax,ax
exit:   
        ret
error2:
		mov ax,502h
        int 31h
error:        
		mov ax,8
        jmp exit
        
DosAllocHuge endp

DOSXXX  ends

end

