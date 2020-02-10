
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

?NOCASEMAP	equ 0	;win32 std is 0

	.code

if ?FLAT

;--- eax = resource directory
;--- id may be an id (HIWORD=0) or a string pointer

;--- used by EnumResourceXXX as well !!

ScanResDir proc public uses esi pRes:DWORD, dwDir:DWORD, id:DWORD

	mov esi, pRes
	add esi, dwDir
	movzx ecx, [esi].IMAGE_RESOURCE_DIRECTORY.NumberOfNamedEntries
	mov eax, id
	.if (eax & 0FFFF0000h)
		.if (byte ptr [eax] == '#')
			lea edx,[eax+1]
			call GetNumber
			jmp ok
		.endif
		lea esi, [esi + sizeof IMAGE_RESOURCE_DIRECTORY]
		.while (ecx)
			mov edx, [esi].IMAGE_RESOURCE_DIRECTORY_ENTRY.Name_
			and edx, edx
			.if (SIGN?)
				and edx, 7FFFFFFFh
				add edx, pRes
				pushad
				mov esi, edx
				mov edi, eax
				lodsw
				movzx ecx, ax
@@:
if ?NOCASEMAP
				lodsw
				scasb
else
				lodsw
				call ToLower
				mov ah,al
				mov al,[edi]
				inc edi
				call ToLower
				cmp al,ah
endif
				loopz @B
				popad
				.if (ZERO? && (byte ptr [edi] == 0))
					mov eax, [esi].IMAGE_RESOURCE_DIRECTORY_ENTRY.OffsetToData
					jmp done
				.endif
			.endif
			add esi, sizeof IMAGE_RESOURCE_DIRECTORY_ENTRY
			dec ecx
		.endw
		jmp error
	.endif
ok:
	push eax
	mov eax, sizeof IMAGE_RESOURCE_DIRECTORY_ENTRY
	mul ecx
;-------------------- let esi point to resources with id entries
	movzx ecx, [esi].IMAGE_RESOURCE_DIRECTORY.NumberOfIdEntries
	lea esi, [esi + eax + sizeof IMAGE_RESOURCE_DIRECTORY]
	pop eax
	.while (ecx)
		.if ((ax == [esi].IMAGE_RESOURCE_DIRECTORY_ENTRY.Id) || (ax == 0))
			mov eax, [esi].IMAGE_RESOURCE_DIRECTORY_ENTRY.OffsetToData
			jmp done
		.endif
		add esi, sizeof IMAGE_RESOURCE_DIRECTORY_ENTRY
		dec ecx
	.endw
error:
	xor eax, eax
done:
	ret
ife ?NOCASEMAP
ToLower:
	cmp al,'A'
	jb @F
	cmp al,'Z'
	jae @F
	or al,20h
@@: 
	retn
endif
GetNumber:
	push ebx
	xor eax, eax
	.while (byte ptr [edx])
		movzx ebx,byte ptr [edx]
		inc edx
		sub bl,'0'
		add eax, eax
		push eax
		shl eax, 2
		add eax, [esp]
		add eax, ebx
		pop ebx
	.endw
	pop ebx
	retn
	align 4

ScanResDir endp

;--- hiword of lpName and lpType may be NULL
;--- in this case it is an integer identifier

FindResourceA proc public uses esi edi hModule:DWORD, lpName:DWORD, lpType:DWORD

	mov esi, hModule
	.if (!esi)
		invoke GetModuleHandle, esi
		mov esi, eax
		mov hModule, eax
	.endif

	add esi, [esi].IMAGE_DOS_HEADER.e_lfanew
	mov edi, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE * sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	mov edx, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE * sizeof IMAGE_DATA_DIRECTORY].Size_
	.if (edi)
		add edi, hModule
		invoke ScanResDir, edi, 0, lpType
		.if (eax)
			and eax, eax
			.if (SIGN?)
				and eax, 7FFFFFFFh
				invoke ScanResDir, edi, eax, lpName
				.if (eax)
					and eax, eax
					.if (SIGN?)
						and eax, 7FFFFFFFh
						invoke ScanResDir, edi, eax, 0
						.if (eax)
							add eax, edi
							jmp done
						.endif
					.else
						add eax, edi
						jmp done
					.endif
				.endif
			.endif
		.endif
	.endif
error:
	xor eax, eax
done:
ifdef _DEBUG
	@trace <"FindResourceA(">
	@tracedw hModule
	@trace <", ">
	.if (word ptr lpName+2) 
		@trace lpName
	.else
		@tracedw lpName
	.endif
	@trace <", ">
	.if (word ptr lpType+2) 
		@trace lpType
	.else
		@tracedw lpType
	.endif
	@trace <")=">
	@tracedw eax
	@trace <13,10>
endif

	ret
	align 4

FindResourceA endp

;--- attention: name and type are exchanged!

FindResourceExA proc public hModule:DWORD, lpType:DWORD, lpName:DWORD, wLanguage:DWORD

	invoke FindResourceA, hModule, lpName, lpType
	@strace <"FindResourceExA(", hModule, ", ", lpType, ", ", lpName, ", ", wLanguage, ")=", eax>
	ret
	align 4

FindResourceExA endp

LoadResource proc public hModule:DWORD, hres:DWORD

	.if (!hModule)
		invoke GetModuleHandle, hModule
		mov hModule, eax
	.endif
	mov eax, hres
	.if (eax)
		mov eax, [eax].IMAGE_RESOURCE_DATA_ENTRY.OffsetToData
		add eax, hModule
	.endif
	@strace <"LoadResource(", hModule, ", ", hres, ")=", eax>
	ret
	align 4

LoadResource endp

LockResource proc public hres:DWORD

	mov eax,hres
	@strace <"LockResource(", hres, ")=", eax>
	ret
	align 4

LockResource endp

FreeResource proc public hres:DWORD

	@mov eax,1
	@strace <"FreeResource(", hres, ")=", eax>
	ret
	align 4

FreeResource endp

SizeofResource proc public hModule:DWORD, hres:DWORD

	mov eax, hres
	.if (eax)
		mov eax, [eax].IMAGE_RESOURCE_DATA_ENTRY.Size_
	.endif
	@strace <"SizeofResource(", hModule, ", ", hres, ")=", eax>
	ret
	align 4

SizeofResource endp

endif

	end
