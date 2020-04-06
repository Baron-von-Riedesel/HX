
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

_llseek proc public handle:dword,dwOffs:dword,origin:dword

	invoke SetFilePointer,handle,dwOffs,NULL,origin
	ret
_llseek endp

	end

