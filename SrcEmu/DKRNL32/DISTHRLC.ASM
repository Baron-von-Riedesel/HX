
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

DisableThreadLibraryCalls proc public hModule:dword

	mov edx, hModule
	xor eax, eax
	.if (edx && (word ptr [edx] == "ZM"))
		add edx,[edx].IMAGE_DOS_HEADER.e_lfanew
		.if ([edx].IMAGE_NT_HEADERS.FileHeader.Characteristics & IMAGE_FILE_DLL) 
			or [edx].IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics, FKF_DISTHREADLIBCALLS
			inc eax
		.endif
	.endif
	@strace <"DisableThreadLibraryCalls(", hModule, ")=", eax>
	ret
	align 4

DisableThreadLibraryCalls endp

	end

