
;--- implements int 31h, ax=05xx + ax=08xx

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

?ADDRISHANDLE	equ 1		;std=1, 1=handle is address of block
?NEVERFREEMEM	equ 0		;std=0, 1=never free a memory block

;--- extended structure for int 31h, ax=50bh
MEMINFOX struct
dwTotalPhys   dd ?
dwTotalHost   dd ?
dwFreeHost    dd ?
dwTotalVM     dd ?
dwFreeVM      dd ?
dwTotalClient dd ?
dwFreeClient  dd ?
dwTotalLocked dd ?
dwMaxLocked   dd ?
dwHighestAddr dd ?
dwLargestBlock dd ?
dwMinSize     dd ?
dwAllocUnit   dd ?
MEMINFOX ends

_TEXT32  segment

	@ResetTrace

;*** adress space

;*** search/alloc a free address space
;*** IN: ECX=size in pages
;***     EBX=linear address (or any if ebx=NULL)
;---     DS=GROUP16
;*** OUT: NC + EAX=handle, else C

;*** scans memory handle linked list for a
;*** free object of requested size
;*** if none is found, calls pagemgr to
;*** create a new addr space

	assume DS:GROUP16

_getspecaddrspace proc public

	pushad
	@dprintf "getspecaddrspace: req base=%lX, size=%lX", ebx, ecx
nextscan:
	mov esi, offset pMemItems
	jmp skipitem
nexthandle:						   ;<----

;	@dprintf "_getspecaddrspace: hdl=%lX,nxt=%lX,base=%lX,siz=%lX,fl=%X",esi,\
;	[esi].MEMITEM.pNext,[esi].MEMITEM.dwBase,[esi].MEMITEM.dwSize,[esi].MEMITEM.flags

	test byte ptr [esi].MEMITEM.flags,HDLF_ALLOC
	jnz skipitem
	mov edx, [esi].MEMITEM.dwSize
	and ebx,ebx
	jz nospec

;---- the list is sorted, so if base of current handle is > ebx
;---- we can decide here that the space is not free

	cmp ebx, [esi].MEMITEM.dwBase
	jb error

	shl edx, 12
	add edx, [esi].MEMITEM.dwBase	;get max address of block in edx

	@dprintf "getspecaddrspace: hdl=%lX,base=%lX,end=%lX (req=%lX,siz=%lX)",esi,\
		[esi].MEMITEM.dwBase, edx, ebx, ecx

	cmp ebx, edx					;is req. address in this block?
	jnc skipitem					;no, jump!
	sub edx,ebx
	shr edx, 12
	cmp edx,ecx						;is free block large enough?
	jnc found
									;no, but is it the last block?
	mov eax,[esi].MEMITEM.pNext
	and eax, eax
	stc
	jnz error						;no, so its an error
getnewspace:
	mov eax, ecx					;get new addr space. this will
	sub eax, edx					;increase the last block
	call _AllocUserSpace			;get new address space, EAX pages
	jc error
	call _addmemhandle				;add adress space to list
	jnc nextscan
	jmp error
nospec:
	cmp edx,ecx						;size large enough?
	jnc found1

skipitem:
	mov eax,esi
	mov esi,[esi].MEMITEM.pNext
	and esi,esi
	jnz nexthandle
	xor edx, edx
	cmp eax, offset pMemItems
	jz getnewspace
	mov esi, eax		 ;last handle to esi (this is always free)
	mov eax, ebx
	and eax, eax
	jz @F
	sub eax, [esi].MEMITEM.dwBase
	shr eax, 12
@@:
	add eax, ecx
if 1
	sub eax, [esi].MEMITEM.dwSize
endif
	@dprintf "getspecaddrspace: create addr space, size=%lX (%lX)",eax,ecx
	call _AllocUserSpace		;get new address space 
	jc error
	call _addmemhandle	;add adress space to list
	jnc nextscan
error:
	@dprintf "getspecaddrspace: alloc failed"
	popad
	ret

;----------------- found a free area large enough for spec address
;----------------- EAX = prev handle

found:
	cmp ebx, [esi].MEMITEM.dwBase
	jz found1

;---------------- we need a new handle which covers free area
;---------------- until spec address

	mov edx,ebx
	call _allocmemhandle ;get new handle in EBX
	xchg edx, ebx		;new handle to EDX, ebx = req. base
	jc error
	push ecx
	mov ecx, edx
	xchg ecx, [eax].MEMITEM.pNext
	mov [edx].MEMITEM.pNext, ecx	 ;now EAX->EDX->ESI
	mov ecx, [esi].MEMITEM.dwBase
	mov [edx].MEMITEM.dwBase, ecx
	mov [esi].MEMITEM.dwBase, ebx
	sub ebx, ecx
	shr ebx, 12
	mov [edx].MEMITEM.dwSize, ebx
	sub [esi].MEMITEM.dwSize, ebx
	@dprintf "getspecaddrspace: new free handle, handle=%lX,base=%lX,size=%lX",\
		edx,[edx].MEMITEM.dwBase,[edx].MEMITEM.dwSize
	@dprintf "getspecaddrspace: next free handle, handle=%lX,base=%lX,size=%lX",\
		esi,[esi].MEMITEM.dwBase,[esi].MEMITEM.dwSize
	mov eax, edx
	pop ecx

if _LTRACE_
?DISPLAYHDLTAB equ 1
	call displayhdltab
endif

;---------------- found a free area for unspec address
;---------------- EAX=prev hdl, esi=free current hdl

found1:
	cmp [esi].MEMITEM.pNext,0
	jz @F
	cmp ecx,[esi].MEMITEM.dwSize	;fully meets request
	jz exit
@@:
;	@dprintf "_getspecaddrspace: new handle required"

;-------------------------------- allocate a new handle. this will be the
;-------------------------------- one we return

	call _allocmemhandle ;get new handle in EBX
	jc error
;;	@dprintf "getspecaddrspace: new handle allocated"
	mov [ebx].MEMITEM.dwSize, ecx
	sub [esi].MEMITEM.dwSize, ecx
	mov edx, [esi].MEMITEM.dwBase
	mov [ebx].MEMITEM.dwBase, edx
	shl ecx, 12
	add [esi].MEMITEM.dwBase, ecx
	mov edx, ebx
	xchg edx, [eax].MEMITEM.pNext
	mov [ebx].MEMITEM.pNext, edx
	mov esi, ebx
if _LTRACE_
?DISPLAYHDLTAB equ 1
	call displayhdltab
endif

exit:
	@dprintf "getspecaddrspace: alloc ok, handle=%lX,addr=%lX,size=%lX",\
		esi,[esi].MEMITEM.dwBase,[esi].MEMITEM.dwSize
	or [esi].MEMITEM.flags, HDLF_ALLOC
	movzx ax,byte ptr [cApps]
	mov [esi].MEMITEM.owner, ax
	mov [esp].PUSHADS.rEAX, esi
	popad
	ret
	align 4
_getspecaddrspace endp

	@ResetTrace

;*** commit memory
;*** inp: ebx=handle

_commitblock proc
	push es
	pushad
	mov eax,[ebx].MEMITEM.dwBase
	mov ecx,[ebx].MEMITEM.dwSize
	call _CommitRegion
	popad
	pop es
	ret
	align 4
_commitblock endp

;*** uncommit memory
;*** inp: ebx=handle

_uncommitblock proc
	pushad
	mov eax,[ebx].MEMITEM.dwBase
	mov ecx,[ebx].MEMITEM.dwSize
	call _UncommitRegion
	popad
	ret
	align 4
_uncommitblock endp

;*** check (new) size in bytes in eax, get size in pages in edx ***

checksize proc

	xor edx, edx
	test ax,0FFFh
	setnz dl
	shr eax,12			;convert to pages (0-FFFFF)
	add edx,eax
	jz _errret			;size 0 is error
	test eax,0FFF00000h	;max is 0FFFFF pages (4096 MB - 4kB)
	jnz _errret
	ret
_errret::
	stc
	ret
	align 4

checksize endp

	@ResetTrace

;--- alloc memory, committed or uncommitted
;--- called by int 31h, ax=501h and ax=504h (if ebx==0)
;--- EAX=bytes
;--- CL = type (committed?)

_AllocMemEx proc

	call checksize		;get size in pages in EDX
	jc _errret
	push ss
	pop ds
	assume ds:GROUP16

_AllocMemEx endp				;<--- fall thru

;*** general memory allocator
;*** inp: pages in EDX
;***      flags in CL
;***      DS=GROUP16
;*** out: EBX=handle
;*** modifies eax, edx and ebx

_AllocMem proc

	push ecx
	@dprintf "AllocMem: request for %lX pages, flags=%X", edx, cx
	mov ecx,edx
	xor ebx,ebx
	call _getspecaddrspace
	jc error
	mov ebx, eax
	test byte ptr [esp],HDLF_COMMIT
	jz done
	test byte ptr [ebx.MEMITEM.flags], HDLF_COMMIT
	jnz done
	@dprintf "AllocMem: commit %lX pages for base %lX", [ebx.MEMITEM.dwSize], [ebx.MEMITEM.dwBase]
	call _commitblock
	jc error2
if _LTRACE_
	mov eax, [ebx].MEMITEM.dwBase
	push es
	push byte ptr _FLATSEL_
	pop es
	mov eax, es:[eax]
	nop
	pop es
endif
done:
	@dprintf "AllocMem: request successful, handle=%lX, base=%lX", ebx, [ebx.MEMITEM.dwBase]
	pop ecx
	ret
error2:
	call _freememint
error:
	@dprintf "AllocMem: request failed"
	pop ecx
	stc
	ret
	align 4

_AllocMem endp


;*** functions int 31h, ax=05xxh

;*** ax=0500h, get mem info
;--- ES:E/DI = buffer for info

	@ResetTrace

getmeminfo proc public

	pushad

	push ss
	pop ds
	assume ds:GROUP16

	call _GetNumPhysPages	;eax=free pages, edx=total pages, ecx=reserved
	@dprintf "getmeminfo: free phys=%lX, total phys=%lX, res=%lX", eax, edx, ecx
if ?RESTRICTMEM
	test ss:[fMode2],FM2_RESTRMEM
	jz @F
	cmp eax, ?RESTRICTMEM
	jb @F
	mov eax, ?RESTRICTMEM
@@:
endif
ife ?32BIT
	movzx edi,di
endif
;--- some clients assume that they can allocate freePhys pages
;--- these will not work with HDPMI unless option -n is set!
if ?MEMBUFF
	test ss:[fMode2],FM2_MEMBUFF
	jz @F
	sub eax, ecx
	shr ecx, 2
	sub eax, ecx
	xor ecx, ecx
@@:
endif
	mov es:[edi.MEMINFO.freePhys],eax		;+20 free phys pages
	mov es:[edi.MEMINFO.totalPhys],edx		;+24 total phys pages
	mov es:[edi.MEMINFO.unlocked],eax		;+16 unlocked phys pages
	sub eax, ecx
	mov es:[edi.MEMINFO.freeUnlocked],eax	;+4 max free unlocked
	mov es:[edi.MEMINFO.maxLockable],eax	;+8 max free lockable
	shl eax,12
	mov es:[edi.MEMINFO.maxBlock],eax		;+0 max free (bytes)
	mov es:[edi.MEMINFO.swapFile],-1		;swap file
	call _getaddrspace
	@dprintf "getmeminfo: free space=%lX, total space=%lX", eax, edx

	mov ebx, pMemItems
	mov ecx, eax
;-------------------------- scan free handles if a larger block is available
nextitem:
	and ebx, ebx
	jz done
	test [ebx.MEMITEM.flags], HDLF_ALLOC
	jnz skipitem
	mov esi, [ebx.MEMITEM.dwSize]
	cmp ecx, esi
	jnc @F
	mov ecx, esi
@@:
	add eax, esi
skipitem:
	mov ebx, [ebx.MEMITEM.pNext]
	jmp nextitem
done:
;-------------------------- ecx contains the largest free addr space
	cmp ecx, es:[edi.MEMINFO.maxLockable]
	jnc @F
	@dprintf "getmeminfo: maxblock reduced to %lX", ecx
	mov es:[edi.MEMINFO.maxLockable], ecx
	shl ecx, 12
	mov es:[edi.MEMINFO.maxBlock], ecx
@@:
	@dprintf "getmeminfo: max Block=%lX", es:[edi.MEMINFO.maxBlock]
	mov es:[edi.MEMINFO.freeAdrSpace],eax	;free linear space
	mov es:[edi.MEMINFO.totalAdrSpace],edx	;linear space
	@dprintf "getmeminfo: free addr space=%lX", eax
	popad
	clc
	ret
	align 4
getmeminfo endp

;*** Int 31h, ax=0501: allocate memory
;--- inp: requested size in BX:CX
;*** returns linear address in BX:CX, handle in SI:DI

	@ResetTrace

allocmem proc public

	pushad
	push bx
	push cx
	pop eax		;size -> EAX
	@dprintf "allocmem: bx:cx=%X:%X", bx, cx
	mov cl, HDLF_COMMIT
	call _AllocMemEx
	jc error1
	@dprintf "allocmem: no error, ebx=%lX, base=%lX", ebx, [ebx].MEMITEM.dwBase
if ?ADDRISHANDLE
	mov eax, [ebx].MEMITEM.dwBase
	mov edx, eax
else
	mov eax, ebx
	mov edx, [ebx].MEMITEM.dwBase
endif
	mov [esp].PUSHADS.rCX, dx
	mov [esp].PUSHADS.rDI, ax
	shr edx, 16
	shr eax, 16
	mov [esp].PUSHADS.rBX, dx
	mov [esp].PUSHADS.rSI, ax
	clc
error1:
	popad
	ret
	align 4
allocmem endp


;*** search handle in handle list, used by freemem + resizemem
;*** inp: handle in ebx
;*** out: handle in ebx, previous handle in eax
;*** changes eax, ds=GROUP16

searchhandle proc uses ecx

	push ss
	pop ds

	assume ds:GROUP16

	mov ecx,ebx
	mov eax, offset pMemItems
	jmp @F
nextitem:
if ?ADDRISHANDLE
	cmp ecx,[ebx.MEMITEM.dwBase]
else
	cmp ebx,ecx
endif
	jz done
	mov eax,ebx
@@:
	mov ebx,[eax.MEMITEM.pNext]
	and ebx,ebx
	jnz nextitem
	stc
done:
	ret
	align 4
searchhandle endp

;--- internal function: free EBX internal handle

	@ResetTrace

_freememint proc
if ?ADDRISHANDLE
	mov ebx,[ebx.MEMITEM.dwBase]
endif
_freememint endp	;fall through

;--- internal function: free EBX external handle

_freememintEx proc
	pushad
	@dprintf "freememint: ebx=%lX", ebx
	call searchhandle				;get previous handle in EAX, sets ds to GROUP16
	jc error
	test byte ptr [ebx].MEMITEM.flags,HDLF_ALLOC;is region already free?
	jz error

	mov esi, eax					;save previous block is ESI
	mov edi,[ebx].MEMITEM.pNext		;save next block in EDI

	call _uncommitblock
	and byte ptr [ebx].MEMITEM.flags,not HDLF_ALLOC

	@dprintf "freememint: block released, handle=%lX, addr=%lX, size=%lX",\
		ebx, [ebx].MEMITEM.dwBase, [ebx].MEMITEM.dwSize

;--- is next handle a free block?
	test byte ptr [edi].MEMITEM.flags,HDLF_ALLOC
	jnz @F
	@dprintf "freememint: next block is free, base=%lX, size=%lX",\
		[edi].MEMITEM.dwBase, [edi].MEMITEM.dwSize
	mov ecx,[ebx].MEMITEM.dwSize
	mov edx, ecx
	shl edx, 12
	add edx, [ebx].MEMITEM.dwBase
	cmp edx, [edi].MEMITEM.dwBase	;are blocks contiguous?
	jnz @F
	add [edi].MEMITEM.dwSize, ecx
	shl ecx, 12
	sub [edi].MEMITEM.dwBase, ecx
	push ebx
	call _freememhandle
	@dprintf "freememint: handle released"

	mov [esi].MEMITEM.pNext, edi
@@:
	cmp esi, offset pMemItems		;is there a previous block?
	jz @F
	test byte ptr [esi].MEMITEM.flags, HDLF_ALLOC
	jnz @F
	@dprintf "freememint: previous block is free, base=%lX, size=%lX",\
		[esi].MEMITEM.dwBase, [esi].MEMITEM.dwSize
	mov edi,[esi].MEMITEM.pNext		;this next block is always free!
	mov eax,[esi].MEMITEM.dwSize
	shl eax, 12
	add eax,[esi].MEMITEM.dwBase
	cmp eax,[edi].MEMITEM.dwBase	;are blocks contiguous?
	jnz @F
	mov ecx,[edi].MEMITEM.dwSize
	add [esi].MEMITEM.dwSize, ecx
	mov ecx,[edi].MEMITEM.pNext
	mov [esi].MEMITEM.pNext, ecx
	push edi
	call _freememhandle
	@dprintf "freememint: handle released"
@@:
	popad
	clc
	ret
error:
	@dprintf "freememint: error"
	popad
	stc
	ret
	align 4
_freememintEx endp

;*** int 31h, ax=0502h, free memory
;*** inp si:di = handle

	@ResetTrace

freemem proc public

	push ebx
	@dprintf "freemem: si:di=%X:%X",si,di
	push si
	push di
	pop ebx
	call _freememintEx
	pop ebx
if _LTRACE_
	jnc @F
  if ?32BIT
	mov cx,[esp+3*4].IRETS.rCS
	mov ebx,[esp+3*4].IRETS.rIP
  else
	mov cx,[esp+3*4].IRETS.rCS
	movzx ebx,[esp+3*4].IRETS.rIP
  endif
	@dprintf "freemem: free mem block FAILED, handle %X%X, CS:(E)IP=%X:%lX",si,di,cx,ebx

;	call displayhdltab
@@:
endif
	ret
	align 4
freemem endp

if 0

;*** copy memory, free old block
;*** obsolete
;--- inp: EBX=new mem handle to copy to
;--- inp: EAX=old mem handle to copy from

	@ResetTrace

moveblock proc
	@dprintf "moveblock: copy %lX pages from %lX to %lX",\
		dword ptr [eax].MEMITEM.dwSize, dword ptr [eax].MEMITEM.dwBase, dword ptr [ebx].MEMITEM.dwBase

	pushad
	mov edi,[ebx.MEMITEM.dwBase]		;destination
	mov esi,[eax.MEMITEM.dwBase]		;source
	mov ecx,[eax.MEMITEM.dwSize]
	mov ebx, eax					;save old handle in ebx
	shl ecx,10						;pages -> dwords
	push es
	push ds
	mov eax,_FLATSEL_
	mov es,eax
	mov ds,eax
ife _LTRACE_
	rep movsd
else
@@:
	lodsd
	stosd
	dec ecx
	jnz @B
endif
	pop ds
;------------------------ free EBX handle (memory and handle)
	call _freememint
	pop es
	popad
	ret
	align 4
moveblock endp

endif

;--- internal function used by int 31h, ax=503h and ax=505h
;--- eax=new size
;--- ebx=handle
;--- ebp, bit 0: commit block
;--- out: new handle in eax
;--- old base in edi (+ old size in esi if block has moved)

	@ResetTrace

_resizememint proc
	call checksize					;size in eax to edx (in pages)
	jc error
	call searchhandle				;search handle of memory block, sets DS to GROUP16
	jc resizememerr
	@dprintf "resizemem: handle found (%lX,Base=%lX,Size=%lX,Flags=%X)",\
		 ebx,[ebx.MEMITEM.dwBase],[ebx.MEMITEM.dwSize],[ebx.MEMITEM.flags]

	mov edi,[ebx].MEMITEM.dwBase	;save old base

	test byte ptr [ebx.MEMITEM.flags],HDLF_ALLOC
	jz resizememerr
	test byte ptr [ebx.MEMITEM.flags],HDLF_MAPPED
	jnz resizememerr

	cmp edx,[ebx.MEMITEM.dwSize] 	;what is to be done?
	jz done						;---> nothing, size doesnt change
	jc resizemem3					;---> block shrinks

;-------------- block grows

	mov esi, ebx
	mov eax,[ebx.MEMITEM.dwSize]
	mov ecx, edx
	sub ecx, eax					;ecx=pages to add to block
	shl eax, 12
	add eax,[ebx.MEMITEM.dwBase]	;address for new pages to commit
	mov ebx, eax
	call _getspecaddrspace
	jc resizemem2

;-------------- block grows and we successfully allocated a new block 
;-------------- behind the current one. now these blocks must be merged

	mov ebx, eax
	@dprintf "resizemem: commit new addr space %lX",[ebx.MEMITEM.dwSize]
	test ebp,1
	jz @F
	call _commitblock
	jc error5
@@:
	mov edx, [ebx.MEMITEM.dwSize]
	mov ecx, [eax.MEMITEM.pNext]
	mov ebx, esi
	mov [ebx.MEMITEM.pNext],ecx
	add [ebx.MEMITEM.dwSize],edx	;adjust size in current block
	@dprintf "resizemem: free handle %lX, base=%lX, size=%lX", eax, [eax.MEMITEM.dwBase], edx
	push eax
	call _freememhandle
	jmp done

;-------------- block shrinks
;-------------- alloc a new handle, split the block
;-------------- at finally free the second block

resizemem3:
	@dprintf "resizemem: block shrinks to %lX pages", edx
	mov eax, ebx
	call _allocmemhandle 			;get new handle in EBX
	jc resizememerr
	@dprintf "resizemem: new handle %lX", ebx
	mov ecx,[eax.MEMITEM.dwSize]
	mov [eax.MEMITEM.dwSize],edx
	sub ecx, edx					;pages for second block in ECX
	mov [ebx.MEMITEM.dwSize], ecx
	mov ecx, ebx
	xchg ecx, [eax.MEMITEM.pNext]	 ;current handle is done now
	mov [ebx.MEMITEM.pNext], ecx
	shl edx,12
	add edx,[eax.MEMITEM.dwBase]
	mov [ebx.MEMITEM.dwBase], edx
	or [ebx.MEMITEM.flags], HDLF_ALLOC
	@dprintf "resizemem: changed hdl=%lX, nxt=%lX, base=%lX, size=%lX",\
		eax, [eax.MEMITEM.pNext], [eax.MEMITEM.dwBase], [eax.MEMITEM.dwSize]
	@dprintf "resizemem: free block hdl=%lX, nxt=%lX, base=%lX, size=%lX",\
		ebx, [ebx.MEMITEM.pNext], [ebx.MEMITEM.dwBase], [ebx.MEMITEM.dwSize]
	call _freememint 			   ;release block in EBX
	mov ebx,eax
	jmp done

;--------------- the worst case: next block is allocated
;--------------- so we need a new block and have to move the PTEs
;--------------- the old block must then be released
;--------------- esi = current handle

resizemem2:
	@dprintf "resizemem: cannot enlarge memory block"

	xor ebx, ebx
	mov ecx, edx
	call _getspecaddrspace
	jc resizememerr2				;error 'no more space'
	@dprintf "resizemem: new address space allocated %lX",[eax].MEMITEM.dwBase
	mov ebx, eax
	test ebp,1
	jz @F
	mov ecx,[ebx].MEMITEM.dwSize	;new size
	mov eax,[esi].MEMITEM.dwSize	;old size
	sub ecx,eax						;ecx == bytes added to block
	shl eax, 12
	add eax,[ebx].MEMITEM.dwBase	;eax == end of old block
	push es
	call _CommitRegion				;commit new space of new block
	pop es
	jc error3
	@dprintf "resizemem: for new block new space committed"
@@:
	mov ecx,[esi].MEMITEM.dwSize
	mov edx,[ebx].MEMITEM.dwBase
	mov eax,[esi].MEMITEM.dwBase
	@dprintf "resizemem: moving PTEs, old=%lX, size=%lX, new=%lX", eax, ecx, edx
	call _MovePTEs				;move PTEs from eax to edx, size ecx
	@dprintf "resizemem: PTE moved"
	push ebx
	mov ebx, esi
	mov esi, [ebx].MEMITEM.dwSize	;get old size in ESI
	call _freememint					;free the old handle
	@dprintf "resizemem: old block freed"
	pop ebx
done:
	mov eax, ebx

	@dprintf "resizemem: exit, handle=%lX,addr=%lX,size=%lX,flags=%X",\
		ebx,[ebx.MEMITEM.dwBase],[ebx.MEMITEM.dwSize],[ebx.MEMITEM.flags]
if _LTRACE_
	push ebx
	mov ebx,[ebx.MEMITEM.pNext]
	@dprintf "resizemem: next handle=%lX,addr=%lX,size=%lX,flags=%X",\
		ebx,[ebx.MEMITEM.dwBase],[ebx.MEMITEM.dwSize],[ebx.MEMITEM.flags]
	pop ebx
endif
	clc
	ret
error5:
error3:
	call _freememint					;free (new) ebx block
resizememerr2:
resizememerr:
	@dprintf "resizemem: error ,ebx=%lX",ebx
error:
	stc
	ret
	align 4
        
_resizememint endp

;*** int 31h, ax=0503h, resize memory
;*** INP: SI:DI=Handle
;***	  BX:CX=new SIZE
;*** OUT: SI:DI=Handle
;***	  BX:CX=lin. address

	@ResetTrace

resizemem proc public

	pushad

	@dprintf "resizemem: handle=%X:%X, new size=%X:%X",si,di,bx,cx
        
	push bx
	push cx
	pop eax
	push si
	push di
	pop ebx
	mov ebp,1
	call _resizememint
	jc @F
	mov edx, [eax].MEMITEM.dwBase
if ?ADDRISHANDLE
	mov eax, edx
endif
	mov [esp].PUSHADS.rDI, ax
	shr eax, 16
	mov [esp].PUSHADS.rSI, ax
	mov [esp].PUSHADS.rCX, dx
	shr edx, 16
	mov [esp].PUSHADS.rBX, dx
	clc
@@:
	popad
	ret
	align 4
        
resizemem endp

;------------------------------------------------------

;---- DPMI 1.0 memory functions

if ?DPMI10

	@ResetTrace
        
;--- int 31h, ax=0504h
;--- ebx=base (or 0), ecx=size (in bytes), dl[0]:committed?
;--- returns: NC: handle in ESI, base in EBX
;--- or C on errors

allocmemx proc public

	pushad
	@dprintf "allocmemx: linear memory request, ebx=%lX, ecx=%lX, dx=%X", ebx, ecx, dx
	and ebx, ebx
	jz anyaddress
	test bx,0FFFh
	jnz error8025
	push ss
	pop ds
	push edx
	mov eax, ecx
	call checksize
	mov ecx, edx
	pop edx
	jc error8021
	call _getspecaddrspace	 ;get addr space base=EBX,size=ECX
	jc error8012
	mov ebx, eax
	test dl, 1
	jz done
	@dprintf "allocmemx: commit block %lX pages", [ebx.MEMITEM.dwSize]
	call _commitblock
	jnc done
	jmp error8013
anyaddress: 					;EBX=0
	mov eax, ecx
	mov cl, HDLF_COMMIT
	test dl,1
	jnz @F
	mov cl,0
@@:
	call _AllocMemEx		;modifies EBX
	jc errorX
done:
	mov eax, [ebx.MEMITEM.dwBase]
	mov [esp].PUSHADS.rEBX, eax
ife ?ADDRISHANDLE
	mov eax, ebx
endif
	mov [esp].PUSHADS.rESI, eax
	popad
	clc
	ret
errorX:
	popad
	stc
	ret
error8012:
	popad
	mov ax,8012h
	ret
error8013:
	call _freememint
	popad
	mov ax,8013h
	stc
	ret
error8021:
	popad
	mov ax,8021h
	ret
error8025:
	popad
	mov ax,8025h
	stc
	ret
	align 4
allocmemx endp

;--- int 31h, ax=0505h
;--- esi=handle
;--- ecx=new size
;--- edx=flags
;---  bit 0: commit pages
;---  bit 1: descriptor table update required
;--- es:ebx: descriptor table (WORDs)
;--- edi=selectors in descriptor table 
;--- out: ebx=new base, esi=new handle

	@ResetTrace

resizememx proc public

	pushad
	@dprintf "resizememx: handle=%lX, new size=%lX, flags=%lX",esi,ecx,edx
	mov ebx, esi
	mov eax, ecx
	mov ebp, edx
	call _resizememint
	jc error
	mov edx, [eax].MEMITEM.dwBase
	cmp edi, edx
	jz nobasechange
	test byte ptr [esp].PUSHADS.rEDX, 2
	jz noselectorupdate
	mov ecx, [esp].PUSHADS.rEDI
	jecxz noselectorupdate
	@dprintf "resizememx: selector update, %lX selectors", ecx
	mov ebx, esi		;old size -> ebx
	mov esi, [esp].PUSHADS.rEBX
	shl ebx, 12
	add ebx, edi		;now ebx -> behind old block
	push es
	pop ds
	push eax
	cld
nextitem:
	lodsw
	@dprintf "resizememx: selector %X", ax
	push eax
	call getlinaddr
	jc @F
	@dprintf "resizememx: base of selector=%lX, old base=%lX, old end=%lX", eax, edi, ebx
	cmp eax, edi
	jb @F
	cmp eax, ebx
	jnc @F
	sub eax, edi	;subtract old base
	add eax, edx	;add new base
	push ds
	push ebx
	movzx ebx, word ptr [esi-2]
	mov ds,ss:[selLDT]
	and bl,0F8h
	mov [ebx].DESCRPTR.A0015,ax
	shr eax, 16
	mov [ebx].DESCRPTR.A1623,al
	mov [ebx].DESCRPTR.A2431,ah
	pop ebx
	pop ds
@@:
	dec ecx
	jnz nextitem
	pop eax
nobasechange:
noselectorupdate:
	clc
if ?ADDRISHANDLE
	mov eax, edx
endif
	mov [esp].PUSHADS.rESI, eax
	mov [esp].PUSHADS.rEBX, edx
	popad
	ret
error:
	popad
	stc
	ret
	align 4

resizememx endp

;--- int 31h, ax=0506h
;--- esi=handle
;--- ebx=offset within block
;--- ecx=pages
;--- es:edx=attributes

	@ResetTrace

getpageattr proc public
getpageattr endp		;fall throu

;--- int 31h, ax=0507h
;--- esi=handle
;--- ebx=offset within block
;--- ecx=pages
;--- es:edx=attributes
;--- out: NC = ok
;--- C = failure, ECX=pages which have been set

setpageattr proc public
setpageattr endp		;fall throu

getsetpageattr proc
	pushad
	@dprintf "getsetpageattr (%X): esi=%lX, ebx=%lX, ecx=%lX, es:edx=%lX:%lX",ax,esi,ebx,ecx,es,edx
if 0					;allow 0 pages because of 32rtm.exe
	stc
	jecxz exit
endif        
	mov edi, ebx		;save ebx
	mov ebx, esi
	call searchhandle	;sets ds to GROUP16
	jc error8023
	shr edi, 12
	mov eax, [ebx].MEMITEM.dwSize
	sub eax, edi
	jc error8025		;error "offset is beyond block size"
	cmp eax, ecx
	jc error8025		;error "offset + pages are beyond block size"
	shl edi, 12
	mov ebx, [ebx].MEMITEM.dwBase
	add ebx, edi
	cmp [esp].PUSHADS._AL,07
	jz @F
	call _getpageattributes	;es:edx -> word table, ebx=addr, ecx= size in pages
	jmp exit
@@:
	call _setpageattributes	;es:edx -> word table, ebx=addr, ecx= size in pages
	jnc exit
	mov [esp].PUSHADS.rECX, ecx
	mov [esp].PUSHADS.rAX, 8013h	;physical memory unavailable
exit:
if _LTRACE_
	pushfd
	pop eax
	@dprintf "getsetpageattr: fl=%X",ax
endif
	popad
	ret
error8023:
	popad
	mov ax,8023h
	@dprintf "getsetpageattr: error %X",ax
	stc
	ret
error8025:
	popad
	mov ax,8025h
	@dprintf "getsetpageattr: error %X",ax
	stc
	ret
	align 4

getsetpageattr endp

if ?DPMI10EX

;*** int 31h, ax=0508 (map physical device)
;--- ESI=memory handle
;--- EBX=offset within block
;--- ECX=no of pages
;--- EDX=physical address of memory to map

	@ResetTrace

mapphysx proc public
	cmp edx, 0A0000h
	jnc mapx
	mov ax,8003h
	stc
	ret
	align 4
mapphysx endp        

;*** int 31h, ax=0509 (map dos memory)
;--- ESI=memory handle
;--- EBX=offset within block
;--- ECX=no of pages
;--- EDX=linear address of memory to map

mapdos proc public
;	test edx, 0FFF00000h
;	jz mapx
	cmp edx, 110000h
	jb mapx
	mov ax,8003h
	stc
	ret
	align 4
mapdos endp        

;*** either a) map a physical address space 
;--- or b) copy PTEs
;--- ESI=memory handle
;--- EBX=offset within block
;--- ECX=no of pages (0 is allowed)
;--- EDX=address of memory to map

mapx proc
	pushad
	@dprintf "mapx (%X): esi=%lX, ebx=%lX, ecx=%lX, edx=%lX",ax,esi,ebx,ecx,edx
	mov ebx, esi
	call searchhandle	;sets DS=GROUP16
	jc error8023
	mov esi, ebx
	mov ebx, [esp].PUSHADS.rEBX
	test bx,0FFFh
	jnz error8025
	test dx,0FFFh
	jnz error8025
	shr ebx, 12
	mov eax, [esi].MEMITEM.dwSize
	sub eax, ebx
	jc error8025
	cmp eax, ecx
	jc error8025
	shl ebx, 12
	mov eax, [esi].MEMITEM.dwBase
	add eax, ebx
	pushad
	call _UncommitRegion
	popad

;--- to be fixed: the "mapped" flag must be on the PTE level!
	or [esi].MEMITEM.flags, HDLF_MAPPED

	cmp [esp].PUSHADS._AL,08	;is it int 31h, ax=508?
	jnz ax509
	mov bl,1					;set BL=1 -> page flags "write thru" + "cache disable"
	call pm_mapphysregion		;cannot fail, eax=lin dst, edx=phys src
	jmp done
ax509:	;v3.19: if DOS memory is to be mapped, copy PTEs, so it works correctly with UMBs
	mov ebx, eax
	mov eax, edx
	xor edx,edx
	mov dl, PTF_WRITEABLE or PTF_USER
	call pm_CopyPTEs	;eax=linear src, ebx=linear dst, ecx=pages, dx=flags
done:
	popad
	clc
	ret
error8023:
	popad
	mov ax,8023h
	stc
	ret
error8025:
	popad
	mov ax,8025h
	stc
	ret
	align 4
mapx endp        

;*** int 31h, ax=050A (get handle size)
;--- inp: SI:DI memory handle
;--- out: SI:DI size
;--- out: BX:CX linear address

	@ResetTrace

getmemsize proc public
	pushad
	@dprintf "getmemsize (%X): si:di=%lX",ax,si,di
	push si
	push di
	pop  ebx
	call searchhandle	;sets DS=GROUP16
	jc error8023
	mov eax, [ebx].MEMITEM.dwBase
	mov [esp].PUSHADS.rCX, ax
	shr eax, 16
	mov [esp].PUSHADS.rBX, ax
	mov eax, [ebx].MEMITEM.dwSize
	shl eax, 12				;pages -> bytes
	mov [esp].PUSHADS.rDI, ax
	shr eax, 16
	mov [esp].PUSHADS.rSI, ax
	@dprintf "getmemsize (%X): returnes si:di=%lX, bx:cx=%lX",ax,si,di,bx,cx
	clc
	popad
	ret
error8023:
	popad
	mov ax,8023h
	stc
	ret
	align 4
getmemsize endp        

;*** int 31h, ax=050B (get mem info)
;--- INP: ES:E/DI -> MEMINFOX

	@ResetTrace

getmeminfox proc public

	pushad
	push ss
	pop ds
	assume ds:GROUP16

	@dprintf "getmeminfox (%X): es:edi=%lX:%lX",ax,es,edi

	call _GetNumPhysPages  ;get free pages
if ?32BIT eq 0
	movzx edi,di
endif
	shl edx,12
	shl eax,12
	shl ecx,12
	mov es:[edi.MEMINFOX.dwTotalPhys],edx
	mov es:[edi.MEMINFOX.dwTotalHost],edx
	mov es:[edi.MEMINFOX.dwFreeHost],eax
	mov es:[edi.MEMINFOX.dwTotalVM],edx
	mov es:[edi.MEMINFOX.dwFreeVM],eax
	mov es:[edi.MEMINFOX.dwTotalClient],edx
	mov es:[edi.MEMINFOX.dwFreeClient],eax
	mov es:[edi.MEMINFOX.dwTotalLocked],0
	mov es:[edi.MEMINFOX.dwMaxLocked],eax
	mov es:[edi.MEMINFOX.dwHighestAddr],0FF800000h
	sub eax, ecx
	mov es:[edi.MEMINFOX.dwLargestBlock],eax
	mov es:[edi.MEMINFOX.dwMinSize],1
	mov es:[edi.MEMINFOX.dwAllocUnit],1000h
        
	popad
	clc
	ret
	align 4
getmeminfox endp

endif

endif

;*** int 31h, ax=0800h
;*** in: phys addr=BX:CX, size=SI:DI
;*** out: linear address in BX:CX

	@ResetTrace

mapphysregion proc public

	pushad
	push bx
	push cx
	pop  edx		;physical address -> edx

	push si
	push di
	pop eax		;size -> eax

	@dprintf "mapphysregion: phys2lin addr=%lX, size=%lX",edx,eax

	lea eax, [eax+edx-1]	;eax -> last byte to map
	cmp eax, edx
	jc error				;error if size==0 or too large

if 0 ;replaced by code below
	mov ecx,edx
	shr ecx,12
	shr eax,12
	sub eax,ecx
	inc eax					;now eax contains pages
	test eax, 0fff00000h
	stc
	jnz error
endif

	and dx,0F000h			;adjust to page boundary

if 1
	inc eax
	sub eax,edx	;now eax=true size in bytes
	add eax,1000h-1
	shr eax,12
endif

	call _searchphysregion	;search region EDX, size EAX (pages)
	jnc found
	xor ebx, ebx
	mov ecx, eax
	push ss
	pop ds
	call _getspecaddrspace		;changes eax only
	jc error
	or [eax].MEMITEM.flags, HDLF_MAPPED
	mov eax,[eax.MEMITEM.dwBase]
	mov bl,0					;dont set PWT flag in PTEs
	call pm_mapphysregion		;map ECX pages, cannot fail

	@dprintf "mapphysregion: phys2lin successfull, mapped at %lX",eax
found:
	mov cx,word ptr [esp.PUSHADS.rCX]
	and ch,0Fh
	or ax,cx
	mov [esp].PUSHADS.rCX, ax
	shr eax, 16
	mov [esp].PUSHADS.rBX, ax
	clc
ife _LTRACE_
error:
endif
	popad
;	or byte ptr [esp+2*4+2*4+1],1	;set client TF (debugging)
	ret
if _LTRACE_
error:
	@dprintf "mapphysregion: phys2lin failed"
?DISPLAYHDLTAB equ 1
	call displayhdltab
	stc
	popad
	ret
endif
	align 4

mapphysregion endp

if ?DPMI10

;--- int 31h, ax=0801h, bx:cx=linear address of region to unmap

unmapphysregion proc public

	pushad
	shl ebx, 16
	mov bx, cx
	and bx,0F000h		;v3.19: reset bits 0-11, else the handle wouldn't be found
	call _freememintEx
if _LTRACE_
	jc @F
	@dprintf "unmapphysregion: unmap successfull"
@@:
endif
	popad
	ret
	align 4

unmapphysregion endp

endif

;*** free all memory of current client
;*** called by _exitclient (int 21h, ah=4Ch)
;*** inp: DS=GROUP16
;--- no registers modified

	@ResetTrace

_freeclientmemory proc public

	pushad
	mov cl,[cApps]
	@dprintf "freeclientmemory enter, client=%X", cx
if 0;_LTRACE_
	@dprintf "freeclientmemory: hdltab before freeing blocks"
?DISPLAYHDLTAB equ 1
	call displayhdltab
endif
nextscan:
	mov ebx,offset pMemItems
	jmp nexthandle
freememory_1:
	test byte ptr [ebx].MEMITEM.flags,HDLF_ALLOC
	jz nexthandle
	cmp byte ptr [ebx].MEMITEM.owner,cl
	jnz nexthandle
	@dprintf "freeclientmemory: free handle=%lX, base=%lX, size=%lX, owner=%X",ebx,\
		[ebx].MEMITEM.dwBase,[ebx].MEMITEM.dwSize,[ebx].MEMITEM.owner
	call _freememint
	jmp nextscan
nexthandle:
	mov ebx,[ebx].MEMITEM.pNext
	and ebx, ebx
	jnz freememory_1
if 1
;--- if there is just 1 large address space remaining
;--- free it
	mov ebx, pMemItems
	and ebx, ebx
	jz @F
	cmp [ebx].MEMITEM.pNext,0
	jnz @F
	test [ebx].MEMITEM.flags,HDLF_ALLOC
	jnz @F
	mov eax, [ebx].MEMITEM.dwBase
	mov ecx, [ebx].MEMITEM.dwSize
	call _FreeUserSpace
	mov pMemItems,0
	push ebx
	call _freememhandle
@@:
endif
if _LTRACE_
?DISPLAYHDLTAB equ 1
	call displayhdltab
endif
	@dprintf "freeclientmemory exit"
	popad
	ret
	align 4

_freeclientmemory endp

	assume ds:GROUP16

ifdef ?DISPLAYHDLTAB 

_LTRACE_ = 1	;this should always be 1

displayhdltab proc
	pushad
	@dprintf "handle   size     flgs owner"
	@dprintf "-----------------------------"
	mov ebx, pMemItems
	xor esi, esi
next:
	and ebx, ebx
	jz done
	@dprintf "%lX %lX %X %X",\
		[ebx.MEMITEM.dwBase],[ebx.MEMITEM.dwSize],[ebx.MEMITEM.flags],[ebx.MEMITEM.owner]
	add esi, [ebx].MEMITEM.dwSize
	mov ebx, [ebx].MEMITEM.pNext
	jmp next
done:
	@dprintf "-----------------------------"
	mov ecx, esi
	shr ecx, 10
	add ecx, esi
	@dprintf "         %lX (%lX incl PDEs)", esi, ecx
	call _GetNumPhysPages  ;get free pages
	@dprintf "pages free phys=%lX, total phys=%lX, res=%lX", eax, edx, ecx
	popad
	ret
	align 4

	@ResetTrace

displayhdltab endp

endif

_TEXT32  ends

	end
