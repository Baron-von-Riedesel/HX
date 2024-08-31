
;*** DOSQFILEINFO

	.286

LEVEL1 struct
filedate dw ?
filetime dw ?
fileaccdate dw ?
fileacctime dw ?
writaccdate dw ?
writacctime dw ?
filesize dd ?
filealloc dd ?
fileattrib dw ?
LEVEL1 ends

LEVEL2 struct
	LEVEL1 <>
cbList dw ?
LEVEL2 ends

LEVEL3 struct
       dw ?
LEVEL3 ends

DOSXXX	segment	byte public 'CODE'

DOSQFILEINFO proc far pascal uses ds bx cx dx si handle:word, infolevel:word, buffer:far ptr, buffersize:word

local dwOldPos:dword

	mov	bx,handle
    mov ax,infolevel
    lds si,buffer
    cmp ax,1
    jz lev1
    cmp ax,2
    jz lev2
    cmp ax,3
    jz lev3
    mov ax,124
    jmp exit
lev1:
	mov ax,5700h
    int 21h
    jc exit
    mov [si].LEVEL1.writaccdate,dx
    mov [si].LEVEL1.writacctime,cx
	mov ax,5704h
    int 21h
    jc @F
    mov [si].LEVEL1.fileaccdate,dx
    mov [si].LEVEL1.fileacctime,cx
@@:    
	push si
	mov ax,5706h
    int 21h
    pop si
    jc @F
    mov [si].LEVEL1.filedate,dx
    mov [si].LEVEL1.filetime,cx
@@:
	call getfsize
    mov word ptr [si].LEVEL1.filesize+0,ax
    mov word ptr [si].LEVEL1.filesize+2,dx
    mov word ptr [si].LEVEL1.filealloc+0,ax
    mov word ptr [si].LEVEL1.filealloc+2,dx

    mov [si].LEVEL1.fileattrib, 0

	xor ax,ax
	jmp exit
lev2:
	mov ax,5
	jmp exit
lev3:
	mov ax,5
exit:
	ret
    
getfsize:
	xor cx,cx
    xor dx,dx
	mov ax,4201h
    int 21h
    mov word ptr dwOldPos+2,dx
    mov word ptr dwOldPos+0,ax
	xor cx,cx
    xor dx,dx
    mov ax,4202h
    int 21h
    push dx
    push ax
    mov cx,word ptr dwOldPos+2
    mov dx,word ptr dwOldPos+0
    mov ax,4200h
    int 21h
    pop ax
    pop dx
    retn

DOSQFILEINFO endp

DOSXXX	ends

	end
