
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc

	.CODE

;--- if functions failed, return -1 (HFILE_ERROR),
;--- else number of bytes write/read

_lwrite proc public handle:dword,buffer:dword,laenge:dword

	push edx
	@loadesp edx
	invoke WriteFile,handle,buffer,laenge,edx,0
	and eax,eax
	pop eax
	jnz exit
	xor eax,eax
	dec eax
exit:
	ret
	align 4
_lwrite endp

_lread proc public handle:dword,buffer:dword,laenge:dword

	push edx
	@loadesp edx
	invoke ReadFile,handle,buffer,laenge,edx,0
	and eax,eax
	pop eax
	jnz exit
	xor eax,eax
	dec eax
exit:
	ret
	align 4
_lread endp

	end
