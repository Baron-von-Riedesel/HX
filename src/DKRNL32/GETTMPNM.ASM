
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:NONE

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

GetTempFileNameA proc uses esi edi ebx pszTempDir:ptr BYTE, pszPrefix:ptr BYTE,
			uUnique:DWORD, pszOut:ptr BYTE

local	systemtime:SYSTEMTIME
local	tmpdir[MAX_PATH]:byte

	@strace <"GetTempFileNameA(", pszTempDir, ", ", pszPrefix, ", ", uUnique, ", ", pszOut, ") enter">
	mov esi, pszTempDir
	mov ecx, sizeof tmpdir
	lea edi, tmpdir
@@:
	lodsb
	stosb
	and al,al
	loopnz @B
	dec edi
	cmp byte ptr [edi-1],'\'
	jz @F
	mov al,'\'
	stosb
@@:
	mov esi,pszPrefix
	and esi,esi
	jz tmpnam_0
	mov ecx,3
@@:
	lodsb
	and al,al
	jz @F
	stosb
	loop @B
@@:
tmpnam_0:
	mov eax, uUnique
	.if (eax)
		call __dw2a
		mov eax,"PMT."
		stosd
		mov al,0
		stosb
	.else
		invoke GetSystemTime, addr systemtime
;------------------------- ensure that size filename is <= 8
;------------------------- prefix is max 3 bytes
;------------------------- so unique should be 5 max (eax=000xxxxx)
		xor eax, eax
		mov ah, byte ptr systemtime.wMinute
		and ah, 0Fh
		mov al, byte ptr systemtime.wSecond
		shl eax, 8
		mov al, byte ptr systemtime.wMilliseconds
		mov uUnique, eax
		mov ebx, edi
		.while (1)
			mov edi, ebx
			mov eax, uUnique
			call __dw2a
			mov eax,"PMT."
			stosd
			mov al,0
			stosb
			invoke CreateFile, addr tmpdir, GENERIC_WRITE, 0,\
				NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL
			.break .if (eax != -1)
			inc uUnique
		.endw
		invoke CloseHandle, eax
	.endif
	invoke lstrcpy, pszOut, addr tmpdir
	mov eax, uUnique
	jmp done
tmpnam_er:
	xor eax,eax
done:
	@strace <"GetTempFileNameA()=", eax>
	ret
	align 4
GetTempFileNameA endp

GetTempFileNameW proc pszTempDir:ptr WORD, pszPrefix:ptr WORD,
			uUnique:DWORD, pszOut:ptr WORD

	mov eax, pszTempDir
	.if (eax)
		call ConvertWStr
		mov pszTempDir, eax
	.endif
	mov eax, pszPrefix
	.if (eax)
		call ConvertWStr
	.endif
	invoke GetTempFileNameA, pszTempDir, eax, uUnique, pszOut
	.if (eax && pszOut)
		invoke ConvertAStr, pszOut
	.endif
	@strace <"GetTempFileNameW(", pszTempDir, ", ", pszPrefix, ", ", uUnique, ", ", pszOut, ")=", eax>
	ret
	align 4
GetTempFileNameW endp

	END
