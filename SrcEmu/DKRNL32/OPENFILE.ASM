
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
	include dkrnl32.inc
	include macros.inc

	.CODE

OpenFile proc public uses ebx pszFilename:ptr byte, lpReopenBuff:ptr OFSTRUCT, uStyle:dword

local	lpFilePart:ptr byte

	@strace <"OpenFileA(", &pszFilename, ", ", lpReopenBuff, ", ", uStyle, ") enter">
	mov ebx, lpReopenBuff
	invoke SearchPath, NULL, pszFilename, NULL,\
		sizeof OFSTRUCT.szPathName, addr [ebx].OFSTRUCT.szPathName,\
		addr lpFilePart
	mov ecx, uStyle
	.if (eax)
		mov [ebx].OFSTRUCT.cBytes, sizeof OFSTRUCT
		mov [ebx].OFSTRUCT.fFixedDisk, 1
		mov [ebx].OFSTRUCT.nErrCode, 0
		.if (ecx & OF_PARSE)
		.elseif (ecx & OF_EXIST)
		.elseif (ecx & OF_CREATE)
			invoke _lcreat, pszFilename, 0
		.elseif (ecx & OF_DELETE)
			invoke DeleteFile, addr [ebx].OFSTRUCT.szPathName
		.else
			invoke _lopen, pszFilename, uStyle
		.endif
	.else
		.if (ecx & OF_CREATE)
			invoke _lcreat, pszFilename, 0
		.else
			@mov eax, HFILE_ERROR
		.endif
	.endif
	@strace <"OpenFileA(", &pszFilename, ", ", lpReopenBuff, ", ", uStyle, ")=", eax>
	ret
	align 4

OpenFile endp

	end

