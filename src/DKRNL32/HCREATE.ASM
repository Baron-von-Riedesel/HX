
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
	include heap32.inc
	include macros.inc

?DEFHEAPSIZE	equ 100000h	;default reserved heap size for growable heaps

	.CODE

;*** In : eax=^block, ecx=size of blocks, edx=heap flags ***
;*** Out: eax=Heap Handle (=unchanged)

;--- this proc has to be public, called by static CRT for SMALL model

_heapset proc c public uses ebx

	mov ebx,eax 					; ebx=heap descriptor
	mov [ebx].HEAPDESC.flags, edx
	add eax,sizeof HEAPDESC
;;	and cl,3
	sub ecx,7 + sizeof HEAPDESC 	;8 bytes overhead (set bit 0
	mov [eax].FLITEM.dwSize, ecx
	mov [eax].FLITEM.pNext,0
	mov [ebx].HEAPDESC.start,eax	;init start/rover
	mov [ebx].HEAPDESC.rover,eax
	add eax,ecx
	add eax,3
	mov dword ptr [eax],_HEAP_END

	mov [ebx].HEAPDESC.pNextRegion,0;further regions for this heap
	mov [ebx].HEAPDESC.last,eax		;pointer to end-of-heap
	xor eax,eax
	mov [ebx].HEAPDESC.dwSize,eax	;init uncommitted memory size
	test edx,HEAP_NO_SERIALIZE
	jnz @F
	invoke CreateMutexA, eax, eax, eax
@@:
	mov [ebx].HEAPDESC.mutex, eax
	mov eax,ebx
	ret
	align 4

_heapset endp

;--- alloc a heap region
;--- dwReserved: reserved bytes
;--- dwInitial: committed bytes - if 0, 1000h is used
;--- out: eax = linear address of heap region

HeapAllocRegion proc public uses ebx dwAddr:dword, dwReserved:dword, dwInitial:dword, heapdesc:dword, dwFlags:dword

	@strace <"HeapAllocRegion(", dwAddr, ", ", dwReserved, ", ", dwInitial, ", ", heapdesc, ", ", dwFlags, ")">

;--- round up the committed part to a page boundary
	add dwInitial,0FFFh
	and word ptr dwInitial,0F000h
	cmp dwInitial,0
	jnz @F
	mov dwInitial,1000h
@@:
;--- round up the reserved part to a 64 kB boundary
	add dwReserved,0FFFFh
	mov word ptr dwReserved,0h
	invoke VirtualAlloc, dwAddr, dwReserved, MEM_RESERVE, PAGE_READWRITE
	.if (eax)
		mov ebx, eax
		invoke VirtualAlloc, ebx, dwInitial, MEM_COMMIT, PAGE_READWRITE
		.if (eax)
			mov eax, heapdesc	;is it the first region of a heap?
			and eax, eax
			jnz @F
			mov eax, ebx
			mov ecx, dwInitial
			mov edx, dwFlags
			invoke _heapset
@@:
			mov ecx, dwReserved
			sub ecx, dwInitial
			jc @F
			mov [eax].HEAPDESC.dwSize, ecx
@@:
			mov eax, ebx
		.endif
	.endif
	@strace <"HeapAllocRegion()=", eax>
	ret
	align 4
HeapAllocRegion endp

;*** create a heap
;--- dwInitial: initial committed size. if 0, one page (1000h) is committed
;--- dwMax: max size of heap. if 0, heap is growable.

HeapCreate proc public dwOptions:dword, dwInitial:dword, dwMax:dword

	mov edx,dwOptions
	mov eax,dwMax
	and edx,HEAP_NO_SERIALIZE
	and eax,eax
	jnz @F
	or edx, HEAP_GROWABLE
	mov eax, ?DEFHEAPSIZE
	cmp eax, dwInitial
	jnc @F
	mov eax, dwInitial
@@:
	invoke HeapAllocRegion, 0, eax, dwInitial, 0, edx
	and eax, eax
	jz error2
exit:
	@strace <"HeapCreate(", dwOptions, ", ", dwInitial, ", ", dwMax, ")=", eax>
	ret
error2:
	test dwOptions, HEAP_GENERATE_EXCEPTIONS
	jz exit
	invoke RaiseException, STATUS_NO_MEMORY,0,0,0
	align 4

HeapCreate endp

	end
