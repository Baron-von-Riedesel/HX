
;*** clear huge memory ( dpmild16, GlobalAlloc emulation )

	.286

externdef __AHINCR:far
BLOCKSIZE equ 8000h

_TEXT segment word public 'CODE'

_hmemset proc far pascal uses di dst:dword, wValue:word, dwSize:dword

	les di, dst
	mov bx, word ptr dwSize+0
	mov dx, word ptr dwSize+2
	cld
nextblock:
	mov ax,di
	neg ax
	mov cx,bx	; CX = min(size,0x8000)
	and dx,dx
	jz	@F
	mov cx, BLOCKSIZE
@@:
	jcxz done
	cmp ax,cx	; CX = min(CX,AX)
	jnc @F
	and ax,ax
	jz	@F
	mov cx,ax
@@:
	sub bx,cx
	sbb dx,0
	shr cx,1
	mov al,byte ptr wValue
	mov ah,al
	rep stosw
	adc cl,ch
	rep stosb
	mov ax,bx		; check if done
	or	ax,dx
	jz	done
	and di,di
	jnz nextblock	;----> next block
	mov ax,es
	add ax,offset __AHINCR
	mov es,ax
	jmp nextblock
done:
	mov ax,word ptr dst+0
	mov dx,word ptr dst+2
	ret

_hmemset endp

_TEXT ends

	end
