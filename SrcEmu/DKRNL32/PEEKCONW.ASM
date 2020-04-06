
;*** implements 
;--- PeekConsoleInputW
;--- ReadConsoleInputW
;--- WriteConsoleInputW

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif

	option proc:private
	option casemap:none
	option dotname

	include winbase.inc
	include wincon.inc
	include keyboard.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

;--- PeekConsoleInputW just calls PeekConsoleInputA

PeekConsoleInputW proc public handle:dword, pBuffer:ptr WORD, nSize:dword, lpRead:ptr dword
	invoke PeekConsoleInputA, handle, pBuffer, nSize, lpRead
	@straceF DBGF_CIN,<"PeekConsoleInputW(", handle, ", ", pBuffer, ", ", nSize, ", ", lpRead, ")=", eax>
	ret
	align 4
PeekConsoleInputW endp

;--- ReadConsoleInputW just calls ReadConsoleInputA

ReadConsoleInputW proc public handle:dword, pBuffer:ptr WORD, nSize:dword, lpRead:ptr dword

	invoke ReadConsoleInputA, handle, pBuffer, nSize, lpRead
	@straceF DBGF_CIN,<"ReadConsoleInputW(", handle, ", ", pBuffer, ", ", nSize, ", ", lpRead, ")=", eax>
	ret
	align 4
ReadConsoleInputW endp

;--- WriteConsoleInputW just calls WriteConsoleInputA

WriteConsoleInputW proc public uses esi edi handle:dword, lpBuffer:ptr INPUT_RECORD, nLength:DWORD, lpWritten:ptr DWORD

	invoke WriteConsoleInputA, handle, lpBuffer, nLength, lpWritten
	@straceF DBGF_CIN, <"WriteConsoleInputW(", handle, ", ", lpBuffer, ", ", nLength, ", ", lpWritten, ")=", eax>
	ret
	align 4
WriteConsoleInputW endp

	end
