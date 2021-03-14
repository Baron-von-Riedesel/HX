
;--- host memory heap handler
;--- for small amounts of memory (< 1 page)
;--- mainly used for client memory handles 
;--- TABSIZE 4

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

_DATA16V segment

heap    db 36 dup (0)
maxheap label byte

dwCurPg			dd 0			;normalized address of current page for allocs
dwCurOfs		dd offset heap	;offset within the page
dwMaxOfs		dd offset maxheap;max offset within the page

_DATA16V ends

_TEXT32 segment

	assume DS:GROUP16

	@ResetTrace

if ?VM
hp_createvm proc public
	mov dwCurPg, 0
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
	@dprintf "heapalloc: try to alloc a heap item, size=%lX", eax
	mov ecx,[dwCurOfs]
	add eax,3
	and al,0FCh
	add ecx,eax
	cmp ecx,[dwMaxOfs]
	ja heapalloc_1
	mov eax,[dwCurOfs]
	mov [dwCurOfs],ecx
	add eax,[dwCurPg]
	@dprintf "heapalloc: heap item allocated, eax=%lX",eax
	pop ecx
	ret
heapalloc_1:
	@dprintf "heapalloc: try to alloc a new page for heap"
	pushad
	mov ecx,1				;1 page
	call _AllocSysPagesX	;alloc host heap space
	jc @F
	@dprintf "heapalloc: new page for heap allocated: %lX",eax
	sub eax,[dwSSBase]  ;since no FLAT model, normalize address
	mov [dwCurPg],eax
	mov [dwCurOfs], 0
	mov [dwMaxOfs], 1000h
@@:
	popad
	jnc tryagain
	pop ecx
	@dprintf "heapalloc: allocating new page failed"
	ret
	align 4

_heapalloc endp

_TEXT32 ends

	end
