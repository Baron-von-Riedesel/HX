
;*** load a program with int 21h, ax=4b01
;*** this will bypass hxldr32

	.286
	.MODEL SMALL, stdcall
	.386
	option casemap:none

	.stack 512

EXECP	struct
envir	dw ?
pcmdl	dw ?
seg1	dw ?
ofs2	dw ?
seg2	dw ?
ofs3	dw ?
seg3	dw ?
sssp	dd ?
csip	dd ?
EXECP	ends

	.CODE

main proc c

local execp:EXECP
local szPgm[128]:byte

	mov ax,es:[2Ch]
	mov execp.envir, ax
	mov execp.pcmdl,80h
	mov execp.seg1,es
	mov execp.ofs2,5Ch
	mov execp.seg2,es
	mov execp.ofs3,6Ch
	mov execp.seg3,es

	mov si,0080h
	mov cl,es:[si]
	.if (!cl)
		jmp error2
	.endif
	inc si
	.while (cl)
		mov al,es:[si]
		.break .if (al > ' ')
		inc si
		dec cl
	.endw
	lea di,szPgm
	mov ah,0
	mov ch,0
	.while (cl)
		mov al,es:[si]
		.if (al == '"')
			xor ah,1
		.else
			.if (!ah)
				.break .if (al <= ' ')
			.endif
			mov ss:[di],al
			.if (al == '.')
				inc ch
			.endif
			inc di
		.endif
		inc si
		dec cl
	.endw
	.if (!ch)
		mov eax, "EXE."
		mov ss:[di],eax
		add di,4
	.endif
	mov al,0
	mov ss:[di],al

	mov di,0080h
	mov es:[di],cl
	inc cl
	inc di
	.while (cl)
		mov al,es:[si]
		mov es:[di],al
		inc si
		inc di
		dec cl
	.endw

	lea bx,execp
	push ss
	pop es
	lea dx,szPgm
	push ss
	pop ds
	mov ax,4B01h
	int 21h
	jc error1
	mov si,word ptr execp.csip+0
	mov di,word ptr execp.csip+2
	lss sp,execp.sssp
	mov ah,62h
	int 21h
	pop ax				;for subfunc 01 the value for AX is pushed
	push di
	push si
	mov es,bx
	mov ds,bx
	mov ds:[000Ah],offset retexec
	mov ds:[000Ch],cs
	retf
retexec:
	mov ah,4ch
	int 21h
error1:
	mov ah,9
	push cs
	pop ds
	mov dx,offset szErr1
	int 21h
	ret
error2:
	mov ah,9
	push cs
	pop ds
	mov dx,offset szErr2
	int 21h
	ret

main endp

szErr1	db "load error",13,10,'$'
szErr2	db "HXDOSLD loads a program bypassing HXLDR32",13,10
		db "usage: HXDOSLD program_name <parameters>",13,10
		db '$'

start:
	mov cx,ds
	mov ax,ss
	sub ax,cx
	shl ax,4
	mov cx,sp
	shr cx,4
	inc cx
	add ax,cx
	mov bx,ax
	mov ah,4Ah
	int 21h
	call main
	mov ah,4ch
	int 21h

	END start
