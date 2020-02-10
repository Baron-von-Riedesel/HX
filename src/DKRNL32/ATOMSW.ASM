
;--- implements:
;--- [Global]AddAtomW
;--- [Global]GetAtomNameW

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif

	option proc:private
	option casemap:none

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

GlobalAddAtomW proc public lpString:ptr WORD

	mov eax, lpString
	call ConvertWStr
	invoke GlobalAddAtomA, eax
	@strace <"GlobalAddAtomW(", lpString, ")=", eax>
	ret
	align 4

GlobalAddAtomW endp

GlobalGetAtomNameW proc public atom:DWORD, lpBuffer:ptr WORD, nSize:DWORD

	invoke GlobalGetAtomNameA, atom, lpBuffer, nSize
	.if (eax && lpBuffer)
		invoke ConvertAStr, lpBuffer
	.endif
	@strace <"GlobalGetAtomNameW(", atom, ", ", lpBuffer, ", ", nSize, ")=", eax>
	ret
	align 4

GlobalGetAtomNameW endp

end

