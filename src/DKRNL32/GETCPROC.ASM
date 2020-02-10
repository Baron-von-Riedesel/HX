
;--- implements GetCurrentProcess, GetCurrentProcessId

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

	.code

;--- in Win32 GetCurrentProcess returns a pseudo handle
;--- 7FFFFFFFh in win9x, FFFFFFFF in winxp
;--- dkrnl returns the true handle

GetCurrentProcess proc public

	mov eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	ret
	align 4

GetCurrentProcess endp

GetCurrentProcessId proc public

	invoke GetCurrentProcess
	@strace <"GetCurrentProcessId()=", eax>
	ret
	align 4

GetCurrentProcessId endp

	end
