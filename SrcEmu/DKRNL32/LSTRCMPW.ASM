
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc

	.code

lstrcmpW  proc uses esi edi strg1:ptr WORD,strg2:ptr WORD

	mov esi,strg1
	mov edi,strg2
	xor eax,eax
	@mov ecx,-1
	repne scasw
	not ecx
	mov edi,strg2
	repz cmpsw
	je @F
	sbb eAX,eAX
	sbb eAX,-1
@@:
	ret
lstrcmpW  endp

	end
