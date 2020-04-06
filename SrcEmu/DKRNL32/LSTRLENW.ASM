
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc

	.CODE

lstrlenW proc public pStr:ptr WORD

	mov edx,edi
	mov edi,pStr
	xor ecx,ecx
	dec ecx
	mov ax,00
	repne scasw
	not ECX
	dec ECX
	mov eax,ecx
	mov edi,edx
	ret
	align 4
lstrlenW endp

	end

