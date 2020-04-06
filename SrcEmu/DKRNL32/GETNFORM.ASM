
;--- implements GetNumberFormatA, GetNumberFormatW
;--- implements GetCurrencyFormatA, GetCurrencyFormatW

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
	include dpmi.inc
	include winerror.inc
	include macros.inc

	.CODE

GetNumberFormatA proc public lcid:dword, dwFlags:dword, lpValue:ptr BYTE, lpFormat:ptr, lpNumberStr:ptr BYTE, cchNumber:dword

	.if (cchNumber)
		invoke lstrcpyn, lpNumberStr, lpValue, cchNumber
		invoke lstrlen, lpNumberStr
		inc eax
	.else
		invoke lstrlen, lpValue
		inc eax
	.endif
	@strace <"GetNumberFormatA(", lcid, ", ", dwFlags, ", ", lpValue, ", ", lpFormat, ", ", lpNumberStr, ", ", cchNumber, ")=", eax>
	ret
	align 4

GetNumberFormatA endp

GetNumberFormatW proc public lcid:dword, dwFlags:dword, lpValue:ptr WORD, lpFormat:ptr, lpNumberStr:ptr WORD, cchNumber:dword
	mov eax, lpValue
	call ConvertWStr
	invoke GetNumberFormatA, lcid, dwFlags, eax, lpFormat, lpNumberStr, cchNumber
	@strace <"GetNumberFormatW(", lcid, ", ", dwFlags, ", ", lpValue, ", ", lpFormat, ", ", lpNumberStr, ", ", cchNumber, ")=", eax>
	ret
	align 4
GetNumberFormatW endp

GetCurrencyFormatA proc public lcid:dword, dwFlags:dword, lpValue:ptr BYTE, lpFormat:ptr, lpCurrencyStr:ptr BYTE, cchCurrency:dword

	.if (cchCurrency)
		invoke lstrcpyn, lpCurrencyStr, lpValue, cchCurrency
		invoke lstrlen, lpCurrencyStr
		inc eax
	.else
		invoke lstrlen, lpValue
		inc eax
	.endif
	@strace <"GetCurrencyFormatA(", lcid, ", ", dwFlags, ", ", lpValue, ", ", lpFormat, ", ", lpCurrencyStr, ", ", cchCurrency, ")=", eax>
	ret
	align 4

GetCurrencyFormatA endp

GetCurrencyFormatW proc public lcid:dword, dwFlags:dword, lpValue:ptr WORD, lpFormat:ptr, lpCurrencyStr:ptr WORD, cchCurrency:dword
	mov eax, lpValue
	call ConvertWStr
	invoke GetCurrencyFormatA, lcid, dwFlags, eax, lpFormat, lpCurrencyStr, cchCurrency
	@strace <"GetCurrencyFormatW(", lcid, ", ", dwFlags, ", ", lpValue, ", ", lpFormat, ", ", lpCurrencyStr, ", ", cchCurrency, ")=", eax>
	ret
	align 4
GetCurrencyFormatW endp

	end
