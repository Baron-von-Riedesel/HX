
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc

	.CODE

DebugBreak proc public

	int 3
	ret
	align 4

DebugBreak endp

	end

