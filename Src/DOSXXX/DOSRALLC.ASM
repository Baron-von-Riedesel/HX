
		.286

DOSXXX  segment word public 'CODE'

;--- DosReallocSeg reallocs only until 64 kB

GlobalReAlloc proto far pascal :WORD, :DWORD, :WORD

DOSREALLOCSEG proc far pascal public wSize:WORD, wSel:WORD

		pusha
		push es
if 1
		xor dx,dx
		mov ax,wSize
		cmp ax,1			;convert size 0 to size 64 kb
		adc dx,dx
		invoke	GlobalReAlloc, wSel, dx::ax,0
		.if (ax)
			xor ax,ax
		.else
;			mov ax,-1
			mov ax,0008		;ERROR_NOT_ENOUGH_MEMORY
		.endif
else
		mov bx,wSize
		add bx,15
		shr bx,4
		and bx,bx
		jnz @F
		mov bx,1000h
@@:
		mov es,wSel
		mov ah,4ah
		int 21h
;		mov ax,-1		;AX contains an error code already
		jc @F
		xor ax,ax
@@:
endif
		mov [bp-2],ax	;set AX in POPA on stack
		pop es
		popa
		ret
DOSREALLOCSEG endp

DOSXXX ends

		end
