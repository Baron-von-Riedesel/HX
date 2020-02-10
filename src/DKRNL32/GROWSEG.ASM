
;*** function: increase heap in chunks
;*** compatible with MSVC CRT
;*** chunk size in g_amblksiz

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

	.DATA

g_amblksiz	dd _HEAP_GROWSEG

	.CODE

;*** EBX->heapdesc ***

setmemblock proc blockaddr:dword

	pushad
	invoke GetKernelHeap	;don't do that for kernel heap
	cmp eax, ebx
	jz @F
	invoke KernelHeapAlloc, sizeof HBLOCK
	and eax,eax
	jnz objok
@@:
	mov eax, blockaddr	;store the HBLOCK info at start of this block
	stc
objok:
	mov edx,eax
	xchg eax,[ebx.HEAPDESC.pNextRegion]
	mov [edx].HBLOCK.pNext,eax
	mov eax,blockaddr
	mov [edx].HBLOCK.dwAddr,eax
	popad
	ret
	align 4

setmemblock endp

;*** increase heap
;*** in: ebx -> heap object
;--- edi = flags 
;*** ecx = bytes

_growseg proc c public uses ecx esi

local	dwSize:dword
local	dwLast:dword

	@strace <"_growseg enter, size=", ecx, ", still uncommitted=", [ebx].HEAPDESC.dwSize, ", rover=", [ebx].HEAPDESC.rover, ", last=", [ebx].HEAPDESC.last>
	mov dwSize, ecx        
	test edi,HEAP_NO_SERIALIZE
	jnz @F
	invoke WaitForSingleObject,[ebx].HEAPDESC.mutex,INFINITE
	or byte ptr [ebx.HEAPDESC.flags],_HEAP_GROWING
@@:
	mov dwLast,0
	mov ecx, dwSize
	push edi
	call _findlast		;check if last item is free
	jc @F				;jump if it is not
	mov dwLast,eax
	sub ecx, eax
	jbe done 			;last item is large enough!?
@@:
	mov esi, [ebx].HEAPDESC.last
	add esi, 4
	cmp ecx, [ebx].HEAPDESC.dwSize  ;will uncommitted part suffice?
	jc @F
	mov ecx, dwSize
	cmp [ebx].HEAPDESC.dwSize, 0
	jz nouncommitted
	mov ecx, [ebx].HEAPDESC.dwSize
@@:
	add ecx,0FFFh
	and cx,0F000h
	push ecx
	invoke VirtualAlloc, esi, ecx, MEM_COMMIT, PAGE_READWRITE
	pop ecx
	and eax,eax
	stc
	jz exit 
	sub [ebx].HEAPDESC.dwSize,ecx
	lea eax,[esi+ecx-4]
	mov dword ptr [eax],_HEAP_END
	mov edx,[ebx].HEAPDESC.last
	mov [ebx].HEAPDESC.last, eax
	lea esi, [eax+4]
	cmp dwLast,0 				 ;last item free?
	jnz @F						 ;then jump
	lea eax,[ecx-3]
	mov [edx].FLITEM.dwSize,eax
	mov eax,[ebx].HEAPDESC.rover
	mov [edx].FLITEM.pNext, eax
	mov [ebx].HEAPDESC.rover, edx
	jmp nextl1
@@:
	mov edx,[ebx].HEAPDESC.rover
	add [edx].FLITEM.dwSize, ecx
nextl1:
	mov eax, [edx].FLITEM.dwSize
	and al,not 1
	mov ecx, dwSize
	cmp eax, ecx
	jnc done
	mov dwLast, eax

;--- current region cannot fulfill the request
;--- create a new one
;--- esi=???

nouncommitted:
        
	@strace <"_growseg new region req, size=", ecx, ", last=", dwLast>
	sub ecx, dwLast
	push esi
tryagain:
	add ecx, 2*4 			;add size of 2 pointers as overhead
	mov eax,g_amblksiz
	cmp ecx,eax
	jnc @F
	mov ecx,eax
@@:
	xor edx,edx
	xchg eax,ecx			;amblksiz -> ecx
	div ecx
	inc eax
	mul ecx					;always get a multiple of
	mov edi,eax				;g_amblksiz
	cmp eax,40000h
	jnc @F
	shl eax,2
@@:
	invoke HeapAllocRegion, esi, eax, edi, ebx, 0
	and eax, eax
	jnz @F
	and esi,esi
	mov esi,eax				;try again, this time without given base
	mov ecx,dwSize			;and use full size requested
	jnz tryagain
	pop esi 
	stc
	jmp exit
@@:
	pop esi
	mov ecx,eax				;???
	invoke setmemblock, eax
	jnc @F
	add eax,sizeof HBLOCK
	sub edi,sizeof HBLOCK
@@:

;--- are the regions contiguous (possibly by chance for a 0.9 host)?

	cmp esi, eax
	jz contiguous

	@strace <"_growseg non-contiguous new region">
	mov ecx, eax
	mov edx, ecx
	sub edx, esi
	or dl,FHEAPITEM_INTERNAL
	mov [esi-4].FLITEM.dwSize, edx	;this was the previous "EOH" marker
	mov [ecx].FLITEM.dwSize,-7
	jmp noncontiguous
contiguous:
	mov ecx, [ebx].HEAPDESC.rover
	cmp dwLast,0
	jnz @F
	mov ecx, [ebx].HEAPDESC.last
	mov [ecx].FLITEM.dwSize,-3
@@:
noncontiguous:
									;edi=size of new block
									;ecx=heap item (either new or last)
	add [ecx].FLITEM.dwSize,edi
	mov eax,[ecx].FLITEM.dwSize
	lea eax,[eax+ecx+3]
	mov dword ptr [eax],_HEAP_END
	mov [ebx].HEAPDESC.last, eax
	mov eax,[ebx.HEAPDESC.rover]
	cmp eax,ecx
	jz @F
	mov [ebx.HEAPDESC.rover],ecx
	mov [ecx].FLITEM.pNext,eax
@@:
done:
	clc
exit:
	pop edi
	lahf
	test edi,HEAP_NO_SERIALIZE
	jnz @F
	push eax
	and byte ptr [ebx.HEAPDESC.flags],not _HEAP_GROWING
	invoke ReleaseMutex,[ebx].HEAPDESC.mutex
	pop eax
@@:
	@strace <"_growseg exit, still uncommitted=", [ebx].HEAPDESC.dwSize, ", rover=", [ebx].HEAPDESC.rover, ", last=", [ebx].HEAPDESC.last>
	sahf
	ret
	align 4
_growseg endp


;*** find last heap item in esi ***

_findlast proc c
if ?FREELIST
	mov esi,[ebx.HEAPDESC.rover] ;liste leer?
	and esi,esi
	jz @F
	lodsd				;get dwSize
	and al,0FEh		;reset bit 0
	add esi,eax
	cmp dword ptr [esi],_HEAP_END
	jnz @F
	ret
@@:
	stc
	ret
else
	push edi
	mov esi,[ebx.HEAPDESC.rover]
	cmp esi,[ebx.HEAPDESC.last]
	jne @F
	mov esi,[ebx.HEAPDESC.start]
@@:
	lodsd
	cmp eax,_HEAP_END
	je @F
	mov edi,esi
	and al,0FEh
	add esi,eax
	jmp @B
@@:
	lea esi,[edi-4]
	pop edi
endif
	ret
_findlast endp

end

