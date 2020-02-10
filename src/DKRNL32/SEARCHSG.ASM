
;*** __searchseg: search a free and sufficiently large item in heap
;*** used by HeapAlloc()

;*** the strategy for HeapAlloc is:
;*** 1. call __searchseg to find a free item
;*** 2. if nothing found, call growseg to enlarge heap
;*** 3. try again with __searchseg

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

;--- free items are stored in a linked list
;--- so one hasnt to scan the whole heap to find some free space
;--- the strategy is to not reuse items until the region is
;--- almost allocated 

?VERBOSE equ 0	;1=additional debug displays

	.CODE

if ?FREELIST

;*** eax=free and sufficiently large item found
;*** esi=predecessor
;*** ecx=req. bytes
;*** ebx=heap-desc

;--- if size of this item is at least requested size + 8
;--- the rest remains as free heap item, else 
;--- let this space in this item 

modifyitem proc

if ?VERBOSE
	@strace	<"modifyitem enter: ebx=", ebx, " eax=", eax, " ecx=", ecx>
endif
	push esi
	mov esi,[eax].FLITEM.dwSize
	and esi,not (1+2)			;mask flags
	sub esi,ecx
	sub esi,sizeof FLITEM
	jb mi_1						;jump if no 8 bytes available 
	lea edx,[eax+ecx+4]			;split item (first used, second free)
	add esi,4+1 				;set FREE bit for second item
	mov [edx].FLITEM.dwSize,esi
	mov esi,[eax].FLITEM.pNext	;delete first item from free item list
	mov [edx].FLITEM.pNext,esi	;insert second item in free item list
if ?VERBOSE
	@strace <"modifyitem: a) ", edx, ".pNext=", esi>
endif
	jmp mi_2
mi_1:							;delete item from free item list
if ?VERBOSE
	@strace <"modifyitem: item ", eax, " deleted from freelist">
endif
	add esi, sizeof FLITEM
	add ecx, esi
	mov edx, [eax].FLITEM.pNext	;get next item into edx
mi_2:
	pop esi
	mov [eax].FLITEM.dwSize,ecx ;set size of now allocated item
	add eax,4
if ?VERBOSE
	@strace <"modifyitem: b) ", esi, ".pNext=", edx>
endif
	mov [esi].FLITEM.pNext,edx
	ret
	align 4

modifyitem endp

endif

;*** __searchseg is called by HeapAlloc
;*** scans the list of free items (start in heapdesc.rover)
;*** inp: EBX=heap descriptor, ECX=size in bytes (dword aligned, minimum is 4)
;---      EDI=flags
;*** out: EAX=item, ecx = bytes
;*** modifies esi!

_searchseg proc c public

if ?FREELIST
	test edi,HEAP_NO_SERIALIZE
	jnz @F
	push ecx
	invoke WaitForSingleObject,[ebx].HEAPDESC.mutex,INFINITE
	pop ecx
	push offset relsemaph
@@:
	lea esi,[ebx-4].HEAPDESC.rover
	mov eax,[ebx].HEAPDESC.rover
if ?VERBOSE
	@strace <"searchseg, rover=", eax, " size requested=", ecx>
endif
nextitem:
	and eax,eax
	jz done				;----> no item found
	mov edx,[eax].FLITEM.dwSize
	and dl,0FCh 			;bits 0 and 1 are flags
if ?VERBOSE
	@strace <"searchseg, freelist item=", eax, ", size=", edx>
endif
	cmp edx,ecx 			;is item large enough?
	jae found
	mov esi,eax
	mov eax,[eax].FLITEM.pNext
	jmp nextitem
found:
;;	@strace  <"searchseg, item found">
	call modifyitem			;found a free, suitable item
done:
	ret
relsemaph:
	push eax
	push ecx
	invoke ReleaseMutex,[ebx].HEAPDESC.mutex
	pop ecx
	pop eax
	ret

else ; !FREELIST

	push ebp
	push ecx
	invoke WaitForSingleObject,[ebx].HEAPDESC.semaphor,INFINITE
	pop ecx
	cld
	mov esi,[ebx.HEAPDESC.rover]
	mov ebp,[ebx.HEAPDESC.last]
	xor edi,edi 			;remember last free item in edi
	jmp startscan
nexttry:					;<----
	mov eax,ebp 			;nothing found from rover to end
	test AL,1				;test, if we are in second pass
	jne error3				;if yes, exit
	mov esi,[ebx.HEAPDESC.start]
	mov ebp,[ebx.HEAPDESC.rover]
	cmp ebp,esi
	je error2				;chain is empty ----> error
	dec ebp 				;bit 0 set (end marke)
	xor edi,edi
	jmp startscan
nextitem:					;<----
	lea edx,[esi-4]
	cmp edx,ebp 			;last item?
	jnc nexttry				;end of chain  ---->
	add esi,eax
	jc error				;overflow -> exit
startscan:
	lodsd
	test AL,1				;free?
	je nextitem				;----> no, next item
	mov edi,esi
@@: 						;<----
	dec eax					;reset bit 0
	cmp eax,ecx 			;large enough?
	jnc found				;then jump
	add esi,eax
	jc error				;----> error
	mov edx,eax
	lodsd
	test AL,1				;next block free as well?
	je nextitem				;no, so continue
	add eax,edx
	add eax,4				;add 4 bytes for pointer
	mov esi,edi
	mov [esi-4],eax 		;concat the 2 items
	jmp @B					;and check again ---->

							;*** error: no item found ***
error:
error2:
error3:
	mov eax,[ebx.HEAPDESC.start]
	mov [ebx.HEAPDESC.rover],eax
	stc
	jmp done
							;*** free item found ***
found:
	mov [esi-4],ecx 		;set size of item setzen
	je @F					;size matches exactly
	add edi,ecx 			;edi -> behind item
	sub eax,ecx
	sub eax,3				;set bit 1 of the new item (its free)
	mov [edi],eax
	sub edi,ecx
@@:
	add edi,ecx
	mov [ebx.HEAPDESC.rover],edi
	mov eax,esi
	clc
done:
	push eax
	push ecx
	invoke ReleaseSemaphore,[ebx].HEAPDESC.semaphor,1,0
	pop ecx
	pop eax
	pop ebp
	ret

endif	;!?FREELIST

_searchseg endp

	end
