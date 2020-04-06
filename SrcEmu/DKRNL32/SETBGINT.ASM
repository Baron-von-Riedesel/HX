
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include dkrnl32.inc

?USEI10 equ 0

	.code

;*** set 16 background colors instead of blinking
;*** internal function

SetIntensityBackground proc

if ?USEI10
	push ebx
	mov ax,1003h
	mov bx,0000
	int 10h
	pop ebx
else
	mov dx, [VIOCRTPORT]
	add dl,6				;3d4 -> 3da, 3b4 -> 3ba
	mov ecx,8000h
@@:
	in al,dx			   ;attribute mode control register
	test al,1				 ;display enable (horz or vert retrace)?
	loopz @B

	mov al,10h
	mov dx,3c0h
	out dx,al
	inc dx
	in al,dx
	and al,0F7h
	dec dx
	out dx,al
	mov al,20h
	out dx,al
endif
	ret

SetIntensityBackground endp

	end

