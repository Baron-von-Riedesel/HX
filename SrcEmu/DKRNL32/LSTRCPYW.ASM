
;*** copy wide strings ***

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

lstrcpyW proc public uses esi edi strg1:ptr word,strg2:ptr word

	mov edi,strg2	;source string
	xor eax,eax
	@mov ecx,-1
	repne scasw
	inc ecx
	neg ecx
	mov eax,ecx 	;rc = string length (incl 0000)
	mov edi,strg1
	mov esi,strg2
	mov dl,cl
	shr ecx,1
	rep movsd
	adc ecx, ecx
	rep movsw
	@strace <"lstrcpyW(", strg1, ", ", strg2, ")=", eax>
	ret
lstrcpyW endp

	end

