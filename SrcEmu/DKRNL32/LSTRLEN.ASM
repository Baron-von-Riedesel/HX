
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc

	.CODE

lstrlen proc public pStr:ptr byte
lstrlen endp

lstrlenA proc public pStr:ptr byte

	mov edx,edi
	mov edi,pStr
	xor ecx,ecx
	dec ecx
	mov al,00
	repne scasb
	not ECX
	dec ECX
	mov eax,ecx
	mov edi,edx
	ret
	align 4
lstrlenA endp

	end
