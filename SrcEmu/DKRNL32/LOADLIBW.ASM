
;*** implements LoadLibraryW()

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

	.CODE

if ?FLAT

LoadLibraryW proc public fname:ptr WORD
	mov eax, fname
	call ConvertWStr
	invoke LoadLibraryA, eax
	@strace <"LoadLibraryW(", fname, ")=", eax>
	ret
	align 4
LoadLibraryW endp

LoadLibraryExW proc public fname:ptr WORD, hFile:DWORD, dwFlags:DWORD
	mov eax, fname
	call ConvertWStr
	invoke LoadLibraryExA, eax, hFile, dwFlags
	@strace <"LoadLibraryExW(", fname, ", ", hFile, ", ", dwFlags, ")=", eax>
	ret
	align 4
LoadLibraryExW endp

endif

	end

