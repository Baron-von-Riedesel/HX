
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include macros.inc

	.CODE

ConvertWStr proc public
	and eax, eax
	jz exit
	push eax
	invoke lstrlenW, eax
	add eax,3+1
	and al,0FCh
	pop ecx
	pop edx
	sub esp,eax
	mov eax,esp
	push edx
	push esi
	push edi
	mov edi, eax
	mov edx, eax
	mov esi, ecx
@@:
	lodsw
	stosb
	and ax,ax
	jnz @B
	mov eax, edx
	pop edi
	pop esi
exit:
	ret
	align 4
ConvertWStr endp

GetFileVersionInfoA proc public uses ebx lpszFilename:ptr BYTE, dwHandle:dword, dwLen:dword, lpData:ptr

	invoke LoadLibrary, lpszFilename
	.if (eax)
		mov ebx, eax
		invoke FindResource, ebx, 1, RT_VERSION
		.if (eax )
			invoke LoadResource, ebx, eax
			.if (eax)
				invoke CopyMemory, lpData, eax, dwLen
				@mov eax,1
			.endif
		.endif
		push eax
		invoke FreeLibrary, ebx
		pop eax
	.endif
	@strace <"GetFileVersionInfoA(", lpszFilename, ", ", dwHandle, ", ", dwLen, ", ", lpData, ")=", eax>
	ret
	align 4

GetFileVersionInfoA endp

GetFileVersionInfoW proc public uses ebx lpszFilename:ptr BYTE, dwHandle:dword, dwLen:dword, lpData:ptr

	mov eax, lpszFilename
	call ConvertWStr
	invoke GetFileVersionInfoA, eax, dwHandle, dwLen, lpData
	@strace <"GetFileVersionInfoW(", lpszFilename, ", ", dwHandle, ", ", dwLen, ", ", lpData, ")=", eax>
	ret
	align 4

GetFileVersionInfoW endp

GetFileVersionInfoSizeA proc public uses ebx lpszFilename:ptr BYTE, lpdwHandle:ptr dword

	mov ecx, lpdwHandle
	xor eax, eax
	mov [ecx], eax
	invoke LoadLibrary, lpszFilename
	.if (eax)
		mov ebx, eax
		invoke FindResource, ebx, 1, RT_VERSION
		.if (eax )
			invoke SizeofResource, ebx, eax
		.endif
		push eax
		invoke FreeLibrary, ebx
		pop eax
	.endif
	@strace <"GetFileVersionInfoSizeA(", lpszFilename, ", ", lpdwHandle, ")=", eax>
	ret
	align 4

GetFileVersionInfoSizeA endp

GetFileVersionInfoSizeW proc public uses ebx lpszFilename:ptr WORD, lpdwHandle:ptr dword

	mov eax, lpszFilename
	call ConvertWStr
	invoke GetFileVersionInfoSizeA, eax, lpdwHandle
	@strace <"GetFileVersionInfoSizeW(", lpszFilename, ", ", lpdwHandle, ")=", eax>
	ret
	align 4

GetFileVersionInfoSizeW endp

VerQueryValueA proc public pBlock:ptr, lpSubBlock:ptr BYTE, lplpBuffer:ptr ptr, puLen:ptr dword

	xor eax, eax
	@strace <"VerQueryValueA(", pBlock, ", ", lpSubBlock. ", ", lplpBuffer, ", ", puLen, ")=", eax>
	ret
	align 4

VerQueryValueA endp

VerQueryValueW proc public pBlock:ptr, lpSubBlock:ptr WORD, lplpBuffer:ptr ptr, puLen:ptr dword

	xor eax, eax
	@strace <"VerQueryValueW(", pBlock, ", ", lpSubBlock. ", ", lplpBuffer, ", ", puLen, ")=", eax>
	ret
	align 4

VerQueryValueW endp

	end
