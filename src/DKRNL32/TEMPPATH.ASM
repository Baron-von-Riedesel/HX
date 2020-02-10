
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:NONE
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

;--- the returned string should end with a "\"

GetTempPathA proc public nBufferLength:DWORD, lpBuffer:ptr BYTE

	invoke GetEnvironmentVariableA, CStr("TMP"), lpBuffer, nBufferLength
	.if (!eax)
		invoke GetEnvironmentVariableA, CStr("TEMP"), lpBuffer, nBufferLength
		.if (!eax)
			invoke GetCurrentDirectoryA, nBufferLength, lpBuffer
		.endif
	.endif
	.if (eax)
		mov ecx, lpBuffer
		mov dl, [ecx+eax-1]
		.if ((dl != '\') && (dl != '/'))
			mov word ptr [ecx+eax],'\'
			inc eax
		.endif
	.endif
	@strace <"GetTempPathA(", nBufferLength, ", ", lpBuffer, ")=", eax>
	ret
	align 4

GetTempPathA endp

GetTempPathW proc public nBufferLength:DWORD, lpBuffer:ptr WORD

	invoke GetTempPathA, nBufferLength, lpBuffer
	.if (eax && lpBuffer)
		invoke ConvertAStr, lpBuffer
	.endif
	@strace <"GetTempPathW(", nBufferLength, ", ", lpBuffer, ")=", eax>
	ret
	align 4

GetTempPathW endp

	end
