
;--- implements ResetDCA()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wingdi.inc
	include dgdi32.inc
	include macros.inc

	.CODE

ResetDCA proc public uses ebx hdc:DWORD, lpDevmode:ptr DEVMODEA

	xor eax, eax
	@strace <"ResetDCA(", lpDevmode, ")=", eax, " *** unsupp ***">
	ret
	align 4
ResetDCA endp

	end
