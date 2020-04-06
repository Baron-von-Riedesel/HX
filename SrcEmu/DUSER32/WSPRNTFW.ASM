
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

wvsprintfW proto stdcall :ptr WORD, :ptr WORD, :ptr

wsprintfW proc c public a1:ptr WORD, a2:ptr WORD, a3:VARARG

	invoke wvsprintfW, a1, a2, addr a3
	@strace <"wsprintfW(", a1, ", ", a2, ", ", a3, ")=", eax>
	ret

wsprintfW endp

	end
