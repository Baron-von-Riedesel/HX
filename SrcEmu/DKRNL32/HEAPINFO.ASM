
;--- HeapSetInformation
;--- supported by WinXP+

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include heap32.inc
	include macros.inc

	.code

HeapSetInformation proc public heap:dword, hic:DWORD, pv:ptr, hil:dword

	xor eax, eax
exit@:
	@strace  <"HeapSetInformation(", heap, ", ", hic, ", ", pv, ", ", hil, ")=", eax >
	ret
	align 4

HeapSetInformation endp

	end

