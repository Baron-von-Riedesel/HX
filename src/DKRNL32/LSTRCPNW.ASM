
	.386
if ?FLAT
	.model flat, stdcall
else
	.model small, stdcall
endif
	option casemap:none

	include winbase.inc

	.code

lstrcpynW proc uses esi edi pDest:ptr word,pSrc:ptr word,len:dword

	mov edi,pDest	;destination
	mov esi,pSrc	;source
	mov edx,edi
	mov ecx,len 	;get output buffer size
	jecxz done
@@:
	lodsw
	stosw
	or AX,AX		;end of string?
	loopnz @B
done:
	mov eax,edx
	ret

lstrcpynW endp

	end

