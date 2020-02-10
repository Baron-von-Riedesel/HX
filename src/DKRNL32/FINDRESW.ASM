
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.code

if ?FLAT

FindResourceW proc public hModule:DWORD, lpName:ptr WORD, lpType:ptr WORD

	mov eax, lpName
	test eax, 0FFFF0000h
	jz @F
	call ConvertWStr
	mov lpName, eax
@@:
	mov eax, lpType
	test eax, 0FFFF0000h
	jz @F
	call ConvertWStr
	mov lpType, eax
@@:
	invoke FindResourceA, hModule, lpName, lpType
	@strace <"FindResourceW(", hModule, ", ", lpName, ", ", lpType, ")=", eax>
	ret
	align 4

FindResourceW endp

;--- attention: name and type are exchanged!

FindResourceExW proc public hModule:DWORD, lpType:DWORD, lpName:DWORD, wLanguage:DWORD

	mov eax, lpType
	test eax, 0FFFF0000h
	jz @F
	call ConvertWStr
	mov lpType, eax
@@:
	mov eax, lpName
	test eax, 0FFFF0000h
	jz @F
	call ConvertWStr
	mov lpName, eax
@@:
	invoke FindResourceExA, hModule, lpType, lpName, wLanguage
	@strace <"FindResourceExW(", hModule, ", ", lpType, ", ", lpName, ", ", wLanguage, ")=", eax>
	ret
	align 4

FindResourceExW endp

endif

	end
