
;--- some exports contained in ntdll.dll
;--- dpmild32 will try to resolve ntdll imports by looking into dkrnl32!

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc

;--- versions set in GETVERS.ASM may differ!

?MAJVER	equ 5		;4=win NT/win9x, 5=2K/XP
?MINVER	equ 1
?BUILD	equ 2222

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

	.code

NtCurrentTeb proc public

	mov eax, fs:[THREAD_INFORMATION_BLOCK.ptibSelf]
	ret
	align 4

NtCurrentTeb endp

;--- used by XP OpenGL32.dll

DbgPrint proc c public
	@strace <"DbgPrint()">
	ret
	align 4
DbgPrint endp

;--- called by DOSXNT

RtlExAllocateHeap proc public hHeap:dword, flags:dword, dwBytes:dword

	mov eax, hHeap
	and eax, eax
	jnz @F
	invoke GetProcessHeap
@@:
	invoke HeapAlloc, eax, flags, dwBytes
	@strace <"RtlExAllocateHeap(", hHeap, ", ", flags, ", ", dwBytes, ")=", eax>
	ret
	align 4
RtlExAllocateHeap endp

RtlExFreeHeap proc public hHeap:dword,flags:dword,handle:dword

	mov eax, hHeap
	and eax, eax
	jnz @F
	invoke GetProcessHeap
@@:
	invoke HeapFree, eax, flags, handle
	@strace <"RtlExFreeHeap(", hHeap, ", ", flags, ", ", handle, ")=", eax> 
	ret
	align 4
RtlExFreeHeap endp

RtlExReAllocateHeap proc public hHeap:dword, flags:dword, handle:dword, dwNewSize:dword
	mov eax, hHeap
	and eax, eax
	jnz @F
	invoke GetProcessHeap
@@:
	invoke HeapReAlloc, eax, flags, handle, dwNewSize
	@strace <"RtlExReAllocateHeap(", hHeap, ", ", flags, ", ", handle, ", ", dwNewSize, ")=", eax> 
	ret
	align 4
RtlExReAllocateHeap endp

;--- imported by MSVCRT.DLL of WinXP

RtlGetNtVersionNumbers proc public pMajorVersion:ptr DWORD, pMinorVersion:ptr DWORD, pBuildNumber:ptr DWORD
	mov ecx,pMajorVersion
	jecxz @F
	mov dword ptr [ecx], ?MAJVER
@@:
	mov ecx,pMinorVersion
	jecxz @F
	mov dword ptr [ecx], ?MINVER
@@:
	mov ecx,pBuildNumber
	jecxz @F
	mov dword ptr [ecx], ?BUILD
@@:
	@mov eax,1
	@strace <"RtlGetNtVersionNumbers(", pMajorVersion, ", ", pMinorVersion, ", ", pBuildNumber, ")=", eax>
	ret
	align 4
RtlGetNtVersionNumbers endp        

IsWow64Process proc public hProcess:dword, pbIs64:ptr dword
	mov ecx, pbIs64
	xor eax, eax
	mov [ecx],eax
	inc eax
	@strace <"IsWow64Process(", hProcess, ", ", pbIs64, ")=", eax>
	ret
	align 4
IsWow64Process endp

	end
