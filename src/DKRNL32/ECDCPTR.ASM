
;--- EncodePointer, DecodePointer
;--- supported by WinXP SP2+

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

EncodePointer proc public p:ptr

	mov eax, p
	xor eax, -1
	@strace  <"EncodePointer(", p, ")=", eax >
	ret
	align 4

EncodePointer endp

DecodePointer proc public p:ptr

	mov eax, p
	xor eax, -1
	@strace  <"DecodePointer(", p, ")=", eax >
	ret
	align 4

DecodePointer endp

	end

