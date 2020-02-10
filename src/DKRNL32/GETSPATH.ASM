
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

GetShortPathNameA proc public uses esi edi lpszSrcPath:ptr BYTE,lpszDestPath:ptr BYTE,cchBuffer:dword

local	szTmpPath[128]:byte
local	szTmpPath2[128]:byte

	mov esi, lpszSrcPath
	lea edi, szTmpPath
	mov cx,8001h				;CL=01: get short path form
	mov ax,7160h
	stc
	int 21h						;this call returns the full path!
	jnc lfnok
	cmp ax,7100h
	jz nolfn
	xor eax,eax
	jmp exit
lfnok:
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
nolfn:
	invoke lstrlen, esi		;stringlength of source
	cmp eax, cchBuffer
	jae @F
	push eax
	invoke lstrcpy, lpszDestPath, esi		   
	pop eax
@@:
exit:
	@strace <"GetShortPathNameA(", &lpszSrcPath, ", ", lpszDestPath, ", ", cchBuffer, ")=", eax>
	ret
	align 4

GetShortPathNameA endp

GetShortPathNameW proc public lpszwLongPath:ptr WORD,lpszwShortPath:ptr WORD,cchBuffer:dword

local	pszAStr:dword

	mov eax,lpszwLongPath
	invoke ConvertWStr
	mov ecx, cchBuffer
	sub esp, ecx
	sub esp, ecx
	mov pszAStr, esp
	invoke	GetShortPathNameA, eax, pszAStr, ecx
	.if (eax)
		invoke ConvertAStrN, pszAStr, lpszwShortPath, cchBuffer
	.endif
	@strace <"GetShortPathNameW(", lpszwLongPath, ", ", lpszwShortPath, ", ", cchBuffer, ")=", eax>
	ret
	align 4

GetShortPathNameW endp

	end

