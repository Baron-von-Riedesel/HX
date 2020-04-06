
;*** FindFirstFileW, FindNextFileW 

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

	.CODE

ConvW2A proc pSrc:ptr WIN32_FIND_DATAW, pDest:ptr WIN32_FIND_DATAA
	pushad
	mov esi, pSrc
	mov edi, pDest
	mov ecx, 11
	rep movsd
	mov cx, MAX_PATH+14
@@:
	lodsw
	stosb
	loop @B
	popad
	ret
	align 4
ConvW2A endp

ConvA2W proc pSrc:ptr WIN32_FIND_DATAA, pDest:ptr WIN32_FIND_DATAW
	pushad
	mov esi, pSrc
	mov edi, pDest
	mov ecx, 11
	rep movsd
	mov cx, MAX_PATH+14
	mov ah,0
@@:
	lodsb
	stosw
	loop @B
	popad
	ret
	align 4
ConvA2W endp

FindFirstFileW proc public pFileSpec:ptr WORD, pBuffer:ptr WIN32_FIND_DATAW

local	wfd:WIN32_FIND_DATAA

	@strace <"FindFirstFileW(", pFileSpec, ") enter">
	mov eax, pFileSpec
	call ConvertWStr
	lea ecx, wfd
	invoke FindFirstFileA, eax, ecx
	.if (eax != INVALID_HANDLE_VALUE)
		lea ecx, wfd
		invoke ConvA2W, ecx, pBuffer
	.endif
	@strace <"FindFirstFileW()=", eax>
	ret
	align 4

FindFirstFileW endp

FindNextFileW proc public fhandle:dword, pBuffer:ptr WIN32_FIND_DATAW

local	wfd:WIN32_FIND_DATAA

	@strace <"FindNextFileW(", fhandle, ") enter">
	invoke ConvW2A, pBuffer, addr wfd
	invoke FindNextFileA, fhandle, addr wfd
	.if (eax)
		lea ecx, wfd
		invoke ConvA2W, ecx, pBuffer
	.endif
	@strace <"FindNextFileW(", fhandle, ")=", eax>
	ret
	align 4

FindNextFileW endp

	END

