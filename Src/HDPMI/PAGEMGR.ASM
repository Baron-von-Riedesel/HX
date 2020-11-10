
;--- page handling
;--- handles physical memory, address space and un/committed memory

	.486P

	option proc:private
	option casemap:none

	include hdpmi.inc
	include external.inc

?XMSALLOCRM 	= 1	;std 1, alloc 1. EMB in real mode (XMS-Mode only)
?CLEARACCBIT	= 0	;std 0, on entry clear ACC-Bit for all PTEs in 1. MB
?FREEPDIRPM 	= 0	;std 0, on exit reset CR3 in protected mode (?)
?VCPIALLOC		= 1	;std 1, alloc VCPI mem if no XMS host found
?RESPAGES		= 4	;std 4, small reserve, do not alloc these pages
?ZEROFILL		= 0	;std 0, 1=do zero fill all committed pages
?USEE820		= 0	;std 0, use int 15h, ax=e820 to get extmem in raw mode
?USEE801		= 1	;std 1, use int 15h, ax=e801 to get extmem in raw mode
?FREEVCPIPAGES	= 1	;std 1, free all VCPI pages in pm_exit_rm
?FREEXMSINRM	= 1	;std 1, free XMS blocks in pm_exit_rm
?NOVCPIANDXMS	= 1	;std 1, 1=avoid using VCPI if XMS host exists
?FREEXMSDYN 	= 1	;std 1, 1=free XMS blocks dynamically
?XMSBLOCKCNT	= 1	;std 1, 1=count XMS blocks to improve alloc strategy
?SETPTE equ 0

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
; 080=reserved
; 100=reserved
; 200=available
; 400=available : is _XMSFLAG_
; 800=available	: is _VCPIFLAG_

if ?SAFEPAGETABS
?PAGETABLEATTR	= PTF_PRESENT or PTF_WRITEABLE
else
?PAGETABLEATTR	= PTF_PRESENT or PTF_WRITEABLE or PTF_USER
endif

_XMSFLAG_		= 4h	;page src xms (+i15 +dos)
_VCPIFLAG_		= 8h	;page src vcpi

?SYSTEMSPACE	= 0FF8h ;offset in page dir for system area (std FF8=0xFF800000)   
?SYSPGDIRAREA	= 2*4	;2 system page tables (sys pagetab 0+1)

?SYSAREA0	= (?SYSTEMSPACE+0) shl 20				; = FF800000
?SYSAREA1	= (?SYSTEMSPACE+4) shl 20				; = FFC00000
?PTSYSAREA0	= ?SYSAREA1 + 1000h						; = FFC01000

; memory structure as implemented by page manager:
; - page directory is mapped at end of system area (FFBFF000)
; - page tables are mapped in linear region FFC00000-FFFFFFFF
; - page table sys area 0 (FF800000-FFBFFFFF) is at FFC01xxx
; - page table sys area 1 (FFC00000-FFFFFFFF) is at FFC00xxx (page map table)
; - page tables user space (00000000-FF7FFFFF) begin at FFC02xxx
; - variables:
; - pPageDir    = FFBFF000
; - pPageTab0   = FFC02000
; - pPageTables = FFC00000 (=sysarea 1, fix)

_DATA16 segment

pPageDir	 dd 0		;linear address page dir (FFBFF000)
pPageTables  dd 0		;linear address start page tables (FFC00000)
pPageTab0	 dd 0		;linear address page table 0 (FFC02000)
dwOfsPgTab0  dd 0		;is used to calc total address space (const!)

;--- system address space (FF800000-FFBFFFFF)
;--- the space is allocated by using 2 pointers, SysAddrUp
;--- and SysAddrDown (one upwards, the other downwards)

;--- the first is used to alloc space for code, GDT, LDT, IDT, ...
;--- the second is used to alloc space for mapped page dir
;--- + client save states

SysAddrUp	dd 0		;init: bottom of sys addr space (FF801000)
SysAddrDown	dd 0		;init: top of sys address space (FFC00000)
SysAddrSize	dd 0		;free pages in system region

;--- the VM-specific data is cleared for a new VM

startvdata label near

;--- physical memory
;--- the page pool are uncommitted PTEs which are
;--- stored in the page tables. the pool is scanned from top to bottom

; client address space:
; - pMaxPageTab = FFC02444 on startup (corresponds to linear address 111000h)
; after 8 MB address space allocation vars are:
; - pMaxPageTab = FFC04444 (= linear address 911000h)


dwPagePool	dd 0		;uncommitted PTEs (XMS+I15) in page pool
pPoolMax	dd 0		;top of page pool
pMaxPageTab	dd 0		;linear address free space in page table region

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
cr3flgs	 	dw 0		;save bits 0-11 of CR3 phys entry here
endif
if ?XMSBLOCKCNT
bXMSBlocks	db 0
endif
		align 4
endvdata label near

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
;*** C if address space isn't allocated (no page table exists)
;--- other registers preserved

	@ResetTrace

_Linear2PT proc public uses ecx

	@DebugBreak 0
	push eax
	mov edi,ss:pPageTables
	mov ecx, ?SYSAREA1		 ; FFC00000?
	cmp eax,ecx
	jnc @F
	add edi,1000h
	mov ecx, ?SYSAREA0		 ; FF800000?
	cmp eax,ecx
	jnc @F
	add edi,1000h
	xor ecx,ecx
@@:
	sub eax,ecx
	shr eax,10				;div 1024 -> offset in page table
	and al,0FCh
	add edi,eax
;------------------------------- pMaxPageTab may be NULL (all allocated)
	mov ecx,ss:[pMaxPageTab]
	jecxz @F
	cmp ss:[pMaxPageTab],edi
@@:
	pop eax
	@strout <"#Linear2PT: lin addr %lX - addr PTE %lX, max addr PTE %lX",lf>,eax,edi,ss:[pMaxPageTab]
	ret
	align 4
_Linear2PT endp

;--- get linear address from a PTE address
;--- in: eax = linear address where PTE is stored
;--- out: eax = linear address
;--- modifies ecx

PT2Linear proc
	sub eax, ss:pPageTables
	jc exit
	mov ecx, 1000h
	cmp eax, ecx
	jc sysarea1		;eax < 1000h -> sys area 1
	sub eax, ecx
	cmp eax, ecx
	jc sysarea0		;eax < 2000h -> sys area 0
	sub eax, ecx
	shl eax, 10
	ret
sysarea1:
	shl eax, 10
	add eax, ?SYSAREA1
	ret
sysarea0:
	shl eax, 10
	add eax, ?SYSAREA0
exit:
	ret
	align 4
PT2Linear endp

if ?MAPDOSHIGH

;--- copy PTEs 
;--- EAX: source linear address
;--- EDX: dest linear address
;--- ECX: #pages

_CopyPTEs proc public
	@strout <"#CopyPTEs: src=%lX, dst=%lX, pages=%lX",lf>,eax,edx,ecx
	push ds
	push es
	pushad
	call _Linear2PT	;get source PTEs
	mov esi, edi
	mov eax, edx
	call _Linear2PT	;get dest PTEs
	@strout <"#CopyPTEs: src PTR=%lX, dst PTE=%lX, pages=%lX",lf>,esi,edi,ecx
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
	or al, PTF_PRESENT or PTF_WRITEABLE
	stosd
	loop @B
endif
if 0
	mov ebx,[esp].PUSHADS.rEDX
	mov ecx,[esp].PUSHADS.rECX
	call updatetlb
endif
	popad
	pop es
	pop ds
	ret
_CopyPTEs endp

endif

;*** search physical address region in page tables
;*** called by _searchphysregion
;*** ESI = ^ page table
;*** EDX = physical address to search
;*** EDI = length of region in pages
;*** ECX = entries in page table(s)
;*** DS = FLAT
;*** Out: NC + EAX=linaddr

	@ResetTrace

checkpt proc

	cld
	@strout <"#checkpt: checking page table at lin %lX",lf>,esi
nextentry:
	cmp ecx,edi
	jb error
	lodsd
	and ax,0F000h or PTF_PRESENT or PTF_USER
	cmp eax,edx
	jz checkpt_2
checkpt_11:
	loopd nextentry
error:
	stc
	ret

;--- first page tab entry is ok, check the rest
        
checkpt_2:
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
	jmp checkpt_11	;continue search
found:
	popad
	lea eax, [esi-4];adjust esi so it points to 1. entry again
	call PT2Linear
	@strout <"#checkpt: mapping found for real addr %lX=%lX",lf>,edx,eax
	clc
	ret
	align 4
checkpt endp

;--- search a region of physical pages in linear address space
;--- edx=physical address start
;--- eax=size in pages
;--- out: NC: found, eax=linear address
;--- else C, all preserved

_searchphysregion proc public uses ds
	pushad
	@strout <"#searchphysregion: addr=%lX,pages=%lX",lf>,edx,eax

	mov edi,eax 			;search in spaces already mapped
	push byte ptr _FLATSEL_
	pop ds
	and dh,0F0h
	mov dl,PTF_PRESENT or PTF_USER

;------- get number of pages allocated so far in ECX

	mov esi,ss:pPageTables
	mov ecx,ss:[pMaxPageTab]
	sub ecx, esi
	shr ecx, 2
	call checkpt
	jc error
	mov [esp.PUSHADS.rEAX],eax
error:
	popad
	ret
	align 4
_searchphysregion endp

;*** helper for DPMI functions 0800h, 0508h, 0509h
;*** map a physical address region into linear address space
;*** INP: EDX=physical address region start
;***      ECX=length of region in pages (may be 0!)
;***      EAX=linear address space to map the region to
;***      BL=1 -> set PTF_PWT bit in PTEs

	@ResetTrace

_mapphysregion proc public uses es

	pushad

	@strout <"#mapphysregion: addr=%lX,size=%lX",lf>,edx,ecx
	jecxz done

	push byte ptr _FLATSEL_
	pop es
	call _Linear2PT			;get addr PTR in EDI for linear address in EAX
	@strout <"#mapphysregion: adspace allocated, ^pagetab=%lX, addr=%lX",lf>,edi,eax
	mov eax,edx
	or al, PTF_PRESENT or PTF_WRITEABLE or PTF_USER
	test bl,1
	jz @F
	or al, PTF_PWT or PTF_PCD	;set 'write through' + 'cache disable'
@@:
	stosd
	add eax,1000h
	loopd @B
done:
	popad
	ret
	align 4

_mapphysregion endp

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
	mov ax,0DE03h			 ;get number of free pages (EDX)
	call [vcpicall]
exit:
	ret
	align 4
getavailvcpipages endp
endif

;*** get free XMS pages in EAX
;*** modifies EDX

getavailxmspages proc uses ebx

	test fHost, FH_XMS
	jz error
	@strout <"#getavailxmspages: calling XMS (cs:ip=%X:%X, RMS=%X:%X)",lf>,\
		word ptr ss:xmsaddr+2, word ptr ss:xmsaddr+0, v86iret.rSS, v86iret.rSP
;	@waitesckey
	push ecx
	mov ah, fXMSQuery
	mov bl,0
	pushd offset callxms
	call callrmprocintern
	pop ecx

;--- largest free block in E/AX
;--- total free in E/DX
;--- it is returned even if the call ah=88h "fails" (BL=A0)

	@strout <"#getavailxmspages: XMS returned (e)ax=%lX, (e)dx=%lX, bx=%X",lf>, eax, edx, bx
	cmp bl,0
	jz @F
	cmp bl,0A0h				;status "all memory allocated"?
	jnz error
@@:
	xchg eax,edx			;free XMS memory (kB) into EAX, largest free block in EDX
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
	ret
	align 4
getavailxmspages endp

	@ResetTrace

;*** get number of physical pages
;*** out: eax=free pages, edx=total pages, ecx=reserved for address space

_GetNumPhysPages proc public

	assume ds:GROUP16

	@strout <"#GetNumPhysPages: free pages in cur block=%lX",lf>, PhysBlk.dwFree
	call getavailxmspages	;get free XMS pages in EAX
	@strout <"#GetNumPhysPages: XMS pages=%lX",lf>, eax
	add eax,PhysBlk.dwFree	;add free pages cur block (XMS or I15)
if ?VCPIALLOC
	and eax, eax			;is XMS memory available?
	jnz @F
	call getavailvcpipages	;get VCPI pages
	@strout <"#GetNumPhysPages: VCPI pages=%lX",lf>, edx
	mov eax, edx
@@:
endif
	test [bEnvFlags],ENVF_INCLDOSMEM
	jz @F
	push eax
	@strout <"#GetNumPhysPages: calling getavaildospages",lf>
	call getavaildospages
	@strout <"#GetNumPhysPages: DOS pages=%X",lf>,ax
	pop ecx
	add eax,ecx
@@:
	mov ecx,eax 			;some pages will be needed for paging
	shr ecx,10				;(1 page for 4MB address space)
if ?RESPAGES        
	add ecx, ?RESPAGES
endif
	@strout <"#GetNumPhysPages: subtract %lX pages for pagetables",lf>,ecx
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
	@strout <"#GetNumPhysPages: block total=%lX, free=%lX",lf>,[ecx].PHYSBLK.dwSize, [ecx].PHYSBLK.dwFree
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
	@strout <"#GetNumPhysPages: total=%lX, free=%lX, res=%lX",lf>,edx,eax,ecx
	ret
	align 4
_GetNumPhysPages endp

;*** get physical address of a linear address in 1. MB
;*** inp: eax=linear address
;--- no check done

linear2phys proc uses es
	shr eax,10
	add eax, pPageTab0
	push byte ptr _FLATSEL_
	pop es
	mov eax,es:[eax]
	ret
	align 4
linear2phys endp

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
	call linear2phys
@@:
if _LTRACE_
	push ecx
	mov ecx, PhysBlk.dwSize
	shl ecx, 12
	add ecx, PhysBlk.dwBase
	dec ecx
	@stroutx ?LOG_PMGREXT,<"#getblockpage: page %lX from cur block %lX-%lX, free=%lX",lf>, eax, PhysBlk.dwBase, ecx, PhysBlk.dwFree
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
	mov eax,sizeof PHYSBLK
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
	@strout <"#freephyshandle: phys handle %lX found, pNext=%lX, hdl=%lX, start=%X",lf>, eax, [eax].PHYSBLK.pNext, [eax].PHYSBLK.dwHandle, offset PhysBlk
@@:
	mov dl, [eax].PHYSBLK.bFlags
	mov [eax].PHYSBLK.bFlags, 0
	test dl, PBF_XMS
	jz @F
	mov dx,[eax].PHYSBLK.wHandle
	@strout <"#freephyshandle: calling XMS host to free handle=%X",lf>, dx
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

;	@strout <"#setphyshandle: XMS/DOS memory allocated, addr=%lX, size=%lX",lf>,edx,eax

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
	@strout <"#setphyshandle: new phys mem obj %lX, base=%lX, size=%lX, free=%lX",lf>,eax,[eax].PHYSBLK.dwBase, [eax].PHYSBLK.dwSize, [eax].PHYSBLK.dwFree
	@strout <"#setphyshandle: current: base=%lX, size=%lX, free=%lX",lf>, PhysBlk.dwBase, PhysBlk.dwSize, PhysBlk.dwFree
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
	jz getxmspage_err

	@strout <"#getxmspage: try to alloc XMS mem (real mode), ecx=%lX",lf>,ecx
	call getavailxmspages
	cmp eax, 1
	jc getxmspage_err		;XMS is out of memory
	call getbestxmssize		;return best size
	push ecx
	mov ecx,eax
	pushd offset allocxms
	call callrmprocintern
	pop ecx
	jc getxmspage_err		;XMS is out of memory
	call setphyshandle
	mov PhysBlk.wHandle, bx
	mov PhysBlk.bFlags, PBF_XMS
if ?XMSBLOCKCNT
	inc [bXMSBlocks]
endif
	jmp getblockpage
getxmspage_err:
	@strout <"#getxmspage: memory alloc failed, ax=%X",lf>,ax
	stc
	ret
	align 4
getxmspage endp

;*** allocate DOS memory to satisfy requests, ecx=pages
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
	@strout <"#getdospage: try to enlarge DOS block %X to %X paras",lf>,v86iret.rES,bx
	mov ah,4Ah
	call rmdosintern
	pop ebx
	jc @F
	@strout <"#getdospage: DOS block enlarged",lf>
	add PhysBlk.dwSize,ecx
	mov PhysBlk.dwFree,ecx
	call setowner
	jmp getblockpage
@@:
	@strout <"#getdospage: DOS block enlarge failed",lf>
	mov ah,4Ah				;due to a bug in most DOSes the block
	call rmdosintern		;has to be resized to its previous size
	call setowner
newdosblock:
	mov bh,cl				;nur angeforderte pages
	inc bh					;1 mehr, da beginn nicht an pagegrenze
	mov bl,00
	@strout <"#getdospage: try to alloc a new DOS block, size=%X",lf>,bx
	mov ah,48h
	call rmdosintern
	jc error2
	@strout <"#getdospage: new DOS block allocated, addr=%X, size=%X",lf>,ax,bx
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
	@strout <"#getdospage: alloc new dos block failed",lf>
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

	mov esi,pPoolMax
	mov ecx,pPageTables

	@strout <"#scanpagepool: %lX-%lX, pages in pool=%lX",lf>, ecx, esi, dwPagePool

if _LTRACE_
	and esi, esi
	jnz @F
;--- pages in page pool, but pPoolMax is zero. This shouldn't happen!
	@strout <"#scanpagepool: pPoolMax is NULL!, pages in pool=%lX",lf>, dwPagePool
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
	mov pPoolMax, esi
exit:
	ret
notfound:
;--- no page in page pool. This shouldn't happen!
	@strout <"#scanpagepool error: no page in page pool found",lf>
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
	dec [dwPagePool]
if _LTRACE_
	jns @F
	@printf <"#getphyspagex: page pool cnt %lX < 0!, PTE=%lX, caller=%lX",lf>, dwPagePool, eax, dword ptr [esp]
	@printf <"   pPageDir=%lX  pPageTables=%lX",lf>, pPageDir, pPageTables
	@printf <"  pPageTab0=%lX  pMaxPageTab=%lX",lf>, pPageTab0, pMaxPageTab
	@printf <" dwPagePool=%lX     pPoolMax=%lX",lf>, dwPagePool, pPoolMax
	@printf <"edi=%lX",lf>, edi
@@:
endif
exit:
	ret
	align 4
getphyspagex endp

	@ResetTrace

;--- get one free physical page
;--- ecx = hint for xms how much pages will be requested

getphyspage proc

	cmp [dwPagePool],0		;free pages in page tables to be found?
	jz @F
	call scanpagepool
	jc @F
	dec [dwPagePool]
	@stroutx ?LOG_PMGREXT,<"#getphyspage: page pool decremented [%lX], Entry=%lX",lf>, [dwPagePool], eax
	ret
@@:

	@ResetTrace

	call getblockpage		;get page from current phys mem block
	jnc exit
	@strout <"#getphyspage: get page thru XMS",lf>
	call getxmspage
	jnc exit
if ?VCPIALLOC
	test [fHost],FH_VCPI
	jz novcpimem
if ?NOVCPIANDXMS
	test [fHost],FH_XMS	;using VCPI when XMS exists but fails
	jnz novcpimem		;seems to be unstable for many VCPI hosts
endif
	@strout <"#getphyspage: try VCPI alloc",lf>

	@ResetTrace

	mov ax,0DE04h			   ;1 page alloc VCPI
	call [vcpicall]
	and ah,ah				   ;ok?
	jnz @F
	inc [dwVCPIPages]
	@strout <"#getphyspage: page %lX allocated thru VCPI, total=%lX",lf>, edx, dwVCPIPages
	mov eax,edx
	and ax,0F000h
	or ax,PTF_NORMAL + (_VCPIFLAG_*100h)
	ret
@@:
	@strout <"#getphyspage: VCPI alloc failed, ax=%X",lf>, ax

	@ResetTrace

novcpimem:
endif
	call getdospage
exit:
	@stroutx ?LOG_PMGREXT,<"#getphyspage: exit, eax=%lX",lf>, eax
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
	jz exit				;if not, do nothing	   
	test ah,_XMSFLAG_		;is it from XMS/I15/DOS?
	jz noxmspage	        ;no (VCPI or mapped)
	inc [dwPagePool]		;XMS/I15/DOS will be put in page pool
	and al, not PTF_PRESENT
	@stroutx ?LOG_PMGREXT,<"#freephyspage: Page Pool incremented [%lX], Entry=%lX, caller=%lX",lf>,[dwPagePool],eax,<dword ptr [esp]>
exit:
	ret
	align 4
noxmspage:
if ?VCPIALLOC
	test ah,_VCPIFLAG_		   ;is it a vcpi page? 
	jz novcpipage

	@ResetTrace

	pushad
	mov edx,eax
	and dx,0F000h			   ;nur VCPI pages sofort  zurueckgeben
	mov ax,0DE05h			   ;1 page free VCPI
	call [vcpicall]
	and ah,ah				   ;ok?
	jnz @F
	dec [dwVCPIPages]
@@:
	@strout <"#freephyspage: free VCPI page %lX returned ax=%X, remaining %lX",lf>, edx, ax, dwVCPIPages
	popad
novcpipage:
endif
	xor eax, eax			   ;return 0 (value of new page entry 
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
	mov edi,esi 			;now edi is offset to free area
	mov edx,pPageTables		;linear address of page table area
	mov es:[edi+edx],eax	;set new page table in mapping page

if _LTRACE_
	lea edx, [edi+edx]
	@stroutx ?LOG_PMGREXT,<"#mapPageTable: written %lX to %lX",lf>, eax, edx
endif

;--- now clear new page table

	shl edi,10			;* 1024
	add edi, pPageTables

	@stroutx ?LOG_PMGREXT, <"#mapPageTable: phys entry %lX mapped at %lX",lf>, eax, edi


	push edi
	push eax
	mov ecx,1000h/4			 ;clear the new page table
	xor eax,eax
	rep stosd

	pop eax
	pop edi
	pop ecx
	clc
	ret
	align 4

mapPageTable endp


;--- return free address space in eax (pages)
;--- total address space in edx (pages)
;--- called by int 31h, ax=0500h
;--- ds=GROUP16

_getaddrspace proc public
	xor edx,edx 			   ;  00000000h
	sub edx, pPageTab0
	sub edx,[dwOfsPgTab0]
	shr edx,2

	xor eax,eax
	sub eax,[pMaxPageTab]
	shr eax,2
	ret
	align 4
_getaddrspace endp

;--- if a page table is totally clear (4 MB)
;--- free physical memory (PTE in mapping page table) + reset to zero
;--- + clear PDE in page dir
;--- EDX=linear address of page tab
;--- BL=1 -> free entry in page map table

	@ResetTrace

freepagetab proc

	pushad

	mov esi, pPageTables	;linear address page tables
	mov edi, pPageDir

	cmp edx, pPoolMax		;is page used by pool?
	setnc al
	and bl,al

	sub edx, pPageTab0
	shr edx, 10 			;convert it to offset in page table

	xor eax, eax			;simply clear PDE in page dir
							;no need to free it, it is a double
	mov es:[edi+edx],eax


	cmp bl,1				;can page table freed in mapping area?
	jnz @F

	lea edi, [esi+edx+?SYSPGDIRAREA]

	mov eax,es:[edi]		;and free PTE in mapping pagetab
if _LTRACE_
	mov ecx, edx
	add ecx, ?SYSPGDIRAREA
	shl ecx, 10
	add ecx, pPageTables
	shl edx, 20
	@strout <"#freepagetab: rel. PTE %lX at %lX [reg %lX, mapped %lX",lf>, eax, edi, edx, ecx
endif
	call freephyspage
	stosd
	cmp edi, pPoolMax
	jc @F
	mov pPoolMax, edi
@@:
	popad
	ret
	align 4

freepagetab endp

;--- free user address space
;--- IN: eax = linear address
;--- IN: ecx = pages
;--- ES=FLAT
;--- free entries in page directory and entries in page tables

	@ResetTrace

FreeUserAddrSpace proc

	pushad
	@strout <"#FreeUserAddrSpace: free space at %lX, %lX pages",lf>, eax, ecx
	@strout <"#FreeUserAddrSpace: pMaxPageTab=%lX pPoolMax=%lX",lf>, pMaxPageTab, pPoolMax
	mov edi, eax
	shr edi, 10 			;400000h -> 1000h, 800000 -> 2000
	add edi, pPageTab0

	xor ebp, ebp
	lea edx, [edi+ecx*4]
	cmp edx, pMaxPageTab	;is it the "last" space?
	jnz @F
	mov pMaxPageTab, edi
	inc ebp
@@:

	xor eax, eax
	xor edx, edx			;count entries in page table
	xor ebx, ebx
if _LTRACE_
	xor esi, esi
endif
;----------------------------------- clear entries in page table
	jecxz exit
nextpage:
	test di, 0FFFh
	jnz @F
	cmp dx, 400h			;all pages in pagetab
	jnz noclear
if _LTRACE_
	inc esi
endif
	cmp edx, ebx			;were all pages released?
	setz bl
	lea edx, [edi-1000h]
	call freepagetab
noclear:
	xor edx,edx
	xor ebx,ebx
@@:
							;this is always uncommitted memory
	mov eax,es:[edi]
	test ah,_XMSFLAG_		;but is a page pool page assigned?
	jnz @F
	mov dword ptr es:[edi],0
	inc ebx
@@:
	add edi, 4
	inc edx
	dec ecx
	jnz nextpage

	and ebp, ebp			;was it at the end?
	jz @F
	mov eax, edi
	and ax, 0F000h
	sub edi, eax
	shr edi, 2				;PTEs in last page table
	@strout <"#FreeUserAddrSpace: last page table entries: %lX %X %X",lf>, edi, dx, bx
	cmp edi, edx
	jnz @F
	cmp edx, ebx
	setz bl
	mov edx, eax
	call freepagetab
@@:
	@strout <"#FreeUserAddrSpace: %X pages for page tables freed",lf>, si
exit:
	popad
	ret
	align 4
FreeUserAddrSpace endp

;*** allocate user address space
;*** in: ECX=pages, DS=GROUP16, ES=FLAT
;*** out: NC if successful, EAX=linear address
;*** C on error
;*** modifies EDI, ESI, EBX, EDX
;*** updates: pMaxPageTab
;--- 4 GB are 1.0000.0000/1000 == 100000 pages
;--- example (pMaxPageTab = FFC20440h):
;--- NEG(pMaxPageTab) = 3DFBC0h, SHR 2 = F7EF0h pages == F7EF0000h bytes

	@ResetTrace

AllocUserAddrSpace proc near

	assume ds:GROUP16

	@strout <"#AllocUserAddrSpace: alloc %lX pages",lf>,ecx
	mov edi,[pMaxPageTab]	;top used address space (may be 0!)
;	and edi, edi
;	jz error
;	cmp ecx,100000h
;	jnc error
;	lea eax, [ecx*4+edi]
;	cmp eax, edi			;overflow?
;	jc error				;then insufficient free address space
	mov eax, edi
	neg eax
	shr eax, 2				;remaining free pages
	cmp ecx, eax
	ja error

	push ecx
	push edi
	cld
nextpage:
	test di,0FFFh			;start of a new page table?
	jz newpagetab
donenewpagetab:
	mov eax,es:[edi]
	mov al,PTF_NORMAL
;	@strout <"#AllocUserAddrSpace: mem page at %lX",lf>,edi
	stosd							;save PTE in page table
	dec ecx
	jnz nextpage
	mov [pMaxPageTab],edi
	pop edx
	pop ecx
									;page tables are stored so that
									;it is very simple to get linear
									;address from pointer to PTE
	@strout <"#AllocUserAddrSpace: edx=%lX, pPageTab0=%lX",lf>, edx, pPageTab0
	sub edx, pPageTab0
	shl edx,10					;* 1024 -> jetzt in edx die lin addr
	mov eax, edx
	@strout <"#AllocUserAddrSpace: new addrspace generated: addr=%lX,size=%lX",lf>,eax,ecx
	clc
	ret
newpagetab:
	mov esi,edi
	mov edx,pPageTables
	sub esi,edx
	shr esi,10					;1000h -> 004, 2000h -> 8
	mov eax,es:[esi+edx]		;get current PTE
	test al,PTF_PRESENT
	jnz @F

;--- set ECX (is a parameter for XMS mem alloc)

	push ecx
	mov ecx,[esp+8]				; address space pages
	shr ecx,10					; 1024 pages -> 1 page table
	inc ecx
	call getphyspagex			;get a page for new page table
	pop ecx

	jc error2
	and al,0F8h
	or al, ?PAGETABLEATTR
	call mapPageTable			;and map page table in sys region 1
@@:
	mov ebx, pPageDir			;get pointer to current PDE
	mov es:[ebx+esi-?SYSPGDIRAREA],eax	;set PDE in page dir
	jmp donenewpagetab
error2:
	pop edi 					;get pMaxPageTab
	mov eax, ecx
	mov ecx,[esp]				;total size in pages
	@strout <"#AllocUserAddrSpace: alloc %lX pages failed at %lX",lf>, ecx, eax
	sub ecx, eax				;subtract pages not allocated so far
	mov eax, edi
	sub eax, pPageTab0
	shl eax,10
	invoke FreeUserAddrSpace
	pop ecx
error:
	stc
	ret
	align 4

AllocUserAddrSpace endp


if ?DPMI10

	@ResetTrace

;--- get page entry attributes to es:edx
;--- ebx = linear address
;--- ecx = size in pages
;--- attributes (WORD):
;--- bit 0+1: 00=uncommitted, 01=committed, 02=mapped
;--- bit 3: writable
;--- bit 4: bit 5+6 valid (accessed+dirty)

_getpageattributes proc public
	@strout <"#getpageattributes: lin addr %lX - copy %lX attr to %lX:%lX",lf>,ebx, ecx, es, edx
	mov eax, ebx
	call _Linear2PT
	jc exit
	push byte ptr _FLATSEL_
	pop ds
	mov esi, edi
	mov edi, edx
	jecxz done
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
_getpageattributes endp

if 0

	@ResetTrace

;--- test BX:CX region, size SI:DI
;--- AX=bits whose value will be set (mask), dx=new value of bits

;--- this is for DPMI functions 06xx and 07xx

_setregionattributes proc public
	pushad
	push bx
	push cx
	pop eax		;start in eax
	push si
	push di
	pop ecx		;size in ECX
	@strout <"#setregionattributes: addr %lX, size %lX",lf>, eax, ecx
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

	@strout <"#setregionattributes, adjusted: addr %lX, size(pg) %lX",lf>, eax, ecx

	call _Linear2PT	;get PTE address in EDI
	jc exit
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
_setregionattributes endp

endif

;--- make region readonly
;--- eax=linear address
;--- ecx=pages

_makeregionreadonly proc public
	pushad
	call _Linear2PT
@@:
	and byte ptr es:[edi],not PTF_WRITEABLE
	add edi,4
	loop @B
	mov ebx,[esp].PUSHADS.rEAX
	mov ecx,[esp].PUSHADS.rECX
	call updatetlb
	popad
	ret
_makeregionreadonly endp

;--- clear tlb for linear address EBX, size ECX pages

updatetlb proc
if ?USEINVLPG
	cmp ecx,10	;it's faster to avoid INVLPG for 10+ pages
	jnc noinvlpg
	test ss:[fMode2],FM2_NOINVLPG	;option -g or cpu=80386?
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
;--- C = failure

	@ResetTrace

_setpageattributes proc public
	@strout <"#setpageattr: lin addr %lX - copy %lX attr from %lX:%lX",lf>,ebx, ecx, es, edx
	mov eax, ebx
	call _Linear2PT	;shouldn't fail since ebx was verified to be valid
	jc exit
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
	and ah,7		   ;001 = committed, 000=uncommitted
	cmp ah,1			;should page be committed?
	jnz @F
	test dl,PTF_PRESENT
	jnz step1			;jmp if page is already committed
	push ecx
	push eax
	mov eax, edx
	call getphyspagex	;expects in ECX a hint for XMS block size
	mov edx, eax
	pop eax
	pop ecx
	jc error		;error, out of physical pages!
	@strout <"#setpageattr: page %lX [old=%lX] committed [pt=%lX]",lf>,eax, edx, edi
	or dl, PTF_PRESENT or PTF_USER
	jmp step1
@@:
	cmp ah,0			;should page be uncommitted?
	jnz nouncommit
	test dl,PTF_PRESENT
	jz nouncommit		;jump if it is already uncommitted
	push eax
if _LTRACE_
	mov eax, edi
	push ecx
	call PT2Linear
	pop ecx
	@strout <"#setpageattr: page %lX, lin addr=%lX uncommitted [pt=%lX]",lf>,edx, eax, edi
endif
	mov  eax, edx
	call freephyspage
	lea edx, [edi+4]
	cmp edx, ss:pPoolMax
	jc @F
	mov ss:pPoolMax, edx
@@:
	mov edx, eax
	pop eax
nouncommit:
step1:
	and dl, not PTF_WRITEABLE
	test al,08h
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
	call updatetlb
	clc
exit:
	ret
error:
	sub ebp,ecx
	mov ecx,ebp		;return pages changed in ECX
	stc
	ret
	align 4

_setpageattributes endp

endif

;-------------------------------------------------------

;*** get user address space
;*** RC: C on errors
;*** Inp: EAX num pages
;*** out: EAX=linear address, EDX = pages
;--- DS=GROUP16

_AllocUserSpace proc public

	push es
	pushad
	push byte ptr _FLATSEL_
	pop es
	mov ecx, eax
	call AllocUserAddrSpace
	jc @F
	mov [esp].PUSHADS.rEAX, eax
	mov [esp].PUSHADS.rEDX, ecx
@@:
	popad
	pop es
	ret
	align 4
_AllocUserSpace endp

;*** Inp: ECX num pages
;*** Inp: EAX linear address

_FreeUserSpace proc public

	push es
	pushad
	push byte ptr _FLATSEL_
	pop es
	call FreeUserAddrSpace
	popad
	pop es
	ret
	align 4
_FreeUserSpace endp

	@ResetTrace

;--- commit region u/ser, r/w and p/resent

_CommitRegion proc near public
	mov dl,PTF_PRESENT or PTF_WRITEABLE or PTF_USER
_CommitRegion endp	;fall throu

;*** commit a region
;--- INP: EAX=linear addr, ECX=size in pages, DL=page flags
;--- modifies ES (=FLAT)

commitblockx proc near
	pushad
	push byte ptr _FLATSEL_
	pop es
	call _Linear2PT
	jc error
	@strout <"#commitblockx: alloc %lX pages at %lX, ptr PTE=%lX",lf>,ecx,eax,edi
nextpage:						;<---- commit next page
	mov eax,es:[edi]
	push edx
	call getphyspagex	;expects in ECX a hint for XMS block size
	pop edx
	jc error
if _LTRACE_
	test cx,0FFFh
	jnz @F
	@strout <"#commitblockx: commit page %lX at %lX:%lX, remaining %lX",lf>, eax, es, edi, ecx
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
	@strout <"#commitblockx: alloc failed, remaining %lX pages, pPoolMax=%lX",lf>,ecx, ss:pPoolMax
	mov eax, ecx
	mov ecx, [esp].PUSHADS.rECX
	sub ecx, eax
	jecxz error_done
	cmp edi, ss:pPoolMax
	jc @F
	mov ss:pPoolMax,edi
@@:
	sub edi,4
	mov eax,es:[edi]
	call freephyspage
	mov es:[edi], eax
	loopd @B
error_done:
	@strout <"#commitblockx: alloc failed, pPoolMax=%lX",lf>,ss:pPoolMax
	stc
	jmp exit
	align 4
commitblockx endp

;*** uncommit memory region
;*** EAX=linear address, ECX=size in pages
;--- eax, ecx, edx modified

_UncommitRegion proc public
	jecxz exit
	mov edx, eax			;save linear address begin
	push es
	push byte ptr _FLATSEL_
	pop es
	@strout <"#UncommitRegion: free %lX pages at %lX, pPoolMax=%lX",lf>,ecx,eax,ss:pPoolMax
	call _Linear2PT
	push ebx
	push ecx
	mov ebx,ss:pPoolMax
nextpage:
	mov eax,es:[edi]
	call freephyspage
	test ah,_XMSFLAG_
	stosd
	jz @F
	mov ebx, edi
@@:
	loopd nextpage
	cmp ebx, ss:pPoolMax
	jc @F
	mov ss:pPoolMax,ebx
@@:
	@strout <"#UncommitRegion: pPoolMax=%lX",lf>,ss:pPoolMax
	pop ecx
	mov ebx, edx
	call updatetlb
	pop ebx
	pop es
exit:
	ret
	align 4

_UncommitRegion endp

;--- move PTEs from one block to another
;--- eax = lin addr of old block
;--- edx = lin addr of new block
;--- ecx = size in pages (may be 0)

_MovePTEs proc public uses es esi edi ebx
	push byte ptr _FLATSEL_
	pop es
	@strout <"#MovePTEs: mov %lX pages from %lX to %lX",lf>,ecx,eax,edx
	push eax
	push ecx

	call _Linear2PT
	mov esi, edi
	mov eax, edx
	call _Linear2PT
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
;	@strout <"#MovePTEs: exit",lf>
	ret
	align 4
_MovePTEs endp

	@ResetTrace

;*** dl=flags,eax=lin addr, ecx=pages ***

_CommitRegionZeroFill proc public

	push es
	@strout <"#CommitRegionZeroFill: addr=%lX, size=%lX",lf>, eax, ecx
	call commitblockx	;will set es to FLAT, other regs unchanged
	jc @F
	cld
	pushad
	mov edi,eax
	xor eax,eax
	@strout <"#CommitRegionZeroFill: %lX:%lX, size=%lX",lf>,es,edi,ecx
	shl ecx,10
	rep stosd
	popad
@@:
	pop es
	ret
	align 4
_CommitRegionZeroFill endp

;--- allocate address space in system region 0
;--- cannot be freed anymore
;--- IN: ECX pages
;--- OUT: EAX=linear address

	@ResetTrace

_AllocSysAddrSpace proc public
	mov eax,[SysAddrUp]
	cmp [SysAddrSize],ecx
	jc error
	sub [SysAddrSize],ecx
	shl ecx,12
	add [SysAddrUp],ecx
	@strout <"#AllocSysAddrSpace: block %lX, remaining pages: %lX",lf>,eax, SysAddrSize
error:
	ret
	align 4
_AllocSysAddrSpace endp

if 0
;--- not really useful, since if WP bit is set,
;--- we cant do anything with such pages.
;--- so alloc pages with _AllocSysPages, fill them
;--- and then make them r/o!

;--- alloc pages with attr p/resent, r/o, u/ser
;*** IN: ECX pages, DS=GROUP16
;--- OUT: EAX=Addr

_AllocSysPagesRo proc public
	mov dl,PTF_PRESENT or PTF_USER
	jmp AllocSysPages_Common
	align 4
_AllocSysPagesRo endp
endif

;--- alloc ecx pages with attr p/resent, r/w, s/ystem

_AllocSysPagesX proc public
	mov dl,PTF_PRESENT or PTF_WRITEABLE
	jmp AllocSysPages_Common
	align 4
_AllocSysPagesX endp

;--- alloc ecx pages with attr p/resent, r/w, u/ser
;--- return linear address in EAX

_AllocSysPages proc public
	mov dl,PTF_PRESENT or PTF_WRITEABLE or PTF_USER
AllocSysPages_Common::
	mov eax,[SysAddrUp]
	cmp [SysAddrSize],ecx
	jc error
	call _CommitRegionZeroFill	;first do a commit
	jc error					;no more memory
	push ecx
	call _AllocSysAddrSpace		;now allocate address space
	pop ecx
error:
	ret
	align 4
_AllocSysPages endp

if ?USESYSSPACE2
_AllocSysPagesDn proc public
	cmp [SysAddrSize],ecx
	jc error
	mov edx,ecx
	shl edx,12
	mov eax,[SysAddrDown]
	sub eax,edx
	mov dl,PTF_PRESENT or PTF_WRITEABLE
;	call _CommitRegion	;alloc pages u/ser, r/w
	call commitblockx	;alloc pages s/ystem, r/w
	jc error
	mov [SysAddrDown],eax
	sub [SysAddrSize],ecx
error:
	ret
	align 4
_AllocSysPagesDn endp

_FreeSysPagesDn proc public
	push ecx
	push eax
	call _UncommitRegion
	pop eax
	pop ecx
	cmp eax,[SysAddrDown]
	jnz @F
	add [SysAddrSize],ecx
	mov edx,ecx
	shl edx,12
	add [SysAddrDown],edx
@@:
	ret
	align 4
_FreeSysPagesDn endp
endif

;--- alloc committed memory in user address space
;--- in:ECX=pages
;--- out: eax=linear address

_AllocUserPages proc public
	pushad
	call AllocUserAddrSpace
	jc exit
	call _CommitRegion
	jc exit		;the address space cannot be freed currently
	mov [esp].PUSHADS.rEAX, eax
exit:
	popad
	ret
	align 4
_AllocUserPages endp

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
	@strout <"#freememblock: free page %lX at %lX",lf>, eax, esi
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

	@strout <"#FreeVCPIPages: entry, di=%X",lf>, di

;--- copy system region FF800000 pages to host stack

	mov bl,0

	mov esi, pPageTables
	add esi, 1000h
	mov ecx, 400h
	@strout <"#FreeVCPIPages: free sys space=%lX, entries=%lX",lf>, esi, ecx
	call freememblock

;--- free mapped page tables FFC00000 pages 

	mov bl,1

	mov esi, pPageTables
if 1
	lea esi, [esi+3*4]
	mov ecx, 400h-3
else
	lea esi, [esi+2*4]	
	mov ecx, 400h-2
endif
	@strout <"#FreeVCPIPages: free sys space=%lX, entries=%lX",lf>, esi, ecx
	call freememblock

;--- free anything from 004-FF8 in page dir

	mov esi, pPageDir			;linear address page dir
	lea esi, [esi+4]
	mov ecx,400h-3
	@strout <"#FreeVCPIPages: free page tables in page dir %lX, entries=%lX",lf>, esi, ecx
	call freememblock

;--- copy the rest to host stack

	mov bl,0

	mov esi, pPageDir			;linear address page dir
	mov ecx,400h
	call freememblock

	@strout <"#FreeVCPIPages: exit, di=%X",lf>, di
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

_SetPage proc public
	pushad
	@strout <"#SetPage: edx=%lX, eax=%lX",lf>, edx, eax
	mov eax, edx
	call _Linear2PT		;get address of PTE in EDI for the address in EAX
	jc exit
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
_SetPage endp

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
	call _Linear2PT
	pop eax
	jc error1
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
	@strout <"#ClonePage: addr=%lX, just PTE=%lX copied",lf>, edx, eax
error1:
	pop edi
	ret
@@:
	pop edi
	push edx
	push ebx
	call getphyspage	;get a free PTE
	pop ebx
	pop edx
	jc error
	@strout <"#ClonePage: addr=%lX, new PTE=%lX",lf>, edx, eax
	call CopyPageContent
	@strout <"#ClonePage: dest PTE=%lX, src PTE=%lX",lf>, eax, ecx
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
	call _Linear2PT
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

;--- check the committed pages if one is
;--- contained in current block. If no, release block + clear PTEs in pool

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
	@strout <"#compresspagepool: blk base=%lX, size=%lX, free=%lX, nxt free=%lX",lf>, PhysBlk.dwBase, PhysBlk.dwSize, PhysBlk.dwFree, edx
	@strout <"#compresspagepool: pPoolMax=%lX, dwPagePool=%lX, pMaxPageTab=%lX",lf>,pPoolMax, dwPagePool, pMaxPageTab
endif
nextblock:
	call compresspool
	mov edx, PhysBlk.dwBase
	mov ebx, PhysBlk.dwSize
	sub ebx, PhysBlk.dwFree
	shl ebx, 12
	add ebx, edx
	mov ecx, pMaxPageTab
	mov edi, pPageTables
nextitem:
	cmp edi, ecx
	jz blockisfree
	mov eax, es:[edi]
	add edi, 4
	test al,PTF_PRESENT
	jz nextitem
	test ah,_XMSFLAG_
	jz nextitem
	cmp eax, edx
	jc nextitem
	cmp eax, ebx
	jnc nextitem
;--- the page is in use, but in may be just because of the page pool
;--- this could possibly be "ignored"
	@strout <"#compresspagepool: PTE %lX in use at %lX",lf>, eax, edi
	mov esi, pPageTables
	lea esi, [esi+1000h];check if page is an entry in mapping page
	lea ebp, [edi-4]
	cmp ebp, esi
	jnc scandone		;no, so it can't be for page pool -> abort
	mov esi, pMaxPageTab
	sub esi, pPageTables
	shr esi, 10
	add esi, ?SYSPGDIRAREA
	and si, 0FFFCh
	add esi, pPageTables
	cmp ebp, esi
	jc scandone
	call getpoolpage		;get a pool page, but not from current block!
	jc scandone
	@strout <"#compresspagepool: weak usage %lX %lX",lf>, ebp, eax
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
	cmp ecx, pPoolMax
	jnc @F
	mov ecx, pPoolMax
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
	@strout <"compresspagepool: page pool cnt %lX < 0",lf>, dwPagePool
@@:
endif
	jmp nextitem2
blockdone:
	@strout <"#compresspagepool: release current PHYSBLK",lf>
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
	@strout <"#compresspagepool: blk base=%lX, size=%lX, free=%lX, nxt free=%lX",lf>, PhysBlk.dwBase, PhysBlk.dwSize, PhysBlk.dwFree, edx
	@strout <"#compresspagepool: pPoolMax=%lX, dwPagePool=%lX, pMaxPageTab=%lX",lf>,pPoolMax, dwPagePool, pMaxPageTab
endif
	pop es
	ret
	align 4
compresspool:
	cld
	mov esi, pMaxPageTab
	mov edi, esi
	mov ecx, pPoolMax
@@:
	cmp esi, ecx
	jnc @F
	mov eax, es:[esi]
	add esi, 4
;	cmp eax, PTF_NORMAL
;	jz @B
	test ah,_XMSFLAG_
	jz @B
	add edi, 4
	cmp edi, esi
	jz @B
	@stroutx ?LOG_PMGREXT,<"#compresspagepool: pool entry %lX at %lX",lf>, eax, edi
	mov dword ptr es:[esi-4],PTF_NORMAL
	mov es:[edi-4], eax
	jmp @B
@@:
	mov pPoolMax, edi
	@strout <"#compresspagepool: pPoolMax before/after compress %lX/%lX",lf>, ecx, edi

;--- the top of the pool has been adjusted		  
;--- now free all PTEs in the mapping page (FFC00000)
;--- which are beyond the new pool top

	mov esi, pPageTables
	sub edi, esi

	shr edi, 10
	add edi, ?SYSPGDIRAREA
	and di, 0FFFCh
	lea edi, [edi+esi+4]
	lea esi, [esi+1000h]
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
	mov edi, pMaxPageTab
	mov ecx, pPoolMax
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
	align 4
noppfound:
	popad
	stc
	retn
	align 4
compresspagepool endp

endif

;--- client has terminated. If DOS memory has been
;--- used by pagemgr, release as much of it as possible 

compressdosmem proc uses es

	push byte ptr _FLATSEL_
	pop es
	mov esi, pPageTables
	mov ecx, pMaxPageTab

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
	mov esi,pPageTables
	mov ecx,pPoolMax
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
	@strout <"compressdosmem: page pool cnt %lX < 0",lf>, dwPagePool
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
	@strout <"#pm_exitclient enter",lf>
	mov ebx, offset PhysBlk
nextblock:
	@strout <"#pm_exitclient, PhysBlk: base=%lX, size=%lX, free=%lX, handle=%lX",lf>,\
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
	cmp cApps,1				;this is before it is decremented
	jnz notidle
	test fMode, FM_RESIDENT
	jz notidle				;host will exiting soon, do nothing
	test PhysBlk.bFlags,PBF_XMS
	jz notidle				;no XMS block, cannot be released
	call compresspagepool
notidle:
endif
	popad
	@strout <"   pPageDir=%lX  pPageTables=%lX",lf>, pPageDir, pPageTables
	@strout <"  pPageTab0=%lX  pMaxPageTab=%lX",lf>, pPageTab0, pMaxPageTab
	@strout <" dwPagePool=%lX     pPoolMax=%lX",lf>, dwPagePool, pPoolMax
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
	@strout <"#pm_exit_pm enter",lf>
;------------------ save all XMS handles on stack *before* freeing memory
	@strout <"#pm_exit_pm: start save xms handles on host stack",lf>
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
	@strout <"#pm_exit_pm: xms handle %X saved",lf>,ax
	inc esi
	inc esi
skipitem:
	mov ebx,[ebx].PHYSBLK.pNext
	jmp nextitem
xmsdone:
	@strout <"#pm_exit_pm: done save xms handles on host stack",lf>
if ?FREEXMSINRM
	mov pXMSHdls,si
  if ?FREEVCPIPAGES
;---- VCPI pages have to be freed in real-mode as well
;---- because the pages are freed with XMS.
	@strout <"#pm_exit_pm: call FreeVCPIPages",lf>
	mov edi, esi
	call FreeVCPIPages
	mov pVCPIPages, di
  endif
endif
ife ?FREEXMSINRM
	@strout <"#pm_exit_pm: free xms memory blocks",lf>
nextitem2:
	cmp esi,esp
	jz @F
	pop dx
	@strout <"#pm_exit_pm: free xms block %X, rm ss:sp=%X:%X",lf>,dx,ss:v86iret.rSS, ss:v86iret.rSP

	pushd offset freexms
	call callrmprocintern
	jmp nextitem2
@@:
endif
if ?FREEPDIRPM
	@strout <"#pm_exit_pm: restore cr3",lf>
	mov eax,[orgcr3]
	mov cr3,eax
	xchg eax,[cs._cr3]
	@strout <"#pm_exit_pm: free cr3 page",lf>
	mov ax,[cr3flgs]
	call freephyspage
endif
if ?VCPIALLOC
	@strout <"#pm_exit_pm: VCPI pages allocated on pm exit=%lX",lf>,dwVCPIPages
endif
	@strout <"#pm_exit_pm: exit",lf>
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
;--- simple solution: do the cleanup when the cApps counter 
;--- goes to zero and the host is resident.

_freeI15mem proc public
	test ss:[fHost], FH_XMS or FH_VCPI
	jnz exit
	push eax
	mov eax, ss:[dwResI15Pgs]
	and eax, eax
	jnz @F
	mov eax, ss:PhysBlk.dwFree
	shr eax, 1
	mov ss:[dwResI15Pgs], eax
	@strout <"#freeI15mem: pages released for int 15h,ax=e801h: %lX",lf>, eax
@@:
	sub ss:PhysBlk.dwFree, eax
	pop eax
exit:
	ret
	align 4
_freeI15mem endp

;--- called after a int21, ax=4b00 in i21srvr.asm

_restoreI15mem proc public
	test ss:[fHost], FH_XMS or FH_VCPI
	jnz exit
	push eax
	xor eax, eax
	xchg eax, ss:[dwResI15Pgs]
	add ss:PhysBlk.dwFree, eax
	@strout <"#restoreI15mem: pages restored: %lX, now free: %lX",lf>, eax, ss:PhysBlk.dwFree
	pop eax
exit:
	ret
	align 4
_restoreI15mem endp

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
	@strout <"#pm_CloneGroup32: alloc %lX bytes 32bit code+data",lf>, ecx
	mov edx, ecx
	shr ecx, 12
	test dx,0FFFh
	jz @F
	inc ecx
@@:
	and eax, eax
	jz isfirst
	mov edi, eax
	mov edx, SysAddrUp
	@strout <"#pm_CloneGroup32: source %lX, dest=%lX, pg=%lX",lf>, edx, edi, ecx
@@:
	push ecx
	call _ClonePage
	pop ecx
	jc error
	@strout <"#pm_CloneGroup32: %lX cloned, PTE=%lX", lf>, edx, eax
	stosd
	add edx,1000h
	dec SysAddrSize
	mov SysAddrUp, edx
	loopnz @B
	@strout <"#pm_CloneGroup32 done, last PTE=%lX, ppt=%lX",lf>, eax, edi
	ret
isfirst:
	call _AllocSysPages		;alloc pages for GROUP32
	jc error
	@strout <"#pm_CloneGroup32: copying code to extended memory",lf>
	mov edi, eax
	push ds
	push cs
	pop ds
	push ecx
ifdef ?PE
	mov esi, 1000h
	mov ecx, ss:dwVSize
	sub ecx, esi
else
	xor esi, esi
	mov ecx, offset endoftext32
endif
	shr ecx, 2
	rep movsd
	pop ecx
	pop ds
ifdef ?PE
	sub ecx,2	;the last 2 pages get special flags
endif
	call _Linear2PT	;get PTE ptr in edi
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
;--- +2 pages  client save state
;----------------------------------
;    10 pages
;--- +7 pages  GROUP32 if code is moved high
;

;--- now paging will be fully initialized:
;--- 1. alloc 4 physical pages and map them temporarily at 3FC000-3FFFFF;
;---    3FC000=SA1, 3FD000=SA0, 3FE000=PT0, 3FF000=PD
;--- 2. clear the page contents
;--- 3. copy content of page tab 0 to 3FE000
;--- 4. copy PDEs 000, FF8 and FFC to 3FFxxx (temp. mapped new pagedir)
;--- 5. restore content of old pagetab 0
;--- 6. test if this is the very first VM. If no, copy content of
;---    FFC00000+1000 to 3FC000+1000 (PTEs for system area 0). This
;---    will make GROUP32, GDT, and IDT accessible after CR3 has been
;---    switched.
;--- 7. set new CR3
;--- 8. copy PTE for pagedir to FFC01004h (maps new page dir at FFBFFxxx)

;*** variables already set (will be set again):
;*** v86topm._cr3: CR3
;*** pPageDir:   lin  address page dir
;*** pPagesTab0: lin  address page tab 0

;*** new variables set:
;*** pPageTables:lin  address page tables (=FFC00000)
;*** pMaxPageTab:lin  address next entry in cur. page table

?TEMPBASE	equ 3FC000h	;linear address of page tables for new VM in
						;current VM (valid just temporarily inside here)

	@ResetTrace

pm_createvm proc public

	assume ds:GROUP16

	pushad
	mov ebp, esp
	@strout <"#pm_createvm enter",lf>
	@strout <"#pm_createvm: cr3=%lX pPageDir=%lX pPageTab0=%lX",lf>, v86topm._cr3, pPageDir, pPageTab0

;--- global variables may (and "should") be set here. The host instance has been
;--- switched already in case it isn't the very first VM.

	mov SysAddrUp, ?SYSAREA0 + 1000h
	mov SysAddrDown, ?SYSAREA1 - 1000h
	mov SysAddrSize, 400h-2

	test fMode, FM_CLONE	;dont clear the PhysBlk var
	jz noinit				;for the first instance

	mov edx, offset GROUP16:startvdata
	xor eax, eax
@@:
	mov [edx], eax
	add edx, 4
	cmp edx, offset GROUP16:endvdata
	jb @B

	test fHost, FH_XMS or FH_VCPI
	jnz noinit
	call pm_alloci15
	jc noinit
	@strout <"#pm_createvm: I15 mem start=%lX, size=%lX",lf>, edx, eax
	mov PhysBlk.bFlags, PBF_I15 or PBF_TOPDOWN
	mov PhysBlk.dwBase, edx
	mov PhysBlk.dwSize, eax
	mov PhysBlk.dwFree, eax

noinit:
if ?FREEPDIRPM
	mov eax, v86topm._cr3
	mov orgcr3, eax
endif

if 1
	invoke _GetNumPhysPages
	@strout <"#pm_createvm: free/total phys pages: %lX/%lX",lf>, eax, edx
	cmp eax, 10
	jc exit
endif

;--- first alloc 4 physical pages, store them onto stack

	@strout <"#pm_createvm: alloc 4 physical pages",lf>
	mov ecx,4
@@:
	call getphyspage
	jc exit
	and al, 0F8h
	or al, ?PAGETABLEATTR
	push eax
	loop @B

;--- map the 4 pages at ?TEMPBASE
;--- save old PTEs onto the stack

	mov edi, pPageTab0
	add di, 0FF0h	;this is offset of PTEs for 3FC000-3FF000
	xor ecx, ecx
@@:
	mov eax, [esp+ecx*4]
	xchg eax, es:[edi+ecx*4]
	mov [esp+ecx*4], eax
	inc ecx
	cmp cl,4
	jnz @B

if 0
;--- may be necessary to update the tlb!
	mov ecx,4
	mov ebx,?TEMPBASE
	call updatetlb
endif

;--- clear content of new pages
	cld
	mov edi, ?TEMPBASE
	push edi
	mov ecx, 4000h/4
	xor eax, eax
	rep stosd
	pop edi

;--- now clone old pagetab 0
;--- the new pages mapped at 3FC000h are intended to be used:
;--- 3FC000 -> PT of 4 MB region FFCxxxxx (system area 1)
;--- 3FD000 -> PT of 4 MB region FF8xxxxx (system area 0)
;--- 3FE000 -> PT of 4 MB region 000xxxxx (page table 0)
;--- 3FF000 -> page directory

?SA1OFS equ 0 shl 12
?SA0OFS equ 1 shl 12
?PT0OFS equ 2 shl 12
?PDOFS	equ 3 shl 12

;--- the PTE copy must be done in pagetab 0, because for the very
;--- first VM, there is no other address space available

	@strout <"#pm_createvm: copy PTEs from previous PT0, dwOfs=%lX",lf>, dwOfsPgTab0

	lea ebx, [edi + ?PDOFS]	;mapped new page dir
	lea edi, [edi + ?PT0OFS];new page tab 0
	mov esi, pPageTab0
	push edi
	push esi
	mov ecx, dwOfsPgTab0	;just copy the PTEs which are global (=conv. memory)!
	shr ecx, 2
	push ds
	push es
	pop ds
	rep movsd
	pop ds
	pop esi
	pop edi

	mov eax, 0FF0h
	add edi, eax			;never copy the last 4 PTEs
	add esi, eax

;--- store the original, saved 4 PTEs in new PT0
;--- todo: explain why!

	mov cl,4
@@:
	pop eax
	stosd
	loop @B

	test [bEnvFlags2],ENVF2_HMAMAPPING
	jz nohmamapping
;--- reinit region 100000-10FFFF
	sub edi,300h*4
	mov eax,100000h + PTF_PRESENT + PTF_WRITEABLE + PTF_USER
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

	mov edi, ?TEMPBASE
	lodsd				;get PDE for SA1 (= 3FC000 )
	stosd
	mov [ebx+?SYSTEMSPACE+4],eax
	@strout <"#pm_createvm: new PDE for FFC00000=%lX",lf>,eax

	lodsd				;get PDE for SA0 (= 3FD000 )
	stosd
	mov [ebx+?SYSTEMSPACE+0],eax
	@strout <"#pm_createvm: new PDE for FF800000=%lX",lf>,eax

	lodsd				;get PDE for PT0 (= 3FE000 )
	stosd
	mov [ebx+0000h],eax
	@strout <"#pm_createvm: new PDE for 00000000=%lX",lf>,eax

	lodsd				;get PTE for mapped PD
	mov ebx, eax

	mov esi, ss:pdGDT.dwBase
	test ss:fMode, FM_CLONE
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
	call _Linear2PT
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

;;	@strout <"#pm: snapshot PTEs: %lX %lX",lf>, <dword ptr [edi-8]>, <dword ptr [edi-4]>
;	sub ss:[SysAddrDown],2000h
;	sub ss:[SysAddrSize],2
isfirst:

;--- restore PTEs in old pagetab 0

	mov esi, ?TEMPBASE + ?PT0OFS + 0FF0h	;esi -> PTEs for 3FC000h
	mov edi, ss:pPageTab0
	add di, 0FF0h
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
	mov v86topm._cr3, eax
if ?FREEPDIRPM
	push eax
	or al,?PAGETABLEATTR
	mov [cr3flgs],ax
	pop eax
endif

;--- the new tables are set, CR3 can be reloaded now

	@strout <"#pm_createvm: will set CR3 to %lX",lf>,eax
	mov cr3,eax
	@strout <"#pm_createvm: new value for CR3 set",lf>

;--- new page dir is set and mapped, but the address space isn't reserved yet

;	mov eax, SysAddrDown
	mov eax, ?SYSAREA1 - 1000h
	mov pPageDir, eax
	mov es:[?PTSYSAREA0 + 0FFCh], ebx	; map page dir at FFBFF000h

;--- now reinit pPageTab0

	mov pPageTab0, ?SYSAREA1 + ?SYSPGDIRAREA * 400h

;--- init some important variables

	mov pPageTables, ?SYSAREA1

	@strout <"#pm_createvm: pPageTab0=%lX,   pPageDir=%lX, pPageTables=%lX",lf>, pPageTab0, pPageDir, pPageTables
	@strout <"#pm_createvm: dwPagePool=%lX,  pPoolMax=%lX",lf>, dwPagePool, pPoolMax

if ?CLEARACCBIT
	@strout <"#pm_createvm: clear accessed+dirty bits in region 0-10FFFF",lf>
	mov ecx,110h
	mov edi, pPageTab0
@@:
	and byte ptr es:[edi],09Fh
  ifdef _DEBUG
	mov eax,es:[edi]
	and al,7
	.if (al != 7)
		@strout <"#pm_createvm: invalid PTE at %lX: %lX !!!",lf>,edi,eax
	.endif
  endif
	add edi,4
	loop @B
endif

;--- init the vm's user address space

	mov esi, pPageTab0
	add esi,dwOfsPgTab0
;;	add esi, 32				;if a security buffer is needed
	mov [pMaxPageTab],esi
	@strout <"#pm_createvm: pMaxPageTab=%lX, SysAddrUp=%lX, SysAddrDown=%lX",lf>, pMaxPageTab, SysAddrUp, SysAddrDown

	@strout <"#pm_createvm exit",lf>
	clc
exit:
	mov esp,ebp
	popad
	ret
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
	@strout <"#pm_alloci15: int 15h, ax=E801",lf>
	mov ax,0E801h
	stc
	@simrmint 15h
	jc e801_err
	@strout <"#pm_alloci15: int 15h, ax=E801 ok, 1M-16M=%X,%X >16M=%X,%X",lf>, ax, cx, bx, dx
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
	@strout <"#pm_alloci15: pages=%lX",lf>, eax
	mov edx,100000h
	clc
	ret
e801_err:
	@strout <"#pm_alloci15: int 15h,ax=E801h failed",lf>
	stc
	ret

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
	@stroutrm <"-pm_int15rm, ax=e801h: free pages=%lX",lf>, ecx
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

seti15pages proc near
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
seti15pages endp

endif

;*** get memory block from XMS
;*** inp: ECX=size of block in pages
;*** DS=GROUP16
;*** Out: Carry on errors, else
;*** EAX=pages allocated
;*** EDX=physical address
;*** BX=XMS handle

	@ResetTrace

allocxms proc near uses ds

	push cs
	pop ds
	push ecx
	mov edx,ecx
	shl edx,2
	mov ah,fXMSAlloc
	@stroutrm <"-allocxms: try to alloc %lX kb XMS mem,ax=%X",lf>,edx,ax 
	call [xmsaddr]
	and ax,ax
	jz allocxmserr1			;---> error
	@stroutrm <"-allocxms: EMB allocated, handle=%X",lf>,dx
	push dx
	mov ah,0Ch					;lock EMB
	call [xmsaddr]
	pop cx
	and ax,ax
	jz allocxmserr1			;---> error
	push dx
	push bx
	pop edx 					;physical address -> edx
	mov bx,cx
	@stroutrm <"-allocxms: EMB locked, addr=%lX",lf>, edx
	pop eax						;get no of kbytes
;;	shr eax,2					;convert to pages
	test dx,0FFFh				;starts block on page boundary?
	jz @F
	and dx,0F000h				;if no, do a page align
	add edx,1000h
	dec eax
@@: 							;RC: num pages in EAX
if 0;_LTRACE_
	push ax
	push bx
	push cx
_GetA20State proto near 
	call _GetA20State
	@stroutrm <"-allocxms: A20 state is %X",lf>,ax
	pop cx
	pop bx
	pop ax
endif
	@stroutrm <"-allocxms: allocated %lX pages",lf>,eax
	clc
	ret
allocxmserr1:
	pop ecx 		;adjust stack
	mov ax,bx		;al contains error code
	@stroutrm <"-allocxms: unable to alloc XMS memory, error=%X, sp=%X",lf>,ax,sp
	stc
	ret
allocxms endp

;*** free XMS memory handle
;--- DX = xms memory handle
;--- may modify BX

freexms proc near
	mov ah,0Dh					;unlock EMB
	call cs:[xmsaddr]
	mov ah,0Ah					;free EMB
callxms::
	@stroutrm <"-callxms: AX=%X",lf>,ax
	call cs:[xmsaddr]
	ret
freexms endp

	@ResetTrace

;--- DS=GROUP16

pm_exit_rm proc public

if _LTRACE_
	nop
	@stroutrm <"-pm_exit_rm enter",lf>
;	@waitesckey
endif

	@stroutrm <"-pm_exit_rm: pVCPIPages=%X, pXMSHdls=%X",lf>, pVCPIPages, pXMSHdls
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
	@stroutrm <"-pm_exit_rm: free VCPI page %lX returned ax=%X",lf>, edx, ax
@@:
endif
	and ah,ah
	jnz nextitem
	dec dwVCPIPages
	@stroutrm <"-pm_exit_rm: free VCPI page %lX returned ax=%X, remaining %lX",lf>, edx, ax, dwVCPIPages
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
	@stroutrm <"-pm_exit_rm: free XMS handle %X",lf>, dx
	call freexms
	jmp nextitem2
xmsdone:
if 0
	test PhysBlk.bFlags, PBF_DOS
	jz @F
	mov es,PhysBlk.wHandle
	@stroutrm <"-pm_exit_rm: free DOS mem block %X",lf>,es
	mov ah,49h
	int 21h
@@:
endif
	@stroutrm <"-pm_exit_rm: done, sp=%X",lf>,sp
	ret
pm_exit_rm endp

_TEXT16 ends

;*** initialization

_ITEXT16 segment

	@ResetTrace

;*** no XMS/VCPI host detected, try Int15 alloc
;*** Out: EAX=number of free pages
;*** Out: EDX=phys. addr of block

alloci15rm proc near
	mov cl, 0
if ?USEE820
	@stroutrm <"-alloci15rm: int 15h, ax=E820",lf>
	xor ebx, ebx
	sub sp, 20
	mov di, sp
	push ss
	pop es
nextitem:
	mov ecx, 20
	mov edx,"SMAP"
	mov eax,00E820h
	int 15h
;	jc done
	cmp eax,"SMAP"
	jnz done
	cmp dword ptr es:[di+16], 1	;type "available"?
	jnz @F
	cmp word ptr es:[di+4], 0	;beyond 4 GB?
	jnz @F
	mov edx, es:[di+0]
	cmp edx, 100000h			;base above 1 MB?
	jb @F
	mov eax, es:[di+8]
	shr eax, 12 		;bytes -> pages
	@stroutrm <"-alloci15rm, ax=e820: found available mem at %lX, pages %lX",lf>,\ 
		dword ptr es:[di+0], eax
	add sp, 20
	jmp exit
@@:
	and ebx, ebx
	jnz nextitem
done:
	add sp, 20
endif
if ?USEE801
	@stroutrm <"-alloci15rm: int 15h, ax=E801",lf>
	clc
	mov ax,0E801h
	int 15h
	jc e801_err
	@stroutrm <"-alloci15rm, ax=E801: ok, ax-dx=%X %X %X %X",lf>, ax, bx, cx, dx
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
	@stroutrm <"-alloci15rm: pages=%lX",lf>, eax
	jmp done
e801_err:
endif
	@stroutrm <"-alloci15rm: int 15, ah=88h",lf>
	clc
	mov ah,88h				;get extended memory size (kB)
	int 15h
	jc exit
	@stroutrm <"-alloci15rm: Int 15 extended memory size=%X",lf>,ax
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

getphysaddr proc
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
getphysaddr endp

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

	@stroutrm <"-initpagetab0: try to alloc 2000h bytes conv. memory",lf>
	mov bx, 200h		;2 pages (8 kB), needed are 1004h bytes
	mov ah, 48h
	int 21h
	jc error
	mov word ptr taskseg._ES,ax	;save it here, will be released soon
	@stroutrm <"-initpagetab0: DOS memory alloc for page tabs ok (%X)",lf>,ax

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
	@stroutrm <"-initpagetab0: DOS memory realloc for page tabs ok (%X)",lf>,bx
endif
	mov ax,es
	add ax,100h-1
	mov al,00
	@stroutrm <"-initpagetab0: page tab start %X",lf>,ax
	mov es,ax
	movzx eax,ax
	shl eax,4
	mov pPageTab0, eax
	call getphysaddr		;get physical address (PDE) of PT0 in edx
	@stroutrm <"-initpagetab0: pPageTab0=%lX [PDE=%lX]",lf>, eax, edx
	or dl,PTF_PRESENT or PTF_NORMAL
	assume es:SEG16
	mov es:[1000h+000],edx	;set PDE for pagetab0 in page dir
	add eax,1000h
	mov pPageDir, eax
	call getphysaddr
	mov v86topm._cr3, edx	;CR3 will be modified later
	@stroutrm <"-initpagetab0: pPageDir=%lX [CR3=%lX]",lf>, eax, edx

;--- init page table 0:
;--- 000000-10FFFF: phys=linear 
;--- 110000-3FFFFF: NULL
	xor di,di
	mov cx,440h/4
	xor eax,eax
	or al,PTF_PRESENT or PTF_USER or PTF_WRITEABLE
	cld
@@:
	stosd
	add eax,1000h
	loop @B
	mov cx,(1000h-440h)/4	;init rest of tab0
	xor eax,eax
	rep stosd
	@stroutrm <"-initpagetab0: initialization pagetab0 done",lf>
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
	@stroutrm <"-initpagetab0: get VCPI protected mode interface ok (%lX,%X)",lf>,ebx,di
@@:
;--- v3.18: ensure 1 uncommitted page exists between DOS memory
;--- and host memory
	cmp di,444h 			;never go below linear addr 111000h 
	jnb @F
	mov di,444h
@@:
	mov word ptr [dwOfsPgTab0],di	;first free entry in page table 0
	clc
error:
	ret
initpagetab0 endp

if ?INT15XMS

	@ResetTrace

getunmanagedmem proc
	@stroutrm <"-getunmanagedmem: enter",lf>

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
	@stroutrm <"-getunmanagedmem: highest address=%lX",lf>, ecx
	push ecx		
	call alloci15rm
	pop ecx
	@stroutrm <"-getunmanagedmem: int 15h base=%lX, size=%lX",lf>, edx, eax
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
	@stroutrm <"-getunmanagedmem: using unmanaged memory base=%lX, size=%lX",lf>, edx, eax
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
;***  pPageDir:linear address page dir
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
	@stroutrm <"-pm_init_rm: enter",lf>
endif
	test [fHost], FH_XMS
if ?XMSALLOCRM
	jz noxms
  if ?INT15XMS
	test fMode2, FM2_INT15XMS
	jz @F
	call getunmanagedmem
	jnc initpagemgr_rm_1
@@:
  endif
  if ?VCPIPREF
	test fMode2, FM2_VCPI
	jz @F
	test fHost, FH_VCPI
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
	mov ecx, eax
	call allocxms			;alloc XMS memory
	jc noxms
	mov PhysBlk.wHandle,bx
	mov PhysBlk.bFlags, PBF_XMS
	jmp initpagemgr_rm_1
noxms:
	@stroutrm <"-pm_init_rm: no XMS memory",lf>
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
	@stroutrm <"-pm_init_rm: free VCPI pages=%lX",lf>, edx
	cmp edx, ?PAGEMIN
	jnc initpagemgr_rm_2
@@:
endif
	@stroutrm <"-pm_init_rm: no VCPI or XMS memory",lf>
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
	@stroutrm <"-pm_init_rm: no extended memory found, try to alloc dos mem",lf>
	mov bx,(?PAGEMIN+1)*100h
	mov ah,48h
	int 21h
	jc error				;if this fails, we are 'out of mem'
	mov PhysBlk.wHandle, ax
	movzx edx,ax
	add dx,100h-1			;align to page 
	mov dl,0
	shl edx,4				;make it a linear address
	@stroutrm <"-pm_init_rm: dos memory allocated, addr=%lX, size=%X paras",lf>,edx, bx
	mov eax,?PAGEMIN
	mov PhysBlk.bFlags, PBF_DOS or PBF_LINEAR

initpagemgr_rm_1:
;--- here we have a PhysBlk with enough space for initialization
	@stroutrm <"-pm_init_rm: PhysBlk init, base=%lX, size=%lX pg",lf>, edx, eax
	mov PhysBlk.dwSize, eax 	;pages total
	mov PhysBlk.dwFree, eax 	;pages free to allocate
	mov PhysBlk.dwBase, edx		;phys. address

initpagemgr_rm_2:
	call initpagetab0
	jc error

if ?386SWAT
	test fDebug,FDEBUG_KDPRESENT
	jz @F
	mov ebx, v86topm._cr3
	mov edx, pPageDir
	mov ax, 0DEF4h
	int 67h
@@:
endif
	clc
error:
	@stroutrm <"-pm_init_rm: exit",lf>
	ret
pm_init_rm endp

pm_init2_rm proc public
	push es
	mov es,word ptr taskseg._ES
	@stroutrm <"-pm_init2_rm: releasing old page tables %X",lf>, es
	mov ah,49h
	int 21h
	pop es
	ret
pm_init2_rm endp

_ITEXT16 ends

	end

