
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

	.data

;--- g_hCurThread is public, because GetCurrentThread() in Win32
;--- does return a constant value, not the real thread handle.
;--- in HX this in currently not true, but may be changed to be
;--- more Win32 compatible

if ?GBLCURRENT
g_hCurThread	dd 0
endif

	.code

;--- GetCurrentThread is not quite compatible with Win32
;--- because in Win32 it returns a pseudo handle (-2?)

GetCurrentThread proc public
GetCurrentThread endp

;--- this is the internally used version of GetCurrentThread
;--- it returns a valid thread handle in any case

_GetCurrentThread proc public
if ?GBLCURRENT
	mov   eax,[g_hCurThread]	 ;does a thread exist?
else
	mov   eax, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov   eax, [eax].PROCESS.hThread
endif
;	@strace	<"GetCurrentThread()=", eax>
	ret
	align 4
        
_GetCurrentThread endp

	end
        
