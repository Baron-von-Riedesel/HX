
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
	include dkrnl32.inc
	include hxvdd.inc

HXVDD	equ 1	;use HXVDD for GlobalAlloc ( Clipboard support for DOS )

	.CODE

;--- like in win32 there's no difference between
;--- Local/GlobalAlloc and they all end up in
;--- HeapAlloc

;--- in: local/global flags in edx, out: heap flags in ecx

translateflags proc
	xor ecx,ecx
	test dl,LMEM_ZEROINIT
	jz @F
	or cl,HEAP_ZERO_MEMORY
@@:
	ret
	align 4
translateflags endp

;--- the GlobalXXX versions must remain empty or include a RET!
;--- else MASM will create not-working code

GlobalAlloc proc public flags:dword,bytes:dword
GlobalAlloc endp

LocalAlloc proc public uFlags:dword, uBytes:dword

if HXVDD
externdef g_hVdd:dword
	test uFlags, GMEM_MOVEABLE
	jz @F
	cmp g_hVdd, 0
	jz @F
	push ebx
	mov edx, VDD_GLOBALALLOC
	mov ecx, uFlags
	mov ebx, uBytes
	call HXDispatch
	pop ebx
	jmp exit
@@:
endif
	invoke GetProcessHeap
	mov edx, uFlags
	call translateflags
	invoke HeapAlloc,eax,ecx, uBytes
exit:
	@strace <"Local/GlobalAlloc(", uFlags, ", ", uBytes, ")=", eax>
	ret
	align 4
LocalAlloc endp

;--- GlobalFree/LocalFree return NULL on success,
;--- and the handle on failure

GlobalFree proc public hMem:dword
GlobalFree endp

LocalFree proc public hMem:dword

	invoke GetProcessHeap
	invoke HeapFree, eax, 0, hMem
	.if (!eax)
		mov eax, hMem
	.else
		xor eax, eax
	.endif
	@strace <"Local/GlobalFree(", hMem, ")=", eax>
	ret
	align 4
LocalFree endp

GlobalReAlloc proc public hMem:dword, uBytes:dword, uFlags:DWORD
GlobalReAlloc endp

LocalReAlloc  proc public hMem:dword, uBytes:dword, uFlags:DWORD

	invoke GetProcessHeap
	mov edx, uFlags
	test dl, LMEM_MODIFY
	jnz modify
	call translateflags
	test dl, LMEM_MOVEABLE
	jnz @F
	or cl, HEAP_REALLOC_IN_PLACE_ONLY
@@:
	invoke HeapReAlloc, eax, ecx, hMem, uBytes
exit:
	@strace <"Local/GlobalReAlloc(", hMem, ", ", uBytes, ", ", uFlags, ")=", eax>
	ret
modify:
	mov eax,hMem
	jmp exit
	align 4

LocalReAlloc endp

GlobalHandle proc public handle:DWORD
GlobalHandle endp

LocalHandle proc public handle:DWORD
LocalHandle endp

GlobalLocalHandle proc handle:DWORD
	invoke GetProcessHeap
	invoke HeapValidate, eax, 0, handle
	.if (eax)
		mov eax, handle
	.endif
	@strace <"Global/LocalHandle(", handle, ")=", eax>
	ret
	align 4
GlobalLocalHandle endp

GlobalLock proc public handle:DWORD
GlobalLock endp

LocalLock proc public handle:DWORD
if HXVDD
	cmp g_hVdd, 0
	jz @F
	mov edx, VDD_GLOBALLOCK
	mov ecx, handle
	call HXDispatch
	and eax, eax
	jnz exit
@@:
endif
	invoke GlobalLocalHandle, handle
exit:
	@strace <"Global/LocalLock(", handle, ")=", eax>
	ret
	align 4
LocalLock endp

GlobalUnlock proc public handle:DWORD
GlobalUnlock endp

LocalUnlock proc public handle:DWORD
if HXVDD
	cmp g_hVdd, 0
	jz @F
	mov edx, VDD_GLOBALUNLOCK
	mov ecx, handle
	call HXDispatch
	and eax, eax
	jz @F
	ret
@@:
endif
	mov eax, handle
	@strace <"Global/LocalUnlock(", handle, ")=", eax>
	ret
	align 4
LocalUnlock endp

;--- the xxxFlags() functions will return 00000000

GlobalFlags proc public handle:DWORD
GlobalFlags endp

LocalFlags proc public handle:DWORD
	xor eax, eax
	@strace <"Global/LocalFlags(", handle, ")=", eax>
	ret
	align 4
LocalFlags endp

GlobalSize proc public handle:DWORD
ifdef _DEBUG
	invoke GetProcessHeap
	invoke HeapSize, eax, 0, handle
	@strace <"GlobalSize(", handle, ")=", eax>
	ret
	align 4
endif
GlobalSize endp

LocalSize proc public handle:DWORD
	invoke GetProcessHeap
	invoke HeapSize, eax, 0, handle
	@strace <"LocalSize(", handle, ")=", eax>
	ret
	align 4
LocalSize endp

GlobalCompact proc public handle:DWORD
	xor eax, eax
	@strace <"GlobalCompact(", handle, ")=", eax>
	ret
GlobalCompact endp

if 0
	public GlobalFix@4
	public GlobalUnfix@4
GlobalFix@4::
GlobalUnfix@4::
	retn 4
endif

end

