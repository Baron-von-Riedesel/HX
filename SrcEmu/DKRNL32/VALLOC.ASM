
;--- implements:
;--- + VirtualAlloc()
;--- + VirtualFree()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall	;obsolete!
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include heap32.inc
	include macros.inc

?SUPPUNCOMMITTED	equ 1	;support uncommitted memory
?STACKBEHINDIMAGE	equ 0	;assume stack is part of image memory block
							;this is no longer true (and requires DPMILD32
                            ;to be changed!)

extern __CHECKOS:abs

	.DATA

ife ?FLAT
 if 0
externdef __baseadd:dword		;base of DS
 else
__baseadd	dword -1
 endif
endif

g_bRealloc	db 1			;realloc mem to free wasted space

	.CODE

ife ?FLAT

;--- MZ and NE executables are NOT zero based

getbase proc
	pushad
	mov ebx,ds
	mov ax,0006h
	int 31h
	push cx
	push dx
	pop __baseadd
	popad
	ret
	align 4
getbase endp

;--- convert linear to based
;--- EAX=linear address

__lin2based proc public

	.if ([__baseadd] == -1)
		invoke getbase
	.endif
	sub eax, [__baseadd]
	ret
	align 4
__lin2based endp

;--- based to linear
;--- EAX=based address

__based2lin proc public

	.if ([__baseadd] == -1)
		invoke getbase
	.endif
	add eax, [__baseadd]
	ret
	align 4
__based2lin endp

endif

;--- check if address in esi is inside a loaded image
;--- if yes, returns MBLOCK in EAX, else NULL

SearchAddrInModList proc uses ebx pBlock:ptr MBLOCK

if ?FLAT
	xor eax, eax
	test [g_bIntFl],IKF_PELDR	;12/2013: DPMILD32 here?
	jz done
	mov edx, eax
	.while (1)
		mov ax, 4b83h	;call DPMILD32 function (returns EAX, ECX, EDX )
		int 21h
		and eax,eax
		jz done
		mov ebx, eax
		add	eax, [ebx.IMAGE_DOS_HEADER.e_lfanew]
		mov	ecx, [eax.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage]
if ?STACKBEHINDIMAGE			
		test [eax].IMAGE_NT_HEADERS.FileHeader.Characteristics, IMAGE_FILE_DLL
		jnz @F
		add ecx, [eax.IMAGE_NT_HEADERS.OptionalHeader.SizeOfStackReserve]
@@:
endif
		lea eax, [ecx+ebx]
		.if ((esi >= ebx) && (esi < eax))
			mov eax, pBlock
			mov [eax].MBLOCK.dwHandle, edx
			mov [eax].MBLOCK.dwAddr, ebx
			mov [eax].MBLOCK.dwBase, ebx
			mov [eax].MBLOCK.dwSize, ecx
			.break
		.endif
		mov edx, ebx
	.endw
done:
endif
	ret
	align 4

SearchAddrInModList endp

;--- search region with address=esi/size=ecx
;--- leaves esi unchanged
;--- returns NULL or pointer to MBLOCK in eax

_SearchRegion proc public uses ebx edi pBlock:ptr MBLOCK

	call GetCurrentProcess	;changes EAX only!
	add ecx, esi
	@noints
	mov ebx, [eax].PROCESS.pVirtual
	.while (ebx)
		mov edi, [ebx].MDESC.dwCnt
		lea eax, [ebx+sizeof MDESC]
		and edi, edi
		jz noitem
nextitem:
		mov edx, [eax].MBLOCK.dwAddr
		cmp esi, edx
		jb @F
		add edx, [eax].MBLOCK.dwSize
		cmp ecx, edx
		jbe found
@@:
		add eax,sizeof MBLOCK
		dec edi
		jnz nextitem
noitem:
		mov ebx,[ebx].MDESC.pNext
	.endw
	xor eax, eax
found:
	@restoreints
	.if (!eax)
		invoke SearchAddrInModList, pBlock
	.endif
	ret
	align 4

_SearchRegion endp

;--- VirtualQuery may also scan the list of memory blocks

_RegionStart proc public
	call GetCurrentProcess
	mov eax, [eax].PROCESS.pVirtual
	ret
	align 4
_RegionStart endp

;--- search a memory block
;--- return MBLOCK in eax and MDESC in EDX

VirtualFindBlock proc uses ebx dwAddress:DWORD

	call GetCurrentProcess	;changes EAX only!
	@noints
	mov ebx,[eax].PROCESS.pVirtual
	mov edx, dwAddress
	.while (ebx)
		mov ecx, [ebx].MDESC.dwCnt
		lea eax, [ebx+sizeof MDESC]
		jecxz noitem
nextitem:
		cmp edx, [eax].MBLOCK.dwAddr
		jz found
		add eax,sizeof MBLOCK
		dec ecx
		jnz nextitem
noitem:
		mov ebx,[ebx].MDESC.pNext
	.endw
	xor eax,eax
found:
	mov edx, ebx
if 0
	@strace  <"VirtualFindBlock ", [eax].MBLOCK.dwAddr>
endif
	@restoreints
	ret
	align 4

VirtualFindBlock endp

;--- add a memory region to the linked list
;--- handle may be -1 - then it's the application stack
;--- which is NOT to be released!

_AddMemoryRegion proc public uses ebx esi edi handle:dword, dwBase:dword, dwAddr:dword, dwSize:dword

	invoke GetCurrentProcess
	lea ebx, [eax].PROCESS.pVirtual
	mov eax, [ebx]
	@noints
	.while (eax)
		mov ecx,[eax].MDESC.dwCnt
		cmp ecx, (4096 / sizeof MBLOCK) - 1 ;all items used?
		jz noitem
		mov ebx, eax
		mov eax, sizeof MBLOCK
		mul ecx
		lea edx, [eax+ebx+sizeof MDESC]
		mov eax, ebx
		jmp found
noitem:
		mov ebx, eax
		mov eax, [eax].MDESC.pNext
	.endw
	push ebx
	mov cx,1000h
	mov bx,0
	mov ax,0501h
	int 31h
	mov edx,ebx
	pop ebx
	mov eax,0
	jc exit
	mov eax,edx
	shl eax,16
	mov ax,cx	;eax=linear address of this block
ife ?FLAT
	call __lin2based
endif
	mov [eax].MDESC.pNext,0
	mov [eax].MDESC.dwCnt, 0
	mov word ptr [eax].MDESC.dwHdl+0,di
	mov word ptr [eax].MDESC.dwHdl+2,si
	mov [ebx].MDESC.pNext, eax
	lea edx, [eax+sizeof MDESC]
found:
	inc [eax].MDESC.dwCnt
	mov eax,handle
	mov [edx].MBLOCK.dwHandle, eax
	mov eax, dwBase
	.if (!eax)
		mov	eax,dwAddr
	.endif
	mov [edx].MBLOCK.dwBase, eax
	mov eax, dwAddr
	mov [edx].MBLOCK.dwAddr, eax
	mov eax, dwSize
	test ax, 0FFFh
	jz @F
	add eax, 1000h
@@:
	and ax, 0F000h
	mov [edx].MBLOCK.dwSize, eax
exit:
	@restoreints
	ret
	align 4

_AddMemoryRegion endp        

;--- VirtualAlloc:
;--- flag MEM_RESERVE: base will be rounded down to 64 kB boundary
;--- flag MEM_COMMIT: will fail if MEM_RESERVE is NOT set and
;--- a base is given but not in an already allocated block

VirtualAlloc proc public uses ebx esi edi dwAddress:dword,dwSize:dword,fAllocType:dword,fProtect:dword

local	handle:dword	;DPMI memory block handle
local	dwBase:dword	;DPMI memory block base
local	dwAddr:dword	;address to return
local	myblock:MBLOCK	;used if block is not private (image)

	@strace <"VirtualAlloc(", dwAddress, ", ", dwSize, ", ", fAllocType, ", ", fProtect, ") enter">
doagain:
	mov dwBase, 0
	mov esi, dwAddress
if ?FLAT        
	and si, 0F000h
endif

ifdef _DEBUG
	mov handle,0
	.if (esi)
		mov eax, esi
		mov ecx, dwSize
		invoke _SearchRegion, addr myblock
		.if (eax)
			mov eax, [eax].MBLOCK.dwHandle
			mov handle, eax
		.endif
	.endif
endif
;--- a base is given and MEM_RESERVE is not set: change page attributes in
;--- an already reserved region

	.if (esi && (!(fAllocType & MEM_RESERVE)))
		mov ecx, dwSize
if ?FLAT
		add ecx, dwAddress
		dec ecx
		or cx, 0FFFh
		inc ecx
		sub ecx, esi
endif
if ?SUPPUNCOMMITTED
		mov eax, esi
		.if (fAllocType & MEM_COMMIT)
			invoke VirtualSetPageAttr, esi, ecx, 9, 9	;commit + writable
			.if (eax)
if 0	;this is now done in VirtualSetPageAttr                
				mov edi,dwAddress
				mov ecx,dwSize
				xor eax,eax
				shr ecx,2
				rep stosd
endif                
				mov eax,dwAddress
			.endif
		.else
			invoke _SearchRegion, addr myblock
			.if (eax)
				mov eax,dwAddress
			.endif
		.endif
else                
		invoke _SearchRegion, addr myblock
		.if (eax)
			mov edi,dwAddress
			mov ecx,dwSize
			xor eax,eax
			shr ecx,2
			rep stosd
			mov eax,dwAddress
		.endif
endif
		jmp done
	.endif

;--- if MEM_RESERVE is NOT set, base must be NULL

if ?SUPPUNCOMMITTED
	.if (esi && (!(fAllocType & MEM_RESERVE)))
		jmp error
	.endif
	mov ebx, esi
	mov ecx, dwSize
	and ecx,ecx
	jz error
	xor edi, edi
	.if (ebx)
ife ?FLAT
		mov eax, ebx
		invoke __based2lin
		mov ebx, eax
endif
		movzx eax,bx
		xor bx,bx			;round base down to 64 kB boundary
		add ecx, eax
		mov dwSize, ecx		;dwSize can be modified here because if 
							;base != 0 there will be no further tries!
							;after int 31h, 504h failed.
							;win9x rounds the size up to 64 kB boundary,
							;but winxp doesn't.
	.elseif (fAllocType & MEM_RESERVE)
;		add ecx, 10000h		;align reserved memory on 64 kB boundary
		add ecx, 10000h-1000h	;isn't this enough?
		inc edi
	.endif
	xor edx, edx
	.if (fAllocType & MEM_COMMIT)
		inc edx
	.endif
if 1        
	@strace <"VirtualAlloc: int 31h, ax=504h, ebx=", ebx, ", ecx=", ecx, ", edx=", edx>
endif        
	mov ax,0504h
	int 31h
	jc donormal
	mov handle, esi
	mov dwBase, ebx
	movzx eax, bx
	.if (edi && eax)	;is MEM_RESERVE and start not 64kb aligned?
		xor bx,bx
		add ebx, 10000h	;then align base returned by VirtualAlloc (adds 1000-f000)
	.endif
	mov dwAddr, ebx
if 1        
	.if (edi && g_bRealloc && ax != 1000h)	;some memory may be freed in this case
		;--- eax=1000h, f000 added to base, size ok
		;--- eax=2000h, e000 added to base, size 1000h too large
		;--- eax=0000h, 0000 added to base, size f000h too large
		sub ax,01000h
;		.if !eax
;			mov eax,10000h
;		.endif
		sub ecx, eax
		@strace <"VirtualAlloc: resize block ", dwBase, " to ", ecx, " bytes, commit=", edx>
;--- int 31h, ax=505h: esi=handle, ecx=new size, edx=flags
;---   if dl bit 1=1 (never the case here): es:ebx=desc table, edi=size table
		@strace <"VirtualAlloc: int 31h, ax=505h, esi=", esi, ", ecx=", ecx, ", edx=", edx>
		mov ax, 0505h
		int 31h
		jnc @F
		@strace	<"VirtualAlloc: resize block (int 31h, ax=505h) failed!">
		mov g_bRealloc, 0	;no longer try to realloc
		xor esi, esi
		jmp isallocated
@@:
;------------------------------- dont allow base to change
		.if (ebx != dwBase)
			@strace <"VirtualAlloc: resize changed block address to ", ebx, ", new try!">
			push esi
			pop di
			pop si
			mov ax, 0502h
			int 31h
			mov g_bRealloc, 0	;dont use func 0505h any more
			jmp doagain
		.endif
		mov handle, esi
ifdef _DEBUG
		.if (dwSize > 200000h)
			sub esp,sizeof MEMORYSTATUS
			push esp
			call GlobalMemoryStatus
			add esp,sizeof MEMORYSTATUS
		.endif
endif
	.endif
endif
	xor esi, esi
	jmp isallocated
donormal:
	and ebx, ebx			;18.9.2004: is a base address given?
	jnz error				;then fail
endif        
	mov cx,word ptr dwSize+0
	mov bx,word ptr dwSize+2
if 0; def _DEBUG
	movzx ebx,bx
	movzx ecx,cx
	@strace <"VirtualAlloc: int 31h, ax=501h, bx=", ebx, ", cx=", ecx>
endif        
	mov ax,0501h
	int 31h
	jc error
	mov word ptr dwAddr+0,cx
	mov word ptr dwAddr+2,bx
	mov word ptr handle+0,di
	mov word ptr handle+2,si
	@mov esi,1
isallocated:        
ife ?FLAT					;NE/MZ (not-zero based models)
							;don't understand linear addresses
	mov eax, dwAddr
	invoke __lin2based
	mov dwAddr, eax
	mov ebx,ds
	lsl ebx,ebx
	cmp ebx,-1
	jz @F
	mov cx,-1			 ;set ds limit to -1
	mov dx,cx
	mov ebx,ds
	mov ax,0008
	int 31h
	push ds
	pop ds
	push es
	pop es
@@:
endif
;---- committed memory has to be zero initialized!
;---- if host doesnt support get/set page attribs, clear memory as well!
;
	.if ((fAllocType & MEM_COMMIT) || (esi))
		mov edi,dwAddr
		mov ecx,dwSize
		xor eax,eax
		shr ecx,2
		rep stosd
	.endif

	invoke _AddMemoryRegion, handle, dwBase, dwAddr, dwSize

	mov eax,dwAddr
	jmp done
error:
	xor eax,eax
done:
	@trace <"VirtualAlloc()=">
	@tracedw eax
	@trace <" dpmihdl=">
	@tracedw handle
	@trace <13,10>
	ret
	align 4
VirtualAlloc endp

;--- remove MBLOCK item from list
;--- EAX=MBLOCK item to remove
;--- EDX=MDESC
;--- modifies ESI, EDI, EAX, ECX

;--- MBLOCKS are stored as an array behind MDESC

RemoveBlock proc
	push eax
	@strace <"RemoveBlock: mblock item=", eax, " addr=", [eax].MBLOCK.dwAddr, " siz=", [eax].MBLOCK.dwSize, " hdl=", [eax].MBLOCK.dwHandle>
	@strace <"RemoveBlock: mdesc item=", edx, " nxt=", [edx].MDESC.pNext, " cnt=", [edx].MDESC.dwCnt, " hdl=", [edx].MDESC.dwHdl>
	mov edi,[eax].MBLOCK.dwHandle
	cmp edi, -1			;12/2013: don't try to free handle -1
	jz @F
	shld esi, edi, 16	;DPMI handle in SI:DI
	mov ax,0502h
	int 31h
@@:
	pop edi
	lea esi,[edi+sizeof MBLOCK]	;esi -> MBLOCK behind the deleted one

;--- calculate block index into EAX
	mov eax, edi
	sub eax, edx
	sub eax, sizeof MDESC
	shr eax, 4				;size of MBLOCK is 16!, MBLOCK index into EAX

if 1
	dec [edx].MDESC.dwCnt	;changed for v3.5 (GPF in Lynx)
	mov ecx,[edx].MDESC.dwCnt
else
	mov ecx,[edx].MDESC.dwCnt
	dec [edx].MDESC.dwCnt
endif
	sub ecx, eax
	shl ecx, 2				;1 item needs 4 DWORD to be copied
	rep movsd
	ret
	align 4
RemoveBlock endp        

;---- VirtualFree(DWORD dwAddress, DWORD dwSize, DWORD dwFreeType);

VirtualFree proc public uses ebx esi edi dwAddress:dword,dwSize:dword,dwFreeType:dword

ife ?FLAT
	mov eax, dwAddress
	invoke __based2lin
	mov dwAddress, eax
endif
	xor eax, eax
	test dwFreeType,MEM_RELEASE
	jnz @F
	test dwFreeType,MEM_DECOMMIT
	jz exit
	cmp dwSize, eax			;function fails if dwSize is zero
	jz exit
	invoke VirtualSetPageAttr, dwAddress, dwSize, 0, 1	;decommit
	jmp exit
@@:
	cmp dwSize, eax			;function fails if dwSize is not zero
	jnz exit
	invoke VirtualFindBlock, dwAddress
	.if (eax)
		call RemoveBlock
		@mov eax,1
	.endif
exit:
	@strace <"VirtualFree(", dwAddress, ", ", dwSize, ", ", dwFreeType, ")=", eax>
	ret
	align 4
VirtualFree endp

;--- on termination: free all memory blocks of current process

_FreeAllRegions proc public
	@strace <"_FreeAllRegions enter">
	pushad
;	@noints
	invoke GetCurrentProcess
	xor edx, edx
	xchg edx, [eax].PROCESS.pVirtual
	.while (edx)
		@strace <"_FreeAllRegions: block=", edx, " cnt=", [edx].MDESC.dwCnt, " hdl=", [edx].MDESC.dwHdl>
		mov ecx, [edx].MDESC.dwCnt
		jecxz noitem
		mov eax, ecx
		dec eax
		shl eax, 4	  ;size of MBLOCK is 16!  
		lea eax, [eax+edx+sizeof MDESC]
nextitem:
		push eax
		push ecx
		call RemoveBlock
		pop ecx
		pop eax
		sub eax, sizeof MBLOCK
		loop nextitem
noitem:
		mov esi,[edx].MDESC.dwHdl
		mov edx,[edx].MDESC.pNext
		mov edi, esi
		shr esi, 16
		mov ax,0502h
		int 31h
	.endw
;	@restoreints
	popad
	@strace <"_FreeAllRegions exit">
	ret
	align 4
_FreeAllRegions endp

end

