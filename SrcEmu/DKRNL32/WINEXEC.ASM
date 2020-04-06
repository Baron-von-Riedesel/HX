
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include wincon.inc
	include macros.inc

	.CODE

WinExec proc public uses esi edi pszCmdLine:ptr BYTE, nCmdShow:DWORD

local	dwESP:DWORD
local	sinfo:STARTUPINFOA
local	pinfo:PROCESS_INFORMATION

	@strace <"WinExec(", pszCmdLine, ", ", nCmdShow, ") enter">
	invoke RtlZeroMemory, addr sinfo, sizeof STARTUPINFOA
	mov sinfo.cb, sizeof STARTUPINFOA

;--------------------------- copy cmdline to a temp buffer
;--------------------------- since we may need to add ".exe"
	mov esi, pszCmdLine
	invoke lstrlen, esi
	add eax, 3+4
	and al,0FCh
	mov dwESP, esp
	sub esp, eax
	@loadesp edi
	mov edx, "EXE."
	mov ah,0
	mov cl,0
	.while (1)
		lodsb
		.break .if (!al)
		.if (ah && (al == ah))
			mov ah,0
			.continue
		.elseif (al == '"' || al == "'")
			mov ah, al
			.continue
		.elseif (al == '\')
			mov cl,0
		.elseif (al == '.')
			mov cl,1
		.endif
		.if ((!ah) && al <= ' ')
			.if ((!cl) && edx)
				mov [edi],edx
				add edi,4
				xor edx, edx
			.endif
		.endif
		stosb
	.endw
	stosb
	@loadesp edx

	invoke CreateProcess, 0, edx, 0, 0, 0, 0, 0, 0, addr sinfo, addr pinfo

	mov esp, dwESP
	.if (eax)
		invoke CloseHandle, pinfo.hProcess
		invoke CloseHandle, pinfo.hThread
		mov eax, 0FFFh ;pinfo.hProcess
	.else
		invoke GetLastError
		.if (eax > 31)
			xor eax, eax
		.endif
	.endif
	ret
WinExec endp

	end
