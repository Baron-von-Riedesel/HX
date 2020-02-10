
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

GetConsoleTitleA proc public uses esi edi lpConsoleTitle:dword,dwSize:dword

local	szModuleName[MAX_PATH]:byte

	invoke GetModuleFileName, NULL, addr szModuleName, sizeof szModuleName
	lea ecx, szModuleName
	.while (eax)
		dec eax
		.if (byte ptr [eax+ecx] == '\')
			lea esi, [eax+ecx+1]
			mov edi, lpConsoleTitle
			mov ecx, dwSize
			jecxz done
@@:
			lodsb
			stosb
			and al,al
			loopnz @B
done:
			mov eax, dwSize
			sub eax, ecx
			.break
		.endif
	.endw
	@strace <"GetConsoleTitleA(", lpConsoleTitle, ", ", dwSize, ")=", eax>
	ret
	align 4

GetConsoleTitleA endp

GetConsoleTitleW proc public lpConsoleTitle:ptr WORD,dwSize:dword

	sub esp, dwSize
	mov edx, esp
	invoke GetConsoleTitleA, edx, dwSize
	.if (eax)
		mov edx, esp
		invoke ConvertAStrN, edx, lpConsoleTitle, dwSize
	.endif
	ret
	align 4
GetConsoleTitleW endp

SetConsoleTitleA proc public lpConsoleTitle:dword
	@mov eax,1
	@strace <"SetConsoleTitleA(", lpConsoleTitle, ")=", eax>
	ret
	align 4
SetConsoleTitleA endp

SetConsoleTitleW proc public lpConsoleTitle:ptr WORD
	@mov eax,1
	@strace <"SetConsoleTitleW(", lpConsoleTitle, ")=", eax>
	ret
	align 4
SetConsoleTitleW endp

	end
