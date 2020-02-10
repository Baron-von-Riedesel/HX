
;--- implements
;--- CreateTapePartition
;--- EraseTape
;--- GetTapeParameters
;--- GetTapePosition
;--- GetTapeStatus
;--- PrepareTape
;--- SetTapeParameters
;--- SetTapePosition
;--- WriteTapemark

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
	include macros.inc

	.CODE

CreateTapePartition proc public hFile:dword, dw1:dword, dw2:dword, dw3:dword

	xor eax, eax
	@strace <"CreateTapePartition(", hFile, ")=", eax, " *** unsupp ***">
	ret
	align 4

CreateTapePartition endp

EraseTape proc public hFile:dword, dw1:dword, b1:dword

	xor eax, eax
	@strace <"EraseTape(", hFile, ")=", eax, " *** unsupp ***">
	ret
	align 4

EraseTape endp

GetTapeParameters proc public hFile:dword, dw1:dword, lpdw:ptr dword, lpvoid:ptr

	xor eax, eax
	@strace <"GetTapeParameters(", hFile, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetTapeParameters endp

GetTapePosition proc public hFile:dword, dw1:dword, lpdw1:ptr DWORD, lpdw2:ptr DWORD, lpdw3:ptr DWORD

	xor eax, eax
	@strace <"GetTapePosition(", hFile, ", ", dw1, ", ", lpdw1, ", ", lpdw2, ", ", lpdw3, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetTapePosition endp

GetTapeStatus proc public hFile:dword

	xor eax, eax
	@strace <"GetTapeStatus(", hFile, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetTapeStatus endp

PrepareTape proc public hFile:dword, dw1:DWORD, b1:dword

	xor eax, eax
	@strace <"PrepareTape(", hFile, ", ", dw1, ")=", eax, " *** unsupp ***">
	ret
	align 4

PrepareTape endp

SetTapeParameters proc public hFile:dword, dw1:DWORD, lpvoid:ptr

	xor eax, eax
	@strace <"SetTapeParameters(", hFile, ", ", dw1, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetTapeParameters endp

SetTapePosition proc public hFile:dword, dw1:DWORD, dw2:DWORD, dw3:DWORD, dw4:DWORD, b1:dword

	xor eax, eax
	@strace <"SetTapePosition(", hFile, ", ", dw1, ")=", eax, " *** unsupp ***">
	ret
	align 4

SetTapePosition endp

WriteTapemark proc public hFile:dword, dw1:dword, dw2:dword, b1:dword

	xor eax, eax
	@strace <"WriteTapemark(", hFile, ", ", dw1, ")=", eax, " *** unsupp ***">
	ret
	align 4

WriteTapemark endp

	end
