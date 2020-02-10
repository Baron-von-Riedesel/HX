
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.code

lstrcmp proc public uses esi edi strg1:ptr byte,strg2:ptr byte
lstrcmp endp

lstrcmpA proc public uses esi edi strg1:ptr byte,strg2:ptr byte

	mov esi,strg1
	mov edi,strg2
	xor eax,eax
	@mov ecx,-1
	repne scasb
	not ecx
	sub edi,ecx
	repz cmpsb
	je @F
	sbb eAX,eAX
	sbb eAX,-1
@@:
	ret
lstrcmpA endp

	end
