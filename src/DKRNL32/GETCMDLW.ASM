
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

	.DATA

pCmdLineW	dd 0	;todo: this shouldnt be a global variable
					;place it in PROCESS structure

	.CODE


GetCommandLineW proc public uses esi

	@strace <"GetCommandLineW enter">
	cmp pCmdLineW, 0
	jnz done
	invoke GetCommandLineA
	and eax, eax
	jz done
	mov esi, eax
	invoke lstrlenA, eax
	inc eax
	add eax, eax
	invoke LocalAlloc, LMEM_FIXED, eax
	and eax, eax
	jz done
	push edi
	mov edi, eax
	mov pCmdLineW, eax
	mov ah,0
@@:
	lodsb
	stosw 
	and al,al
	jnz @B
	pop edi
done:
	mov eax, pCmdLineW
	@strace <"GetCommandLineW()=", eax >
	ret
GetCommandLineW endp

	end
