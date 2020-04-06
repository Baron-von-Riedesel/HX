
;--- CloseHandle()
;--- the handle might be
;--- 1. a true DOS file handle (<= 10000h [10000h "is" 0000])
;--- 2. Kernel object  (> 10000h && < FFFFFFD0)
;--- 3. special object  (>= FFFFFFD0)

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

	.CODE

CloseHandle proc public uses ebx dwHandle:dword

	xor eax,eax
	mov ebx,dwHandle
if ?FLAT
	test ebx,0FFFF0000h
else
	test ebx,0FFFFF000h
endif
	jz @F
if ?NONULLHDL
	cmp ebx,10000h			;this is DOS handle 0!
	jz resetcon
endif
	inc eax
	cmp ebx,-30 			;some special handles (vwin32, process)
	jnc done
	invoke KernelHeapFree, ebx
	jmp done
@@:
	and ebx, ebx
	jz done				;dont allow handle 0 to be closed
	mov ah,3Eh
	int 21h
	jc error
	xor eax,eax
resetcon:
	movzx ebx,bl
	btr g_bProcessed, ebx
	btr g_bIsConsole, ebx
	inc eax
done:
	@strace <"CloseHandle(", dwHandle, ")=", eax>
	ret
error:
	movzx eax,ax
	invoke SetLastError, eax
	xor eax, eax
	jmp done
	align 4

CloseHandle endp

	end
