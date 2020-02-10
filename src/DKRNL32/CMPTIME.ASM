
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

	.CODE

CompareFileTime proc public pFT1:ptr FILETIME, pFT2:ptr FILETIME

	mov ecx,pFT1
	mov edx,pFT2
	mov eax,[ecx].FILETIME.dwHighDateTime
	cmp eax,[edx].FILETIME.dwHighDateTime
	jnz @F
	mov eax,[ecx].FILETIME.dwLowDateTime
	cmp eax,[edx].FILETIME.dwHighDateTime
@@:
	mov eax,-1
	jc @F
	@mov eax,0
	jz @F
	inc eax
@@:
	@strace <"CompareFileTime(", pFT1, ", ", pFT2, ")=", eax>
	ret
	align 4

CompareFileTime endp

	end
