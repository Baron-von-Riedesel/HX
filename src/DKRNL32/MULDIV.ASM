
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc

	.CODE

MulDiv proc public dw1:DWORD, dw2:dword, dw3:dword

	mov eax,dw1
	mul dw2
	div dw3
	@strace <"MulDiv(",dw1, ", ", dw2, ", ", dw3, ")=", eax>
	ret
MulDiv endp

	end

