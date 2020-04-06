
;--- helper functions for virtual memory

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

?CLEAR	equ 1			;clear all pages that have been committed
?PAGES	equ 512			;count of page for which attributes are to be set
extern	__CHECKOS:abs

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

;--- get page attributes of a memory block
;--- size is in pages (todo: change this to bytes!)

VirtualGetPageAttr proc public uses ebx esi dwAddress:dword, pAttr:ptr WORD, dwSize:DWORD

local	myblock:MBLOCK

	mov esi, dwAddress
	mov ecx, dwSize
	shl ecx, 12
	invoke _SearchRegion, addr myblock
	.if (eax)
		mov ebx, dwAddress
		sub ebx, [eax].MBLOCK.dwBase
		mov esi, [eax].MBLOCK.dwHandle
		mov ecx, dwSize
		mov edx, pAttr
		mov ax, 0506h
		int 31h
		.if (CARRY?)
			.while (ecx)
				mov word ptr [edx],9	;r/w + commit
				inc edx
				inc edx
				dec ecx
			.endw
		.endif
	.endif
	@trace <"VirtualGetpageAttr ">
	@tracedw eax
	@trace <13,10>
	ret
	align 4

VirtualGetPageAttr endp

;--- size is in bytes!
;--- and all pages in the range will be modified, so a size of 2 bytes
;--- may modify 2 pages!
;--- if host doesnt support function 0x506h 
;--- and memory is to be uncommitted use 0x703h (discard page contents)
;--- else do nothing, the memory then (most likely) is already committed

VirtualSetPageAttr proc public uses ebx esi edi dwAddress:dword, dwSize:DWORD,
		attr:DWORD, wMask:DWORD

local	myblock:MBLOCK
local	dwESP:DWORD
local	dwPages:dword

	mov dwESP, esp
	mov esi, dwAddress
	mov ecx, dwSize
	invoke _SearchRegion, addr myblock
	.if (eax)
		mov ebx, esi
		mov esi, [eax].MBLOCK.dwHandle
		mov edi, [eax].MBLOCK.dwBase
ife ?FLAT
		mov eax, ebx
		invoke __based2lin
		mov ebx, eax
endif
		sub ebx, edi
		mov ecx, dwSize
		add ecx, ebx
		and bx, 0F000h
		sub ecx, ebx
		mov eax, ecx
		shr ecx, 12
		test ax,0FFFh
		jz @F
		inc ecx
@@:
		mov eax,attr
		and eax,wMask
		test al,1		;request to commit memory?
		jz notest
		.if (ecx > ?PAGES)	;more than 256 pages (1 MB?)
			push edi
			sub esp,12*4
			mov edi,esp
			mov ax,0500h
			int 31h
			cmp dword ptr [edi+20h],-1	;swapfile supplied
			jnz @F
			cmp ecx,[edi+14h]	;enough free physical memory
			jnc error
@@:
			add esp,12*4
			pop edi
		.endif
notest:
		.while (ecx)
			mov dwPages,ecx
if 0; def _DEBUG
			push edi
			sub esp,12*4
			mov edi,esp
			mov ax,0500h
			int 31h
			@strace <"free pages left: ", dword ptr [edi+14h], " required: ", ecx>
			add esp,12*4
			pop edi
endif
			mov edx, ?PAGES		;restrict pages for 1 DPMI call

			cmp ecx, edx
			jb @F
			mov ecx, edx
@@:
			mov eax, ecx
if ?CLEAR
			shl eax, 2
else
			inc eax
			and eax,not 1		;make it even so stack remains dword aligned
			shl eax, 1
endif
			sub esp, eax
			mov edx, esp

;			@strace <"int 31h, ax=506h, hdl=", esi, " ofs=", ebx, " pgs=", ecx, " ptr=", edx>
			mov	ax, 0506h
			int 31h
;			jc error
			jc no10host
			pushad
			mov esi, edx
			mov edx, attr
			mov ebx, wMask
			not bx
if ?CLEAR
			lea edi, [esi+ecx*2]
endif
			.while (ecx)
				lodsw
				and ax, bx
				or ax, dx
if ?CLEAR
				stosw
else
				mov [esi-2],ax
endif
				dec ecx
			.endw
			popad
if ?CLEAR
			lea edx,[edx+2*ecx]
endif
;			@strace <"int 31h, ax=507h, hdl=", esi, " ofs=", ebx, " pgs=", ecx, " ptr=", edx>
			mov ax, 0507h
			int 31h
			jc error		;this is a real error!
if ?CLEAR
			pushad
			add edi, ebx
ife ?FLAT
			mov eax, edi
			call __lin2based
			mov edi, eax
endif
			mov ebx, edx
			sub ebx, ecx
			sub ebx, ecx
;--- clear the newly committed, writable pages!
			.while (ecx)
				mov al,[edx]
				and al,1+8
				cmp al,1+8				;is new state committed + writable?
				jnz dont_clear
				test byte ptr [ebx],1	;or was page already committed?
				jnz  dont_clear
				push edi
				push ecx
				mov ecx, 1000h/4
				xor eax, eax
;				@strace <"clear edi=", edi, " ecx=", ecx>
				rep stosd
				pop ecx
				pop edi
dont_clear:
				add edi, 1000h
				add edx, 2
				add ebx, 2
				dec ecx
			.endw
			popad
endif
			mov edx,ecx
			mov esp,dwESP
			mov ecx,dwPages
			sub ecx,edx
			shl edx,12
			add ebx,edx
		.endw
exitok:
		@mov eax, 1
	.endif
exit:
	mov esp, dwESP
	@strace <"VirtualSetPageAttr(", dwAddress, ", ", dwSize, ", ", attr, ", ", wMask, ")=", eax>
	ret
error:
if 0;def _DEBUG
	int 3
endif
	xor eax, eax
	jmp exit
no10host:
	test byte ptr wMask,1	;is the commit flag to be set/unset?
	jz exitok
	test byte ptr attr,1	;is the commit flag to be set?
	jnz exitok
	push dwAddress
	pop cx
	pop bx
	push dwSize
	pop di
	pop si
	mov ax,0703h		;discard page contents
	int 31h				;on win9x this will free the pages
	jmp exitok
	align 4

VirtualSetPageAttr endp

	end

