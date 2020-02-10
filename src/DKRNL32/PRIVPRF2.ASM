
;--- implements
;--- GetPrivateProfileSectionNamesA
;--- WritePrivateProfileSectionA

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

	.CODE

GetPrivateProfileSectionNamesA proc public uses esi edi ebx lpszReturnBuffer:ptr BYTE,
        nSize:dword, lpFileName:ptr byte

	mov ecx, lpFileName
	.if (!ecx)
		mov ecx, CStr("win.ini")
	.endif
	invoke GetPrivateProfileStringA, NULL, NULL, CStr(""), lpszReturnBuffer, nSize, ecx
ifdef _DEBUG
	mov  edx, lpFileName
	.if (!edx)
		mov edx, CStr("NULL")
	.endif
	@strace <"GetPrivateProfileSectionNamesA(", lpszReturnBuffer, ", ", nSize, ", ", &edx, ")=", eax>
endif
	ret
	align 4

GetPrivateProfileSectionNamesA endp

;--- if all three parameters are null, the cache is flushed

WritePrivateProfileSectionA proc public uses esi edi ebx lpAppName:ptr BYTE, lpString:ptr BYTE, lpFileName:ptr BYTE

local	szKey[256]:byte

	mov ecx, lpAppName
	mov edx, lpString
	mov ebx, lpFileName
	mov eax, ebx
	or eax, edx
	or eax, ecx
	jz flush
;--- delete the section
	invoke WritePrivateProfileStringA, lpAppName, 0, 0, lpFileName

	mov esi, lpString
	xor eax, eax
	.while (byte ptr [esi])
		lea edi, szKey
nextitem:
		lodsb
		and al,al
		jz exit
		cmp al,'='
		jz keycopied
		stosb
		jmp nextitem
keycopied:
		mov al,0
		stosb
		invoke WritePrivateProfileString, lpAppName, addr szKey, esi, lpFileName
		and eax, eax
		jz exit
@@:
		lodsb
		and al,al
		jnz @B
	.endw
	mov eax,1
	jmp exit
flush:
	invoke WritePrivateProfileString, 0, 0, 0, lpFileName
exit:        
	@strace <"WritePrivateProfileSectionA(", lpAppName, ", ", lpString, ", ", lpFileName, ")=", eax>
	ret
	align 4

WritePrivateProfileSectionA endp

	end
