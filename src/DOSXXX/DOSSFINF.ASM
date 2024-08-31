
;*** DOSSETFILEINFO

	.286

LEVEL1 struct
filedate dw ?
filetime dw ?
fileaccdate dw ?
fileacctime dw ?
writaccdate dw ?
writacctime dw ?
;filesize dd ?
;filealloc dd ?
;fileattrib dw ?
LEVEL1 ends

LEVEL2 struct
	LEVEL1 <>
cbList dw ?
LEVEL2 ends

LEVEL3 struct
       dw ?
LEVEL3 ends

DOSXXX segment byte public 'CODE'

DOSSETFILEINFO proc far pascal uses ds bx cx dx si handle:word, infolevel:word, buffer:far ptr, buffersize:word

	mov bx,handle
	mov ax,infolevel
	lds si,buffer
	cmp ax,1
	jz lev1
;	 cmp ax,2
;	 jz lev2
;	 cmp ax,3
;	 jz lev3
	mov ax,124
	jmp exit
lev1:
	mov dx,[si].LEVEL1.writaccdate
	mov cx,[si].LEVEL1.writacctime
	mov ax,5701h
	int 21h
	jc exit
	mov dx,[si].LEVEL1.fileaccdate
	mov cx,[si].LEVEL1.fileacctime
	mov ax,5705h
	int 21h
	mov dx,[si].LEVEL1.filedate
	mov cx,[si].LEVEL1.filetime
	push si
	mov si,100
	mov ax,5707h
	int 21h
	pop si
	xor ax,ax
exit:
	ret

DOSSETFILEINFO endp

DOSXXX ends

	end
