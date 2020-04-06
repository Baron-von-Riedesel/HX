
;*** copy strings ***

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

lstrcpy proc public uses esi edi strg1:ptr byte,strg2:ptr byte
lstrcpy endp

lstrcpyA proc public uses esi edi strg1:ptr byte,strg2:ptr byte

	mov edi,strg2	;source string
	xor al,al
	@mov ecx,-1
	repne scasb
	inc ecx
	neg ecx
	mov eax,ecx 	;rc = string length (incl 00)
	mov edi,strg1
	mov esi,strg2
	mov dl,cl
	shr ecx,2
	rep movsd
	mov cl,dl
	and cl,3
	rep movsb
	ret
	align 4
lstrcpyA endp

	end

