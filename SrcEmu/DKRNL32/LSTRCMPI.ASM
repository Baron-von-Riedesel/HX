
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

lstrcmpi proc public uses esi edi strg1:ptr byte,strg2:ptr byte
lstrcmpi endp

lstrcmpiA proc public uses esi edi strg1:ptr byte,strg2:ptr byte

	mov edi,strg1
	@mov ecx,-1
	xor al,al
	repnz scasb
	not ecx
	mov edx,ecx
	@mov ecx,-1
	mov edi,strg2
	repnz scasb
	not ecx
	cmp ecx,edx
	jb @F
	mov ecx,edx
@@:
	mov esi,strg1
	mov edi,strg2
@@:
	lodsb
	mov ah,[edi]
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
lstrcmpiA endp

	end

