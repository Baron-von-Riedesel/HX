
;--- implements OleFlushClipboard

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include windef.inc
	include winbase.inc
	include winreg.inc
	include winuser.inc
	include objbase.inc
	include macros.inc

	.CODE

OleFlushClipboard proc public

	mov eax,S_OK
	@strace <"OleFlushClipboard()=", eax>
	ret
	align 4

OleFlushClipboard endp

	end
