
;--- implements 
;--- GetPrivateProfileStringW
;--- WritePrivateProfileStringW

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

;--- cases:
;--- lpAppName == NULL: copy all section names to buffer
;--- lpKeyName == NULL: copy all key names to buffer

GetPrivateProfileStringW proc public lpAppName:ptr WORD,
        lpKeyName:ptr WORD, lpDefault:ptr WORD, retbuff:ptr WORD, 
        bufsize:dword, filename:ptr WORD

local	tAppName:dword
local	tKeyName:dword
local	tfilename:dword

	mov eax, filename
	call ConvertWStr
	mov tfilename, eax
	mov eax, lpAppName
	.if (eax)
		call ConvertWStr
	.endif
	mov tAppName, eax
	mov eax, lpKeyName
	.if (eax)
		call ConvertWStr
	.endif
	mov tKeyName, eax
	mov ecx, bufsize
	add ecx, 3
	and ecx, not 4
	sub esp, ecx
	mov edx, esp
	invoke GetPrivateProfileStringA, tAppName, tKeyName, lpDefault, edx, bufsize, tfilename
	.if (eax && retbuff)
		mov edx, esp
		invoke ConvertAStrN, edx, retbuff, eax
	.endif
	add esp, bufsize

	@strace	<"GetPrivateProfileStringA(", lpAppName, ", ", lpKeyName,  ", ", lpDefault, ", ", retbuff, ", ", bufsize, ", ", filename, ")=", eax>
	ret
	align 4

GetPrivateProfileStringW endp

;--- lpAppName might be NULL
;--- lpKeyName might be NULL
;--- lpValue might be NULL

WritePrivateProfileStringW proc public lpAppName:ptr WORD,
            lpKeyName:ptr WORD, lpValue:ptr WORD, filename:ptr WORD

local	tAppName:dword
local	tKeyName:dword
local	tValue:dword
local	tfilename:dword

	mov eax, filename
	call ConvertWStr
	mov tfilename, eax
	mov eax, lpAppName
	.if (eax)
		call ConvertWStr
	.endif
	mov tAppName, eax
	mov eax, lpKeyName
	.if (eax)
		call ConvertWStr
	.endif
	mov tKeyName, eax
	mov eax, lpValue
	.if (eax)
		call ConvertWStr
	.endif
	mov tValue, eax
	invoke WritePrivateProfileStringA, tAppName, tKeyName, tValue, tfilename
	@strace	<"WritePrivateProfileStringW(", lpAppName, ", ", lpKeyName, ", ", lpValue, ", ", filename, ")=", eax>
	ret
	align 4

WritePrivateProfileStringW endp

	end

