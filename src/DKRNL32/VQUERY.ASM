
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
	include macros.inc

?ILINK32SUPP	equ 1			;ILINK32.EXE needs special handling

if ?ILINK32SUPP

;--- there is the shared memory region of win9x, size 1 GB

?SHAREDREGIONBEGIN	equ 080000000h	;start of shared region
?SHAREDREGIONEND	equ 0C0000000h	;end of shared region

	.DATA

g_fSharedInit db 0

	.CODE

;--- inp: current linear address in esi
;--- returns next region in eax, previous in edx (or NULL)

_FindNextRegion proc public uses ebx edi pNext:ptr MBLOCK, pPrev:ptr MBLOCK

local	tBlock:MBLOCK

	call EnterSerialization
	call _RegionStart
	mov ebx, eax
	xor eax, eax
	xor edi, edi
	xor edx, edx
	.while (ebx)
		mov ecx,[ebx].MDESC.dwCnt
		jecxz nextdesc
		push ebx
		add ebx, sizeof MDESC
@@:
		push ecx
		call findprev_next
		add ebx, sizeof MBLOCK
		pop ecx
		loop @B
		pop ebx
nextdesc:
		mov ebx, [ebx].MDESC.pNext
	.endw

	xor eax, eax
if ?FLAT
	lea ebx, tBlock
	.while (1)
		push edx
		mov edx, eax
		mov ax, 4b83h
		int 21h
		pop edx
		and eax, eax
		jz done
		push eax
		mov [ebx].MBLOCK.dwAddr, eax
		add eax, [eax.IMAGE_DOS_HEADER.e_lfanew]
		mov eax, [eax.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage]
		mov [ebx].MBLOCK.dwSize, eax
		call findprev_next
		pop eax
	.endw
done:
endif
	push edx
	call LeaveSerialization
	pop edx
	mov eax, edi
	@strace <"VirtualQuery_FindNextRegion(", esi, ")=", edx, ":", eax>
	ret

;--- find what?
;--- EBX -> MBLOCK
;--- ESI = address to find?

findprev_next:
	mov ecx, [ebx].MBLOCK.dwAddr
	add ecx, [ebx].MBLOCK.dwSize
	.if ((esi >= [ebx].MBLOCK.dwAddr) && (esi < ecx))
		;
	.elseif (esi < [ebx].MBLOCK.dwAddr)
		.if (!edi)
			mov edi, ebx
			call copynblock
		.else
			mov ecx,[edi].MBLOCK.dwAddr
			.if (ecx > [ebx].MBLOCK.dwAddr)
				mov edi, ebx
				call copynblock
			.endif
		.endif
	.elseif (esi > [ebx].MBLOCK.dwAddr)
		.if (!edx)
			mov edx, ebx
			call copypblock
		.else
			mov ecx,[edx].MBLOCK.dwAddr
			.if (ecx < [ebx].MBLOCK.dwAddr)
				mov edx, ebx
				call copypblock
			.endif
		.endif
	.endif
	retn
copynblock:
	mov ecx,pNext
	jmp @F
copypblock:
	mov ecx,pPrev
@@:
	mov eax,[ebx].MBLOCK.dwAddr
	mov [ecx].MBLOCK.dwAddr,eax
	mov eax,[ebx].MBLOCK.dwSize
	mov [ecx].MBLOCK.dwSize,eax
	retn
	align 4
_FindNextRegion endp
endif

	.CODE

VirtualQuery proc public uses edi esi ebx pRegion:dword,pBuffer:ptr MEMORY_BASIC_INFORMATION,dwSize:dword

local	dwESP:DWORD
local	dwPages:DWORD
local	dwPagesPart:DWORD
local	dwLastBase:DWORD
local	myblock:MBLOCK
local	mbPrev:MBLOCK
local	mbNext:MBLOCK

	xor eax, eax
	cmp dwSize, sizeof MEMORY_BASIC_INFORMATION
	jnz exit
nexttry:
	mov esi, pRegion
	and si, 0F000h
	mov ecx, 1000h
	invoke _SearchRegion, addr myblock
	.if (eax)
		mov ebx, eax
		mov eax, [ebx].MBLOCK.dwSize
		shr eax, 12
		mov dwPages, eax
		mov dwESP, esp
		mov edi, [ebx].MBLOCK.dwAddr
		mov dwSize, 0
		mov dx, -1
		.while (eax)
			cmp eax,512
			jb @F
			mov eax,512
@@:
			mov dwPagesPart,eax
			sub esp, eax
			sub esp, eax
			@loadesp esi
			push edx
			invoke VirtualGetPageAttr, edi, esi, eax
			pop edx
			mov ecx, dwPagesPart
			.while (ecx)
				lodsw
				cmp ax,dx
				jz @F
				.if (edi > pRegion)
					mov esp,dwESP
					jmp nextstep
				.endif
				mov dx,ax
				mov dwSize, 0
				mov dwLastBase, edi
@@:
				add edi,1000h
				add dwSize, 1000h
				dec ecx
			.endw
			mov esp,dwESP
			mov eax, dwPages
			sub eax, dwPagesPart
			mov dwPages, eax
		.endw
nextstep:
		mov edi, pBuffer
		mov eax, dwLastBase
		mov ecx, [ebx].MBLOCK.dwAddr
		mov [edi].MEMORY_BASIC_INFORMATION.BaseAddress, eax 
		mov [edi].MEMORY_BASIC_INFORMATION.AllocationBase, ecx
		.if (dl & 8)
			mov [edi].MEMORY_BASIC_INFORMATION.AllocationProtect, PAGE_READWRITE
			mov [edi].MEMORY_BASIC_INFORMATION.Protect, PAGE_READWRITE
		.else
			mov [edi].MEMORY_BASIC_INFORMATION.AllocationProtect, PAGE_READONLY
			mov [edi].MEMORY_BASIC_INFORMATION.Protect, PAGE_READONLY
		.endif
		mov ecx, dwSize
		mov [edi].MEMORY_BASIC_INFORMATION.RegionSize, ecx
		.if (dl & 1)
			mov [edi].MEMORY_BASIC_INFORMATION.State, MEM_COMMIT
		.else
			mov [edi].MEMORY_BASIC_INFORMATION.State, MEM_RESERVE
		.endif
		mov [edi].MEMORY_BASIC_INFORMATION.Type_, MEM_PRIVATE
		mov esp, dwESP
		mov eax, sizeof MEMORY_BASIC_INFORMATION
if ?ILINK32SUPP
;--- this is an attempt to get ILINK32.EXE to work
;--- this program makes some rigid assumptions about memory layout
;--- and tries to find free address space for file mapping
;--- for this Virtualquery must work for any address in the range
;--- 80000000-C0000000. What's more, due to a bug in ILINK32 there
;--- should be some reserved areas (size 1 page) at the start and end
;--- of this block
	.elseif (esi < ?SHAREDREGIONEND)
		.if (!g_fSharedInit)
;---------------------------------- dont care if these calls succeed
			invoke VirtualAlloc, ?SHAREDREGIONBEGIN, 1000h, MEM_RESERVE, PAGE_NOACCESS
			invoke VirtualAlloc, ?SHAREDREGIONEND-1000h, 1000h, MEM_RESERVE, PAGE_NOACCESS
			mov g_fSharedInit, 1
			jmp nexttry
		.endif
		mov edi, pBuffer
		mov [edi].MEMORY_BASIC_INFORMATION.State, MEM_FREE
		mov [edi].MEMORY_BASIC_INFORMATION.AllocationProtect, 0
		mov [edi].MEMORY_BASIC_INFORMATION.Protect, 0
		mov [edi].MEMORY_BASIC_INFORMATION.Type_, MEM_PRIVATE
		invoke _FindNextRegion, addr mbNext, addr mbPrev
		.if (edx)
			mov esi, mbPrev.dwAddr
			add esi, mbPrev.dwSize
		.else
			@mov esi, 0
		.endif
		.if (eax)
			mov ecx, mbNext.dwAddr
		.else
			mov ecx, ?SHAREDREGIONEND
		.endif
		sub ecx, esi
		mov [edi].MEMORY_BASIC_INFORMATION.BaseAddress, esi
		mov [edi].MEMORY_BASIC_INFORMATION.AllocationBase, esi
		mov [edi].MEMORY_BASIC_INFORMATION.RegionSize, ecx
		mov eax, sizeof MEMORY_BASIC_INFORMATION
endif
	.endif
exit:
ifdef _DEBUG
	@strace <"VirtualQuery(", pRegion, ", ", pBuffer, ", ", dwSize, ")=", eax>
	.if (eax)
		mov edi,pBuffer
		@strace	<"base=", [edi].MEMORY_BASIC_INFORMATION.BaseAddress, " size=", [edi].MEMORY_BASIC_INFORMATION.RegionSize, " state=", [edi].MEMORY_BASIC_INFORMATION.State>
	.endif
endif
	ret
	align 4
VirtualQuery endp

VirtualQueryEx proc public hProcess:dword,pRegion:dword,pBuffer:dword,dwSize:dword

	xor eax,eax 		  ;0 = failure
	@strace <[ebp+4], ": VirtualQueryEx(", hProcess, ", ", pRegion, ", ", pBuffer, ", ", dwSize, ")=", eax, " *** unsupp ***">
	ret
	align 4
VirtualQueryEx endp

	end
