
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

AllocConsole proc public

if 0
	invoke GetCurrentProcess
	mov ecx, eax
	test [ecx].PROCESS.wFlags, PF_CON_ATTACHED
	setz al
	movzx eax, al
	or [ecx].PROCESS.wFlags, PF_CON_ATTACHED
endif
	@strace <"AllocConsole()=", eax>
	ret
	align 4

AllocConsole endp

FreeConsole proc public

if 0
	invoke GetCurrentProcess
	mov ecx, eax
	test [ecx].PROCESS.wFlags, PF_CON_ATTACHED
	setnz al
	and [ecx].PROCESS.wFlags, not PF_CON_ATTACHED
	movzx eax, al
endif
	@strace <"FreeConsole()=", eax>
	ret
	align 4

FreeConsole endp

if ?FLAT

AttachConsole proc public hParm:DWORD

	cmp hParm, ATTACH_PARENT_CONSOLE
	jnz error
	invoke GetCurrentProcess
	test [eax].PROCESS.wFlags, PF_CON_ATTACHED
	jnz error
	or [eax].PROCESS.wFlags, PF_CON_ATTACHED
	@mov eax, 1
exit:
	@strace <"AttachConsole(", hParm, ")=", eax>
	ret
error:
	invoke SetLastError, ERROR_ACCESS_DENIED
	xor eax, eax
	jmp exit
	align 4

AttachConsole endp

endif

end

