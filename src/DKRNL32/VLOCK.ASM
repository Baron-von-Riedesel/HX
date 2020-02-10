
;--- implements:
;--- + VirtualLock()
;--- + VirtualUnlock()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

VirtualLock proc public pStart:dword, dwSize:dword

	@strace <"VirtualLock(", pStart, ", ", dwSize, ")">
	xor eax,eax
	pushad
	mov cx,word ptr pStart+0
	mov bx,word ptr pStart+2
	mov di,word ptr dwSize+0
	mov si,word ptr dwSize+2
	mov ax,0600h
	int 31h
	popad
	jc @F
	inc eax
@@:
	ret
	align 4
VirtualLock endp

VirtualUnlock proc public pStart:dword, dwSize:dword

	@strace <"VirtualUnlock(", pStart, ", ", dwSize, ")">
	xor eax,eax
	pushad
	mov cx,word ptr pStart+0
	mov bx,word ptr pStart+2
	mov di,word ptr dwSize+0
	mov si,word ptr dwSize+2
	mov ax,0601h
	int 31h
	popad
	jc @F
	inc eax
@@:
	ret
	align 4
VirtualUnlock endp

end

