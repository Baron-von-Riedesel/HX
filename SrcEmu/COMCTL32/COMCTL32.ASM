
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif

	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.DATA

	.CODE

DllMain proc public handle:dword,reason:dword,reserved:dword

	@mov eax,1
	ret
DllMain endp

	END DllMain

