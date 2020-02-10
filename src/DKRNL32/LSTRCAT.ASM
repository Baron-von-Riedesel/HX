
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc

	.CODE

lstrcat proc string1:ptr byte,string2:ptr byte
lstrcat endp

lstrcatA proc uses esi edi string1:ptr byte,string2:ptr byte

	xor eax,eax
	or ecx,-1
	mov edi,string2
	repne scasb
	push ecx
	mov edi,string1
	repne scasb
	dec edi
	pop ecx
	not ecx
	mov esi,string2
	shr ecx,1
	rep movsw
	adc ecx,ecx
	rep movsb
	mov eax,string1
	ret
lstrcatA endp

	end

