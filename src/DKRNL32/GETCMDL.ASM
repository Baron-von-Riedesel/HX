
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

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

;--- in Win32 if no command line is given,
;--- the program name + 1 space is returned!

	.CODE

GetDosCmdTail proc uses ebx esi edi pszCmdLine:ptr BYTE, dwMax:dword

local	lpgmname:dword
local	dwCmdSize:DWORD
local	pCmd:dword

	invoke GetModuleHandleA,0
	and eax,eax
	jz exit
	mov esi, eax
	mov edi, pszCmdLine
	invoke GetModuleFileNameA, eax, edi, dwMax
	add edi, eax
	inc eax
	sub dwMax, eax
	mov al," "
	stosb

	mov ah,62h
	int 21h
	push ds
	mov ds,ebx

;---------------- get the parent psp and check if we are called
;---------------- by a "WIN32" app. Thats required because commandline
;---------------- is handled differently for win32 and win16/dos apps.
;---------------- The flag in the PSP is set in CreateProcess emulation

	movzx eax, word ptr ds:[16h]
	shl eax, 4
if ?FLAT
	mov dl,byte ptr es:[eax+4Fh]
else
	mov dl,byte ptr @flat:[eax+4Fh]
endif
	mov esi, 80h
	lodsb
	movzx ecx, al
	mov dwCmdSize, ecx
	.if (ecx)
		dec dwMax				;dont count terminating 0
		.if (ecx > dwMax)
			mov ecx, dwMax
		.endif
		rep movsb
	.endif
	pop ds
	mov byte ptr [edi], 0
	sub edi, pszCmdLine
	mov eax, edi
	.if (dl & 1)
		mov edx, 7Fh
	.else
		mov edx, dwCmdSize
	.endif
exit:
	ret
	align 4

GetDosCmdTail endp

;*** returns ^ to commandline in eax

GetCommandLineA proc public uses esi edi

local	dwSize:DWORD
local	cmdline[1024]:byte

	@trace <"GetCommandLineA() enter",13,10>

	mov esi, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov eax, [esi].PROCESS.pCmdLine
	and eax, eax
	jnz exit
	invoke GetDosCmdTail, addr cmdline, sizeof cmdline
	@trace <"Length of dos command tail: ">
	@tracedw edx
	@trace <13,10>
	.if (edx > 7Eh)
		invoke GetEnvironmentVariableA, CStr("CMDLINE"), addr cmdline, sizeof cmdline
	.endif
	inc eax
	mov dwSize, eax
	invoke LocalAlloc, LMEM_FIXED, eax
	and eax,eax
	jz exit

	mov [esi].PROCESS.pCmdLine, eax

	mov edi,eax
	lea esi,cmdline

	@trace <"commandLine: !">
	@trace esi
	@trace "!"
	@trace <13,10>

	push eax
	mov ecx,dwSize
	rep movsb
	pop eax
exit:
	@strace <"GetCommandLineA()=", eax>
	ret
	align 4

GetCommandLineA endp

	end

