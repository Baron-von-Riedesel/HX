
	.386
if ?FLAT
	.model flat, stdcall
else
	.model small, stdcall
endif
	option casemap:none

	include winbase.inc

	.code

lstrcpyn proc strg1:ptr byte,strg2:ptr byte,len:dword
lstrcpyn endp

lstrcpynA proc uses esi edi strg1:ptr byte,strg2:ptr byte,len:dword

	mov edi,strg1	;destination
	mov esi,strg2	;source
	mov edx,edi
	mov ecx,len 	;get max size in WORDs
	jecxz done
@@:
	lodsb
	stosb
	or AL,AL		;end of string?
	loopnz @B
done:
	mov eax,edx
	ret
	align 4
lstrcpynA endp

	end

