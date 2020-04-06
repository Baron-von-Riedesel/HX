
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

?KHEAP	equ 0	;std=0, 1 for kernel heap debugging

TIBSEG segment use16
TIBSEG ends
	assume fs:TIBSEG	;declare FS=TIB a 16 bit segment (saves space)

	.CODE

;--- dont create heap if not already there

GetProcessHeapEx proc uses ebx bCreate:DWORD

	mov ebx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
	mov eax, [ebx.PROCESS.pHeap]
	and eax, eax
	jnz exit
	.if (bCreate)
if ?FLAT
		invoke GetModuleHandle, NULL
		mov ebx, eax
		add ebx, [ebx].IMAGE_DOS_HEADER.e_lfanew
		mov eax, [ebx.IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeapReserve]
		and eax, eax
		jz exit
		mov ecx, [ebx.IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeapCommit]
else
		mov eax, 20000h
		mov ecx, 20000h/4
endif
if 0
		invoke HeapCreate, 0, eax, NULL
else
		invoke HeapAllocRegion, 0, eax, ecx, 0, HEAP_GROWABLE
endif
		mov ebx, fs:[THREAD_INFORMATION_BLOCK.pProcess]
		mov [ebx].PROCESS.pHeap, eax
	.endif
exit:
	ret
	align 4

GetProcessHeapEx endp

GetProcessHeap proc public

	invoke GetProcessHeapEx, 1
if ?KHEAP
	push eax
	invoke GetKernelHeap
	mov edx, eax
	pop eax
endif
	@strace <"GetProcessHeap()=", eax>
	ret
	align 4

GetProcessHeap endp

	end

