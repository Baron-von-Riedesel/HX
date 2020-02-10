
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc

	.CODE

SetFileApisToOEM proc public

	@strace  <"SetFileApisToOEM()=void">
	ret
	align 4

SetFileApisToOEM endp

SetFileApisToANSI proc public

	@strace  <"SetFileApisToANSI()=void">
	ret
	align 4

SetFileApisToANSI endp

AreFileApisANSI proc public
	xor eax, eax
	@strace  <"AreFileApisANSI()=",eax>
	ret
	align 4

AreFileApisANSI endp

	end

