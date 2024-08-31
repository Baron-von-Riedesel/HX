
	.286

	public DOSDEVCONFIG

DOSXXX segment word public 'CODE'

ERROR_INVALID_PARAMETER equ 0057h
DI_LPT equ 0
DI_COM equ 1
DI_FD  equ 2
DI_FPU equ 3
DI_SM  equ 4	;submodel
DI_MOD equ 5	;model
DI_VID equ 6	;display adapter type

DOSDEVCONFIG proc far pascal uses ds dx bx devinfo:far ptr, item:word, parm:word

	int 11h
	lds BX,devinfo
	mov cx,item
	xor ax,ax
	.if cx == DI_LPT
		shr ah,6
		mov byte ptr [bx],ah
	.elseif cx == DI_COM
		shr ah,1
		and ah,7
		mov byte ptr [bx],ah
	.elseif cx == DI_FD
	    .if (al & 1 )
			and al,0C0h
			shr al,6
		.else
			mov al,0
		.endif
		mov byte ptr [bx],al
	.elseif cx == DI_FPU
		shr al,1
		and al,1
		mov byte ptr [bx],al
	.elseif cx == DI_SM
		mov byte ptr [bx],0FCh
	.elseif cx == DI_MOD
		mov byte ptr [bx],0
	.elseif cx == DI_VID
		mov byte ptr [bx],1
	.else
	   mov AX,ERROR_INVALID_PARAMETER
	.endif
exit:
	ret
DOSDEVCONFIG endp

DOSXXX ends

	end
