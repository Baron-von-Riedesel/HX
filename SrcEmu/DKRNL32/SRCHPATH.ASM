
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

;--- both lpPath and lpExtension can be NULL

SearchPathA	proc public uses ebx esi edi lpPath:ptr BYTE, lpFileName:ptr BYTE, lpExtension:ptr BYTE,
			nBufferLength:DWORD, lpBuffer:ptr BYTE, lpFilePart:ptr ptr BYTE

local	szPath[1024]:byte
local	szFile[MAX_PATH]:byte
local	szFullName[MAX_PATH]:byte

;-------------- if lpPath is NULL, make one with
;-------------- 1. path of executable module +
;-------------- 2. current directory +
;-------------- 3. PATH environment variable

ifdef _DEBUG
	mov ecx, lpExtension
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
endif
	@strace <"SearchPathA(", lpPath, ", ", &lpFileName, ", ", &ecx, ", ", nBufferLength, ", ", lpBuffer, ", ", lpFilePart, ") enter">

	.if (!lpPath)
		invoke GetModuleFileName, NULL, addr szPath, sizeof szPath
		lea ecx, szPath
		mov lpPath, ecx
		.while (eax)
			dec eax
			.if (byte ptr [ecx+eax] == '\')
				mov word ptr [ecx+eax],';'
				inc eax
				.break
			.endif
		.endw
		lea ebx, [ecx+eax]
		invoke GetCurrentDirectory, MAX_PATH, ebx
		add ebx, eax
		mov word ptr [ebx],';'
		inc ebx
		lea ecx, szPath + sizeof szPath
		sub ecx, ebx
		invoke GetEnvironmentVariableA, CStr("PATH"), ebx, ecx
	.endif

;-------------- add extension to filename

	mov ecx, lpExtension
	.if (ecx && byte ptr [ecx] == '.')
		invoke lstrlen, lpFileName
		mov ecx, lpFileName
		mov dl,0
;-------------- check if filename already has an extension
		.while (eax)
			dec eax
			mov dl, [ecx+eax]
			.break .if ((dl == '\') || (dl == ':') || (dl == '.'))
		.endw
		.if (dl != '.')
			invoke lstrcpy, addr szFile, lpFileName
			lea ecx, szFile
			mov lpFileName, ecx
			invoke lstrcat, ecx, lpExtension
		.endif
	.endif

	lea esi, szPath
        
	mov ecx, lpFileName
	.if (byte ptr [ecx+1] == ':')
		mov byte ptr [esi],0
		lea edi, szFullName
		mov ecx, sizeof szFullName
		jmp scandirect
	.endif
        
;--- now search all entries of PATH        
        
	.while (byte ptr [esi])
		lea edi, szFullName
		mov ecx, sizeof szFullName
		mov ah,00
		.while (ecx)
			lodsb
			.break .if ((al == ';') || (al == 0))
			stosb
			mov ah, al
			dec ecx
		.endw
		.if (!al)
			dec esi
		.endif
		.if (ah != '\')
			mov al, '\'
			stosb
			dec ecx
		.endif
;------------------------------------ calulate size so far in ebx
scandirect:
		mov ebx, sizeof szFullName
		sub ebx, ecx

		push esi
		mov esi, lpFileName
		.while (ecx)
			lodsb
			stosb
			dec ecx
			.break .if (!al)
		.endw
		pop esi
		invoke GetFileAttributesA, addr szFullName
		.if (eax != -1)
			invoke lstrlen, addr szFullName
			push eax
			inc eax
			.if (eax <= nBufferLength)
				invoke lstrcpy, lpBuffer, addr szFullName
				mov eax, lpBuffer
				add eax, ebx
				mov ecx, lpFilePart
				jecxz @F
				mov [ecx], eax
@@:                    
			.endif
			pop eax
			.break
		.endif
		xor eax, eax
	.endw
done:
	@strace <"SearchPath()=", eax>
	ret
	align 4

SearchPathA endp

	END
