
;--- implements OutputDebugStringW()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP group _TEXT
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include dpmi.inc
	include macros.inc

	.code

OutputDebugStringW proc public pText:ptr WORD

	mov eax, pText
	call ConvertWStr
	invoke OutputDebugStringA, eax
	ret
	align 4
OutputDebugStringW endp

	end

