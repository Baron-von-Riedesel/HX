
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc

	.DATA

	.CODE

SetVolumeLabelA proc public pRoot:dword

	xor eax,eax
	@strace	<"SetVolumeLabelA(", pRoot, ")=", eax, " *** unsupp ***">
	ret

SetVolumeLabelA endp

	end
