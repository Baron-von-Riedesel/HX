
if ?FLAT
	.386
	.MODEL FLAT, stdcall
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc

	.CODE

InitializeSListHead proc public pp:ptr

	ret
	align 4

InitializeSListHead endp

endif
	end

