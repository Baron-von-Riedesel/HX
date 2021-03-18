
	.286

	public DOSSLEEP

DOSXXX segment word public 'CODE'

DOSSLEEP proc far pascal uses cx dx dwInterval:dword

		mov cx,word ptr dwInterval+0
		mov dx,word ptr dwInterval+2
		mov ax,cx
		or ax,dx
		jnz @F
		mov ax,1680h
		int 2Fh
		jmp exit
@@:
		mov ax,cx
		mov cx,1000	;int 15h expects microseconds in CX:DX
		mul cx
		mov cx,ax
		xchg cx,dx
		mov ah,86h
		int 15h
exit:
		xor ax,ax
		ret
DOSSLEEP endp

DOSXXX ends

	end
