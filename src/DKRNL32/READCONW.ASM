
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include wincon.inc
	include macros.inc
	include dkrnl32.inc

	.CODE

ReadConsoleW proc uses esi edi handle:dword,pBuffer:ptr word,maxRead:dword,pRead:ptr dword,res:dword

local	dwESP:DWORD

		@trace <"ReadConsoleW",13,10>
		mov eax, maxRead
		mov ecx, eax
		add eax, 3
		and al, 0FCh
		mov dwESP, esp
		sub esp, eax
		mov ecx, esp
		invoke ReadConsoleA, handle, ecx, maxRead, pRead, res
		.if (eax)
			mov edx, eax
			mov esi, esp
			mov edi, pBuffer
			mov ecx, pRead
			mov ecx, [ecx]
			mov ah,0
			.while (ecx)
				lodsb
				stosw
				dec ecx
			.endw
			mov eax, edx
		.endif
		mov esp, dwESP
		@strace <"ReadConsoleW(", handle, ", ", pBuffer, ", ", maxRead, ", ", pRead, ", ", res, ")=", eax>
		ret
		align 4

ReadConsoleW endp

	end
