
;--- kernel heap procedures

;--- the heap is used for
;--- 1. sync objects
;       FILE        textequ <"FILE">
;       SEMAPHOR    textequ <"SEMA">
;       MUTEX       textequ <"MUTE">
;       EVENT       textequ <"EVEN">
;       TIMER       textequ <"TIME">
;       PROCESS     textequ <"PROC">
;       THREAD      textequ <"THRD">
;       FILEMAPP    textequ <"FMAP">
;       CHANGENOT   textequ <"CHNT">
;       SOCKET      textequ <"SCKT">
;       PIPE        textequ <"PIPE">
;--- 2. Atom objects (ATOMS.ASM)
;--- 3. Heap block descriptors (HBLOCK)
;--- 4. others

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

	option dotname

?EXTCHK equ 0	;1 to display kernel heap corruption

?KHEAPSIZE	equ 1000h

.BASE$XA SEGMENT dword public 'DATA'
	DD offset Deinstall
.BASE$XA ENDS

;--- for MZ support: make sure constructor is executed before all
;--- other runtime initialization.

ife ?FLAT
extern __KERNELINIT:abs
DGROUP  group .BASE$XA
endif

	.DATA

pNamedObjects dd 0

;--- the kernel heap descriptor.

	dd 0	;a mutex is a kernel object with possible
			;destructor at offset -4
khmutex	MUTEX {{{SYNCTYPE_MUTEX},0,0},1,0,0}
if ?FREELIST
defaultheap	HEAPDESC {khmutex, HEAP_GROWABLE, 0, offset kheap_defblock,\
	offset kheap_defblock, 0 }
else
defaultheap	HEAPDESC {khmutex, HEAP_GROWABLE, 0, offset kheap_defblock,\
	offset kheap_defblock, 0, offset (kheap_defblock + ?KHEAPSIZE - 4)}
endif

hKernelHeap dd 0

	public kheap_defblock

	.data?

;--- the kernel heap is a normal heap which can be accessed
;--- by HeapAlloc, HeapFree, ...

kheap_defblock db ?KHEAPSIZE dup (?)

	.code

if 1
GetKernelHeap proc public
	mov eax, hKernelHeap
	ret
	align 4
GetKernelHeap endp
endif

IsKernelHeapLocked proc public
	mov ecx, hKernelHeap
	xor eax, eax
	mov ecx, [ecx].HEAPDESC.mutex
	cmp [ecx].MUTEX.dwOwner, eax
	setnz al
	ret
	align 4
IsKernelHeapLocked endp

;--- alloc a kernel heap memory object.
;--- all objects have an optional destructor at offset -4
;--- which is used by KernelHeapFree

KernelHeapAlloc proc public dwBytes:DWORD

	mov eax, hKernelHeap
	.if (!eax)
		mov eax, offset defaultheap
		mov hKernelHeap, eax
		mov ecx, ?KHEAPSIZE - 8 + 1
		mov edx, offset kheap_defblock
		mov [edx].FLITEM.dwSize, ecx
		mov [edx].FLITEM.pNext, NULL
		lea ecx,[ecx+edx+3]
		mov dword ptr [ecx], _HEAP_END
		mov [eax].HEAPDESC.last, ecx
		@strace <"init kernel heap, heap desc=", eax, ", start block=", [eax].HEAPDESC.start>
	.endif
	mov ecx, dwBytes
	lea ecx, [ecx+4]
;;	invoke HeapAlloc, eax, 0, ecx
ifdef _DEBUG
	pushfd
	pop edx
	test dh,2	;interrupts disabled?
	jnz @F
	mov edx, [eax].HEAPDESC.mutex
	.if ([edx].MUTEX.dwOwner)	;kernelheap locked?
		int 3
	.endif
@@:
endif
	invoke HeapAlloc, eax, HEAP_ZERO_MEMORY, ecx
	.if (eax)
		mov dword ptr [eax],0
		lea eax, [eax+4]
	.endif
	@strace <"KernelHeapAlloc(", dwBytes, ")=", eax>
	ret
	align 4
KernelHeapAlloc endp

;--- alloc a kernel object

KernelHeapAllocObject proc public uses ebx dwBytes:DWORD, lpName:ptr BYTE

	mov eax, lpName
	.if (!eax)
		invoke KernelHeapAlloc, dwBytes
		jmp done
	.endif
	invoke lstrlen, eax
	inc eax
	add eax, dwBytes
	invoke KernelHeapAlloc, eax
	.if (eax)
		mov ebx, eax
		add  eax, dwBytes
		mov [ebx].NAMEDOBJECT.lpName, eax
		invoke lstrcpy, eax, lpName
		mov eax, ebx
		mov edx, pNamedObjects
		mov pNamedObjects, eax
		mov [eax].NAMEDOBJECT.NextObj, edx
	.endif
done:
	ret
	align 4
KernelHeapAllocObject endp

KernelHeapFree proc public uses ebx handle:DWORD

	xor eax, eax
	mov ebx, handle
	.if (hKernelHeap && ebx)
		mov ecx, dword ptr [ebx-4]
		.if ( ecx && dword ptr [ebx] != -1 )
if ?EXTCHK
			push ecx
			invoke IsBadCodePtr, ecx
			pop ecx
			and eax, eax
			jz @F
			sub esp,80
			mov edx, esp
			invoke _sprintf, edx, CStr(<"corrupted heap. item=%X, [item]=%X %X",lf>),\
				ebx, dword ptr [ebx-4], dword ptr [ebx]
			invoke Display_szString, esp
			add esp,80
			jmp done
@@:
endif
			push ebx
			call ecx
			.if (!eax)
				inc eax
				jmp done
			.endif
			mov dword ptr [ebx],-1	;make sure this is no longer used
		.endif
		lea ebx, [ebx-4]
		invoke HeapFree, hKernelHeap, 0, ebx
	.endif
done:
	@strace <"KernelHeapFree(", handle, ")=", eax>
	ret
	align 4
KernelHeapFree endp

;--- this function can be used to find a named object

KernelHeapFindObject proc public uses ebx esi lpszName:ptr BYTE, dwType:DWORD

	mov ebx, hKernelHeap
	mov esi, pNamedObjects
	.if (ebx && esi)
		invoke WaitForSingleObject, [ebx].HEAPDESC.mutex, INFINITE
		.while (esi)
			invoke lstrcmp, lpszName, [esi].NAMEDOBJECT.lpName
			.if (!eax)
				mov eax, dwType
				.if ( eax == [esi].SYNCOBJECT.dwType )
					.if ([esi].SYNCOBJECT.dwType == SYNCTYPE_EVENT)
						inc [esi].EVENT.bRefCnt
					.elseif ([esi].SYNCOBJECT.dwType == SYNCTYPE_MUTEX)
						inc [esi].MUTEX.wRefCnt
					.elseif ([esi].SYNCOBJECT.dwType == SYNCTYPE_TIMER)
						inc [esi].TIMER.bRefCnt
					.elseif ([esi].SYNCOBJECT.dwType == SYNCTYPE_FILEMAPP)
						inc [esi].FILEMAPOBJ.dwRefCnt
					.else
						inc [esi].SEMAPHORE.dwRefCnt
					.endif
					invoke SetLastError, ERROR_ALREADY_EXISTS
					invoke ReleaseMutex, [ebx].HEAPDESC.mutex
					mov eax, esi
					mov edx, eax
				.else
					invoke SetLastError, ERROR_INVALID_HANDLE
					invoke ReleaseMutex, [ebx].HEAPDESC.mutex
					mov eax, esi
					xor edx, edx
				.endif
				ret
			.endif
			mov esi, [esi].NAMEDOBJECT.NextObj
		.endw
		invoke ReleaseMutex, [ebx].HEAPDESC.mutex
	.endif
	xor eax, eax
	mov edx, eax
	ret
	align 4
KernelHeapFindObject endp

KernelHeapUnlinkObject proc public uses ebx obj:ptr NAMEDOBJECT

	mov ebx, hKernelHeap
	invoke WaitForSingleObject, [ebx].HEAPDESC.mutex, INFINITE
	xor edx, edx
	mov eax, pNamedObjects
	.while eax
		.if  (eax == obj)
			mov ecx, [eax].NAMEDOBJECT.NextObj
			.if ( edx )
				mov [edx].NAMEDOBJECT.NextObj, ecx
			.else
				mov pNamedObjects, ecx
			.endif
			.break
		.endif
		mov edx, eax
		mov eax, [eax].NAMEDOBJECT.NextObj
	.endw
	invoke ReleaseMutex, [ebx].HEAPDESC.mutex
	ret
	align 4
KernelHeapUnlinkObject endp

;--- walk the kernel heap
;--- used by FileMapp.asm

KernelHeapWalk proc public pphe:ptr PROCESS_HEAP_ENTRY, dwType:DWORD

	mov eax, hKernelHeap
	.if (eax)
nextscan:
		invoke HeapWalk, hKernelHeap, pphe
		mov edx,dwType
		.if (eax && edx)
			mov ecx, pphe
			mov ecx, [ecx].PROCESS_HEAP_ENTRY.lpData
			lea ecx, [ecx+4]
			.if (edx != [ecx].SYNCOBJECT.dwType)
				jmp nextscan
			.endif
			mov eax, ecx
		.endif
	.endif
	ret
	align 4
KernelHeapWalk endp

;--- exit sequence. Delete kernel heap.

Deinstall proc

	@strace <"kernelheap deinstall enter">
	xor eax, eax
	xchg eax, hKernelHeap
	.if (eax)
		invoke HeapDestroy, eax		;1 instance of DKRNL32.DLL
	.endif
	@strace <"kernelheap deinstall exit">
	ret
	align 4
Deinstall endp

	end

