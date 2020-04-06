
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

	.code

if ?FLAT

ScanResDir proto pRes:DWORD, dwDir:DWORD, id:DWORD

protoEnumTypeProc typedef proto :DWORD, :DWORD, :DWORD
LPENUMTYPEPROC typedef ptr protoEnumTypeProc
protoEnumNameProc typedef proto :DWORD, :DWORD, :DWORD, :DWORD
LPENUMNAMEPROC typedef ptr protoEnumNameProc
protoEnumLangProc typedef proto :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
LPENUMLANGPROC typedef ptr protoEnumLangProc

EnumResDir proc hModule:DWORD, pRes:DWORD, dwDir:DWORD, lpszType:ptr BYTE, lpszName:ptr BYTE, lpEnumProc:ptr, lParam:DWORD

local	szType[256]:byte

	mov esi, pRes
	add esi, dwDir
	movzx ecx, [esi].IMAGE_RESOURCE_DIRECTORY.NumberOfNamedEntries
	lea esi, [esi + sizeof IMAGE_RESOURCE_DIRECTORY]
	@mov eax,1
	.while (ecx)
		mov edx, [esi].IMAGE_RESOURCE_DIRECTORY_ENTRY.Name_
		and edx, edx
		.if (SIGN?)
			and edx, 7FFFFFFFh
			add edx, pRes
			push esi
			push ecx
			mov esi, edx
			lea edi, szType
			lodsw
			movzx ecx, ax
@@:
			lodsw
			stosb
			loopz @B
			mov al,0
			stosb
			.if (lpszType)
				invoke LPENUMNAMEPROC ptr lpEnumProc, hModule, lpszType, addr szType, lParam
			.else
				invoke LPENUMTYPEPROC ptr lpEnumProc, hModule, addr szType, lParam
			.endif
			pop ecx
			pop esi
			.break .if (!eax)
		.endif
		add esi, sizeof IMAGE_RESOURCE_DIRECTORY_ENTRY
		dec ecx
	.endw
	.if (eax)
		mov esi, pRes
		add esi, dwDir
		movzx ecx, [esi].IMAGE_RESOURCE_DIRECTORY.NumberOfNamedEntries
		mov eax, sizeof IMAGE_RESOURCE_DIRECTORY_ENTRY
		mul ecx
;-------------------- let esi point to resources with id entries
		movzx ecx, [esi].IMAGE_RESOURCE_DIRECTORY.NumberOfIdEntries
		lea esi, [esi + eax + sizeof IMAGE_RESOURCE_DIRECTORY]
		.while (ecx)
			movzx eax, [esi].IMAGE_RESOURCE_DIRECTORY_ENTRY.Id
			push ecx
			.if (lpszName)
				invoke LPENUMLANGPROC ptr lpEnumProc, hModule, lpszType, lpszName, eax, lParam
			.elseif (lpszType)
				invoke LPENUMNAMEPROC ptr lpEnumProc, hModule, lpszType, eax, lParam
			.else
				invoke LPENUMTYPEPROC ptr lpEnumProc, hModule, eax, lParam
			.endif
			pop ecx
			.break .if (!eax)
			add esi, sizeof IMAGE_RESOURCE_DIRECTORY_ENTRY
			dec ecx
		.endw
	.endif
	ret
	align 4

EnumResDir endp

prepare proc
	.if (!esi)
		invoke GetModuleHandle, esi
		mov esi, eax
	.endif
	mov ecx, esi
	add esi, [esi].IMAGE_DOS_HEADER.e_lfanew
	mov edi, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE * sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	mov edx, [esi].IMAGE_NT_HEADERS.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE * sizeof IMAGE_DATA_DIRECTORY].Size_
	xor eax, eax
	ret
	align 4
prepare endp

EnumResourceTypesA proc public uses esi edi hModule:DWORD, lpEnumFunc:DWORD, lParam:DWORD

	mov esi, hModule
	invoke prepare
	.if (edi)
		add edi, ecx
		invoke EnumResDir, hModule, edi, 0, 0, 0, lpEnumFunc, lParam
		@mov eax, 1
	.endif
	@strace <"EnumResourceTypesA(", hModule, ", ", lpEnumFunc, ", ", lParam, ")=", eax>
	ret
	align 4
EnumResourceTypesA endp

EnumResourceNamesA proc public uses esi edi hModule:DWORD, lpszType:ptr BYTE, lpEnumFunc:DWORD, lParam:DWORD

	mov esi, hModule
	invoke prepare
	.if (edi)
		add edi, ecx
		invoke ScanResDir, edi, 0, lpszType
		.if (eax)
			and eax, eax
			.if (SIGN?)
				and eax, 7FFFFFFFh
				invoke EnumResDir, hModule, edi, eax, lpszType, 0, lpEnumFunc, lParam
				@mov eax, 1
			.endif
		.endif
	.endif
	@strace <"EnumResourceNamesA(", hModule, ", ", lpszType, ", ", lpEnumFunc, ", ", lParam, ")=", eax>
	ret
	align 4
EnumResourceNamesA endp

EnumResourceLanguagesA proc public uses esi edi hModule:DWORD, lpszType:ptr BYTE, lpszName:ptr BYTE, lpEnumFunc:DWORD, lParam:DWORD

	mov esi, hModule
	invoke prepare
	.if (edi)
		add edi, ecx
		invoke ScanResDir, edi, 0, lpszType
		.if (eax)
			and eax, eax
			.if (SIGN?)
				and eax, 7FFFFFFFh
				invoke ScanResDir, edi, eax, lpszName
				.if (eax)
					and eax, eax
					.if (SIGN?)
						and eax, 7FFFFFFFh
						invoke EnumResDir, hModule, edi, eax, lpszType, lpszName, lpEnumFunc, lParam
						@mov eax, 1
					.endif
				.endif
			.endif
		.endif
	.endif
	@strace <"EnumResourceLanguagesA(", hModule, ", ", lpszType, ", ", lpszName, ", ", lpEnumFunc, ", ", lParam, ")=", eax>
	ret
	align 4
EnumResourceLanguagesA endp

endif

	end
