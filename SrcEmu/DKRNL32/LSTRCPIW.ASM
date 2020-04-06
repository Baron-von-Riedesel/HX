
	.386

if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc

	.CODE

lstrcmpiW proc public uses esi edi strg1:ptr WORD,strg2:ptr WORD

	mov edi,strg1
	@mov ecx,-1
	xor ax,ax
	repnz scasw
	not ecx
	mov edx,ecx
	@mov ecx,-1
	mov edi,strg2
	repnz scasw
	not ecx
	cmp ecx,edx
	jb @F
	mov ecx,edx
@@:
	mov esi,strg1
	mov edi,strg2
@@:
	lodsb
	inc esi
	mov ah,[edi]
	inc edi
	inc edi
	or ah,20h
	or al,20h
	cmp al,ah
	loope @B
	mov eax,ecx
	je @F
	sbb eAX,eAX
	sbb eAX,-1
@@:
	ret
lstrcmpiW endp

	end

