
		.286

		public DOSHUGESHIFT, DOSHUGEINCR, DOSGETHUGESHIFT, DOSALLOCHUGE
        
DOSHUGESHIFT equ 0003
DOSHUGEINCR  equ 0008
        
DOSXXX  segment word public 'CODE'

DOSGETHUGESHIFT proc far pascal public pShift:far16 ptr WORD
		push	ds
        push	bx
		mov		ax,3
        lds		bx,pShift
        mov		[bx],ax
        xor		ax,ax
        pop		bx
		pop		ds        
        ret
DOSGETHUGESHIFT endp

DOSALLOCHUGE proc far pascal public uses bx cx si di wSegmentCount:WORD, wLastCount:WORD,
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
            inc word ptr dwLA+2
            mov ax,7
            int 31h
            mov cx,0
            mov dx,-1
            cmp wSelectors,1
            jnz @F
            mov dx,wLastCount
@@:            
            mov ax,8
            int 31h
            add bx,8
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
        
DOSALLOCHUGE endp

DOSXXX  ends

end

