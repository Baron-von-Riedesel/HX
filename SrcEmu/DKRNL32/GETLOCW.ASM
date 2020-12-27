
;--- implements WIDE functions

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include winnls.inc
	include winerror.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

GetLocaleInfoW proc public lcid:dword,
          lctype:dword, pString:dword, cString:dword

local dwEsp:dword

	mov dwEsp, esp
	mov edx, pString
	.if edx && !(lctype & LOCALE_RETURN_NUMBER)
		mov eax, cString
		add eax, 4-1
		and al,0FCh
		sub esp, eax
		mov edx, esp
	.endif
	invoke GetLocaleInfoA, lcid, lctype, edx, cString
	.if (eax )
		.if lctype & LOCALE_RETURN_NUMBER
			shr eax,1
		.elseif pString
			mov edx, esp
			invoke ConvertAStrN, edx, pString, eax
		.endif
	.endif
	mov esp, dwEsp
	@strace <"GetLocaleInfoW(", lcid, ", ", lctype, ", ", pString, ", ", cString, ")=", eax >
	ret
	align 4

GetLocaleInfoW endp

EnumSystemLocalesW proc public pBuffer:dword, flags:dword

	xor eax,eax
	@strace	<"EnumSystemLocalesW(", pBuffer, ", ", flags, ")=", eax, " *** unsupp ***">
	ret
	align 4

EnumSystemLocalesW endp

end

