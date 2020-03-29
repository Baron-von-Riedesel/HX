
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include macros.inc

	.CODE

wsprintfA proc c public a1:ptr byte, a2:ptr byte, a3:VARARG

	invoke wvsprintf, a1, a2, addr a3
	@strace <"wsprintfA(", a1, ", ", a2, ", ", a3, ")=", eax>
	ret

wsprintfA endp

	end
