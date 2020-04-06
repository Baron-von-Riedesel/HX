
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

GetLongPathNameA proc public uses esi edi lpszSrcPath:ptr BYTE,lpszDestPath:ptr BYTE,cchBuffer:dword

local	szTmpPath[MAX_PATH]:byte
local	szTmpPath2[MAX_PATH]:byte


	mov esi, lpszSrcPath
	lea edi, szTmpPath
	mov cx,8002h				;CL=02: get long path form
	mov ax,7160h
	stc
	int 21h
	jc @F
if 1
;--- todo: the dos function returned the full path, but we should
;--- only return the parts we got as input.
	invoke lstrlen, edi		;get short path name length
	lea edi, [edi+eax]
	invoke lstrlen, esi		;get long path name length
	lea esi, [esi+eax]
	lea edx, szTmpPath2+sizeof szTmpPath2
	lea ecx, szTmpPath
	.while (esi >= lpszSrcPath)
		mov al,[esi]
		.if ((al == '.') && (byte ptr [esi+1] == '\'))
			.repeat
				dec edx
				mov [edx],al
				dec esi
			.until ((esi < lpszSrcPath) || (byte ptr [esi] != '.'))
			.while (byte ptr [edi] != '\')
				dec edi
			.endw
		.elseif (al == '\')
			.repeat
				dec edx
				mov ah,[edi]
				mov [edx],ah
				dec edi
			.until ((edi < ecx) || (ah == '\'))
		.elseif (esi == lpszSrcPath)
			.while ((edi >= ecx) && (byte ptr [edi] != '\'))
				dec edx
				mov ah,[edi]
				mov [edx],ah
				dec edi
			.endw
		.endif
		dec esi
	.endw
endif
	mov esi, edx
@@:
	invoke lstrlen, esi
	inc eax
	cmp eax, cchBuffer
	ja @F
	dec eax
	push eax
	invoke lstrcpy, lpszDestPath, esi
	pop eax
@@:
	@strace <"GetLongPathNameA(", lpszSrcPath, ", ", lpszDestPath, ", ", cchBuffer, ")=", eax>
	ret
	align 4

GetLongPathNameA endp

GetLongPathNameW proc public lpszwShortPath:ptr WORD,lpszwLongPath:ptr WORD,cchBuffer:dword

local	pszAStr:dword

	mov eax,lpszwShortPath
	invoke ConvertWStr
	mov ecx, cchBuffer
	sub esp, ecx
	sub esp, ecx
	mov pszAStr, esp
	invoke GetLongPathNameA, eax, pszAStr, ecx
	.if (eax)
		invoke ConvertAStrN, pszAStr, lpszwLongPath, cchBuffer
	.endif
	@strace <"GetLongPathNameW(", lpszwShortPath, ", ", lpszwLongPath, ", ", cchBuffer, ")=", eax>
	ret
	align 4

GetLongPathNameW endp

	end

