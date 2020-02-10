
;*** DKRNL32.DLL uses dynamic load features from DPMILD32
;*** so LoadLibrary, FreeLibrary and GetProcAddress
;*** all end up in int 21h, AX=4BXX calls

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

?SYSDIR equ 0

	.CODE

if ?FLAT

if ?SYSDIR

TrySysDir proc uses esi edi ebx pszPath:dword

local	szSysDir[256]:byte
local	szPath[512]:byte

	mov esi, pszPath
	.while (byte ptr [esi])
		lodsb
		.if (al == '/') || (al == '\')
			jmp found
		.endif
	.endw
	invoke GetSystemDirectoryA, addr szSysDir, 256
	mov ebx, eax
	invoke GetEnvironmentVariableA, CStr("PATH"), addr szPath, sizeof szPath
	lea esi, szPath
	.while (byte ptr [esi])
		mov ecx, ebx
@@:
		lodsb
		mov ah, [edi]
		inc edi
		and al,not 20h
		and ah,not 20h
		cmp al,ah
		loopz @B
		jz found
		dec esi
		.repeat
			lodsb
		.until ((al == 0) || (al == ';'))
		.break .if (al == 0)
	.endw
	invoke lstrcat, addr szSysDir, CStr("\")
	invoke lstrcat, addr szSysDir, pszPath
	lea edx, szSysDir
	xor ebx, ebx
	push es
	mov es,ebx		  ;no parm block for DLLs
	mov ax,4B00h
	int 21h
	pop es
	ret
found:
	stc
	ret

TrySysDir endp

endif

LoadLibraryExA proc public uses ebx esi edi fname:ptr byte, hFile:DWORD, dwFlags:DWORD

local	szPath[MAX_PATH]:byte

	@strace <"LoadLibraryExA(", &fname, ", ", hFile, ", ", dwFlags, ") enter">

if 0 
;--- check for presence of dpmild32?
;--- if the hdpmi dos extender is called with ES=0, a GPF in ring 0 will occur.
	mov eax,2
	test [g_bIntFl],IKF_PELDR
	jz fail
endif
	mov esi, fname
	lea edi, szPath
	mov al, 00
nextdir:
	mov dl, al
@@:
	lodsb
	stosb
	cmp al, '.'
	jz nextdir
	cmp al,'\'
	jz nextdir
	and al,al
	jnz @B
	.if (dl != '.')
		dec edi
		mov eax, "lld."
		stosd
		mov al,0
		stosb
	.endif
	lea edx, szPath
	xor ebx,ebx
	push es
	mov es,ebx		  ;no parm block for DLLs
	mov ax,4B00h
	int 21h
	pop es
	jnc libfound
	movzx eax,ax
if ?SYSDIR
	cmp eax,2
	jnz @F
	push eax
	invoke TrySysDir, addr szPath
	pop eax
	jnc libfound
@@:
endif
fail:
	@strace <"LoadLibraryExA() load failed, error=", eax>
	invoke SetLastError, eax
	xor eax, eax
libfound:
	@strace <"LoadLibraryExA()=", eax>
	ret
	align 4
LoadLibraryExA endp

endif

	end
