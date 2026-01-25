
;--- page handling
;--- handles physical memory, address space and un/committed memory

;--- todo: get rid of dwMaxOfsPT - user address space is to be
;---       managed by i31mem.

	.486P

	option proc:private

	include hdpmi.inc
	include external.inc

?XMSALLOCRM 	equ 1	;std 1, alloc 1. EMB in real mode (XMS-Mode only)
?CLEARACCBIT	equ 0	;std 0, on entry clear ACC-Bit for all PTEs in 1. MB
?FREEPDIRPM 	equ 0	;std 0, on exit reset CR3 in protected mode (?)
?VCPIALLOC		equ 1	;std 1, alloc VCPI mem if no XMS host found
?RESPAGES		equ 4	;std 4, small reserve, do not alloc these pages
?ZEROFILL		equ 0	;std 0, 1=do zero fill all committed pages
?USEE820		equ 0	;std 0, use int 15h, ax=e820 to get extmem in raw mode
?USEE801		equ 1	;std 1, use int 15h, ax=e801 to get extmem in raw mode
?FREEVCPIPAGES	equ 1	;std 1, free all VCPI pages in pm_exit_rm
?FREEXMSINRM	equ 1	;std 1, free XMS blocks in pm_exit_rm
?NOVCPIANDXMS	equ 1	;std 1, 1=avoid using VCPI if XMS host exists
?FREEXMSDYN 	equ 1	;std 1, 1=free XMS blocks dynamically
?XMSBLOCKCNT	equ 1	;std 1, 1=count XMS blocks to improve alloc strategy
?DOSPGLOBAL		equ 0	;std 0, 1=set global flag for pages in region 0-10FFFFh
?SETPTE			equ 0	;std 0, 1=enable pm_SetPage
?NOCR3CACHE		equ 0	;std 0, 1=set PWT & PCD bits in cr3

?USESEARCHREGION equ 1 ;std=1, new for v3.22; also in i31mem.asm; "std=0"-branch to be removed.

PTF_NORMAL	equ PTF_WRITEABLE + PTF_USER

@seg _ITEXT16

ifndef ?USEINVLPG
?USEINVLPG = 1 		;use invlpg opcode (80486+)
endif

;--- PHYSBLK: describes a block of physical memory
;--- there is always just 1 item with free pages
;--- and it is stored in PhysBlk variable

PHYSBLK struct
pNext	dd ?	;ptr next block
dwBase	dd ?	;base address of block
dwSize	dd ?	;size in pages
dwFree	dd ?	;pages allocated
union
dwHandle dd ?        
struct
wHandle	dw ?	;handle (XMS+DOS)
bFlags  db ?
		db ?
ends
ends
PHYSBLK ends

;--- bFlags

PBF_XMS		equ 1	;is a XMS handle
PBF_I15		equ 2	;is a I15 block (no handle)
PBF_DOS		equ 4	;is a DOS block
PBF_TOPDOWN	equ 8	;get memory from top to bottom (i15)
PBF_LINEAR 	equ 40h	;dwBase is linear, not physical
PBF_INUSE   equ PBF_XMS or PBF_I15 or PBF_DOS


;*** Flags in paging tables

; 001=present/not present
; 002=read-write/read-only
; 004=user/system
; 008=PWT (cache write through) 586+
; 010=PCD (cache disable) 586+
; 020=accessed (read access)
; 040=dirty (write access)
; 080=PAT
; 100=Global
; 200=available
; 400=available : is _XMSFLAG_
; 800=available	: is _VCPIFLAG_

?PAGETABLEATTR	= PTF_PRESENT or PTF_WRITEABLE or PTF_USER

_XMSFLAG_		= 4h	;page src xms (+i15 +dos)
_VCPIFLAG_		= 8h	;page src vcpi

?SYSTEMSPACE	= 0FF8h ;offset in page dir for system area (std FF8=0xFF800000)   
?SYSPGDIRAREA	= 2*4	;2 system page tables (sys pagetab 0+1)

?SYSAREA0	= (?SYSTEMSPACE+0) shl 20		; = FF800000
?SYSAREA1	= (?SYSTEMSPACE+4) shl 20		; = FFC00000
?PTSYSAREA0	= ?SYSAREA1+0					; = FFC00000

?OFSMAPPAGE equ 1000h

; memory structure as implemented by page manager:
; - page directory is mapped at end of sysarea 0 (FFBFF000)
; - page tables are mapped in linear region FFC00000-FFFFFFFF
; - page table sysarea 0 (FF800000-FFBFFFFF) is at FFC00xxx
; - page table sysarea 1 (FFC00000-FFFFFFFF) is at FFC01xxx (page map table)
; - page tables user space (00000000-FF7FFFFF) begin at FFC02xxx
; - variables:
; - pPageDir    = FFBFF000
; - pPageTables = FFC00000 (=sysarea 1)
; - pPageTab0   = FFC02000

_DATA16 segment

pPageDir	 dd ?SYSAREA1-1000h	;const, linear address page dir (FFBFF000)
pPageTables  dd ?SYSAREA1	;const, linear address start page tables (FFC00000)
pPageTab0	 dd 0			;const after init, linear address page table 0 (FFC02000)
dwOfsPgTab0  dd 0			;const after init, start user space in PT 0, used to calc user address space

;--- system address space (FF800000-FFBFFFFF)
;--- the space is allocated by using 2 pointers, SysAddrUp
;--- and SysAddrDown (one upwards, the other downwards)

;--- the first is used to alloc space for code, GDT, LDT, IDT, ...
;--- the second is used to alloc space for mapped page dir
;--- + client save states

SysAddrUp	dd 0		;init: bottom of sys addr space (FF801000)
SysAddrDown	dd 0		;init: top of sys address space (FFC00000)

;--- the VM-specific data is cleared for a new VM

startvdata label byte

;--- dwMaxOfsPT tells what client address space has been "created".
;--- it's an offset within SYSAREA1 (FFC00000).
;--- on startup, the variable is initialized with 2444h in XMS/I15
;--- (corresponds to linear address 111000h).
;--- after 8 MB address space allocation, value would be 4444h.

dwMaxOfsPT	dd 0		;offset free space in page table region

;--- the page pool are uncommitted PTEs (XMS) that are
;--- stored in the page tables. the pool is scanned from top to bottom.

dwMaxPool	dd 0		;top of page pool
dwPagePool	dd 0		;uncommitted PTEs (XMS+I15) in page pool

PhysBlk		PHYSBLK <0>	;linked list of physical memory blocks allocated

if ?VCPIALLOC
dwVCPIPages dd 0		;count allocated VCPI pages (just as info)
endif

if ?FREEXMSINRM
pXMSHdls	dw 0		;pointer to XMS handles when exiting (exit server)
endif
if ?FREEVCPIPAGES
pVCPIPages	dw 0		;VCPI pages saved when exiting (exit server)
endif
if ?FREEPDIRPM
orgcr3		dd 0		;original cr3
;cr3flgs	 	dw 0		;save bits 0-11 of CR3 phys entry here
endif
if ?XMSBLOCKCNT
bXMSBlocks	db 0
endif
		align 4
endvdata label byte

_DATA16 ends

;--- deactivated in v3.18
;_DATA16C segment
;dwResI15Pgs  dd 0		;free pages for int 15h
;_DATA16C ends

_TEXT32  segment

	assume DS:GROUP16

;*** get ptr to PTE of a linear address
;*** in: linear address in EAX
;*** out: EDI=linear address of PTE for address in EAX
;--- other registers preserved

	@ResetTrace

Linear2PT proc

	lea edi,[eax+?SYSPGDIRAREA shl 20]
	shr edi,10				;div 1024 -> offset in page table
	and edi,not 3
	add edi,ss:pPageTables
	@dprintf "Linear2PT: linear %lX -> PTE %lX", eax, edi
	ret
	align 4
Linear2PT endp

;--- same as Linear2PT, but carry flag is set if
;--- space isn't allocated yet (no PDE exists).

pm_Linear2PT proc public

	call Linear2PT
	push eax
	mov eax, ss:dwMaxOfsPT
	add eax, ss:pPageTables
	cmp eax, edi
	pop eax
	ret
	align 4

pm_Linear2PT endp

;--- get linear address from a PTE address
;--- in: eax = linear address where PTE is stored
;--- out: NC & eax = linear address
;---      C error, invalid PTE address

PT2Linear proc
	sub eax, ss:pPageTables	;0-3FFFFFh
	jc exit
	sub eax, ?SYSPGDIRAREA shl 10
	and eax, 3FFFFFh
	shl eax, 10
exit:
	ret
	align 4
PT2Linear endp

if 1;?MAPDOSHIGH

;--- copy PTEs 
;--- EAX: source linear address
;--- EBX: dest linear address
;--- ECX: #pages
;--- EDX: (additional) page flags

pm_CopyPTEs proc public
	@dprintf "pm_CopyPTEs: src=%lX, dst=%lX, pages=%lX",eax,ebx,ecx
	push ds
	push es
	pushad
	call Linear2PT	;get source PTEs
	mov esi, edi
	mov eax, ebx
	call Linear2PT	;get dest PTEs
	@dprintf "pm_CopyPTEs: src PTR=%lX, dst PTE=%lX, pages=%lX",esi,edi,ecx
	push byte ptr _FLATSEL_
	pop ds
	push ds
	pop es
	cld
if 0
	rep movsd
else
@@:
	lodsd
;	and al,0E0h
	and ax,0F000h	;reset PG and all user-reserved flags
	or al, PTF_PRESENT
	or ax, dx
	stosd
	loop @B
endif
if 0
	mov ebx,[esp].PUSHADS.rEBX
	mov ecx,[esp].PUSHADS.rECX
	call updatetlb
endif
	popad
	pop es
	pop ds
	ret
pm_CopyPTEs endp

endif

ife ?USESEARCHREGION

;*** scan page tables for a physical address region
;*** called by pm_searchphysregion
;*** ESI = ^ page table
;*** ECX = items in page table(s)
;*** EDX = start physical region to search
;*** EDI = size physical region in pages
;*** DS = FLAT
;*** Out: NC + EAX=linaddr

	@ResetTrace

scanpagetab proc

	cld
	@dprintf "scanpagetab: scan page table at lin %lX for addr=%lX, size=%lX", esi, edx, edi
nextentry:
	cmp ecx,edi
	jb error
	lodsd
	and ax,0F000h or PTF_PRESENT or PTF_USER
	cmp eax,edx
	jz scanpagetab_2
scanpagetab_11:
	loopd nextentry
error:
	stc
	ret

;--- first PTE is ok, compare the rest
        
scanpagetab_2:
	pushad
nextitem:
	dec edi
	jz found
	lodsd
	and ax,0F000h or PTF_PRESENT or PTF_USER
	add edx,1000h
	cmp eax,edx
	loopzd nextitem
	popad
	jmp scanpagetab_11	;continue search
found:
	popad
	lea eax, [esi-4];adjust esi so it points to 1. entry again
	call PT2Linear
	@dprintf "scanpagetab: mapping found for physical addr %lX: %lX", edx, eax
	clc
	ret
	align 4
scanpagetab endp

;--- search a region of physical pages in linear address space
;--- called by int 31h, ax=800h
;--- edx=physical address start
;--- eax=size in pages
;--- out: NC: found, eax=linear address
;--- else C, all preserved

pm_searchphysregion proc public uses ds
	pushad
	@dprintf "pm_searchphysregion: addr=%lX,pages=%lX",edx,eax

	mov edi,eax 			;search in spaces already mapped
	push byte ptr _FLATSEL_
	pop ds
	and dh,0F0h
	mov dl,PTF_PRESENT or PTF_USER

;--- get number of PTEs in ECX

	mov esi, ss:pPageTables
	mov ecx, ss:dwMaxOfsPT
	shr ecx, 2
	call scanpagetab
	jc error
	mov [esp].PUSHADS.rEAX,eax
error:
	popad
	ret
	align 4
pm_searchphysregion endp

endif

;*** helper for DPMI functions 0800h, 0508h
;*** map a physical address region into linear address space
;*** INP: EDX=physical address region start
;***      ECX=length of region in pages (may be 0!)
;***      EAX=linear address to map the region to
;***      BL=1 -> set PTF_PWT bit in PTEs

	@ResetTrace

pm_mapphysregion proc public uses es

	pushad

	@dprintf "pm_mapphysregion: phys. addr=%lX, size=%lX", edx, ecx
	jecxz done

	push byte ptr _FLATSEL_
	pop es
	call Linear2PT			;convert linear address in EAX to PTE ptr in EDI
	@dprintf "pm_mapphysregion: pPagetab=%lX, addr=%lX", edi, eax
	mov eax,edx
	or al, PTF_PRESENT or PTF_WRITEABLE or PTF_USER
	test bl,1
	jz @F
	or al, PTF_PWT or PTF_PCD	;set 'write through' + 'cache disable'
@@:
if _LTRACE_
	xor ebx,ebx
endif
nextpte:
	mov edx,es:[edi]
	stosd
	test dh,_XMSFLAG_      ;what about VCPI pages? They should be released!
	jz @F
	call savePTEinpagepool
if _LTRACE_
	inc ebx
endif
@@:
	add eax,1000h
	loopd nextpte
if _LTRACE_
	cmp ebx,0
	jz @F
	@dprintf "pm_mapphysregion: %lX PTEs of page pool moved", ebx
@@:
endif
done:
	popad
	ret
	align 4

pm_mapphysregion endp

;--- move PTE (src=XMS) to a "safe" location in the page pool.
;--- currently, just the region "below" EDI is scanned.
;--- in:
;--- EDX=PTE
;--- EDI=(behind) ptr PTE
;--- ECX=pages still to map

savePTEinpagepool proc
	pushad
	mov esi, ss:pPageTables
nextitem:
	sub edi,4
	cmp edi,esi
	jc error
	mov eax,es:[edi]
	test al,PTF_PRESENT
	jnz nextitem
	test ah,_XMSFLAG_	;is another PTE in pool
	jnz nextitem
	mov es:[edi],edx
	jmp done
error:
	dec ss:dwPagePool
	@dprintf "pm_mapphysregion, ERROR: PTE %lX lost for page pool, dwPagePool=%lX", edx, ss:dwPagePool
done:
	popad
	ret
savePTEinpagepool endp

;--- physical memory

;*** get free dos pages

	@ResetTrace

getavaildospages proc

	push ebx
	or  ebx,-1
	mov ah,48h
	call rmdosintern	;get free paragraphs in BX
	movzx eax,bx
	shr eax,8		;paras to pages (10h -> 1000h)
	sub eax,1		;one less???
	jnc @F
	xor eax,eax
@@:
	pop ebx
	ret
	align 4

getavaildospages endp

;*** get free VCPI pages in EDX

if ?VCPIALLOC
getavailvcpipages proc

	xor edx,edx
	test [fHost],FH_VCPI
	jz exit
if ?NOVCPIANDXMS
	test fHost, FH_XMS
	jnz exit
endif
	@NMI_OFF
	mov ax,0DE03h			 ;get number of free pages (EDX)
	call [vcpicall]
	@NMI_ON
exit:
	ret
	align 4
getavailvcpipages endp
endif

;*** out: EAX=free XMS mem in pages, EDX=largest block in pages, other regs preserved.
;*** called by 1) pm_GetNumPhysPages 2) getxmspage

getavailxmspages proc uses ebx

	test fHost, FH_XMS
	jz error
	@dprintf "getavailxmspages: calling XMS (cs:ip=%X:%X, RMS=%X:%X)",\
		word ptr ss:xmsaddr+2, word ptr ss:xmsaddr+0, v86iret.rSS, v86iret.rSP
;	@waitesckey
	push ecx
	mov ah, fXMSQuery
	mov bl,0
	pushd offset callxms
	call callrmprocintern
	pop ecx

;--- here largest free block in E/AX, total free in E/DX
;--- it is returned even if the call ah=88h "fails" (BL=A0)

	@dprintf "getavailxmspages: XMS returned (e)ax=%lX kB, (e)dx=%lX kB, bx=%X", eax, edx, bx
	cmp bl,0
	jz @F
	cmp bl,0A0h				;status "all memory allocated"?
	jnz error
@@:
	xchg eax,edx			;now free XMS memory (kB) into EAX, largest free block in EDX
	test [fHost],FH_XMS30	;xms driver 3.0+?
	jnz @F
	movzx eax,ax
	movzx edx,dx
@@:
	shr eax,2				;kbytes -> pages
	shr edx,2				;kbytes -> pages
	ret
error:
	xor eax,eax
	xor edx,edx	;v3.22: added (it's checked by getxmspage)
	ret
	align 4
getavailxmspages endp

	@ResetTrace

;*** get number of physical pages
;*** out: eax=free pages, edx=total pages, ecx=reserved for address space

pm_GetNumPhysPages proc public

	assume ds:GROUP16

	@dprintf "GetNumPhysPages: free pages in cur block=%lX", PhysBlk.dwFree
	call getavailxmspages	;get free XMS pages in EAX
	@dprintf "GetNumPhysPages: XMS pages=%lX", eax
	add eax,PhysBlk.dwFree	;add free pages cur block (XMS or I15)
if ?VCPIALLOC
	and eax, eax			;is XMS memory available?
	jnz @F
	call getavailvcpipages	;get VCPI pages
	@dprintf "GetNumPhysPages: VCPI pages=%lX", edx
	mov eax, edx
@@:
endif
	test [bEnvFlags],ENVF_INCLDOSMEM
	jz @F
	push eax
	@dprintf "GetNumPhysPages: calling getavaildospages"
	call getavaildospages
	@dprintf "GetNumPhysPages: DOS pages=%X",ax
	pop ecx
	add eax,ecx
@@:
	mov ecx,eax 			;some pages will be needed for paging
	shr ecx,10				;(1 page for 4MB address space)
if ?RESPAGES        
	add ecx, ?RESPAGES
endif
	@dprintf "GetNumPhysPages: subtract %lX pages for pagetables",ecx
	cmp ecx,eax
	jc @F
	mov ecx,eax
@@:
	mov edx, eax
	add eax, dwPagePool		;the pagepool are "allocated" pages

;--- total physical pages are
;---   "true" free pages
;--- + allocated pages in PHYSBLK blocks
;--- + dwVCPIPages

  if ?VCPIALLOC
	add edx, dwVCPIPages
  endif
	push ecx
	mov ecx, offset PhysBlk
nextitem:
	test [ecx].PHYSBLK.bFlags, PBF_INUSE
	jz @F
	add edx, [ecx].PHYSBLK.dwSize
	sub edx, [ecx].PHYSBLK.dwFree	;free pages are in EAX already
@@:
	@dprintf "GetNumPhysPages: block total=%lX, free=%lX",[ecx].PHYSBLK.dwSize, [ecx].PHYSBLK.dwFree
	mov ecx, [ecx].PHYSBLK.pNext
	and ecx, ecx
	jnz nextitem
	pop ecx
if 0
	test [bEnvFlags],ENVF_NOXMS30	;restrict free mem to 63 MB?
	jz norestrict
	cmp eax, 4000h-1h
	jb @F
	mov eax, 4000h-1h
@@:
	cmp edx, 4000h-1h
	jb @F
	mov edx, 4000h-1h
@@:
norestrict:
endif
	@dprintf "GetNumPhysPages: total=%lX, free=%lX, res=%lX",edx,eax,ecx
	ret
	align 4
pm_GetNumPhysPages endp

;*** get physical address of a linear address in 1. MB
;*** inp: eax=linear address (bits 0-11 are cleared)
;--- no check done

conv2phys proc uses es
	shr eax,10
	add eax, pPageTab0
	push byte ptr _FLATSEL_
	pop es
	mov eax,es:[eax]
	ret
	align 4
conv2phys endp

;--- get a page from the current memory block
;--- this block may come from XMS, I15 or DOS

	@ResetTrace

getblockpage proc
	cmp PhysBlk.dwFree, 0
	jz error
	dec PhysBlk.dwFree
	mov eax, PhysBlk.dwBase
	push ecx
	test PhysBlk.bFlags, PBF_TOPDOWN
	jnz topdown
	mov ecx, PhysBlk.dwSize
	sub ecx, PhysBlk.dwFree	;ecx = pages allocated
	dec ecx
	shl ecx, 12
	add eax, ecx
	pop ecx
	test PhysBlk.bFlags, PBF_LINEAR
	jz @F
	call conv2phys
@@:
if _LTRACE_
	push ecx
	mov ecx, PhysBlk.dwSize
	shl ecx, 12
	add ecx, PhysBlk.dwBase
	dec ecx
	@dprintfx ?LOG_PMGREXT,"getblockpage: page %lX from cur block %lX-%lX, free=%lX", eax, PhysBlk.dwBase, ecx, PhysBlk.dwFree
	pop ecx
endif
;	@waitesckey
	or ax,PTF_NORMAL+(_XMSFLAG_*100h)	  ;set user,read-write
	ret
topdown:
	mov ecx, PhysBlk.dwFree
	shl ecx, 12
	add eax, ecx
	pop ecx
	jmp @B
error:
	stc
	ret
	align 4
getblockpage endp

	@ResetTrace

allocphyshandle proc uses edx
	mov eax, offset PhysBlk
	jmp skipitem
nextitem:
	and eax, eax
	jz notfound
	test [eax].PHYSBLK.bFlags, PBF_INUSE
	jz found
skipitem:
	mov edx, eax
	mov eax, [edx].PHYSBLK.pNext
	jmp nextitem
found:
	push [eax].PHYSBLK.pNext
	pop [edx].PHYSBLK.pNext
	xor edx, edx
	mov [eax].PHYSBLK.pNext, edx
	ret
notfound:
	push sizeof PHYSBLK
	call _heapalloc					;this call cannot fail now
	ret
	align 4
allocphyshandle endp

setactivephyshandle proc
	mov edx, offset PhysBlk
@@:
	test [edx].PHYSBLK.bFlags, PBF_INUSE
	jnz found
	mov edx, [edx].PHYSBLK.pNext
	and edx, edx
	jnz @b
	stc
	ret
found:
	cmp edx, offset PhysBlk
	jz done
	mov eax, [edx].PHYSBLK.dwBase
	mov ecx, [edx].PHYSBLK.dwSize
	xchg eax, PhysBlk.dwBase
	xchg ecx, PhysBlk.dwSize
	mov [edx].PHYSBLK.dwBase, eax
	mov [edx].PHYSBLK.dwSize, ecx
	mov eax, [edx].PHYSBLK.dwFree
	mov ecx, [edx].PHYSBLK.dwHandle
	xchg eax, PhysBlk.dwFree
	xchg ecx, PhysBlk.dwHandle
	mov [edx].PHYSBLK.dwFree, eax
	mov [edx].PHYSBLK.dwHandle, ecx
done:
	ret
	align 4
setactivephyshandle endp

if ?FREEXMSDYN

;--- free phys handle in EAX
;--- DS=GROUP16, ES=FLAT?

	@ResetTrace

freephyshandle proc
	pushad
	mov ecx, offset PhysBlk
nextitem:
	cmp eax, ecx
	jz found
	mov ecx, [ecx].PHYSBLK.pNext
	and ecx, ecx
	jnz nextitem
	stc
	popad
	ret
found:
	@dprintf "freephyshandle: phys handle %lX found, pNext=%lX, hdl=%lX, start=%X", eax, [eax].PHYSBLK.pNext, [eax].PHYSBLK.dwHandle, offset PhysBlk
@@:
	mov dl, [eax].PHYSBLK.bFlags
	mov [eax].PHYSBLK.bFlags, 0
	test dl, PBF_XMS
	jz @F
	mov dx,[eax].PHYSBLK.wHandle
	@dprintf "freephyshandle: calling XMS host to free handle=%X", dx
	pushd offset freexms
	call callrmprocintern
if ?XMSBLOCKCNT
	dec [bXMSBlocks]
endif
	jmp done
@@:
	test dl, PBF_DOS
	jz @F
if 0
	mov cx, [eax].PHYSBLK.wHandle
	mov v86iret.rES,cx
	mov ah,49h
	call rmdosintern
else
	push eax
	mov ah,51h
	call rmdosintern	;get PSP in BX
	pop eax
	movzx ecx, [eax].PHYSBLK.wHandle
	dec ecx
	shl ecx, 4
	mov word ptr es:[ecx+1], bx
endif
@@:
done:
	clc
	popad
	ret
	align 4
freephyshandle endp

endif

	@ResetTrace

;--- alloc new phys block and set values
;--- edx == base
;--- eax == size

setphyshandle proc        

;	@dprintf "setphyshandle: XMS/DOS memory allocated, addr=%lX, size=%lX",edx,eax

							;set values so _heapalloc cannot fail
	xchg edx,PhysBlk.dwBase	;save current physical address
	push edx
	push PhysBlk.dwSize
	mov PhysBlk.dwSize,eax	;save current size in pages
	xchg eax, PhysBlk.dwFree
	push eax
	push PhysBlk.dwHandle

	call allocphyshandle
	mov edx, PhysBlk.pNext
	mov [eax].PHYSBLK.pNext, edx
	mov PhysBlk.pNext, eax
	pop [eax].PHYSBLK.dwHandle
	pop [eax].PHYSBLK.dwFree
	pop [eax].PHYSBLK.dwSize
	pop [eax].PHYSBLK.dwBase
	@dprintf "setphyshandle: new phys mem obj %lX, base=%lX, size=%lX, free=%lX",eax,[eax].PHYSBLK.dwBase, [eax].PHYSBLK.dwSize, [eax].PHYSBLK.dwFree
	@dprintf "setphyshandle: current: base=%lX, size=%lX, free=%lX", PhysBlk.dwBase, PhysBlk.dwSize, PhysBlk.dwFree
	ret
	align 4
setphyshandle endp

;*** get pages from XMS
;*** inp ECX: requested size in pages
;*** DS=GROUP16
;--- modifies ebx, eax, edx? 

	@ResetTrace

	assume ds:GROUP16

getxmspage proc near

	test fHost,FH_XMS		;XMS host present?
	jz getxmspage_err1

	@dprintf "getxmspage: try to alloc XMS mem (real mode), ecx=%lX",ecx
	call getavailxmspages   ;largest block in edx, total free in eax (pages)

;--- v3.22: check edx (max block free) instead of eax (total free)
;	cmp eax, 1
	cmp edx, 1              ;largest free block must be at least 1 page
	jc getxmspage_err2		;XMS is out of memory
	call getbestxmssize		;return best size in EAX
	mov edx,eax
	push eax
	mov ah,fXMSAlloc
	shl edx,2
	pushd offset allocxms_rm
	call callrmprocintern
	pop eax
	jc getxmspage_err3		;XMS is out of memory
	test dx,0FFFh			;block's base on page boundary?
	jz @F
	add edx,1000h-1
	and dx,0F000h			;if no, do a page align
	dec eax
@@:
	@dprintf "getxmspage: allocated %lX pages", eax
	call setphyshandle
	mov PhysBlk.wHandle, bx
	mov PhysBlk.bFlags, PBF_XMS
if ?XMSBLOCKCNT
	inc [bXMSBlocks]
endif
	jmp getblockpage
getxmspage_err1:
ifdef _DEBUG
	@dprintf "getxmspage: error, no XMM"
	stc
	ret
endif
getxmspage_err2:
ifdef _DEBUG
	@dprintf "getxmspage: error, getavailxmspages returned 0"
	stc
	ret
endif
getxmspage_err3:
	@dprintf "getxmspage: error, XMM alloc call failed, bx=%X",bx
	stc
	ret
	align 4
getxmspage endp

;*** allocate DOS memory to satisfy requests, ecx=pages
;--- out: C if error
;--- modifies ebx, edx, eax

	@ResetTrace

getdospage proc

	assume ds:GROUP16

	test [bEnvFlags],ENVF_INCLDOSMEM
	jz error

	cmp ecx,100h-1		  ;255 or more pages request (1 MB - 4 kB)?
	jnc error			  ;is an error in any case
	test PhysBlk.bFlags, PBF_DOS
	jz newdosblock

	mov ax, PhysBlk.wHandle
	mov ebx,PhysBlk.dwSize
	mov v86iret.rES,ax
	neg al
	movzx eax, al
	shl ebx,8				;pages -> paragraphs
	add ebx, eax

	mov dh,cl				;angeforderte pages (1 Page -> 100h Paras)
	mov dl,00
	movzx edx,dx
	lea edx,[edx+ebx]
	test edx,0FFFF0000h
	jnz newdosblock
	push ebx
	mov ebx,edx
	@dprintf "getdospage: try to enlarge DOS block %X to %X paras",v86iret.rES,bx
	mov ah,4Ah
	call rmdosintern
	pop ebx
	jc @F
	@dprintf "getdospage: DOS block enlarged"
	add PhysBlk.dwSize,ecx
	mov PhysBlk.dwFree,ecx
	call setowner
	jmp getblockpage
@@:
	@dprintf "getdospage: DOS block enlarge failed"
	mov ah,4Ah				;due to a bug in most DOSes the block
	call rmdosintern		;has to be resized to its previous size
	call setowner
newdosblock:
	mov bh,cl				;nur angeforderte pages
	inc bh					;1 mehr, da beginn nicht an pagegrenze
	mov bl,00
	@dprintf "getdospage: try to alloc a new DOS block, size=%X",bx
	mov ah,48h
	call rmdosintern
	jc error2
	@dprintf "getdospage: new DOS block allocated, addr=%X, size=%X",ax,bx
	mov bx,ax		;handle
	movzx edx,ax
	shl edx,4
	add edx,1000h-1
	and dx, 0F000h
	movzx eax,cl
	call setphyshandle
	mov PhysBlk.wHandle, bx
	mov PhysBlk.bFlags, PBF_DOS or PBF_LINEAR
	call setowner
	jmp getblockpage
error2:
	@dprintf "getdospage: alloc new dos block failed"
error:
	stc
	ret
setowner:
	push es
	push byte ptr _FLATSEL_
	pop es
	movzx edx,PhysBlk.wHandle
	dec edx
	shl edx,4
	mov ax,wHostPSP
	mov es:[edx+1],ax
	pop es
	retn
	align 4
getdospage endp

;*** scan page pool for a free page
;*** is called only if there is at least 1 item in pool
;*** the page pool are released pages in the page tables
;*** (when a page is released just the present bit is cleared)

	@ResetTrace

scanpagepool proc uses es esi ecx

	push byte ptr _FLATSEL_
	pop es

	mov esi, dwMaxPool
	mov ecx, pPageTables
	add esi, ecx

;	@dprintf "scanpagepool: dwMaxPool=%lX, dwPagePool=%lX", dwMaxPool, dwPagePool

if _LTRACE_
	cmp esi, ecx
	ja @F
;--- pages in page pool, but dwMaxPool <= zero. This shouldn't happen!
	@dprintf "scanpagepool: ERROR, dwMaxPool=%lX!, dwPagePool=%lX", dwMaxPool, dwPagePool
@@:
endif

nextitem:
	sub esi,4
	cmp esi, ecx
	jb notfound
	mov eax,es:[esi]
	test al, PTF_PRESENT
	jnz nextitem
	test ah, _XMSFLAG_
	jz nextitem
	mov dword ptr es:[esi],PTF_NORMAL  ;clear PTE here
	sub esi, ecx
exit:
	mov dwMaxPool, esi
	ret
notfound:
;--- no page in page pool. This shouldn't happen!
	@dprintf "scanpagepool: ERROR, no page in page pool found"
	add esi,4
	sub esi, ecx
	stc
	jmp exit
	align 4
scanpagepool endp

;*** get one phys. page
;*** inp: 
;*** EAX = page entry value
;*** ECX = number of pages which will be requested (just a hint for XMS)
;*** DS=GROUP16
;*** out: new value in EAX, inclusive flags (XMS/VCPI)
;*** physical page can come from following sources:
;*** - PTE at current location (page is committed!)
;*** - PTE at current location (previously committed page)
;*** - PTE from page pool (uncommitted page somewhere in address space)
;*** - XMS page from current XMS handle
;*** - XMS page from a new XMS handle
;*** - VCPI page
;*** modifies: ebx, eax, edx

	@ResetTrace

getphyspagex proc

	assume ds:GROUP16

	test al,PTF_PRESENT	;is page committed?
	jnz exit			;then we're done
	test ah,_XMSFLAG_	;is this a page from page pool?
	jz getphyspage		;if no, alloc a new page
	dec dwPagePool
if _LTRACE_
	jns @F
	@dprintf <"#getphyspagex: ERROR, dwPagePool < 0!, PTE=%lX, caller=%lX",lf>, eax, dword ptr [esp]
	@dprintf <"   pPageDir=%lX pPageTables=%lX",lf>, pPageDir, pPageTables
	@dprintf <"  pPageTab0=%lX  dwMaxOfsPT=%lX",lf>, pPageTab0, dwMaxOfsPT
	@dprintf <" dwPagePool=%lX   dwMaxPool=%lX",lf>, dwPagePool, dwMaxPool
	@dprintf <"edi=%lX",lf>, edi
@@:
endif
exit:
	ret
	align 4
getphyspagex endp

	@ResetTrace

;--- get one free physical page
;--- out: C if error
;--- ecx = hint for xms how much pages will be requested

getphyspage proc

	cmp dwPagePool,0		;free pages in page tables to be found?
	jz @F
	call scanpagepool
	jc @F
	dec dwPagePool
	@dprintfx ?LOG_PMGREXT,"getphyspage: PTE=%lX, dwPagePool=%lX, dwMaxPool=%lX", eax, dwPagePool, dwMaxPool
	ret
@@:

	@ResetTrace

	call getblockpage		;get page from current phys mem block
	jnc exit
	@dprintf "getphyspage: get page thru XMS"
	call getxmspage
	jnc exit
if ?VCPIALLOC
	test [fHost],FH_VCPI
	jz novcpimem
 if ?NOVCPIANDXMS
	test [fHost],FH_XMS	;using VCPI when XMS exists but fails
	jnz novcpimem		;seems to be unstable for many VCPI hosts
 endif
	@dprintf "getphyspage: try VCPI alloc"

	@ResetTrace

	@NMI_OFF
	mov ax,0DE04h			   ;1 page alloc VCPI
	call [vcpicall]
	@NMI_ON
	and ah,ah				   ;ok?
	jnz @F
	inc [dwVCPIPages]
	@dprintf "getphyspage: page %lX allocated thru VCPI, total=%lX", edx, dwVCPIPages
	mov eax,edx
	and ax,0F000h
	or ax,PTF_NORMAL + (_VCPIFLAG_*100h)
	ret
@@:
	@dprintf "getphyspage: VCPI alloc failed, ax=%X", ax

	@ResetTrace

novcpimem:
endif
	call getdospage
exit:
	@dprintfx ?LOG_PMGREXT,"getphyspage: exit, eax=%lX", eax
	ret
	align 4
getphyspage endp

;*** free PTE in eax
;*** DS=GROUP16
;*** returns modified PTE in EAX
;--- other registers preserved

	@ResetTrace

freephyspage proc

	test al,PTF_PRESENT		;committed?
	jz exit					;if not, do nothing
	test ah,_XMSFLAG_		;is it from XMS/I15/DOS?
	jz noxmspage	        ;no (VCPI or mapped)
	inc dwPagePool			;XMS/I15/DOS will be put in page pool
	and al, not PTF_PRESENT
	@dprintfxx ?LOG_PMGREXT,"freephyspage: PTE=%lX, dwPagePool=%lX, caller=%lX", eax, dwPagePool, dword ptr [esp]
exit:
	ret
	align 4
noxmspage:
if ?VCPIALLOC
	test ah,_VCPIFLAG_		;is it a vcpi page? 
	jz novcpipage

	@ResetTrace

	pushad
	mov edx,eax
	@NMI_OFF
	and dx,0F000h			;VCPI pages are freed instantly
	mov ax,0DE05h			;1 page free VCPI
	call [vcpicall]
	@NMI_ON
	and ah,ah				;ok?
	jnz @F
	dec [dwVCPIPages]
@@:
	@dprintf "freephyspage: free VCPI page %lX returned ax=%X, remaining %lX", edx, ax, dwVCPIPages
	popad
novcpipage:
endif
if 0
	xor eax, eax			;return 0 (value of new page entry 
else
	mov eax, PTF_NORMAL
endif
	ret
	align 4
freephyspage endp

;*** adress space handling

;*** mapPageTable: used to map a page table
;*** all page tables are mapped into linear address space FFC00000-FFFFFFFF
;*** after being mapped, the page table is cleared to zero
;*** IN: EAX=PTE for page table (will be stored in page map table)
;***     ESI=offset in sys area 1 [FFC00000] to store PTE)
;*** DS=GROUP16, ES=flat
;*** variables needed: pPageTables
;*** out: NC if successful, EDI = linear address of page (FFC00000-FFFFF000)
;*** modifies EDI, EDX
;--- error cannot happen, this case is checked before the call

	@ResetTrace

mapPageTable proc near

	push ecx
	mov edi, esi 			;now edi is offset to free area
	mov edx, pPageTables	;linear address of page table area
;	mov es:[edi+edx], eax	;set new page table in mapping page
	mov es:[edi+edx+?OFSMAPPAGE], eax	;set new page table in mapping page

if _LTRACE_
	lea edx, [edi+edx+?OFSMAPPAGE]
	@dprintfx ?LOG_PMGREXT,"mapPageTable: written %lX to %lX", eax, edx
endif

;--- now clear new page table

	shl edi, 10			;* 1024
	add edi, pPageTables

	@dprintfx ?LOG_PMGREXT, "mapPageTable: phys entry %lX mapped at %lX", eax, edi


	push edi
	push eax
	mov ecx,1000h/4			 ;clear the new page table
if 0
	xor eax,eax
else
	mov eax,PTF_NORMAL
endif
	rep stosd

	pop eax
	pop edi
	pop ecx
	clc
	ret
	align 4

mapPageTable endp


if 0
;--- return free address space in eax (pages)
;--- total address space in edx (pages)
;--- called by int 31h, ax=0500h
;--- ds=GROUP16

pm_getaddrspace proc public
	xor edx,edx			; 00000000h
	sub edx, pPageTab0
	sub edx, dwOfsPgTab0
	shr edx,2

	mov eax,400000h
	sub eax,dwMaxOfsPT
	shr eax,2
	ret
	align 4
pm_getaddrspace endp
endif

pm_getfreeuserspace proc public

;--- eax=start user space, ecx=length user space (pages)
	mov eax, dwOfsPgTab0
	shl eax, 10
	mov ecx, ?SYSAREA0
	sub ecx, eax
	shr ecx, 12
	ret
	align 4
pm_getfreeuserspace endp

;--- clear PDE in page dir
;--- if the page table is totally clear (4 MB)
;--- and doesn't contain pages for page pool,
;--- free physical memory (PTE in mapping page table)
;--- EDX=linear address of page tab
;--- BL=1 -> release PTE in page map table

	@ResetTrace

freepagetab proc

	pushad

;	@dprintf "freepagetab: PT=%lX, bx=%X, dwMaxPool=%lX", edx, bx, dwMaxPool
	mov esi, pPageTables	;linear address page tables
	mov edi, pPageDir

;--- check if page table is below dwMaxPool offset
;--- if yes, it cannot be released in page map region
	mov eax, dwMaxPool
	add eax, esi
	sbb eax, 0				;convert 00000000 to ffffffff
	cmp edx, eax			;is page used by pool?
	setnc al
	and bl,al

	sub edx, pPageTab0
	shr edx, 10 			;convert it to offset in page table

	xor eax, eax			;simply clear PDE in page dir
							;no need to free it, it is a double
	mov es:[edi+edx],eax


	cmp bl,1				;may page table be released in mapping area?
	jnz @F

	lea edi, [esi+edx+?SYSPGDIRAREA+?OFSMAPPAGE]

	mov eax,es:[edi]		;and free PTE in mapping pagetab
if _LTRACE_
	shl edx, 20
	@dprintfx ?LOG_PMGREXT,"freepagetab: release PTE=%lX at edi=%lX [region %lX]", eax, edi, edx
endif
	call freephyspage
	stosd
	sub edi, esi
	cmp edi, dwMaxPool
	jc @F
	mov dwMaxPool, edi
@@:
	popad
	ret
	align 4

freepagetab endp

if 0;def _DEBUG

;--- print page directory and mapping page

printpdpmp proc
	mov esi,pPageDir
	mov ecx,400h
	@dprintf "region   PDE      map page"
	@dprintf "--------------------------"
nextitem:
	lodsd es:[esi]
	lea edx, [esi-4]
	and edx, 0FFFh
	mov ebx, edx
	add ebx, ?SYSPGDIRAREA
	and ebx, 0FFFh
	add ebx, pPageTables
	mov ebx, es:[ebx+?OFSMAPPAGE]
	shl edx, 20
	mov edi, eax
	or edi, ebx
	test edi, PTF_PRESENT
	jz @F
	@dprintf "%lX %lX %lX", edx, eax, ebx
@@:
	loop nextitem
	ret
printpdpmp endp

endif

;--- free user address space
;--- IN: eax = linear address
;--- IN: ecx = pages
;--- ES=FLAT
;--- free entries in page directory and entries in page tables

	@ResetTrace

FreeUserAddrSpace proc

	pushad
	@dprintf "FreeUserAddrSpace: addr=%lX, size=%lX, dwMaxOfsPT=%lX, dwMaxPool=%lX", eax, ecx, dwMaxOfsPT, dwMaxPool

	call Linear2PT

	xor ebp, ebp
	mov edx, edi
	sub edx, pPageTables
	lea edx, [edx+ecx*4]
	cmp edx, dwMaxOfsPT	;is it the "last" space?
	jc @F
	sub edx, dwMaxOfsPT	;reduce size in ECX so it matches dwMaxOfsPT
	shr edx, 2
	sub ecx, edx
	mov eax, edi
	sub eax, pPageTables
	mov dwMaxOfsPT, eax	;set new, decreased dwMaxOfsPT
	inc ebp
@@:
	xor eax, eax
	xor edx, edx		;count entries in page table
	xor ebx, ebx
if _LTRACE_
	xor esi, esi
endif
	cmp ecx, eax
	jz exit

;--- clear entries in page table

nextpage:
	mov eax,es:[edi]		;this is always uncommitted memory
	test ah,_XMSFLAG_		;page pool item?
	jnz @F
	mov dword ptr es:[edi],0
	inc ebx
@@:
	add edi, 4
	inc edx
	test di, 0FFFh
	jnz @F
	cmp dh, 4				;all 400h pages in pagetab?
	jnz noclear
if _LTRACE_
	inc esi
endif
	cmp edx, ebx			;were all pages released?
	setz bl					;BL=1 if no PTE was in page pool 
	lea edx, [edi-1000h]
	call freepagetab
noclear:
	xor edx,edx
	xor ebx,ebx
@@:
	loop nextpage

	and ebp, ebp			;was it at the end?
	jz @F
	@dprintf "FreeUserAddrSpace: last page table entries: edi=%lX dx=%X bx=%X", edi, dx, bx
	mov eax, edi
	and ax, 0F000h
	sub edi, eax
	jz @F
	shr edi, 2				;PTEs in last page table
	cmp edi, edx
	jnz @F
	cmp edx, ebx
	setz bl
	mov edx, eax
	call freepagetab
@@:
	@dprintf "FreeUserAddrSpace: %X pages for page tables freed, dwMaxOfsPT=%lX, dwMaxPool=%lX", si, dwMaxOfsPT, dwMaxPool
if 0;def _DEBUG
	call printpdpmp
endif
if 1
	mov eax,cr3
	mov cr3,eax
endif
exit:
	popad
	ret
	align 4
FreeUserAddrSpace endp

;*** create user address space
;*** in: ECX=pages, EBX=linear address
;---     DS=GROUP16, ES=FLAT
;*** out: NC if successful, EAX=linear address, ECX preserved.
;*** C on error
;*** modifies EDI, ESI, EDX
;*** updates: dwMaxOfsPT
;--- 4 GB are 1.0000.0000/1000 == 100000 pages
;--- example (dwMaxOfsPT = 2440):
;--- 400000h - 2440 = 3FDBC0, SHR 2 = FF6F0 pages, FF6F0000h bytes

	@ResetTrace

CreateUserAddrSpace proc near

	assume ds:GROUP16

	@dprintf "CreateUserAddrSpace: request %lX pages at %lX", ecx, ebx

if 0
	mov edi,dwMaxOfsPT		;max offset so far used in SYSAREA1
;--- if ebx==0, use dwMaxOfsPT
;--- currently not used!
	and ebx, ebx
	jz @F
endif

	mov eax, ebx
	shr eax, 10
	and al, 0FCh
	add eax, ?SYSPGDIRAREA * 400h
	mov edi, eax
	sub eax, dwMaxOfsPT		;is the address below dwMaxOfsPT?
	jbe @F
	shr eax, 2				;if no, create more space to avoid "holes"    
	add ecx, eax
	mov edi, dwMaxOfsPT
@@:
	@dprintf "CreateUserAddrSpace: dwMaxOfsPT=%lX, ecx=%lX edi=%lX", dwMaxOfsPT, ecx, edi

	mov eax, 400000h
	sub eax, edi
	shr eax, 2				;remaining free pages
	cmp ecx, eax
	ja error
	add edi, pPageTables

	push ebx
	push ecx
	push edi
	cld
nextpage:
	test di,0FFFh			;start of a new page table?
	jz newpagetab
donenewpagetab:
if 0	;v3.19: don't read the page tables, just update EDI
	mov eax,es:[edi]
	test al,PTF_PRESENT
	jnz @F
	mov al,PTF_NORMAL
;	@dprintf "CreateUserAddrSpace: mem page at %lX",edi
@@:
	stosd					;save PTE in page table
else
	add edi,sizeof dword
endif
	dec ecx
	jnz nextpage
	sub edi, pPageTables
	cmp edi, dwMaxOfsPT
	jb @F
	mov dwMaxOfsPT,edi
@@:
	pop edx
	pop ecx
	pop eax
	@dprintf "CreateUserAddrSpace: new addrspace generated: addr=%lX, size=%lX, edi=%lX", eax, ecx, edi
	clc
	ret

newpagetab:

;--- convert PTE pointer EDI to offset in PT of SYSAREA1 (mapped page tables)
;--- example:
;--- addr 400000 -> EDI=FFC03000
;--- subtract FFC00000 = 3000
;--- shr 10 = 0C
;--- load PTE of FFC00000+0C

	mov esi,edi
	mov edx, pPageTables
	sub esi,edx
	shr esi,10					;1000h -> 004, 2000h -> 8
;	mov eax,es:[esi+edx]		;get current PDE
	mov eax,es:[esi+edx+?OFSMAPPAGE]	;get current PDE
	test al,PTF_PRESENT			;is page table mapped ( SYSAREA 1, page 1)?
	jnz @F

;--- set ECX (is just a "hint" parameter for XMS mem alloc)

	push ecx
	mov ecx,[esp+8]				; address space pages
	shr ecx,10					; 1024 pages -> 1 page table
	inc ecx
	call getphyspagex			;get a page for new page table
	pop ecx

	jc error2
	and al,0F8h
	or al, ?PAGETABLEATTR
	call mapPageTable			;and map page table in SYSAREA 1
@@:
	mov edx, pPageDir			;get pointer to current PDE
	mov es:[edx+esi-?SYSPGDIRAREA],eax	;set PDE in page dir
	jmp donenewpagetab

error2:
	pop edi 					;get Max PageTab ptr
	mov eax, ecx
	mov ecx,[esp]				;total size in pages
	@dprintf "CreateUserAddrSpace: alloc %lX pages failed at %lX", ecx, eax
	sub ecx, eax				;subtract pages not allocated so far
	mov eax, edi
	sub eax, pPageTab0
	shl eax,10
	call FreeUserAddrSpace
	pop ecx
	pop ebx
error:
	stc
	ret
	align 4

CreateUserAddrSpace endp


if ?DPMI10

	@ResetTrace

;--- get page entry attributes to es:edx
;--- ebx = linear address
;--- ecx = size in pages (may be 0)
;--- attributes (WORD):
;--- bit 0+1: 00=uncommitted, 01=committed, 02=mapped
;--- bit 3: writable
;--- bit 4: bit 5+6 valid (accessed+dirty)
;--- it's ensured by the caller that the region is valid.
;--- DS modified to flat.

pm_getpageattributes proc public
	@dprintf "getpageattributes: lin addr %lX - copy %lX attr to %lX:%lX",ebx, ecx, es, edx
	mov eax, ebx
	call Linear2PT
	push byte ptr _FLATSEL_
	pop ds
	mov esi, edi
	mov edi, edx
	jecxz done
	cld
nextitem:
	lodsd
	mov edx, eax
	mov al, 10h 			;accessed + dirty supplied
	test dl, PTF_WRITEABLE
	setnz ah
	shl ah,3
	or al, ah
	and dl, PTF_DIRTY or PTF_ACCESSED or PTF_PRESENT
	or al, dl
	test al,PTF_PRESENT
	jz @F
	test dh,_XMSFLAG_ or _VCPIFLAG_
	setz ah
	add al,ah	;for mapped pages, convert committed (01) to mapped (02)
	mov ah,0
@@:
	stosw
	loopd nextitem
done:
	clc
exit:
	ret
	align 4
pm_getpageattributes endp

if 0

	@ResetTrace

;--- test BX:CX region, size SI:DI
;--- AX=bits whose value will be set (mask), dx=new value of bits

;--- this is for DPMI functions 06xx and 07xx

pm_setregionattributes proc public
	pushad
	push bx
	push cx
	pop eax		;start in eax
	push si
	push di
	pop ecx		;size in ECX
	@dprintf "setregionattributes: addr %lX, size %lX", eax, ecx
	add ecx, eax
	jc exit		;overflow
	test dh,80h	;80h=1 -> include partial pages
	jnz @F
	add eax,1000h-1	;align to next page boundary
	jmp noal1
@@:
	add ecx,1000h-1	;align to next page boundary
noal1:
	and ax,0F000h
	and cx,0F000h
	sub ecx, eax
	jbe exit
	shr ecx, 12		;get no of pages in ecx

	@dprintf "setregionattributes, adjusted: addr %lX, size(pg) %lX", eax, ecx

	call Linear2PT	;get PTE address in EDI
	push byte ptr _FLATSEL_
	pop ds
	mov esi, edi
	push ecx
@@:
	lodsd
	test al,PTF_PRESENT
	loopnzd @B
	pop ecx
	stc
	jz exit	;at least one page is not committed
	mov esi, edi
	mov bx, [esp+1Ch]
	xor bx, -1
	or bh, 0F0h
	and dh, 0F0h
@@:
	lodsd
	and ax, bx
	or ax, dx
	mov [esi-4],eax
	loopd @B
exit:
	popad
	ret
	align 4
pm_setregionattributes endp

endif

;--- make region readonly
;--- eax=linear address
;--- ecx=pages

pm_makeregionreadonly proc public
	pushad
	call Linear2PT
@@:
	and byte ptr es:[edi],not PTF_WRITEABLE
	add edi,4
	loop @B
	mov ebx,[esp].PUSHADS.rEAX
	mov ecx,[esp].PUSHADS.rECX
	call updatetlb
	popad
	ret
pm_makeregionreadonly endp

;--- clear tlb for linear address EBX, size ECX pages

updatetlb proc
if ?USEINVLPG
	cmp ecx,10		;it's faster to avoid INVLPG for 10+ pages
	jnc noinvlpg
	test ss:[gbl.fMode2],FM2_NOINVLPG	;option -g or cpu=80386?
	jnz noinvlpg
	push ds
	push byte ptr _FLATSEL_
	pop ds
@@:
	invlpg ds:[ebx]
	add ebx, 1000h
	loopd @B
	pop ds
	ret
noinvlpg:
endif
	mov eax, cr3
	mov cr3, eax
	ret
	align 4
updatetlb endp

;--- int 31h, ax=0507: set page entry attributes
;--- ebx = linear address
;--- ecx = size in pages
;--- es:edx -> table of WORDS with attributes for each page
;--- all std registers + DS, but not ES may be modified here
;--- out: NC = ok
;--- C = failure, AX=error code (8013: out of mem, 8021: wrong page type)

;--- valid attributes are:
;--- bits 0-2: page type
;---  000b: change page to uncommitted
;---  001b: change page to committed
;---  011b: modify attributes without changing page type;
;---  anything else is invalid and should terminate the function.
;--- bit 3: 0=r/o, 1=r/w
;--- bit 4: 0=don't modify acc/dirty bits, 1=modify acc/dirty bits

	@ResetTrace

pm_setpageattributes proc public
	@dprintf "setpageattr: lin addr %lX - copy %lX attr from %lX:%lX",ebx, ecx, es, edx
	mov eax, ebx
	call Linear2PT
	push byte ptr _FLATSEL_
	pop ds
	mov esi, edx
	mov ebp, ecx
nextitem:
	and ecx, ecx
	jz done
	mov ax, es:[esi]
	inc esi
	inc esi
	mov edx,[edi]		;get PTE
	push ss
	pop ds

	mov ah,al
;--- 0=uncommitted, 1=committed, 3=modify bits 3-6 only, 2|4|5|6|7=invalid
	and al,7
	jz uncommit
	cmp al,3
	jz step1
	cmp al,1
	jnz error8021

commit:
	test dh, _XMSFLAG_ or _VCPIFLAG_; v3.22: page "mapped"?
	jz @F				; then change it to "committed"
	test dl, PTF_PRESENT
	jnz step1			;else done if page is already committed
@@:
	push ecx
	push eax
	mov eax, edx
	and al, not PTF_PRESENT	;v3.22 (clear bit in case it's a mapped page)
	call getphyspagex	;expects in ECX a hint for XMS block size
	mov edx, eax
	pop eax
	pop ecx
	jc error8013		;error, out of physical pages!
	@dprintf "setpageattr: page %lX [old=%lX] committed [pt=%lX]",eax, edx, edi
	or dl, PTF_PRESENT or PTF_USER
	jmp step1

uncommit:
	test dl,PTF_PRESENT
	jz step1			;jump if it is already uncommitted
	push eax
if _LTRACE_
	mov eax, edi
	push ecx
	call PT2Linear
	pop ecx
	@dprintf "setpageattr: page %lX, lin addr=%lX uncommitted [pt=%lX]",edx, eax, edi
endif
	mov  eax, edx
	call freephyspage
	lea edx, [edi+4]
	sub edx, ss:pPageTables
	cmp edx, ss:dwMaxPool
	jc @F
	mov ss:dwMaxPool, edx
@@:
	mov edx, eax
	pop eax

step1:
	mov al, ah
	and dl, not PTF_WRITEABLE
	test al, 8 
	jz @F
	or dl, PTF_WRITEABLE
@@:
	test al,10h 			;accessed + dirty bits supplied
	jz @F
	and dl, not (PTF_ACCESSED or PTF_DIRTY)
	and al,PTF_ACCESSED or PTF_DIRTY
	or dl, al
@@:
	push byte ptr _FLATSEL_
	pop ds
	mov [edi], edx
	add edi, 4
	dec ecx
	jmp nextitem
done:
	mov ecx, ebp
	jecxz @F		;v3.21 check added
	call updatetlb
@@:
	clc
exit:
	ret
error8013:
	mov al, 13h
	jmp @F
error8021:
	mov al, 21h
@@:
	mov ah, 80h
	sub ebp, ecx
	mov ecx, ebp	;return pages changed in ECX
	stc
	ret
	align 4

pm_setpageattributes endp

endif

;-------------------------------------------------------

;*** get user address space
;*** RC: C on errors
;*** Inp: ECX = #pages
;---      ebx = linear address
;*** out: EAX=linear address
;--- DS=GROUP16

pm_AllocUserSpace proc public

	push es
	pushad
	push byte ptr _FLATSEL_
	pop es
	call CreateUserAddrSpace
	jc @F
	mov [esp].PUSHADS.rEAX, eax
@@:
	popad
	pop es
	ret
	align 4
pm_AllocUserSpace endp

;--- this functions is called by _freeclientmemory()
;--- if the full client space is free.
;*** In: EAX linear address
;*** In: ECX num pages

pm_FreeUserSpace proc public

	push es
	pushad
	push byte ptr _FLATSEL_
	pop es
	call FreeUserAddrSpace
	popad
	pop es
	ret
	align 4
pm_FreeUserSpace endp

	@ResetTrace

;--- commit region u/ser, r/w and p/resent

pm_CommitRegion proc near public
	mov dl,PTF_PRESENT or PTF_WRITEABLE or PTF_USER
pm_CommitRegion endp	;fall throu

;*** commit a region
;--- IN: EAX=linear addr
;---     ECX=size in pages
;---      DL=page flags
;--- modifies ES (=FLAT)

commitblockx proc near
	pushad
	push byte ptr _FLATSEL_
	pop es
	call Linear2PT
	@dprintf "commitblockx: alloc %lX pages at %lX, ptr PTE=%lX",ecx,eax,edi
nextpage:						;<---- commit next page
	mov eax,es:[edi]
	push edx
	call getphyspagex	;expects in ECX a hint for XMS block size
	pop edx
	jc error
if _LTRACE_
	test cx,0FFFh
	jnz @F
	@dprintf "commitblockx: commit page %lX at %lX, remaining %lX", eax, edi, ecx
@@:
endif
;	and al,098h 		;reset DIRTY, ACCESSED, SYS, WRIT, PRES
	and al,not (PTF_DIRTY or PTF_ACCESSED or PTF_USER or PTF_WRITEABLE or PTF_PRESENT)
	or al,dl
	stosd
	dec ecx
	jnz nextpage
	clc
exit:
	popad
	ret
error:
	@dprintf "commitblockx: alloc failed, remaining %lX pages, dwMaxPool=%lX",ecx, ss:dwMaxPool
	mov eax, ecx
	mov ecx, [esp].PUSHADS.rECX
	sub ecx, eax
	jecxz error_done
	mov eax, edi
	sub eax, ss:pPageTables
	cmp eax, ss:dwMaxPool
	jc @F
	mov ss:dwMaxPool,eax
@@:
	sub edi,4
	mov eax,es:[edi]
	call freephyspage
	mov es:[edi], eax
	loopd @B
error_done:
	@dprintf "commitblockx: alloc failed, dwMaxPool=%lX",ss:dwMaxPool
	stc
	jmp exit
	align 4
commitblockx endp

;*** uncommit memory region
;*** EAX=linear address, ECX=size in pages
;--- eax, ecx, edx modified

pm_UncommitRegion proc public
	jecxz exit
	mov edx, eax			;save linear address begin
	push es
	push byte ptr _FLATSEL_
	pop es
	@dprintf "UncommitRegion enter: freeing %lX pages at %lX, dwMaxPool=%lX, dwPagePool=%lX",ecx,eax,ss:dwMaxPool,ss:dwPagePool
	call Linear2PT
	push ebx
	push ecx
	mov ebx,ss:dwMaxPool
	add ebx,ss:pPageTables
nextpage:
	mov eax,es:[edi]
	call freephyspage
	test ah,_XMSFLAG_
	stosd
	jz @F
	mov ebx, edi
@@:
	loopd nextpage
	sub ebx, ss:pPageTables
	cmp ebx, ss:dwMaxPool
	jc @F
	mov ss:dwMaxPool,ebx
@@:
	@dprintf "UncommitRegion exit: dwMaxPool=%lX, dwPagePool=%lX",ss:dwMaxPool,ss:dwPagePool
	pop ecx
	mov ebx, edx
	call updatetlb
	pop ebx
	pop es
exit:
	ret
	align 4

pm_UncommitRegion endp

;--- move PTEs from one block to another
;--- eax = lin addr of old block
;--- edx = lin addr of new block
;--- ecx = size in pages (may be 0)

pm_MovePTEs proc public uses es esi edi ebx
	push byte ptr _FLATSEL_
	pop es
	@dprintf "MovePTEs: mov %lX pages from %lX to %lX",ecx,eax,edx
	push eax
	push ecx

	call Linear2PT
	mov esi, edi
	mov eax, edx
	call Linear2PT
	push ds

	push es
	pop ds
	push esi
	push ecx
	rep movsd
	pop ecx
	pop edi

;--- clear PTEs in src block
	pop ds
	mov eax, PTF_NORMAL
	rep stosd

	pop ecx
	pop ebx
	call updatetlb
;	@dprintf "MovePTEs: exit"
	ret
	align 4
pm_MovePTEs endp

	@ResetTrace

;*** dl=flags,eax=lin addr, ecx=pages ***

pm_CommitRegionZeroFill proc public

	push es
	@dprintf "CommitRegionZeroFill: addr=%lX, size=%lX", eax, ecx
	call commitblockx	;will set es to FLAT, other regs unchanged
	jc @F
	cld
	pushad
	mov edi,eax
	xor eax,eax
	@dprintf "CommitRegionZeroFill: addr=%lX, size=%lX", edi, ecx
	shl ecx,10
	rep stosd
	popad
@@:
	pop es
	ret
	align 4
pm_CommitRegionZeroFill endp

;--- allocate address space in system region 0
;--- cannot be freed anymore
;--- IN: ECX pages
;--- OUT: EAX=linear address

	@ResetTrace

pm_AllocSysAddrSpace proc public
	mov eax, SysAddrUp
	shl ecx,12
	add ecx, eax
	cmp SysAddrDown, ecx
	jc error
	mov SysAddrUp, ecx
	@dprintf "AllocSysAddrSpace: block %lX, SysAddrUp/Dn=%lX/%lX", eax, SysAddrUp, SysAddrDown
error:
	ret
	align 4
pm_AllocSysAddrSpace endp

if 0
;--- not really useful, since if WP bit is set,
;--- we cant do anything with such pages.
;--- so alloc pages with pm_AllocSysPages, fill them
;--- and then make them r/o!

;--- alloc pages with attr p/resent, r/o, u/ser
;*** IN: ECX pages, DS=GROUP16
;--- OUT: EAX=Addr

pm_AllocSysPagesRo proc public
	mov dl,PTF_PRESENT or PTF_USER
	jmp AllocSysPages_Common
	align 4
pm_AllocSysPagesRo endp
endif

;--- alloc ecx pages with attr p/resent, r/w, s/ystem

pm_AllocSysPagesS proc public
	mov dl,PTF_PRESENT or PTF_WRITEABLE
	jmp AllocSysPages_Common
	align 4
pm_AllocSysPagesS endp

;--- alloc ecx pages with attr p/resent, r/w, u/ser
;--- return linear address in EAX

pm_AllocSysPagesU proc public
	mov dl,PTF_PRESENT or PTF_WRITEABLE or PTF_USER
AllocSysPages_Common::
	push SysAddrUp
	push ecx
	call pm_AllocSysAddrSpace	;allocate address space
	pop ecx
	jc error
	call pm_CommitRegionZeroFill;first do a commit
	jc error					;no more memory
	add esp,4
	ret
error:
	pop SysAddrUp
	ret
	align 4
pm_AllocSysPagesU endp

if ?USESYSSPACE2
pm_AllocSysPagesDn proc public
	mov edx, ecx
	shl edx, 12
	mov eax, SysAddrDown
	sub eax, edx
	cmp eax, SysAddrUp
	jb error
	mov dl,PTF_PRESENT or PTF_WRITEABLE
;	call pm_CommitRegion;alloc pages u/ser, r/w
	call commitblockx	;alloc pages s/ystem, r/w
	jc error
	mov SysAddrDown, eax
error:
	ret
	align 4
pm_AllocSysPagesDn endp

;--- free system region, eax=linear addr, ecx=pages
;--- out: nothing?

pm_FreeSysPagesDn proc public
	push ecx
	push eax
	call pm_UncommitRegion
	pop eax
	pop ecx
	cmp eax, SysAddrDown
	jnz @F
	mov edx,ecx
	shl edx,12
	@dprintf "pm_FreeSysPagesDn: update SysAddrDown, %lX + %lX", SysAddrDown, edx
	add SysAddrDown,edx
@@:
	ret
	align 4
pm_FreeSysPagesDn endp
endif

;*** destructor routines Page Manager PM

if ?FREEVCPIPAGES

;--- free VCPI pages in a memory block
;--- either free them directly or copy them to host stack
;--- inp: ESI -> PTE
;---      EDI -> host stack
;---      ECX = cnt pages

	@ResetTrace

freememblock proc

	jecxz exit
nextitem:
	mov eax, es:[esi]
	test al,1
	jz skipitem
	test ah,_VCPIFLAG_
	jz skipitem
	@dprintf "freememblock: free page %lX at %lX", eax, esi
	test bl,1
	jz @F
	call freephyspage
	mov es:[esi],eax
	jmp skipitem
@@:
if ?HSINEXTMEM
	mov es:[edi+ebp], eax
else
	mov [edi], eax
endif
	add edi, 4
skipitem:
	add esi, 4
	loopd nextitem
exit:
	ret
	align 4
freememblock endp

;--- DS=GROUP16

	@ResetTrace

FreeVCPIPages proc uses esi

	test fHost,FH_VCPI
	jz exit
	cld
	push byte ptr _FLATSEL_
	pop es

	@dprintf "FreeVCPIPages: entry, di=%X", di

;--- copy system region FF800000 pages to host stack

	mov bl,0

	mov esi, pPageTables
;	add esi, 1000h	;v3.19: page tables for SYSAREA0 are now mapped at pPageTables+0

	mov ecx, 400h
	@dprintf "FreeVCPIPages: free sys space=%lX, entries=%lX", esi, ecx
	call freememblock

;--- free mapped page tables FFC00000 pages 

	mov bl,1

	mov esi, pPageTables
	add esi, ?OFSMAPPAGE	;v3.19: page tables for SYSAREA1 are now mapped at pPageTables+1000h
if 1
	lea esi, [esi+3*4]
	mov ecx, 400h-3
else
	lea esi, [esi+2*4]
	mov ecx, 400h-2
endif
	@dprintf "FreeVCPIPages: free sys space=%lX, entries=%lX", esi, ecx
	call freememblock

;--- free anything from 004-FF8 in page dir

	mov esi, pPageDir			;linear address page dir
	lea esi, [esi+4]
	mov ecx,400h-3
	@dprintf "FreeVCPIPages: free page tables in page dir %lX, entries=%lX", esi, ecx
	call freememblock

;--- copy the rest to host stack

	mov bl,0

	mov esi, pPageDir			;linear address page dir
	mov ecx,400h
	call freememblock

	@dprintf "FreeVCPIPages: exit, di=%X", di
exit:
	ret
	align 4

FreeVCPIPages endp

endif

if ?SETPTE

;--- set a PTE for a linear address
;--- edx=linear address
;--- eax=new PTE
;--- DS=GROUP16, ES=FLAT
;--- returns the old PTE in eax

	@ResetTrace

pm_SetPage proc public
	pushad
	@dprintf "SetPage: edx=%lX, eax=%lX", edx, eax
	mov eax, edx
	call Linear2PT		;convert address in EAX to ptr PTE in EDI
	mov eax, [esp].PUSHADS.rEAX
	xchg eax, es:[edi]	;set the new PTE
	mov [esp].PUSHADS.rEAX, eax
	mov ecx, 1
	mov ebx, edx
	call updatetlb
exit:
	popad
	ret
	align 4
pm_SetPage endp

endif

;--- inp: edx=linear address to copy from
;---      ecx=pages to clone; that's just a hint,
;---          always 1 page will be cloned.
;--- DS=GROUP16, ES=FLAT
;--- out: C=error 
;--- eax=(new) destination PTE
;--- ecx=(old) source PTE

_ClonePage proc
	push edi
	push eax
	mov eax, edx
	call Linear2PT
	pop eax
ifdef ?PE
	test byte ptr es:[edi],PTF_WRITEABLE
	jnz @F
else
	test byte ptr es:[edi],PTF_DIRTY
	jnz @F
endif
	mov eax, es:[edi]
	mov ecx, eax
	and ax, 0F000h or PTF_PRESENT or PTF_USER
	@dprintf "ClonePage: addr=%lX, just PTE=%lX copied", edx, eax
ifndef _DEBUG
error1:
endif
	pop edi
	ret
ifdef _DEBUG
error1:
	@dprintf "ClonePage: addr=%lX, Linear2PT() failed", edx
	pop edi
	ret
endif
@@:
	pop edi
	push edx
	push ebx
	call getphyspage	;get a free PTE
	pop ebx
	pop edx
	jc error
	@dprintf "ClonePage: addr=%lX, new PTE=%lX", edx, eax
	call CopyPageContent
	@dprintf "ClonePage: dest PTE=%lX, src PTE=%lX", eax, ecx
error:
	ret
	align 4
_ClonePage endp

;--- edx=linear address of source to copy from
;--- eax=new PTE to copy to

;--- out: eax=(new) PTE, where content has been copied to
;---      edx=(old) PTE, where content has been copied from

	@ResetTrace

CopyPageContent proc
	pushad
	cld
	mov ebx, eax
	mov esi, edx

;--- map the dest PTE

	or bl,PTF_PRESENT
;--- map the page in first entry of sysarea 0
	mov es:[?PTSYSAREA0], ebx
	mov edi, ?SYSAREA0

	push ds

;--- copy page content

	push es
	pop ds
	mov ecx, 1000h/4
	rep movsd

;--- get current PTE

	mov eax, edx
	call Linear2PT
	mov eax, es:[edi]

if 0
;--- set new PTE
	mov [esp+4].PUSHADS.rEAX, eax
	and al,PTF_PRESENT or PTF_WRITEABLE or PTF_USER
	and bl, not (PTF_PRESENT or PTF_WRITEABLE or PTF_USER)
	or bl,al
	mov es:[edi],ebx
else
	mov [esp+4].PUSHADS.rECX, eax	;v3.18: return old PTE in ecx
	and al,PTF_PRESENT or PTF_WRITEABLE or PTF_USER
	or byte ptr [esp+4].PUSHADS.rEAX, al
endif

;--- update TLB

	xor ecx, ecx
	mov es:[?PTSYSAREA0],ecx
	inc ecx
	mov ebx, ?SYSAREA0
	call updatetlb
if 0
	mov ecx, 1
	lea ebx, [esi-1000h]
	call updatetlb
endif
	pop ds
	popad
	clc
	ret
	align 4
CopyPageContent endp


if ?FREEXMSDYN

;--- check the committed (XMS) pages if at least one is
;--- contained in current block. If no, release block + clear PTEs in pool.
;--- called by pm_exitclient.

	@ResetTrace

compresspagepool proc

	push es
	push byte ptr _FLATSEL_
	pop es
if _LTRACE_
	mov edx, PhysBlk.dwSize
	sub edx, PhysBlk.dwFree		;edx=pages allocated
	shl edx, 12
	add edx, PhysBlk.dwBase
	@dprintf "compresspagepool: blk base=%lX, size=%lX, free=%lX, nxt free=%lX", PhysBlk.dwBase, PhysBlk.dwSize, PhysBlk.dwFree, edx
	@dprintf "compresspagepool: dwMaxPool=%lX, dwPagePool=%lX, dwMaxOfsPT=%lX", dwMaxPool, dwPagePool, dwMaxOfsPT
endif
nextblock:
	call compresspool
	mov edx, PhysBlk.dwBase
	mov ebx, PhysBlk.dwSize
	sub ebx, PhysBlk.dwFree
	shl ebx, 12
	add ebx, edx
	mov ecx, dwMaxOfsPT
	mov edi, pPageTables
	add ecx, edi
nextitem:
	cmp edi, ecx
	jz blockisfree
	mov eax, es:[edi]
	add edi, 4
	test al,PTF_PRESENT
	jz nextitem
	test ah,_XMSFLAG_
	jz nextitem
	cmp eax, edx	;> lower limit?
	jc nextitem
	cmp eax, ebx	;< upper limit?
	jnc nextitem
;--- the page is in use, but in may be just because of the page pool
;--- this could possibly be "ignored"
	@dprintf "compresspagepool: PTE %lX in use at %lX", eax, edi

	lea ebp, [edi-4]
	mov esi, pPageTables
	lea esi, [esi+1000h];check if page is an entry in mapping page (FFC00000-FFC00FFF)
	cmp ebp, esi
	jnc scandone		;no, so it can't be for page pool -> abort

	mov esi, dwMaxOfsPT
;	sub esi, pPageTables
	shr esi, 10
	add esi, ?SYSPGDIRAREA
	and si, 0FFFCh
	add esi, pPageTables
	cmp ebp, esi
	jc scandone
	call getpoolpage		;get a pool page, but not from current block!
	jc scandone
	@dprintf "compresspagepool: weak usage %lX %lX", ebp, eax
	mov esi, eax
	mov eax, ebp
	push edx
	push ecx
	call PT2Linear		;modifies ECX
	mov edx, eax
	mov eax, es:[esi]
	mov ecx, eax
	call CopyPageContent	;copy 1 Page of linear addr EDX to PTE in EAX

	mov ecx, es:[ebp]
	or al, PTF_PRESENT	;the new PTE must be set
	mov es:[ebp], eax
	and cl, not PTF_PRESENT
	mov es:[esi], ecx	;save the old PTE in the pool
if 1
	push ebx
	mov ebx, edx
	mov ecx, 1
	call updatetlb
	pop ebx
endif
	pop ecx
	pop edx
	jmp nextitem
blockisfree:
	cmp dwPagePool,0
	jz @F
	mov eax, dwMaxPool
	add eax, pPageTables
	cmp ecx, eax
	jnc @F
	mov ecx, eax
@@:
	mov edi, pPageTables
nextitem2:
	cmp edi, ecx
	jz blockdone
	mov eax, es:[edi]
	add edi, 4
	test ah, _XMSFLAG_
	jz nextitem2
	cmp eax, edx
	jc nextitem2
	cmp eax, ebx
	jnc nextitem2
	mov dword ptr es:[edi-4], PTF_NORMAL
	dec dwPagePool
if _LTRACE_
	jns @F
	@dprintf "compresspagepool: page pool cnt %lX < 0", dwPagePool
@@:
endif
	jmp nextitem2
blockdone:
	@dprintf "compresspagepool: release current PHYSBLK"
	mov eax, offset PhysBlk
	call freephyshandle
	call setactivephyshandle
	test PhysBlk.bFlags, PBF_XMS
	jnz nextblock
scandone:
if _LTRACE_
	mov edx, PhysBlk.dwSize
	sub edx, PhysBlk.dwFree		;edx=pages allocated
	shl edx, 12
	add edx, PhysBlk.dwBase
	@dprintf "compresspagepool: blk base=%lX, size=%lX, free=%lX, nxt free=%lX", PhysBlk.dwBase, PhysBlk.dwSize, PhysBlk.dwFree, edx
	@dprintf "compresspagepool: dwMaxPool=%lX, dwPagePool=%lX, dwMaxOfsPT=%lX", dwMaxPool, dwPagePool, dwMaxOfsPT
endif
	pop es
	ret
	align 4

compresspool:
	cld
	mov esi, dwMaxOfsPT
	mov ecx, dwMaxPool
	sub ecx, esi
	jc cpdone
	shr ecx, 2
	add esi, pPageTables
	@dprintf "compresspool start: esi=%lX (bottom), ecx=%lX PTEs", esi, ecx
	mov edi, esi
@@:
	jecxz @F
	mov eax, es:[esi]
	add esi, 4
	dec ecx
	test ah,_XMSFLAG_
	jz @B
	add edi, 4
	cmp edi, esi
	jz @B
	@dprintfx ?LOG_PMGREXT,"compresspool: pool entry %lX at %lX", eax, edi
	mov dword ptr es:[esi-4],PTF_NORMAL
	mov es:[edi-4], eax
	jmp @B
@@:
	mov esi, pPageTables
	sub edi, esi
	@dprintf "compresspool: dwMaxPool old/new=%lX/%lX", dwMaxPool, edi
	mov dwMaxPool, edi

;--- the top of the pool has been adjusted
;--- now free all PTEs in the mapping page (FFC01xxx)
;--- which are beyond the new pool top
;--- example:
; edi=FFC02444h : sub edi,esi
; edi= 2444h      shr edi, 10
; edi= 09h        add edi,?SYSPGDIRAREA
; edi= 11h        and di,0fffch
; edi= 10h        lea edi,[edi+esi+4+1000h]
; edi=FFC01014

	shr edi, 10
	add edi, ?SYSPGDIRAREA
	and di, 0FFFCh
	lea edi, [edi+esi+4+?OFSMAPPAGE]
	lea esi, [esi+?OFSMAPPAGE+1000h]
	@dprintf "compresspool: free PTEs start/end=%lX/%lX", edi, esi
@@:
	cmp edi, esi
	jz cpdone
	mov eax, es:[edi]
	test al,PTF_PRESENT
	jz cpdone
	call freephyspage
	stosd
	jmp @B
cpdone:
if 1
	mov eax, cr3
	mov cr3, eax
endif
	retn

	align 4

;--- get a page from pool, but not from current block
;--- (current block in edx - ebx)
;--- return not the PTE itself but its address in EAX

getpoolpage:
	pushad
	mov edi, pPageTables
	mov ecx, dwMaxPool
	add ecx, edi
	add edi, dwMaxOfsPT
@@:
	cmp edi, ecx
	jnc noppfound
	mov eax, es:[edi]
	add edi, 4
	test ah, _XMSFLAG_
	jz @B
	cmp eax, edx
	jc ppfound
	cmp eax, ebx
	jc @B
ppfound:
	lea eax, [edi-4]
	mov [esp].PUSHADS.rEAX, eax
	popad
	clc
	retn
noppfound:
	popad
	stc
	retn
	align 4
compresspagepool endp

endif

;--- client has terminated. If DOS memory has been
;--- used by pagemgr, release as much of it as possible 
;--- in: EBX->PHYSBLK for a DOS memory block

compressdosmem proc uses es

	push byte ptr _FLATSEL_
	pop es
	mov esi, pPageTables
	mov ecx, dwMaxOfsPT
	add ecx, esi

	mov edx,[ebx].PHYSBLK.dwBase
	mov edi,[ebx].PHYSBLK.dwSize
	sub edi,[ebx].PHYSBLK.dwFree
	shl edi,12	;now edi = mem of this block that is used
	add edi,edx	;edi = end of the used mem block

nextitem:
	cmp esi, ecx
	jnc blockfree		;block is done
	mov eax,es:[esi]
	add esi,4
	test ah,_XMSFLAG_	;page belongs to DOS/XMS/I15?
	jz nextitem
	cmp eax, edx		;page in block range?
	jc nextitem
	cmp eax, edi
	jnc nextitem
	test al,PTF_PRESENT	;page allocated?
	jz nextitem
	ret					;done, there's still a page of this block used
blockfree:
	mov esi, pPageTables
	mov ecx, dwMaxPool
	add ecx, esi
nextitem2:
	cmp esi, ecx
	jnc done
	mov eax,es:[esi]
	add esi,4
	test ah,_XMSFLAG_	;page belongs to DOS/XMS/I15?
	jz nextitem2
	cmp eax, edx		;page in block range?
	jc nextitem2
	cmp eax, edi
	jnc nextitem2
	mov dword ptr es:[esi-4], PTF_NORMAL	;release page
	dec dwPagePool		;update page pool
if _LTRACE_
	jns @F
	@dprintf "compressdosmem: page pool cnt %lX < 0", dwPagePool
@@:
endif
	jmp nextitem2
done:
	mov eax, ebx
	call freephyshandle	;free the block handle
	ret
	align 4
compressdosmem endp

;*** client termination
;*** memory has been released already
;*** physical memory and address space could be cleaned here

	@ResetTrace

pm_exitclient proc public

	assume ds:GROUP16

	pushad
	cld
	@dprintf "pm_exitclient enter"
	mov ebx, offset PhysBlk
nextblock:
	@dprintf "pm_exitclient, PhysBlk: base=%lX, size=%lX, free=%lX, handle=%lX",\
		[ebx].PHYSBLK.dwBase, [ebx].PHYSBLK.dwSize, [ebx].PHYSBLK.dwFree, [ebx].PHYSBLK.dwHandle
	test [ebx].PHYSBLK.bFlags, PBF_DOS
	jz @F
	call compressdosmem
@@:
	mov ebx, [ebx].PHYSBLK.pNext
	and ebx, ebx
	jnz nextblock
	call setactivephyshandle

if ?FREEXMSDYN
	cmp gbl.cApps,1				;this is before it is decremented
	jnz notidle
	test gbl.fMode, FM_RESIDENT
	jz notidle				;host will exiting soon, do nothing
	test PhysBlk.bFlags,PBF_XMS
	jz notidle				;no XMS block, cannot be released
	call compresspagepool
notidle:
endif
	@dprintf "pm_exitclient: dwMaxOfsPT=%lX, dwMaxPool=%lX, dwPagePool=%lX", dwMaxOfsPT, dwMaxPool, dwPagePool
	popad
	ret
	align 4
pm_exitclient endp

	@ResetTrace

	assume ds:GROUP16

;--- inp: DS=GROUP16, ES=FLAT
;--- preserves general registers
;--- TLB might be released already!

pm_exit_pm proc public
	pushad
	@dprintf "pm_exit_pm enter"
;------------------ save all XMS handles on stack *before* freeing memory
	@dprintf "pm_exit_pm: start save xms handles on host stack"
if ?HSINEXTMEM
	movzx ebp, [wHostPSP]
	shl ebp,4
	mov esi, 5ch
else
	mov esi, offset stacktop
endif
;	mov ebx,[pPhysBlkList]
	mov ebx, offset PhysBlk
nextitem:
	and ebx,ebx
	jz xmsdone
if 1
	test [ebx].PHYSBLK.bFlags, PBF_DOS
	jz @F
	mov eax, ebx
	call freephyshandle
@@: 
endif
	test [ebx].PHYSBLK.bFlags, PBF_XMS
	jz skipitem
	mov ax,[ebx].PHYSBLK.wHandle
if ?HSINEXTMEM
	mov es:[esi+ebp],ax
else
	mov [esi],ax
endif
	@dprintf "pm_exit_pm: xms handle %X saved",ax
	inc esi
	inc esi
skipitem:
	mov ebx,[ebx].PHYSBLK.pNext
	jmp nextitem
xmsdone:
	@dprintf "pm_exit_pm: done save xms handles on host stack"
if ?FREEXMSINRM
	mov pXMSHdls,si
  if ?FREEVCPIPAGES
;---- VCPI pages have to be freed in real-mode as well
;---- because the pages are freed with XMS.
	@dprintf "pm_exit_pm: call FreeVCPIPages"
	mov edi, esi
	call FreeVCPIPages
	mov pVCPIPages, di
  endif
endif
ife ?FREEXMSINRM
	@dprintf "pm_exit_pm: free xms memory blocks"
nextitem2:
	cmp esi,esp
	jz @F
	pop dx
	@dprintf "pm_exit_pm: free xms block %X, rm ss:sp=%X:%X",dx,ss:v86iret.rSS, ss:v86iret.rSP

	pushd offset freexms
	call callrmprocintern
	jmp nextitem2
@@:
endif
if ?FREEPDIRPM
	@dprintf "pm_exit_pm: restore cr3"
	mov eax,[orgcr3]
	mov cr3,eax
	xchg eax,[v86topm._cr3]
	@dprintf "pm_exit_pm: free cr3 page"
;	mov ax,[cr3flgs]
	call freephyspage
endif
if ?VCPIALLOC
	@dprintf "pm_exit_pm: VCPI pages allocated on pm exit=%lX",dwVCPIPages
endif
	@dprintf "pm_exit_pm: exit"
	popad
	ret
	align 4
pm_exit_pm endp

if 0

;*** free some physical memory if in i15 mode
;--- used to allow nested execution of clients
;--- since v3.18, this is handled differently:
;--- Int 15h, ax=e801h will return the full PhysBlk.dwFree
;--- amount. It is assumed that the launching app
;--- does NOT allocate any memory while the child is running
;--- missing: a cleanup to adjust the free amount of memory
;--- returned by Int 15h after a client has terminated.
;--- simple solution: do the cleanup when the gbl.cApps counter 
;--- goes to zero and the host is resident.

pm_freeI15mem proc public
	test ss:[fHost], FH_XMS or FH_VCPI
	jnz exit
	push eax
	mov eax, ss:[dwResI15Pgs]
	and eax, eax
	jnz @F
	mov eax, ss:PhysBlk.dwFree
	shr eax, 1
	mov ss:[dwResI15Pgs], eax
	@dprintf "freeI15mem: pages released for int 15h,ax=e801h: %lX", eax
@@:
	sub ss:PhysBlk.dwFree, eax
	pop eax
exit:
	ret
	align 4
pm_freeI15mem endp

;--- called after a int21, ax=4b00 in i21srvr.asm

pm_restoreI15mem proc public
	test ss:[fHost], FH_XMS or FH_VCPI
	jnz exit
	push eax
	xor eax, eax
	xchg eax, ss:[dwResI15Pgs]
	add ss:PhysBlk.dwFree, eax
	@dprintf "restoreI15mem: pages restored: %lX, now free: %lX", eax, ss:PhysBlk.dwFree
	pop eax
exit:
	ret
	align 4
pm_restoreI15mem endp

endif

;--- clone 32-bit code & data
;--- inp: eax=0 -> create first VM
;---      else eax -> dest where copied PTEs are stored
;--- ES=FLAT, DS=GROUP16
;--- out: EAX=linear address of destination block

	@ResetTrace

pm_CloneGroup32 proc public

ifdef ?PE
	mov ecx, dwVSize
	sub ecx, 1000h
else
	mov ecx, offset endoftext32
endif
	@dprintf "pm_CloneGroup32: alloc %lX bytes 32bit code+data", ecx

;	mov edx, ecx
;	shr ecx, 12
;	test dx,0FFFh
;	jz @F
;	inc ecx
;@@:
	add ecx,1000h-1
	shr ecx,12

	and eax, eax
	jz isfirst
	mov edi, eax
	mov edx, SysAddrUp
	@dprintf "pm_CloneGroup32: source %lX, dest=%lX, pg=%lX", edx, edi, ecx
@@:
	push ecx
	call _ClonePage
	pop ecx
	jc error
	@dprintf "pm_CloneGroup32: %lX cloned, PTE=%lX", edx, eax
	stosd
	add edx,1000h
	mov SysAddrUp, edx
	loop @B
	@dprintf "pm_CloneGroup32 done, last PTE=%lX, ppt=%lX", eax, edi
	ret
isfirst:
	call pm_AllocSysPagesU		;alloc pages for GROUP32
	jc error
	@dprintf "pm_CloneGroup32: copying code to extended memory"
	mov edi, eax
;	push ds
;	push cs
;	pop ds
	push ecx
ifdef ?PE
	mov esi, 1000h
	mov ecx, dwVSize
	sub ecx, esi
else
	xor esi, esi
	mov ecx, offset endoftext32
endif
	shr ecx, 2
	rep movsd es:[edi],cs:[esi]
	pop ecx
;	pop ds
ifdef ?PE
	sub ecx,2	;the last 2 pages get special flags
endif
	call Linear2PT	;get PTE ptr in edi
@@:
ifdef ?PE
	and byte ptr es:[edi],not (PTF_DIRTY or PTF_ACCESSED or PTF_USER or PTF_WRITEABLE)
else
	and byte ptr es:[edi],not (PTF_DIRTY or PTF_ACCESSED or PTF_USER)
endif
	add edi,4
	loop @B
ifdef ?PE
	and byte ptr es:[edi],not (PTF_DIRTY or PTF_ACCESSED or PTF_USER)
	and byte ptr es:[edi+4],not (PTF_DIRTY or PTF_ACCESSED)
endif
	clc
error:
	ret
	align 4
pm_CloneGroup32 endp

;*** create a VM
;--- inp: DS=GROUP16, ES=FLAT
;--- all registers preserved

;--- for the very first VM, the real-mode setup has initialized a minimal 
;--- system with paging enabled. CR3 is set and PDE 000 as well. page
;--- table 0 is allocated and valid, variable pPageTab0 is initialized.
;--- variable PhysBlk contains a valid physical memory block, with enough
;--- physical pages (?PAGEMIN) for a full setup:

;---  1 page   page dir
;--- +3 pages  page tables 0, FF8, FFC
;--- +1 page   pm breaks 
;--- +1 page   GDT + IDT
;--- +1 page   LDT
;--- +1 page   LPMS
;--- +2 pages  client save state ( since v3.18, it's actually 1 page only )
;----------------------------------
;    10 pages
;--- +7 pages  GROUP32 if code is moved high
;

;--- now paging will be fully initialized:
;--- 1. alloc 4 physical pages and map them temporarily at 3FC000-3FFFFF;
;---    3FC000=SA0, 3FD000=SA1, 3FE000=PT0, 3FF000=PD
;--- 2. clear the page contents
;--- 3. copy content of page tab 0 to 3FE000
;--- 4. copy PDEs 000, FF8 and FFC to 3FFxxx (temp. mapped new pagedir)
;--- 5. restore content of old pagetab 0
;--- 6. test if this is the very first VM. If no, copy content of
;---    FFC00000+1000 to 3FC000 (PTEs for system area 0). This
;---    will make GROUP32, GDT, and IDT accessible after CR3 has been
;---    switched.
;--- 7. set new CR3
;--- 8. copy PTE for pagedir to FFC00FFCh (maps new page dir at FFBFFxxx)

;*** variables already set (will be set again):
;*** v86topm._cr3: CR3
;*** obsolete --- pPageDir:   lin  address page dir
;*** pPagesTab0: lin  address page tab 0

;*** new variables set:
;*** obsolete --- pPageTables:lin  address page tables (=FFC00000)
;*** dwMaxOfsPT: offset within SYSAREA1, next entry in cur. page table

?TEMPBASE	equ 3FC000h	;linear address of page tables for new VM in
						;current VM (valid just temporarily inside here)

	@ResetTrace

pm_createvm proc public

	assume ds:GROUP16

	pushad
	@dprintf "pm_createvm enter"
	@dprintf "pm_createvm: cr3=%lX pPageDir=%lX pPageTab0=%lX", v86topm._cr3, pPageDir, pPageTab0

;--- global variables may (and "should") be set here. The host instance has been
;--- switched already in case it isn't the very first VM.

	mov SysAddrUp, ?SYSAREA0 + 1000h
	mov SysAddrDown, ?SYSAREA1 - 1000h

	test gbl.fMode, FM_CLONE	;dont clear the PhysBlk var
	jz noinit				;for the first instance

	mov edx, offset startvdata
	xor eax, eax
@@:
	mov [edx], eax
	add edx, 4
	cmp edx, offset endvdata
	jb @B

	test fHost, FH_XMS or FH_VCPI
	jnz noinit
	call pm_alloci15
	jc noinit
	@dprintf "pm_createvm: I15 mem start=%lX, size=%lX", edx, eax
	mov PhysBlk.bFlags, PBF_I15 or PBF_TOPDOWN
	mov PhysBlk.dwBase, edx
	mov PhysBlk.dwSize, eax
	mov PhysBlk.dwFree, eax

noinit:
if ?FREEPDIRPM
	mov eax, v86topm._cr3
	mov orgcr3, eax
endif

;--- make sure that there's enough free physical pages to satisfy the creation

	invoke pm_GetNumPhysPages
	@dprintf "pm_createvm: free/total phys pages: %lX/%lX", eax, edx
	cmp eax, 10
	jc exit

;--- alloc 4 physical pages for pagedir, system areas and pagetab 0;
;--- map the pages at ?TEMPBASE;
;--- save old PTEs onto the stack.

	mov edi, pPageTab0
	add di, ?TEMPBASE shr 10	;this is offset of PTEs for 3FC000-3FF000

	@dprintf "pm_createvm: alloc 4 physical pages"
	xor ecx,ecx
@@:
	call getphyspage
	jc errorx		;errors shouldn't happen here, but to be safe...
	and al, 0F8h
	or al, ?PAGETABLEATTR
	xchg eax,es:[edi+ecx*4] 
	push eax
	inc ecx
	cmp cl,4
	jnz @B

;--- in "safe" mode, don't allow access to SYSAREA1 (page table mapping region)
	test bEnvFlags2,ENVF2_SYSPROT
	jz @F
	and byte ptr es:[edi+1*4],not PTF_USER
@@:

;--- update the tlb!
	mov eax,cr3
	mov cr3,eax

;--- clear content of new pages
	cld
	mov edi, ?TEMPBASE
	push edi
	mov cx, 4000h/4
	xor eax, eax
	rep stosd
	pop edi

;--- now clone old pagetab 0
;--- the new pages mapped at 3FC000h are intended to be used:
;--- 3FC000 -> PT of 4 MB region FF8xxxxx (system area 0)
;--- 3FD000 -> PT of 4 MB region FFCxxxxx (system area 1)
;--- 3FE000 -> PT of 4 MB region 000xxxxx (page table 0)
;--- 3FF000 -> page directory

?SA0OFS equ 0 shl 12	;offset added to ?TEMPBASE
?SA1OFS equ 1 shl 12
?PT0OFS equ 2 shl 12
?PDOFS	equ 3 shl 12

;--- the PTE copy must be done in the first 4MB (pagetab 0), because for the very
;--- first VM, there is no other address space available

	@dprintf "pm_createvm: copy PTEs from previous PT0, dwOfs=%lX", dwOfsPgTab0

	lea ebx, [edi + ?PDOFS]	;mapped new page dir
	lea edi, [edi + ?PT0OFS];new page tab 0
	mov esi, pPageTab0
	push edi
	push esi
	mov ecx, dwOfsPgTab0	;just copy the PTEs which are global (=conv. memory)!
	shr ecx, 2
	rep movsd es:[edi],es:[esi]
	pop esi
	pop edi

;--- store the original, saved 4 PTEs in new PT0
;--- todo: explain why - this should only be done if dwOfsPgTab0 is > 2FF0h!
;--- see test case i315046!!!

;	mov eax, 0FF0h
	mov eax, ?TEMPBASE shr 10	; shr 10 = convert linear address to PTE offset
	add edi, eax
	add esi, eax	;let esi point to PTE for 3FC000h
	mov cl,4
@@:
if 0
	pop eax
	stosd
	loop @B
endif
;--- v3.22, fixed: store PTEs in the correct order!
	mov eax, [esp+ecx*4-4]
	stosd
	loop @B
	add esp, 4*4

	test [bEnvFlags2],ENVF2_HMAMAPPING
	jz nohmamapping
;--- reinit region 100000-10FFFF
	sub edi,300h*4
if ?DOSPGLOBAL
	mov eax,100000h or PTF_PRESENT or PTF_WRITEABLE or PTF_USER or PTF_GLOBAL
else
	mov eax,100000h or PTF_PRESENT or PTF_WRITEABLE or PTF_USER
endif
	mov cl,10h
@@:
	stosd
	add eax,1000h
	loopd @B
nohmamapping:

;--- setup new page directory (ebx)
;--- what's done here?
;--- 1. store mapped page tables in cloned PT0
	push es
	pop ds

	mov edi, ?TEMPBASE+?SA1OFS
	lodsd				;get PDE for SA0 (= 3FC000 )
	stosd
	mov [ebx+?SYSTEMSPACE+0],eax
	@dprintf "pm_createvm: new PDE for FF800000=%lX",eax

	lodsd				;get PDE for SA1 (= 3FD000 )
if 0
;--- protect page mapping region FFC00000h. drawback: slows-down host
	and al,not PTF_USER
endif
	stosd
	mov [ebx+?SYSTEMSPACE+4],eax
	@dprintf "pm_createvm: new PDE for FFC00000=%lX",eax

	lodsd				;get PDE for PT0 (= 3FE000 )
	stosd
	mov [ebx+0000h],eax
	@dprintf "pm_createvm: new PDE for 00000000=%lX",eax

	lodsd				;get PTE for mapped PD
	mov ebx, eax

	mov esi, ss:pdGDT.dwBase
	test ss:gbl.fMode, FM_CLONE
	jz isfirst

	mov eax,?TEMPBASE + ?SA0OFS + 4h  ;PTE for FF801000h
	push ss
	pop ds
	call pm_CloneGroup32

;--- copy PTEs of saved instance data to new address context
;--- so it will be mapped at the very same linear address
;--- but do clear the _VCPIFLAG_ and _XMSFLAG_ flags in the PTEs,
;--- so the physical pages won't be released by the clone.
;--- Also, make them r/o.

	mov eax, ltaskaddr
	call Linear2PT
	mov esi, edi
	sub edi, ?PTSYSAREA0
	add edi, ?TEMPBASE + ?SA0OFS
	push es
	pop ds
	mov cl,2	;assume the data are 2 pages (to be improved).
@@:
	lodsd
	and ah,not (_VCPIFLAG_ or _XMSFLAG_)
	and al,not (PTF_DIRTY or PTF_ACCESSED or PTF_WRITEABLE)
	stosd
	dec cl
	jnz @B

;;	@dprintf "pm: snapshot PTEs: %lX %lX", dword ptr [edi-8], dword ptr [edi-4]
;	sub ss:SysAddrDown,2000h
isfirst:

;--- restore PTEs for 3FC000-3FFFFF in old pagetab 0;
;--- clear them in cloned pagetab 0.

;	mov esi, ?TEMPBASE + ?PT0OFS + 0FF0h	;esi -> PTEs for 3FC000h
	mov esi, ?TEMPBASE + ?PT0OFS + ( ?TEMPBASE shr 10 )	;esi -> PTEs for 3FC000h
	mov edi, ss:pPageTab0
;	add di, 0FF0h
	add di, ?TEMPBASE shr 10
	xor ecx,ecx
	movsd
	mov [esi-4],ecx
	movsd
	mov [esi-4],ecx
	lodsd				;dont use movsd to copy the last 2 entries.
	mov [esi-4],ecx
	push eax			;it is page table 0 + pagedir, VMware doesnt
	lodsd				;like that and will emit an exc 0E
	mov [esi-4],ecx
	xchg eax, [esp]
	stosd
	pop eax
	stosd

;--- done, the temp changes in current VM are undone,
;--- the new VM is ready to be used, just set CR3

	push ss
	pop ds
	assume ds:GROUP16
	mov eax, ebx

	and ax,0F000h
if ?NOCR3CACHE
	or al,18h	;set PWT & PCD
endif
	mov v86topm._cr3, eax
if ?FREEPDIRPM
;	push eax
;	or al,?PAGETABLEATTR
;	mov [cr3flgs],ax
;	pop eax
endif

;--- the new tables are set, CR3 can be reloaded now

	@dprintf "pm_createvm: will set CR3 to %lX",eax
	mov cr3,eax
	@dprintf "pm_createvm: new value for CR3 set"

;--- v3.19: reset user bit for mapped page dir;
;--- prevents this linaddr to be found by pm_searchphysregion (int 31h, ax=800h)
	and bl,NOT PTF_USER

	@dprintf "pm_createvm: page dir mapped at %lX", ?PTSYSAREA0+0FFCh
	mov es:[?PTSYSAREA0 + 0FFCh], ebx	; map page dir at FFBFF000h

;--- now reinit pPageTab0

	mov pPageTab0, ?SYSAREA1 + ?SYSPGDIRAREA * 400h

;--- init some important variables

;	mov pPageTables, ?SYSAREA1

	@dprintf "pm_createvm:  pPageTab0=%lX,   pPageDir=%lX, pPageTables=%lX", pPageTab0, pPageDir, pPageTables
	@dprintf "pm_createvm: dwPagePool=%lX,  dwMaxPool=%lX", dwPagePool, dwMaxPool

if ?CLEARACCBIT
	@dprintf "pm_createvm: clear accessed+dirty bits in region 0-10FFFF"
	mov ecx,110h
	mov edi, pPageTab0
@@:
	and byte ptr es:[edi],09Fh
  ifdef _DEBUG
	mov eax,es:[edi]
	and al,7
	.if (al != 7)
		@dprintf "pm_createvm: invalid PTE at %lX: %lX !!!",edi,eax
	.endif
  endif
	add edi,4
	loop @B
endif

;--- init the vm's user address space

	mov esi, ?SYSPGDIRAREA * 400h	;offset pt 0 within pagetables
	add esi, dwOfsPgTab0
;;	add esi, 32				;if a security buffer is needed
	mov dwMaxOfsPT, esi
	@dprintf "pm_createvm: dwMaxOfsPT=%lX, SysAddrUp=%lX, SysAddrDown=%lX", dwMaxOfsPT, SysAddrUp, SysAddrDown

	@dprintf "pm_createvm exit"
	clc
exit:
	popad
	ret

;--- out of memory error (shouldn't happen)
;--- restore the PTEs in pagetab 0, offset 0FF0h
@@:
	pop dword ptr es:[edi+ecx*4]
errorx:
	dec ecx
	jge @B
	stc
	popad
	ret
	align 4

pm_createvm endp

if ?VM

;--- this code is called only in raw mode, if FM_CLONE is set;
;--- that is, HDPMI=32 is set and the second (or more)
;--- client is launched.
;--- it's a questionable strategy to call real-mode here, since
;--- we should be able to get the info from the parent host directly
;--- returns EAX=size of mem block
;---         EDX=linear address of block

pm_alloci15 proc near
	@dprintf "pm_alloci15: int 15h, ax=E801"
	mov ax,0E801h
	stc
	@simrmint 15h
	jc e801_err
	@dprintf "pm_alloci15: int 15h, ax=E801 ok, 1M-16M=%X,%X >16M=%X,%X", ax, cx, bx, dx
	and ax, ax
	jnz @F
	mov ax, cx
	mov bx, dx
@@:
	cmp ax, 3C00h+1	;max is 3C00h (15360 kB)
	jnc e801_err
	movzx eax, ax
	shr ax, 2		;kb -> pages
	movzx ebx, bx
	shl ebx, 4		;64kb -> pages 
	add eax, ebx
	@dprintf "pm_alloci15: pages=%lX", eax
	mov edx,100000h
	clc
	ret
e801_err:
	@dprintf "pm_alloci15: int 15h,ax=E801h failed"
	stc
	ret
	align 4

pm_alloci15 endp

endif

;*** XMS has only a limited number of handles to be allocated
;*** OTOH we don't want to grap all of extended memory
;*** so a strategy is required:
;*** 1. b1 = _max(EMB/16,512kb)
;*** 2. b2 = _max(b1,req. Block)
;*** 3. b3 = _min(b2,max. Block)
;*** inp: eax=free xms pages returned by XMS
;***      edx=max block, returned by XMS
;***      ecx=pages requested
;*** out: eax size of block to request

getbestxmssize proc
;	mov ebx,eax 		;largest block -> ebx
	mov ebx,edx 		;largest block -> ebx
if ?XMSBLOCKCNT
	push ecx
	mov cl,[bXMSBlocks]
	cmp cl,24+1
	jnc @F
	shr cl,3			;0->0, 8->1, 16->2	24->3
	neg cl				;0->0,	 -1,	-2	   -3
	add cl,4			;	4	  3 	 2		1
	shr eax,cl			;largest block / (16|8|4|2)
@@:
	pop ecx
else
	shr eax,4
endif
	cmp eax,80h			;below 128 pages (512 kB)?
	jae @F
	mov al,80h			;min is 512 kB
@@:
	cmp eax,ecx 		;is req block larger?
	jae @F
	mov eax,ecx 		;then use this amount
@@:
	cmp eax,ebx 		;is this larger than max emb?
	jb @F
	mov eax,ebx 		;then use max emb
@@:
	ret
	align 4
getbestxmssize endp


_TEXT32  ends

_TEXT16 segment


	@ResetTrace

;*** int 15 rm routine, called for ah=88h or ax=e801h in raw mode.
;--- for ah=88h -> return in ax free extended memory in kB
;--- for ax=E801h -> return in ax ext. memory below 16 M in kB (usually 15360)
;--- return in bx extended memory above 16 M (64 kB blocks)

;--- this works because the host allocs physical pages from top to bottom in
;--- this mode

pm_int15rm proc public
	push ecx

;--- since v3.18, there is no longer a part of the memory
;--- "released" and regained, since this didn't really work.
;--- now the one physical block is kept for all VMs.
;	mov ecx, cs:[dwResI15Pgs]
	mov ecx, cs:PhysBlk.dwFree

if ?TRAPI15E801	;intercept int 15h, ax=e801h?
	cmp ah, 0E8h
	jz i15e801
endif
	cmp ecx, 0FFC0h shr 2	;less than 63 MB free?
	mov ax, cx
	pop ecx
	jb @F
	mov ax, 0FFC0h 			;report 63 MB ext mem
	ret
@@:
	shl ax,2				;pages -> kb
	ret
if ?TRAPI15E801
i15e801:
;--- to return: AX/CX ext. memory between 1M-16MB in kB (max 15360)
;--- to return: BX/DX ext. memory above 16MB in 64kB blocks
	@drprintf "pm_int15rm, ax=e801h: free pages=%lX", ecx
	mov ax, 15360
	cmp ecx, 15360 shr 2	;less than 15 MB free? (ecx is pages, not kB!)
	jnc @F
	mov ax, cx
	shl ax, 2				;pages -> kB
	xor bx, bx				;nothing above 16M
	jmp done

@@:
	sub ecx, 15360 shr 2	;subtract 15 MB (in pages)
	shr ecx, 4				;convert 4k-pages to 64k-blocks
	mov bx, cx
done:
	pop ecx
	mov cx, ax				;return the values in CX/DX as well
	mov dx, bx
	ret
endif
pm_int15rm endp

if ?I15MEMMGR	;this is 0

;--- set int15 pages to free by server, edx=pages to free
;--- obsolete

pm_seti15pages proc near
	mov eax,cs:PhysBlk.dwFree ;return size in eax
	sub edx,cs:[dwResI15Pgs]  ;don't count the already reserved pages
	jc set15_1				  ;size shrinks
	cmp eax,edx 			  ;size too large
	jb @F
set15_1:
	sub cs:PhysBlk.dwFree,edx
	add cs:[dwResI15Pgs],edx
	clc
	ret
@@:
	stc
	ret
pm_seti15pages endp

endif

;*** get memory block from XMS
;*** in: EDX=size of block to request in kB
;---      AH=XMS alloc function (09h or 89h)
;*** Out: if error, Carry + error code in BL, else
;*** EDX=physical address
;*** BX=XMS handle

	@ResetTrace

allocxms_rm proc near

	@drprintf "allocxms: try to alloc %lX kb XMS mem,ax=%X",edx,ax 
	call cs:[xmsaddr]
	and ax,ax
	jz allocxmserr1
	@drprintf "allocxms: EMB allocated, handle=%X",dx
	push dx
	mov ah,0Ch		;lock EMB
	call cs:[xmsaddr]
	and ax,ax
	jnz exit
;--- lock error. to be absolutely safe, the EMB should be released here,
;--- but it's very unlikely that this case ever happens.
	@drprintf "allocxms: lock EMB failed, handle=%X", dx
allocxmserr1:		;alloc error
	@drprintf "allocxms: unable to alloc XMS memory, error=%X, sp=%X", bx, sp
	stc
exit:
	push dx
	push bx
	pop edx 		;physical address -> edx
	pop bx
	ret
allocxms_rm endp

;*** free XMS memory handle
;--- DX = xms memory handle
;--- may modify BX

freexms proc near
	mov ah,0Dh					;unlock EMB
	call cs:[xmsaddr]
	mov ah,0Ah					;free EMB
callxms::
	@drprintf "callxms: AX=%X",ax
	call cs:[xmsaddr]
	ret
freexms endp

	@ResetTrace

;--- DS=GROUP16

pm_exit_rm proc public

if _LTRACE_
	nop
	@drprintf "pm_exit_rm enter"
;	@waitesckey
endif

	@drprintf "pm_exit_rm: pVCPIPages=%X, pXMSHdls=%X", pVCPIPages, pXMSHdls
if ?FREEVCPIPAGES

if ?HSINEXTMEM
	mov es,wHostPSP
endif

	mov si, pVCPIPages
nextitem:
	cmp si, pXMSHdls
	jz vcpidone
	sub si, 4
if ?HSINEXTMEM
	mov edx,es:[si]
else
	mov edx,[si]
endif
	and dx,0F000h
	mov ax,0DE05h
	int 67h
if _LTRACE_
	and ah,ah
	jz @F
	@drprintf "pm_exit_rm: free VCPI page %lX returned ax=%X", edx, ax
@@:
endif
	and ah,ah
	jnz nextitem
	dec dwVCPIPages
	@drprintf "pm_exit_rm: free VCPI page %lX returned ax=%X, remaining %lX", edx, ax, dwVCPIPages
	jmp nextitem
vcpidone:
else
	mov si, pXMSHdls
endif
nextitem2:
if ?HSINEXTMEM
	cmp si, 5Ch
else
	cmp si, offset stacktop
endif
	jbe xmsdone
	dec si
	dec si
if ?HSINEXTMEM
	mov dx,es:[si]
else
	mov dx,[si]
endif
	@drprintf "pm_exit_rm: free XMS handle %X", dx
	call freexms
	jmp nextitem2
xmsdone:
if 0
	test PhysBlk.bFlags, PBF_DOS
	jz @F
	mov es,PhysBlk.wHandle
	@drprintf "pm_exit_rm: free DOS mem block %X",es
	mov ah,49h
	int 21h
@@:
endif
	@drprintf "pm_exit_rm: done, sp=%X",sp
	ret
pm_exit_rm endp

_TEXT16 ends

;*** initialization

_ITEXT16 segment

	@ResetTrace

E820MAP struct
baselow  dd ?
basehigh dd ?
lenlow   dd ?
lenhigh  dd ?
type_    dd ?
E820MAP ends

;*** no XMS/VCPI host detected, try Int15 alloc
;*** Out: EAX=number of free pages
;*** Out: EDX=phys. addr of block
;--- all std regs may be modified

alloci15rm proc near
;	mov cl, 0	;???
if ?USEE820
	push bp
	@drprintf "alloci15rm: int 15h, ax=E820"
	xor ebx, ebx
	xor esi, esi
	sub sp, sizeof E820MAP
	mov di, sp
	push ss
	pop es
nextitem:
	mov ecx, sizeof E820MAP
	mov edx,"SMAP"
	mov eax,0E820h
	int 15h
;	jc done_e820
	cmp eax,"SMAP"
	jnz done_e820
	cmp es:[di].E820MAP.type_, 1;type "available"?
	jnz skipitem
	cmp word ptr es:[di].E820MAP.basehigh, 0	;beyond 4 GB?
	jnz skipitem
	cmp es:[di].E820MAP.baselow, 100000h		;base above 1 MB?
	jb skipitem
	mov eax, es:[di].E820MAP.lenlow
	shr eax, 12 		;bytes -> pages
	cmp eax,esi
	jc @F
	mov esi,eax
	mov ebp,es:[di].E820MAP.baselow
	@drprintf "alloci15rm, ax=e820: available memory, base=%lX, size=%lX pg", ebp, esi
@@:
skipitem:
	and ebx, ebx
	jnz nextitem
done_e820:
	mov eax, esi
	mov edx, ebp
	add sp, sizeof E820MAP
	pop bp
	and eax, eax
	jnz exit
endif
if ?USEE801
	@drprintf "alloci15rm: int 15h, ax=E801"
	clc
	mov ax,0E801h
	int 15h
	jc e801_err
	@drprintf "alloci15rm, ax=E801: ok, ax-dx=%X %X %X %X", ax, bx, cx, dx
	and ax, ax
	jnz @F
	mov ax, cx
	mov bx, dx
@@:
	;--- max value in AX "should" be 3C00h, but there are "providers"
	;--- that return FFC0 instead ( i.e. GRUB2 )
	cmp ax, 3C00h+1	;max is 3C00h (15360 kB)
	jnc e801_err
	movzx eax, ax
	shr ax, 2		;kb -> pages
	movzx ebx, bx
	shl ebx, 4		;64kb -> pages 
	add eax, ebx
	@drprintf "alloci15rm: pages=%lX", eax
	jmp done
e801_err:
endif
	@drprintf "alloci15rm: int 15, ah=88h"
	clc
	mov ah,88h				;get extended memory size (kB)
	int 15h
	jc exit
	@drprintf "alloci15rm: Int 15 extended memory size=%X",ax
	movzx eax, ax
	shr ax,2				;kb -> pages
done:
	mov edx,100000h
	clc
exit:
	ret

alloci15rm endp

;--- get physical address of linear address in 1. MB
;--- inp: eax = linear address
;--- out: edx = physical address

getphysaddr_rm proc
	mov edx,eax
	test [fHost],FH_VCPI
	jz exit
	push cx
	push eax
	shr eax,12				;get physical address from VCPI
	mov cx,ax				;inp: page number in CX
	mov ax,0DE06h
	int 67h
	and dl,0F8h				;clear R/O, USER, PRESENT bits
	pop eax
	pop cx
exit:
	ret
getphysaddr_rm endp

;*** init page table 0 for the first 4 MB in DOS memory
;--- behind this table (which starts at a page boundary
;--- will be space for at least 4 PDEs in page dir.
;*** it's temporary until we are in protected mode
;--- and will be changed in initserver_pm
;--- in: DS=GROUP16
;--- out: EAX = linear address page table 0
;--- modifies ES

	@ResetTrace

initpagetab0 proc

	@drprintf "initpagetab0: try to alloc 2000h bytes conv. memory"
	mov bx, 200h		;2 pages (8 kB), needed are 1004h bytes
	mov ah, 48h
	int 21h
	jc error
	mov word ptr taskseg._ES,ax	;save it here, will be released soon
	@drprintf "initpagetab0: DOS memory alloc for page tabs ok (%X)",ax

;--- now shrink the memory so it fits exactly

	mov es,ax
	mov ah,1            ;2 full pages
	neg al				;+ page align the memory
	inc ax				;+ 1 paragraph
	mov bx,ax
	mov ah,4Ah
	int 21h
if 0	;igore shrink failure
	jc error
	@drprintf "initpagetab0: DOS memory realloc for page tabs ok (%X)",bx
endif
	mov ax,es
	add ax,100h-1
	mov al,00
	@drprintf "initpagetab0: page tab start %X",ax
	mov es,ax
	movzx eax,ax
	shl eax,4
	mov pPageTab0, eax
	call getphysaddr_rm		;get physical address (PDE) of PT0 in edx
	@drprintf "initpagetab0: pPageTab0=%lX [PDE=%lX]", eax, edx
	or dl,PTF_PRESENT or PTF_NORMAL
	assume es:SEG16
	mov es:[1000h+000],edx	;set PDE for pagetab0 in page dir
	add eax,1000h
;--- v3.19: pPageDir is a constant now
;	mov pPageDir, eax
	call getphysaddr_rm
	mov v86topm._cr3, edx	;CR3 will be modified later
	@drprintf "initpagetab0: pPageDir=%lX [CR3=%lX]", eax, edx

;--- init page table 0:
;--- 000000-10FFFF: phys=linear 
;--- 110000-3FFFFF: NULL
	xor di,di
	mov cx,440h/4
	xor eax,eax
if ?DOSPGLOBAL
	or ax,PTF_PRESENT or PTF_USER or PTF_WRITEABLE or PTF_GLOBAL
else
	or al,PTF_PRESENT or PTF_USER or PTF_WRITEABLE
endif
	cld
@@:
	stosd
	add eax,1000h
	loop @B
	mov cx,(1000h-440h)/4	;init rest of tab0
	xor eax,eax
	rep stosd
	@drprintf "initpagetab0: initialization pagetab0 done"
	xor di,di
	test [fHost],FH_VCPI
	jz @F

;--- get VCPI protected-mode interface
;--- ds:si = pointer to 3 descriptors in GDT
;--- es:di = page table 0
	mov si,offset vcpidesc
	mov ax,0DE01h			;get protected mode interface
	int 67h
	cmp ah,00				;returns in DI=first free entry
	stc 					;in pagetab 0
	jnz error
	mov [vcpiOfs],ebx		;entry VCPI host
	@drprintf "initpagetab0: get VCPI protected mode interface ok (%lX,%X)",ebx,di
@@:
;--- v3.18: ensure 1 uncommitted page exists between DOS memory
;--- and host memory
	cmp di,444h 			;never go below linear addr 111000h 
	jnb @F
	mov di,444h
@@:
	mov word ptr dwOfsPgTab0,di	;first free entry in page table 0
	clc
error:
	ret
initpagetab0 endp

if ?INT15XMS

	@ResetTrace

getunmanagedmem proc
	@drprintf "getunmanagedmem: enter"

;--- a 2.0 host cannot handle more than 65535 kb extended memory
;--- that would give highest address:
;--- FFFF * 400 -> 3FFFC00 + 100000h -> 40FFC00 - 1 -> 40FFBFF
;--- but usually HMA is not included in this calculation:
;--- FFFF * 400 -> 3FFFC00 + 110000h -> 410FC00 - 1 -> 410FBFF
;--- to be sure, round up to the next page: 410FFFF

	mov ecx,0410FFFFh
	test [fHost],FH_XMS30	;xms driver 3.0+?
	jz @F
	mov ah, fXMSQuery
	call [xmsaddr]
	cmp ecx,110000h
	jb error
	mov ax,cx
	and ah,03h
	cmp ax,03FFh
	jnz error
@@:
	@drprintf "getunmanagedmem: highest address=%lX", ecx
	push ecx		
	call alloci15rm
	pop ecx
	@drprintf "getunmanagedmem: int 15h base=%lX, size=%lX", edx, eax
;--- ecx = highest address for XMS
;--- eax = int 15 mem (pages)
;--- edx = 100000h
	shl eax, 12
	add eax, edx
	inc ecx
	sub eax,ecx
	ja @F
error:
	stc
	ret
@@:
	mov edx, ecx
	shr eax, 12
	@drprintf "getunmanagedmem: using unmanaged memory base=%lX, size=%lX", edx, eax
	mov PhysBlk.bFlags, PBF_I15 or PBF_TOPDOWN
	cmp eax, ?PAGEMIN		;could we get the minimum?
	ret
getunmanagedmem endp
endif

;*** initialization Page Manager RM
;*** allocs minimum space required for init:
;--- in: DS=GROUP16
;*** RC: C on errors (not enough memory)
;*** sets:
;***  PhysBlk: current physical memory block descriptor
;***  vcpiOfs: offset entry VCPI if VCPI host detected
;***  v86topm._cr3: value for CR3 if VCPI host detected
;***  *obsolete* pPageDir:linear address page dir
;***  pPageTab0:linear address page table 0
;***  dwOfsPgTab0: offset 1. free PTE in page table 0

?HEAPPAGE equ 1	;add 1 page for heap

if ?MOVEHIGH
?PAGEMIN	equ 10+7+?HEAPPAGE
else
?PAGEMIN	equ 10+?HEAPPAGE
endif

	@ResetTrace

pm_init_rm proc public

if _LTRACE_
	nop
	@drprintf "pm_init_rm: enter"
endif
	test [fHost], FH_XMS
if ?XMSALLOCRM
	jz noxms
  if ?INT15XMS
	test gbl.fMode2, FM2_INT15XMS
	jz @F
	call getunmanagedmem
	jnc initpagemgr_rm_1
@@:
  endif
  if ?VCPIPREF
	test gbl.fMode2, FM2_VCPI	;option -v set?
	jz @F
	test fHost, FH_VCPI		;running as VCPI client?
	jz @F
	and fHost, not (FH_XMS or FH_XMS30)
	jmp noxms
@@:
  endif
	mov ah, fXMSQuery
	mov bl,0				;some XMS hosts dont set BL on success
	call [xmsaddr]
	cmp bl,0
	jnz noxms
	test [fHost],FH_XMS30	;xms driver 3.0+?
	jnz @F
	movzx eax,ax
@@:
	shr eax,2				;kb->pg
	mov cx,6				;alloc 1/32 of max free block
nexttry:
	cmp eax, ?PAGEMIN*2
	jb @F
	shr eax, 1
	loop nexttry
@@:
	cmp eax, ?PAGEMIN
	jb noxms
	mov edx, eax
	push eax
	shl edx,2
	mov ah,fXMSAlloc
	call allocxms_rm		;alloc XMS memory
	pop eax
	jc noxms
	mov PhysBlk.wHandle,bx
	mov PhysBlk.bFlags, PBF_XMS
	test dx,0FFFh			;block's base on page boundary?
	jz @F
	add edx,1000h-1
	and dx,0F000h			;if no, do a page align
	dec eax
@@:
	jmp initpagemgr_rm_1
noxms:
	@drprintf "pm_init_rm: no XMS memory"
else
	jnz initpagemgr_rm_2	;XMS exists, all ok
endif
if ?VCPIALLOC
	test [fHost],FH_VCPI	;VCPI host exists?
	jz @F
if ?NOVCPIANDXMS
	test [fHost],FH_XMS		;avoid using VCPI if XMS host exists
	jnz @F
endif
	mov ax,0DE03h			;get number of free pages (EDX)
	int 67h
	@drprintf "pm_init_rm: free VCPI pages=%lX", edx
	cmp edx, ?PAGEMIN
	jnc initpagemgr_rm_2
@@:
endif
	@drprintf "pm_init_rm: no VCPI or XMS memory"
	test fHost, FH_XMS or FH_VCPI
	jnz @F
	mov PhysBlk.bFlags, PBF_I15 or PBF_TOPDOWN
	call alloci15rm			;try to alloc with Int 15h
	cmp eax, ?PAGEMIN		;could we get the minimum?
	jnb initpagemgr_rm_1	;that would be ok for now
@@:
	test [bEnvFlags],ENVF_INCLDOSMEM
	stc
	jz error
	@drprintf "pm_init_rm: no extended memory found, try to alloc dos mem"
	mov bx,(?PAGEMIN+1)*100h
	mov ah,48h
	int 21h
	jc error				;if this fails, we are 'out of mem'
	mov PhysBlk.wHandle, ax
	movzx edx,ax
	add dx,100h-1			;align to page 
	mov dl,0
	shl edx,4				;make it a linear address
	@drprintf "pm_init_rm: dos memory allocated, addr=%lX, size=%X paras",edx, bx
	mov eax,?PAGEMIN
	mov PhysBlk.bFlags, PBF_DOS or PBF_LINEAR

initpagemgr_rm_1:
;--- here we have a PhysBlk with enough space for initialization
	@drprintf "pm_init_rm: PhysBlk init, base=%lX, size=%lX pg", edx, eax
	mov PhysBlk.dwSize, eax 	;pages total
	mov PhysBlk.dwFree, eax 	;pages free to allocate
	mov PhysBlk.dwBase, edx		;phys. address

initpagemgr_rm_2:
	call initpagetab0
	jc error

if ?386SWAT
	test fDebug,FDEBUG_KDPRESENT
	jz @F
	test fHost, FH_VCPI	;don't call if HDPMI is a VCPI client
	jnz @F
	mov ebx, v86topm._cr3
;--- v3.19: pPageDir isn't the correct setting yet
;	mov edx, pPageDir
	mov edx, ebx
	mov ax, 0DEF4h
	int 67h
@@:
endif
	clc
error:
	@drprintf "pm_init_rm: exit"
	ret
pm_init_rm endp

pm_init2_rm proc public
	push es
	mov es,word ptr taskseg._ES
	@drprintf "pm_init2_rm: releasing old page tables %X", es
	mov ah,49h
	int 21h
	pop es
	ret
pm_init2_rm endp

_ITEXT16 ends

	end

