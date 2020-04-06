
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include	macros.inc

	.CODE

GetStartupInfoW proc public pInfo:ptr STARTUPINFOW

;--- nothing to translate, no strings are used

	invoke GetStartupInfoA, pInfo
	@strace <"GetStartupInfoW(", pInfo, ")=void">
	ret
	align 4

GetStartupInfoW endp

	end

