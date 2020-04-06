
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc

	.CODE

lstrcatW proc public uses esi edi string1:ptr word,string2:ptr word

	xor eax,eax
	or ecx,-1
	mov edi,string2
	repne scasw
	push ecx
	mov edi,string1
	repne scasw
	dec edi
	pop ecx
	not ecx
	mov esi,string2
	shr ecx,1
	rep movsd
	adc ecx,ecx
	rep movsw
	mov eax,string1
	ret
lstrcatW endp

	end

