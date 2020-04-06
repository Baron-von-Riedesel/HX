
;--- implements CreateProcessW

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

CreateProcessW proc public pAppName:dword,
						   pCmdLine:dword,
						   pProcessAttribs:dword,
						   pThreadAttribs:dword,
						   bInheritHandles:dword,
						   dwCreationFlags:dword,
						   pEnvironment:dword,
						   pCurrentDir:dword,
						   pStartupInfo:dword,
						   pProcessInfo:dword
	mov eax, pAppName
	.if (eax)
		invoke ConvertWStr
		mov pAppName, eax
	.endif
	mov eax, pCmdLine
	.if (eax)
		invoke ConvertWStr
		mov pCmdLine, eax
	.endif
if 0
	mov eax, pEnvironment
	.if (eax)
		invoke ConvertWStr
		mov pEnvironment, eax
	.endif
endif
	mov eax, pCurrentDir
	.if (eax)
		invoke ConvertWStr
		mov pCurrentDir, eax
	.endif
	invoke CreateProcessA, pAppName, pCmdLine, pProcessAttribs,\
			pThreadAttribs, bInheritHandles, dwCreationFlags,\
			pEnvironment, pCurrentDir, pStartupInfo, pProcessInfo
	@strace	<"CreateProcessW(", pAppName, ", ", pCmdLine, ", ", pProcessAttribs, ", ", pThreadAttribs, ", ...)=", eax>
	ret
	align 4
CreateProcessW endp

	end
