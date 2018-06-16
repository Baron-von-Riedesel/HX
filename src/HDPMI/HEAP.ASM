
;--- host memory heap handler
;--- for small amounts of memory (< 1 page)
;--- mainly used for client memory handles 
;--- TABSIZE 4

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

@seg VDATA16
@seg _TEXT32

VDATA16 segment

heap    db 36 dup (0)
maxheap label byte

pMemItems		dd 0			;start of used memory items list
pFreeMemItems	dd 0			;start of free memory items list
dwCurPg			dd 0			;normalized address of current page for allocs
dwCurOfs		dd offset heap	;offset within the page
dwMaxOfs		dd offset maxheap;max offset within the page

VDATA16 ends

_TEXT32 segment

	assume DS:GROUP16

	@ResetTrace

if ?VM
hp_createvm proc public
	xor eax, eax
	mov pMemItems, eax
	mov pFreeMemItems, eax
	mov dwCurPg, eax
	mov dwCurOfs, offset heap
	mov dwMaxOfs, offset maxheap
	ret
	align 4
hp_createvm endp
endif

;*** alloc small amounts of memory
;*** Input: EAX = size
;***        DS=GROUP16
;*** Output: EAX = handle (normalized)
;--- C set on errors
;*** all other registers preserved.
;--- there is no _heapfree function implemented.

_heapalloc proc public

	push ecx
tryagain:
	@strout <"heap: try to alloc a heap item, size=%lX",lf>, eax
	mov ecx,[dwCurOfs]
	add eax,3
	and al,0FCh
	add ecx,eax
	cmp ecx,[dwMaxOfs]
	ja heapalloc_1
	mov eax,[dwCurOfs]
	mov [dwCurOfs],ecx
	add eax,[dwCurPg]
	@strout <"heap: heap item allocated, eax=%lX",lf>,eax
	pop ecx
	ret
heapalloc_1:
	@strout <"heap: try to alloc a new page for heap",lf>
	pushad
	mov ecx,1			  ;alloc 1 page
	call _AllocSysPagesX	  ;returns linear address in EAX
	jc @F
	@strout <"heap: new page for heap allocated: %lX",lf>,eax
	sub eax,[dwHostBase]  ;since no FLAT model, normalize address
	mov [dwCurPg],eax
	mov [dwCurOfs], 0
	mov [dwMaxOfs], 1000h
@@:
	popad
	jnc tryagain
	pop ecx
	@strout <"heap: allocating new page failed",lf>
	ret
	align 4

_heapalloc endp

;*** alloc a MEMITEM handle
;*** inp: DS=GROUP16
;--- return handle in EBX (or C if alloc failed)!
;*** other registers preserved
;--- first view for an item in free item list

	@ResetTrace

_allocmemhandle proc public

if _LTRACE_
	push eax
	mov eax,[pMemItems]
	.if (eax)
		mov eax,[eax].MEMITEM.pNext
	.endif
	@strout <"allocmemhandle: pMemItems=%lX,next handle=%lX",lf>, pMemItems, eax
	pop eax
endif
	@strout <"allocmemhandle: enter",lf>
	mov ebx, pFreeMemItems
	and ebx,ebx
	jnz allocmemhandle1
	@strout <"allocmemhandle: no free handle, will alloc a new item",lf>
	push ecx
	push eax
	mov eax,sizeof MEMITEM
	call _heapalloc
	jc @F
	mov ebx,eax
	xor eax,eax
	@strout <"allocmemhandle: new handle allocated: %lX",lf>,ebx
	mov [ebx].MEMITEM.flags,ax
@@:
	pop eax
	pop ecx
	ret
allocmemhandle1:
	push eax
	xor eax,eax
	mov [ebx].MEMITEM.flags,ax
	xchg [ebx].MEMITEM.pNext,eax
	mov pFreeMemItems, eax
	@strout <"allocmemhandle: could use a free mem handle: %lX",lf>,ebx
	pop eax
	clc
	ret
	align 4
_allocmemhandle endp

;--- free handle in [esp+4]
;--- DS=GROUP16
;--- the handle is added to the "free item" list

_freememhandle proc public
	pop edx
	pop eax
	mov ecx, pFreeMemItems
	mov [eax].MEMITEM.pNext, ecx
	mov pFreeMemItems, eax
	jmp edx
	align 4
_freememhandle endp

;--- called by i31mem.asm
;--- input: EAX=lin addr, EDX=pages, DS=GROUP16
;--- add an item to the MEMITEM list
;--- registers preserved

_addmemhandle proc public
	pushad
	call _allocmemhandle				;alloc new handle
	jc @F
	mov [ebx].MEMITEM.dwBase,eax
	mov [ebx].MEMITEM.dwSize,edx
	call _linkmemhandle				;add item to (sorted) list
@@:
	popad
	ret
	align 4
_addmemhandle endp

;--- insert handle of a free memory block
;--- list is sorted by linear address
;--- merge free blocks here!
;--- input: handle in EBX
;--- registers can be modified here

_linkmemhandle proc
	mov eax, ebx
	mov [eax].MEMITEM.pNext,0
	mov ebx, pMemItems
	and ebx, ebx
	jnz @F
	mov pMemItems, eax
	ret
nextitem:
	mov ebx, [ebx].MEMITEM.pNext
@@:
	cmp [ebx].MEMITEM.pNext,0
	jnz nextitem
	test byte ptr [ebx].MEMITEM.flags,HDLF_ALLOC or HDLF_COMMIT
	jnz linkmemhandle_2
	mov ecx,[ebx].MEMITEM.dwBase	;blocks contiguous?
	mov edx,[ebx].MEMITEM.dwSize
	shl edx,12
	add ecx,edx
	cmp ecx,[eax].MEMITEM.dwBase
	jnz linkmemhandle_1
	mov ecx,[eax].MEMITEM.dwSize	;then adjust size of last item
	add [ebx].MEMITEM.dwSize,ecx	;and throw away the
	push eax
	call _freememhandle				;new handle
	ret
linkmemhandle_1:
linkmemhandle_2:
	mov [ebx.MEMITEM.pNext],eax
	ret
	align 4
_linkmemhandle endp

if 0

;--- handle in EBX

_unlinkmemhandle proc
	push eax
	push ebx
	push ecx
	mov eax, ebx
	mov ebx, pMemItems
@@:
	and ebx, ebx
	stc
	jz unlinkerr
	cmp eax,ebx
	jz @F
	mov ecx, ebx
	mov ebx, [ebx].MEMITEM.pNext
	jmp @B
@@:
	mov eax,[ebx].MEMITEM.pNext
	mov ebx, ecx
	mov [ebx].MEMITEM.pNext, eax
	clc
unlinkerr:
	pop ecx
	pop ebx
	pop eax
	ret
	align 4
_unlinkmemhandle endp

endif

_TEXT32 ends

	end
