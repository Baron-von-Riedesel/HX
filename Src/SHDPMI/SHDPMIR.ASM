
;--- simple DOS TSR which eats memory below 10000h

        .286
        .MODEL SMALL
        .386

		.stack 1024
        
        .CODE

oldint2f	dd 0

myint2f  proc far
   	  	cmp		eax,"MI00"
        jnz		@F
        cmp		ebx,"SHDP"
        jz		found
@@:        
        jmp     cs:[oldint2f]
found:
		xchg	eax, ebx
        mov		cx, cs
        iret
myint2f endp

AlreadyInstalled proc		        
        mov ebx,"SHDP"
   	  	mov eax,"MI00"
        int 2Fh
        cmp eax, "SHDP"
        ret
AlreadyInstalled endp

resident	equ $

main    proc c

		mov 	di, es		;PSP -> di

        mov     bx,ss
        sub     bx,di
        mov		ax,sp
        shr		ax,4
        add		bx,ax
        mov     ah,4Ah
        int     21h

		mov		si,80h
		mov		cl,es:[si]
        .if (cl)
        	inc si
        	.while (cl && (byte ptr es:[si] == ' '))
            	inc si
                dec cl
            .endw
        	mov ax,es:[si]
            .if ((al == '-') || (al == '/'))
            	or ah,20h
                .if ((ah == '?') || (ah == 'h'))
                	jmp disphelp
                .elseif (ah == 'u')
					call AlreadyInstalled
                    jnz notinstalled
                    sub cx, 10h
                    mov es, cx
                    mov es:[0016h],ds
                    mov word ptr es:[000Ah], offset myexit
                    mov es:[000Ch], cs
                    mov eax, ds:[002Eh]
                    sub ax, 20h
                    mov es:[002Eh], eax
                    lds dx, es:[100h]
                    mov ax,252fh
                    int 21h
                    mov bx, es
                    mov ah, 50h
                    int 21h
myexit:                    
                    mov ax,4c00h
                    int 21h
                .endif
                jmp invaloption
            .endif
        .endif

		call AlreadyInstalled
        jz isinstalled
        
        mov ax,3306h
        int 21h
        cmp bx,3205h
        jz isnt
        mov ax,1600h
        int 2fh
        cmp al,3
        jnb iswin9x

		mov		ah,52h
        int		21h
        mov		bx, es:[bx-2]
        
        .while (bx < 1000h)
        	mov es, bx
            mov cx, es:[0003]
            mov ax, es
            add ax, cx
            inc ax
            .if (word ptr es:[0001] == 0)
            	mov es:[0001],di
	            .if (ax > 1000h)
                	mov si, ax
    	        	mov dl,es:[0]
        	    	mov cx, 1000h
            	    sub ax, cx
	                mov byte ptr es:[0],'M'
    	            sub word ptr es:[3], ax
                	mov es, cx
            	    mov es:[0000],dl
                    dec ax
	                mov es:[0003],ax
    	            mov word ptr es:[0001],0
                    mov ax, si
        	    .endif
            .endif
            mov bx, ax
        .endw
        
		mov		ax,352Fh
        int     21h
        mov     word ptr cs:[oldint2f+0],bx
        mov     word ptr cs:[oldint2f+2],es
        push	cs
        pop		ds
        mov		dx,offset myint2f
        mov		ax,252fh
        int     21h

        mov     dx,ss
        sub     dx,di
        mov		ax,sp
        shr		ax,4
        add		dx,ax
        mov     ax,3100h
        int     21h
notinstalled:
		mov		dx,offset szMsg3
        jmp     @F
invaloption:        
disphelp:
		mov		dx,offset szHelp
        jmp		@F
iswin9x:
isnt:
		mov		dx,offset szMsg2
        jmp     @F
isinstalled:
		mov		dx,offset szMsg1
@@:     
		push	cs
        pop		ds
        mov     ah,9
        int     21h
exit:   
		mov		ax,4c00h
        int     21h
main    endp

szMsg1  db "SHDPMIR already installed",13,10,'$'
szMsg2  db "No need to install SHDPMIR in a DOS box",13,10,'$'
szMsg3  db "SHDPMIR is not installed",13,10,'$'
szHelp  db "SHDPMIR reserves all DOS memory below address 10000h",13,10
        db "It is only required if SHDPMI is called with option -d.",13,10
        db "It is not very useful as a standalone program.",13,10
        db "usage: SHDPMIR <-u>",13,10
        db "  -u: uninstall",13,10
        db '$'

        END main
