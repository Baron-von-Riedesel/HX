
;--- implements WriteConsoleW()

	.386

if ?FLAT
	.MODEL FLAT, stdcall 
else
	.MODEL SMALL, stdcall 
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

WriteConsoleW proc public hConOut:dword,pStr:ptr WORD,lstring:dword,pWritten:ptr dword,res:dword

	mov eax, pStr
	mov ecx, lstring
	call ConvertWStrN
	invoke WriteConsoleA, hConOut, eax, lstring, pWritten, res
	@strace <"WriteConsoleW()=",eax>
	ret
	align 4

WriteConsoleW endp

	end

