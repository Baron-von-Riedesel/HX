
;--- HeapAlloc, HeapFree, HeapReAlloc

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
	include heap32.inc
	include macros.inc


?DONTFREE	equ 0	;0 for debugging: dont free item in HeapFree
?CHKITEM	equ 1	;1 check if item is free already
;--- ?EXTCHK = 1 adds 4 byte to the heap item size in HeapAlloc,
;--- fills the additional DWORD with a certain value and checks in
;--- HeapFree if the value is still there. If no, either the debugger
;--- is called or an exception is thrown.
?EXTCHK		equ 0
;--- additional bytes to add to each request if ?EXTCHK is on.
;--- minimum is 4.
?ADDBYTES	equ 4

	.CODE

if ?FREELIST

if ?EXTCHK

heapdisp proc
	push edi
	sub ebx, 4
	mov edi, [esi].HEAPDESC.start
	.while ( dword ptr [edi] != _HEAP_END )
		sub esp,64
		mov eax,[edi]
		and eax, -4
		lea eax,[edi+eax-4]
		invoke IsBadReadPtr, eax, 4
		mov edx, esp
		.if ( eax == 0 )
			mov eax,[edi]
			and eax, -4
			mov eax,[edi+eax-4]
			invoke _sprintf, edx, CStr(<"heap item=%X [item]=%X %X %X %X",10>),\
				edi, dword ptr [edi], dword ptr [edi+4], dword ptr [edi+8], eax
			.break
		.else
			invoke _sprintf, edx, CStr(<"heap item=%X [item]=%X %X %X",10>),\
				edi, dword ptr [edi], dword ptr [edi+4], dword ptr [edi+8]
		.endif
		invoke Display_szString, esp
		add esp,64
		.break .if (edi == ebx)
		mov ecx, [edi].FLITEM.dwSize
		and cl, 0FCh
		lea edi, [edi+ecx+4]
		invoke IsBadReadPtr, edi, 4
		.break .if (eax)
	.endw
	pop edi
	ret
	align 4
heapdisp endp

endif

;--- the list of free items is sorted descending!
;--- this will result in a large free block at the beginning
;--- of the list. This changes only at the end when no large
;--- amount of free space exists

;*** esi = heap descriptor ***
;*** ebx = item (=handle) ***
;*** ecx = flags

?VERBOSE	= 0		;1=additional debug displays

insertfreelist proc

if ?VERBOSE
	@strace <"insertfreelist enter, heap=", esi, " item=", ebx>
endif        
	test cl, HEAP_NO_SERIALIZE
	jnz @F
	invoke WaitForSingleObject,[esi].HEAPDESC.mutex,INFINITE
	push offset relmutex1
@@:
	push edi
	sub ebx,4
	or byte ptr [EBX].FLITEM.dwSize,FHEAPITEM_FREE
	mov eax,[esi].HEAPDESC.rover
	xor edx,edx
	xor ecx,ecx
if ?EXTCHK
	assume fs:nothing
	push offset exception_freeitem
	push fs:[edx]
	mov fs:[edx], esp
endif
;--- scan free list until we find an item
;--- whose address is below address of new item

nextitem:
if 0;?VERBOSE
	@strace <"heap scan, item=", eax, " size=", [eax].FLITEM.dwSize, " next=", [eax].FLITEM.pNext>
endif
	cmp eax,ebx			;cur item - new item: is new item >= cur item?
	jbe @F				;then jump
	mov edx,ecx
	mov ecx,eax
	mov eax,[eax].FLITEM.pNext	;get next free item
	and eax,eax
	jnz nextitem
;----------------------- new item is new last item
@@:
;--- current state:
;--- eax=will become successor of ebx
;--- ebx=new free item to insert
;--- ecx=will become predecessor of ebx (if not 0)
;--- edx=predecessor of ecx (or 0)

;--- check first if eax + ebx can be merged
if ?VERBOSE
	@strace <"heap scan done, succ[eax]=", eax, ", ebx=", ebx, ", pred[ecx]=", ecx, ", pred of pred[edx]=", edx>
endif
	and eax,eax
	jz nomerge 						;no successor available
	mov edi,[eax].FLITEM.dwSize
	and edi, not (1+2)
	lea edi, [edi+eax+4]
	cmp edi,ebx
	jnz nomerge 					;no, cannot merge these 2 items
	mov edi,[eax].FLITEM.dwSize
	and edi, not (1+2)
	mov ebx,[ebx].FLITEM.dwSize 	;the new item can be merged with
	and ebx, not (1+2)				;the "eax" item
	lea edi,[edi+ebx+4+1]
if ?VERBOSE
	push ecx
	mov ecx,[eax].FLITEM.dwSize
	and cl,0FCh
	@strace <"merge items ", eax, ", siz=", ecx, " + ", ebx, " + 4">
	pop ecx
endif
	mov [eax].FLITEM.dwSize,edi 	;set size of eax
	mov ebx,eax						;ebx item has vanished now
	jmp checkpredes
nomerge:
	mov [ebx].FLITEM.pNext,eax		;set successor of new item (may be NULL)

if 0;?VERBOSE
	@strace  <"no merging with successor">
endif

;------------------------------------------- todo:if size < 4 (curr impossible)
checkpredes:
;--- now do same merge check with predecessor
	and ecx,ecx
	jz nopredes
	mov edi,[ebx].FLITEM.dwSize 	;check if ebx+ecx can be merged
	and edi,not (1+2)
	lea edi,[edi+ebx+4]
	cmp edi,ecx
	jnz nomerge2					;no, cannot merge
	mov edi,[ebx].FLITEM.dwSize
	mov ecx,[ecx].FLITEM.dwSize		;ECX item will vanish
	and edi,not (1+2)
	and ecx,not (1+2)
	lea edi,[edi+ecx+4+1]
if ?VERBOSE
	push eax
	mov eax,[ebx].FLITEM.dwSize
	and al,0FCh
	@strace <"merge items: ", ebx, ", siz=", eax, " + ", ecx, "+ 4">
	pop eax
endif
	mov [ebx].FLITEM.dwSize,edi
	and edx, edx
	jz nopredes
	mov [edx].FLITEM.pNext,ebx		;adjust successor in EDX
	jmp done
nopredes:
if ?VERBOSE
	@strace <"merge items: rover set to ", ebx>
endif
	mov [esi].HEAPDESC.rover,ebx
	jmp done

;--- item will simply be inserted
;--- and no size has to be adjusted

nomerge2:
	mov [ecx].FLITEM.pNext,ebx
;;	mov [ebx].FLITEM.pNext,eax
if 0;?VERBOSE
	@strace <"no merging with predecessor">
endif

done:
if ?EXTCHK
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
endif
if 0;?VERBOSE
	@strace <"insertfreelist exit">
endif
	pop edi
	ret
relmutex1:
	invoke ReleaseMutex,[esi].HEAPDESC.mutex
	ret
if ?EXTCHK
	align 4
doneX:
	xor edx, edx
	pop fs:[edx]
	pop ecx			;adjust stack (offset exception)
	invoke ReleaseMutex, [esi].HEAPDESC.mutex
	call heapdisp
	invoke RaiseException, STATUS_NO_MEMORY, EXCEPTION_NONCONTINUABLE, 0, 0
	pop edi
	ret
exception_freeitem:
	mov eax, [esp+12]	;get context
	mov [eax].CONTEXT.rEip, offset doneX
	@strace <"*** exception caught inside insertfreelist">
	xor eax, eax		;== _XCPT_CONTINUE_EXECUTION
	retn
endif
	align 4
insertfreelist endp

;--- delete a free item from freelist
;--- esi = heap descriptor
;--- edx = item to delete from freelist
;--- ecx = flags

?VERBOSE	= 0		;1=additional debug displays

deletefreelist proc

if ?VERBOSE
	@strace <"deletefreelist enter">
endif
	test cl, HEAP_NO_SERIALIZE
	jnz @F
	push edx
	invoke WaitForSingleObject,[esi].HEAPDESC.mutex,INFINITE
	pop edx
	push offset relsemaph2
@@:
	mov eax,[esi].HEAPDESC.rover
	xor ecx,ecx
@@:
if ?VERBOSE
	@strace <"heap scan, item=", eax>
endif
	cmp eax,edx
	jz found
	mov ecx,eax					;save predecessor in ecx
	mov eax,[eax].FLITEM.pNext	;get next free item
	and eax,eax
	jnz @B
if ?VERBOSE
	@strace <"item not found!!!">
endif
	jmp done
found:
if ?VERBOSE
	@strace <"next free item=", eax>
endif
	mov eax, [eax].FLITEM.pNext
	.if (ecx)
if ?VERBOSE
		@strace  <"link with item ", ecx>
endif
		mov [ecx].FLITEM.pNext, eax
	.else
if ?VERBOSE
		@strace  <"set item as rover">
endif
		mov [esi].HEAPDESC.rover, eax
	.endif
	@mov eax, 1
done:
if ?VERBOSE
	@strace <"deletefreelist exit">
endif
	ret
relsemaph2:
	push eax
	invoke ReleaseMutex,[esi].HEAPDESC.mutex
	pop eax
	ret
	align 4

deletefreelist endp

endif ;?FREELIST

HeapFree proc public uses esi ebx heap:dword,flags:dword,handle:dword

if ?VERBOSE        
	@strace <"HeapFree(", heap, ", ", handle, ") enter"> 
endif
ifdef _DEBUG
	invoke HeapValidate, heap, flags, handle
	and eax,eax
	jz exit
endif
	xor eax,eax
	mov ebx,handle
	and ebx,ebx
	jz exit
	mov esi,heap
	cmp [esi].HEAPDESC.start, ebx
	jnc exit							;error invalid handle
	mov ecx,[ebx-4].FLITEM.dwSize
if ?CHKITEM
;---------------------------------------------- is item already free?
	test cl,FHEAPITEM_FREE or FHEAPITEM_INTERNAL
	jnz exit
endif
if ?DONTFREE
	inc eax
	jmp exit
endif
if ?EXTCHK
 if ?VERBOSE
	@strace <"heap item size=", ecx>
 endif
	lea edx,[ebx+ecx-4]
	push edx
	push ecx
	invoke IsBadReadPtr, edx, 4
	pop ecx
	pop edx
	and eax, eax
	jnz isbad
	cmp dword ptr [edx],0DEADBABEh
	jz isok
	@strace <"heap ", heap, " is corrupted, item=", ebx>
isbad:
	invoke IsDebuggerPresent
	.if (eax)
		int 3
	.else
		call heapdisp
		invoke RaiseException, STATUS_INVALID_HANDLE, EXCEPTION_NONCONTINUABLE, 0, 0
	.endif
isok:
endif
ifdef _DEBUG
	pushad
	mov edi, ebx
	mov eax, 0ABCDFEDCh
	shr ecx,2
	rep stosd
	popad
endif
if ?FREELIST
	mov ecx,flags
	or ecx,[esi].HEAPDESC.flags
	invoke insertfreelist			  ;add item to free list
else
	sub ebx,4
	or byte ptr [eBX].FLITEM.dwSize, FHEAPITEM_FREE
	cmp [esi].HEAPDESC.rover,ebx  ;is previous rover smaller?
	jbe @F
	mov [esi].HEAPDESC.rover,ebx  ;else this item is new rover
endif
exit:
	@strace <[ebp+4], ": HeapFree(", heap, ", ", flags, ", ", handle, ")=", eax>
	ret
	align 4
HeapFree endp

HeapAlloc proc public uses ebx esi edi hHeap:dword, flags:dword, dwBytes:dword

	mov ecx,dwBytes
	mov edi,flags
	cmp ecx,_HEAP_MAXREQ
	ja error
	mov ebx,hHeap
	and ebx, ebx
	jz error2
	or edi,[ebx].HEAPDESC.flags
	add ecx,4-1 			;align req size to DWORD
	and ecx,not 3
	jnz @F
	mov cl,4				;alloc a minimum of 4 bytes!
@@:
	mov dwBytes, ecx		;save it so zerofill will use true size
if ?EXTCHK
	add ecx, ?ADDBYTES
endif
@@:
	call _searchseg			;search item >= ecx. modifies esi!
	and eax,eax
	jnz done
	test [ebx].HEAPDESC.flags, HEAP_GROWABLE
	jz error
	call _growseg			;enlarge heap and try again
	jnc @B
error:
error2:
	xor eax,eax
	test edi,HEAP_GENERATE_EXCEPTIONS
	jz exit 
	invoke RaiseException, STATUS_NO_MEMORY, EXCEPTION_NONCONTINUABLE, 0, 0
done:
ifdef _DEBUG
	test flags,HEAP_ZERO_MEMORY
	jnz @F
	push eax
	mov edi, eax
	mov ecx, dwBytes
	mov eax, 12345678h
	shr ecx,2
	rep stosd
	pop eax
@@:
endif
	test flags,HEAP_ZERO_MEMORY
	jz @F
	push eax
	mov edi,eax
	mov ecx,dwBytes
	xor eax,eax
	shr ecx,2			;bytes is dword adjusted!
	rep stosd
	pop eax
@@:
if ?EXTCHK
	mov edx, dwBytes
	mov dword ptr [eax+edx+?ADDBYTES-4],0DEADBABEh
endif
exit:
	@strace <[ebp+4], ": HeapAlloc(", hHeap, ", ", flags, ", ", dwBytes, ")=", eax>
	ret
	align 4

HeapAlloc endp

HeapReAlloc proc public uses ebx esi edi hHeap:dword, flags:dword, handle:dword, dwNewSize:dword

if ?VERBOSE
	@strace <"HeapReAlloc(", hHeap, ", ", flags, ", ", handle, ", ", dwNewSize, ") enter">
endif        
	mov ebx, handle
ifdef _DEBUG
	invoke HeapValidate, hHeap, flags, ebx
	.if (!eax)
		jmp error1
	.endif
endif
	xor eax, eax			;set returncode to error
if ?CHKITEM        
;----------------------------------------- is item already free?
	test byte ptr [ebx-4].FLITEM.dwSize,FHEAPITEM_FREE
	jnz error1
endif
	mov edx, dwNewSize
if ?EXTCHK
	and edx, edx
	jz error1				;size 0 not allowed
	add edx, 3+?ADDBYTES
	and dl, 0FCh			;DWORD align 
else
	add edx, 3
;	and dl, 0FCh			;DWORD align 
;	and edx, edx
	and edx,not 3
	jz error1				;size 0 not allowed
endif
	mov edi, edx

;----------------------------------------- is item shrinking?
checkitem:        
	mov ecx, [ebx-4]		;current size
	sub ecx, edi
	jc isgrowing
	mov eax, ebx			;now eax=handle
	jz exit				;size doesnt change

	cmp ecx, 8
	jc exit				;a free item must have 8 bytes at least
	mov [ebx-4], edi
	add ebx, edi
	sub ecx, 4
	mov [ebx], ecx
if ?EXTCHK
	mov dword ptr [ebx-4], 0DEADBABEh
endif
	add ebx, 4
	push eax
	mov esi, hHeap
	mov ecx, flags
	or ecx, [esi].HEAPDESC.flags
	invoke insertfreelist	;put the free rest into freelist
	pop eax
	jmp exit
isgrowing:
;---------------------------------------- edi = new size
	add ecx, edi
	mov edx, [ebx+ecx]
	test dl,FHEAPITEM_FREE
	jz mustnewalloc		;next item not free!
	test dl,FHEAPITEM_INTERNAL				
	jnz mustnewalloc		;is an internal item, ignore
	lea ecx, [ecx+edx+3]	
	cmp ecx, edi
	jc mustnewalloc		;next item free, but doesnt suffice
	mov esi, hHeap
	mov edx, [ebx-4]
	add edx, ebx
	mov ecx,flags
	or ecx,[esi].HEAPDESC.flags
	invoke deletefreelist		;delete free item from freelist
	and eax, eax
	jz mustnewalloc		;item didnt exist any more
	mov ecx, [ebx-4]
	mov edx, [ebx+ecx]		;get size of free item
	add edx,3
	add [ebx-4],edx
	test flags,HEAP_ZERO_MEMORY
	jz checkitem
	push edi
	lea edi, [ebx+ecx]
	mov ecx, edx
	shr ecx, 2
	xor eax, eax
	rep stosd
	pop edi
	jmp checkitem			;and shrink item now

;--------------------------------- in-place realloc will fail
mustnewalloc:
	test flags,HEAP_REALLOC_IN_PLACE_ONLY
	jnz error2

	invoke HeapAlloc, hHeap, flags, dwNewSize
	and eax,eax
	jz error
	push eax
	mov edi, eax
	mov esi, ebx
	mov ecx, [esi-4]		;get old size (dword adjusted!)
	and cl, 0FCh			;clear bit 1
if 0
	cmp ecx, dwNewSize
	jb @F
	mov ecx, dwNewSize		;if newsize is smaller, use it
@@:
endif
	shr ecx,2
	rep movsd
	invoke HeapFree, hHeap, flags, ebx
	pop eax
error:
exit:
	@strace <[ebp+4], ": HeapReAlloc(", hHeap, ", ", flags, ", ", handle, ", ", dwNewSize, ")=", eax>
	ret
error1:
	test flags, HEAP_GENERATE_EXCEPTIONS
	jz error
	invoke RaiseException, STATUS_ACCESS_VIOLATION, EXCEPTION_NONCONTINUABLE, 0, 0
error2:
	xor eax,eax
	test flags, HEAP_GENERATE_EXCEPTIONS
	jz error
	invoke RaiseException, STATUS_NO_MEMORY, EXCEPTION_NONCONTINUABLE, 0, 0
	align 4

HeapReAlloc endp

	end

