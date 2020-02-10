
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP	group _TEXT
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

;--- currently just 1 help stack is allocated
;--- this may cause reentrancy problems

	.DATA

g_mystack	dd 0

	.CODE

;--- get a 4 kB stack (for int 23h and stack exceptions
;--- out: NC + eax=stack

gethelperstack proc public
	mov eax, g_mystack
	and eax,eax
	jnz done
	pushad
	mov ax,0501h
	mov bx,0000h
	mov cx,1000h
	int 31h
	jc error
	push bx
	push cx
	pop eax
	add eax,1000h
ife ?FLAT
	invoke __lin2based
endif
	mov g_mystack,eax
	clc
error:
	popad
	mov eax, g_mystack
done:
	ret
	align 4
gethelperstack endp

;--- EAX = helperstack + 1000h

freehelperstack proc public
	ret
freehelperstack endp

	END

