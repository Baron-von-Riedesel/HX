
;--- modify/extract section contents of/from a PE binary
;--- copyright japheth.

	.386
	.MODEL FLAT, stdcall
	option casemap:none
	option proc:private

PDWORD typedef ptr DWORD	;required by winnt.inc
_CRTAPI1 equ <c>			;required by stdlib.inc

	.nolist
	.nocref
	include winasm.inc
	include winnt.inc
	include string.inc
	include stdlib.inc
	include stdio.inc
	.list
	.cref

lf	equ 0Ah
cr	equ 0Dh

CStr macro text:VARARG
local x
	.const
x	db text,0
	.code
	exitm <offset x>
	endm

_setargv proto c

	.DATA

;LPSTR typedef ptr BYTE

pFileOut	DWORD 0		;handle for file to write
pFileInp	DWORD 0		;file pointer for input file
pszFileInp 	LPSTR 0
pszFileOut 	LPSTR 0
pOldStub	LPSTR 0

pObjtab		LPSTR 0		;dyn allocated memory for object table
dwObjSize	DWORD 0		;size of object table
dwSection	DWORD 0		;section number for cmd a, d, x
dwVA		DWORD 0		;VA for cmd a
dwLower		DWORD 0		;VA lower bound of section n
dwUpper		DWORD 0		;VA upper bound of section n
fVerbose	BYTE 0		;-v, display all msgs
fQuiet		BYTE 0		;-q, no displays
fInclude	BYTE 0		;-i,generate assembly include file
fWriteHdr	BYTE 0		;-h, automatically set by cmds a, d
fAddMZ		BYTE 0		;-m
bCmd		BYTE 0		;cmd given (a, d, x)
fWriteStub	BYTE 0		;set by cmds a, d
fExpectNumber	BYTE 0	;set by cmds a, d, x
fExpectVA	BYTE 0		;set by cmd a

_errno	dd 0

	.CONST

szLF	db lf,0

	.data?

mzhdr IMAGE_DOS_HEADER <>
pehdr IMAGE_NT_HEADERS <>

	.CODE

;--- get a decimal number
;--- esi -> text
;--- out: number in EAX
;--- C on error

getdec proc
	mov cl,0
	xor edx, edx
nextitem:
	lodsb
	cmp al,'0'
	jb done
	cmp al,'9'
	ja done
	push eax
	mov eax,edx
	mov edx,10
	mul edx
	mov edx, eax
	pop eax
	sub al,'0'
	movzx eax,al
	add edx, eax
	inc cl
	jmp nextitem
done:
	dec esi
	mov eax, edx
	cmp cl,1
	ret
getdec endp

gethex proc
	mov cl,0
	xor edx, edx
nextitem:
	lodsb
	cmp al,'0'
	jb done
	sub al,'0'
	cmp al,9
	jbe @F
	and al,not 20h
	cmp al,11h
	jb done
	cmp al,16h
	ja done
	sub al,7
@@:
	shl edx,4
	movzx eax,al
	add edx, eax
	inc cl
	jmp nextitem
done:
	dec esi
	mov eax, edx
	cmp cl,1
	ret
gethex endp

findsection proc uses ebx dwAddr:dword

	mov eax, pObjtab
	movzx ecx, pehdr.FileHeader.NumberOfSections
	mov edx, dwAddr
	.while ecx
		mov ebx, [eax].IMAGE_SECTION_HEADER.VirtualAddress
		add ebx, [eax].IMAGE_SECTION_HEADER.Misc.VirtualSize
		.if edx >= [eax].IMAGE_SECTION_HEADER.VirtualAddress && edx < ebx
			mov ecx, eax
			.break
		.endif
		add eax, sizeof IMAGE_SECTION_HEADER
		dec ecx
	.endw
	mov eax, ecx
	ret
findsection endp

;--- adjust relocations for a, d and x cmd
;--- a cmd: relocations that refer to the section with
;---        the new VA must be adjusted ( >= dwUpper, < dwLower).
;---        relocations that refer to the section with the new VA
;---        are changed to abs.
;--- d cmd: relocations that belong to the section to be deleted
;---        must also be deleted.
;---        relocations that refer to the section to be deleted
;---        are changed to abs (should be none).
;--- x cmd: nothing done

handle_relocs proc uses ebx esi edi pSection:ptr IMAGE_SECTION_HEADER

local	dwEndRelocs:DWORD
local	dwBlockSize:dword
local	pRelocSec:ptr IMAGE_SECTION_HEADER
local	dwRemoved:dword

;--- get the .reloc section
	invoke findsection, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	mov pRelocSec, eax
	.if (fVerbose)
		invoke printf, CStr(".reloc section: RVA=%lX, size=%lX",lf), [eax].IMAGE_SECTION_HEADER.VirtualAddress, [eax].IMAGE_SECTION_HEADER.Misc.VirtualSize
	.endif

	mov edi, pSection
	.if bCmd == 'a'
		;--- "rebase" a section
		mov edx, dwVA
		add edx, pehdr.OptionalHeader.ImageBase
		add edx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
	.elseif bCmd == 'x'
		;--- PE header to be written? If no, fixups needn't be adjusted 
;		cmp [fWriteHdr],1
;		jz done
;		mov edx, pehdr.OptionalHeader.SizeOfHeaders
		jmp done
	.elseif bCmd == 'd'
		;--- nothing to do
	.endif

	mov ecx, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].Size_
	mov edi, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	.if (fVerbose)
		pushad
		invoke printf, CStr("OptionalHeader Base Relocations: RVA=%lX, size=%lX",lf), edi, ecx
		popad
	.endif

	add edi, esi
	lea ecx, [edi+ecx]
	mov dwEndRelocs, ecx
;	push edi
	mov dwRemoved,0
nextpage:
if 0
	mov eax, edi
	mov ecx, dwEndRelocs
	sub eax, esi
	sub ecx, esi
	invoke printf, CStr("relocation ptr %lX, end=%lX",lf), eax, ecx
endif
	cmp edi, dwEndRelocs
	jae reldone
	mov ebx, [edi].IMAGE_BASE_RELOCATION.VirtualAddress
	mov ecx, [edi].IMAGE_BASE_RELOCATION.SizeOfBlock
	and ecx,ecx
	jz reldone
	.if fVerbose
		pushad
		invoke printf, CStr("relocations for RVA=%lX, size=%lX",lf), ebx, ecx
		popad
	.endif
	mov dwBlockSize, ecx
	add ecx, edi
	.if bCmd == 'd'
		mov eax, ebx
		add eax, pehdr.OptionalHeader.ImageBase
		.if eax >= dwLower && eax < dwUpper
			.if fVerbose
				invoke printf, CStr("d cmd: relocations for RVA=%lX, size=%lX removed",lf),
					ebx, [edi].IMAGE_BASE_RELOCATION.SizeOfBlock
			.endif
			push esi
			mov esi, edi
			add esi, dwBlockSize
			mov ecx, dwEndRelocs
			sub ecx, esi
			push edi
			rep movsb
			pop edi
			pop esi
			mov eax, dwBlockSize
			sub pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].Size_, eax
			sub dwEndRelocs, eax
			mov ecx, pRelocSec
			sub [ecx].IMAGE_SECTION_HEADER.Misc.VirtualSize, eax
			cmp edi, dwEndRelocs
			jb nextpage
			mov [edi].IMAGE_BASE_RELOCATION.VirtualAddress,0
			mov [edi].IMAGE_BASE_RELOCATION.SizeOfBlock,0
			jmp nextpage
		.endif
	.endif
	add edi, sizeof IMAGE_BASE_RELOCATION
	.while (ecx > edi)
		mov ax,[edi]
		.if (ah & 0F0h)
			push ecx
			mov cl,ah
			shr cl,4
			and eax,0FFFh
			add eax, ebx
			.if bCmd == 'a'
				.if cl == IMAGE_REL_BASED_LOW
					movzx ecx,word ptr [esi+eax]
					.if ( ecx >= dwLower && ecx < dwUpper )
						inc dwRemoved
						sub [esi+eax],dx
						and word ptr [edi],0fffh
					.endif
				.elseif cl == IMAGE_REL_BASED_HIGHLOW
					mov ecx,[esi+eax]
					.if ( ecx >= dwLower && ecx < dwUpper )
						inc dwRemoved
						sub [esi+eax],edx
						and word ptr [edi],0fffh
					.endif
				.else
					pushad
					movzx ecx,cx
					sub edi, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
					invoke printf, CStr(<"cannot handle base reloc %X at .reloc.%lX",lf>), ecx, edi
					popad
				.endif
			.elseif bCmd == 'x'
				.if cl == IMAGE_REL_BASED_LOW
					sub [esi+eax],dx
				.elseif cl == IMAGE_REL_BASED_HIGHLOW
					sub [esi+eax],edx
				.else
					pushad
					movzx ecx,cx
					sub edi, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
					invoke printf, CStr(<"cannot handle base reloc %X at .reloc.%lX",lf>), ecx, edi
					popad
				.endif
			.elseif bCmd == 'd'
				.if cl == IMAGE_REL_BASED_LOW
					movzx ecx,word ptr [esi+eax]
					.if ( ecx >= dwLower && ecx < dwUpper )
						inc dwRemoved
						and word ptr [edi],0fffh
					.endif
				.elseif cl == IMAGE_REL_BASED_HIGHLOW
					mov ecx,[esi+eax]
					.if ( ecx >= dwLower && ecx < dwUpper )
						inc dwRemoved
						and word ptr [edi],0fffh
					.endif
				.endif
			.endif
			pop ecx
		.endif
		add edi,2
	.endw
	jmp nextpage
reldone:
;	pop edi
;	mov [edi],dx		;save size of header in first page ofs
done:
	.if (fVerbose)
		invoke printf, CStr("relocations done, %lu modified",lf), dwRemoved
	.endif
	ret
handle_relocs endp

compress_relocs proc uses ebx esi edi pImage:ptr

local dwAddr:dword
local dwSize:dword
local dwOldSrc:dword
local pRelocs:dword

	mov ebx, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].Size_
	mov edi, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	invoke findsection, edi
	mov pRelocs, eax
	mov esi, pImage
	add esi, edi
	mov edi, esi
	.while ebx
		.if fVerbose
			pushad
			invoke printf, CStr("compress: block %lX, old size=%lX"),
				[esi].IMAGE_BASE_RELOCATION.VirtualAddress, [esi].IMAGE_BASE_RELOCATION.SizeOfBlock
			popad
		.endif
		mov dwAddr, edi
		mov dwOldSrc, esi
		mov edx, [esi].IMAGE_BASE_RELOCATION.SizeOfBlock
		mov dwSize, edx
		mov ecx, sizeof IMAGE_BASE_RELOCATION
		sub edx, ecx
		rep movsb
		.while edx
			lodsw
			.if ah & 0f0h
				stosw
			.endif
			sub edx,2
		.endw
		mov ecx, edi
		sub ecx, dwAddr
		test cl,2
		jz @F
		add ecx,2
		xor ax,ax
		stosw
@@:
		mov edx,dwAddr
		mov [edx].IMAGE_BASE_RELOCATION.SizeOfBlock, ecx
		test esi,2
		jz @F
		add esi,2
@@:
		.if fVerbose
			pushad
			invoke printf, CStr(", new size=%lX",lf),
				[edx].IMAGE_BASE_RELOCATION.SizeOfBlock
			popad
		.endif
		mov eax, esi
		sub eax, dwOldSrc
		sub ebx, eax
	.endw
	mov ecx, esi
	sub ecx, edi
	shr ecx,1
	push edi
	xor eax,eax
	rep stosw
	pop edi
	mov edx, pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress
	add edx, pImage
	mov eax, edi
	sub eax, edx
	mov pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].Size_, eax
	mov ecx, pRelocs
	mov [ecx].IMAGE_SECTION_HEADER.Misc.VirtualSize, eax
	push eax
	mov edx, pehdr.OptionalHeader.FileAlignment
	dec edx
	add eax, edx
	not edx
	and eax, edx
	mov [ecx].IMAGE_SECTION_HEADER.SizeOfRawData, eax
	pop eax
	.if fVerbose
		invoke printf, CStr("compress: new size of base relocations=%lX",lf), eax
	.endif
	ret
compress_relocs endp

;--- special handling of d cmd

d_cmd proc uses ebx esi edi pImage:ptr

local dwRawSize:dword
local dwVSize:dword
local dwVAddress:dword

;--- remove the abs base relocs
	invoke compress_relocs, pImage

;--- locate the section in the object table
	mov edi, pObjtab
	mov eax, dwSection
	mov edx, sizeof IMAGE_SECTION_HEADER
	mul edx
	add edi, eax

	mov eax, pehdr.OptionalHeader.AddressOfEntryPoint   
	mov edx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
	add edx, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
	.if eax >= [edi].IMAGE_SECTION_HEADER.VirtualAddress && eax < edx
		mov pehdr.OptionalHeader.AddressOfEntryPoint,0
	.endif

;--- save the sections params (raw & virtual size)
	mov eax, [edi].IMAGE_SECTION_HEADER.SizeOfRawData
	mov dwRawSize, eax
	mov eax, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
	mov ecx, pehdr.OptionalHeader.SectionAlignment
	dec ecx
	lea eax, [eax+ecx]
	not ecx
	and eax, ecx
	mov dwVSize, eax

;--- delete the section contents in the image
	mov esi, pImage
	add esi, [edi].IMAGE_SECTION_HEADER.VirtualAddress
	mov eax, dwVSize
	mov ecx, pehdr.OptionalHeader.SizeOfImage
	sub ecx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
	sub ecx, eax
	push edi
	mov edi, esi
	add esi, eax
	.if fVerbose
		pushad
		sub edi, pImage
		invoke printf, CStr("d cmd: deleting %lX bytes from the image at RVA=%lX",lf), eax, edi
		popad
	.endif
	rep movsb
	pop edi

;--- adjust image size
	sub pehdr.OptionalHeader.SizeOfImage, eax
;--- if section contains reloc info, remove the reloc data directory entry
	mov ecx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
	.if ( ecx == pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress )
		mov pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].VirtualAddress, 0
		mov pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].Size_, 0
	.endif

;--- delete the section header by copying the remaining section headers
;--- to the current one
	lea esi, [edi+sizeof IMAGE_SECTION_HEADER]
	movzx ecx, pehdr.FileHeader.NumberOfSections
	sub ecx,dwSection
	jbe @F
	dec ecx
	jz @F
	mov eax, ecx
	push ecx
	mov ecx, sizeof IMAGE_SECTION_HEADER
	mul ecx
	mov ecx, eax
	push edi
	rep movsb
	pop edi
	pop ecx

;--- adjust raw & virtual addresses of the following sections
	mov eax, dwRawSize
	mov edx, dwVSize
	.while ecx
		push eax
		push ecx
		lea ecx,pehdr.OptionalHeader.DataDirectory
		.while ecx < offset pehdr.OptionalHeader.DataDirectory[IMAGE_DATA_DIRECTORY * IMAGE_NUMBEROF_DIRECTORY_ENTRIES]
			mov eax, [edi].IMAGE_SECTION_HEADER.VirtualAddress
			.if [ecx].IMAGE_DATA_DIRECTORY.VirtualAddress == eax
				sub [ecx].IMAGE_DATA_DIRECTORY.VirtualAddress, edx
			.endif
			add ecx, sizeof IMAGE_DATA_DIRECTORY
		.endw
		pop ecx
		pop eax
		.if ebx
			sub [ebx].IMAGE_SECTION_HEADER.PointerToRawData, eax
		.endif
		sub [edi].IMAGE_SECTION_HEADER.PointerToRawData, eax
		sub [edi].IMAGE_SECTION_HEADER.VirtualAddress, edx
		add edi, sizeof IMAGE_SECTION_HEADER
		dec ecx
	.endw
@@:
	dec pehdr.FileHeader.NumberOfSections
	ret
d_cmd endp

;--- get cmd

getcmd proc pszArgument:LPSTR

	mov edx, pszArgument
	mov eax,[edx]
	cmp ax,"a"
	jnz @F
	mov fExpectNumber, 1
	mov fExpectVA, 1
	mov fWriteStub, 1
	mov fWriteHdr, 1
	jmp done
@@:
	cmp ax,"d"
	jnz @F
	mov fExpectNumber, 1
	mov fWriteStub, 1
	mov fWriteHdr, 1
	jmp done
@@:
	cmp ax,"x"
	jnz @F
	mov fExpectNumber, 1
	jmp done
@@:
	stc
	ret
done:
	mov bCmd,al
	clc
	ret
	
getcmd endp

;--- get param for cmd

getparm proc uses esi pszArgument:LPSTR

	mov esi, pszArgument
;	invoke printf, CStr(<"arg=>%s<",lf>), esi
	call getdec
	jc error
	mov dwSection, eax
	.if fExpectVA
		cmp byte ptr [esi],'='
		jnz error
		inc esi
		call gethex
		jc error
		mov dwVA, eax
		mov fExpectVA, 0
	.endif
	mov fExpectNumber, 0
	clc
	ret
error:
	stc
	ret
getparm endp

;--- scan command line for options

getoption proc pszArgument:LPSTR

	mov eax, pszArgument
	mov eax,[eax]
	shr eax,8
	or al,20h

	cmp ax,"h"
	jnz @F
	mov fWriteHdr, 1
	ret
@@:
	cmp ax,"i"
	jnz @F
	mov fInclude, 1
	ret
@@:
	cmp ax,"m"
	jnz @F
	mov fAddMZ, 1
	ret
@@:
	cmp ax,"q"
	jnz @F
	mov fQuiet, 1
	ret
@@:
	cmp ax,"v"
	jnz @F
	mov fVerbose, 1
	ret
@@:
	stc
	ret
getoption endp

;--- write content of a section

WriteContent proc pMem:ptr, dwSize:dword

local	szLine[80]:byte

	.if (fInclude)
		pushad
		mov esi,pMem
		mov ecx,dwSize
		mov ebx,0
		.while (ecx >= 16)
			push ecx
			mov ecx, 16
			sub esp, 16*4
			mov edi, esp
			xor eax, eax
@@:
			lodsb
			stosd
			loop @B
			invoke sprintf, addr szLine, CStr("db %3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u,%3u",cr,lf )
			add esp, 16*4
			invoke fwrite, addr szLine, 1, eax, pFileOut
			pop ecx
			sub ecx,16
		.endw
		.if (ecx)
			push ecx
			lea ebx, szLine
			invoke sprintf, ebx, CStr("db ")
			add ebx, eax
			pop ecx
			.repeat
				xor eax, eax
				lodsb
				push ecx
				.if (ecx > 1)
					invoke sprintf, ebx, CStr("%3u,"), eax
				.else
					invoke sprintf, ebx, CStr("%3u",cr,lf), eax
				.endif
				pop ecx
				add ebx, eax
				dec ecx
			.until (ecx == 0)
			invoke strlen, addr szLine
			invoke fwrite, addr szLine, 1, eax, pFileOut
		.endif
		popad
	.else
		invoke fwrite, pMem, 1, dwSize, pFileOut
		.if (eax != dwSize)
			invoke printf, CStr("file write error",lf)
			xor eax, eax
		.endif
	.endif
	ret
WriteContent endp

;*** main proc ***

main proc c public argc:dword,argv:dword

local	dwWritten:DWORD
local	dwSizeStubOld:DWORD
local	bError:DWORD


	mov pFileInp, 0
	mov pFileOut, 0
	mov bError, 1
	cmp argc,2
	jb displayusage
	mov ecx, 1
	mov ebx,argv
	.while (ecx < argc)
		push ecx
		mov eax, dword ptr [ebx+ecx*4]
		.if byte ptr [eax] == '/' || byte ptr [eax] == '-'
			invoke getoption, eax
		.elseif !bCmd
			invoke getcmd, eax
		.elseif fExpectNumber
			invoke getparm, eax
		.elseif !pszFileInp
			mov pszFileInp, eax
		.elseif !pszFileOut
			mov pszFileOut, eax
		.else
			stc
		.endif
		pop ecx
		jc displayusage
		inc ecx
	.endw
	cmp pszFileOut, 0
	jz displayusage
;--------------------------- open input binary

	invoke fopen, pszFileInp, CStr("rb")
	.if (eax == 0)
		invoke printf, CStr("cannot open file %s [%X]",lf), pszFileInp, errno
		jmp main_ex
	.endif
	mov pFileInp,eax

	invoke fread, addr mzhdr, 1, sizeof mzhdr, pFileInp
	.if (eax != 40h)
		invoke printf, CStr("%s is not a valid executable",lf), pszFileInp
		jmp main_ex
	.endif
	movzx eax, mzhdr.e_magic
;----------------------------------------- is it a executable?
	.if (eax == "ZM")
		movzx eax, mzhdr.e_cparhdr	;size of header
		.if eax < 4
			invoke printf, CStr("Size of MZ header of %s is < 40h",lf), pszFileInp
			jmp main_ex
		.endif
		mov eax, mzhdr.e_lfanew
		mov dwSizeStubOld, eax
	.else
		invoke printf, CStr("%s is not an MZ binary object",lf), pszFileInp
		jmp main_ex
	.endif

	invoke fseek, pFileInp, 40h, SEEK_SET
	mov eax, dwSizeStubOld
	sub eax, sizeof IMAGE_DOS_HEADER
	.if CARRY?
		invoke printf, CStr("error: position of new header within MZ header",lf)
		jmp main_ex
	.endif
	invoke malloc, eax
	.if (!eax)
		invoke printf, CStr("error: out of memory",lf)
		jmp main_ex
	.endif
	mov pOldStub, eax
	mov ecx, dwSizeStubOld
	sub ecx, sizeof IMAGE_DOS_HEADER
	invoke fread, pOldStub, 1, ecx, pFileInp 

	invoke fseek, pFileInp, dwSizeStubOld, SEEK_SET
	.if (eax == -1)
		invoke printf, CStr("%s is not a PE binary - fseek() failed",lf),pszFileInp
		jmp main_ex
	.endif
	invoke memset, addr pehdr, 0, sizeof pehdr
	invoke fread, addr pehdr.Signature, 1, sizeof IMAGE_NT_HEADERS.Signature, pFileInp 
	.if (eax != sizeof IMAGE_NT_HEADERS.Signature )
		invoke printf, CStr("%s has no valid PE format - read() failed",lf), pszFileInp
		jmp main_ex
	.endif
	movzx eax,word ptr pehdr
	.if eax != "EP" && eax != "XP"
		invoke printf, CStr("%s has no valid PE|PX format - magic bytes PE|PX not found",lf), pszFileInp
		jmp main_ex
	.endif
	invoke fread, addr pehdr.FileHeader, 1, sizeof IMAGE_NT_HEADERS.FileHeader, pFileInp 
	.if (eax != sizeof IMAGE_NT_HEADERS.FileHeader)
		invoke printf, CStr("Error reading PE FileHeader",lf)
		jmp main_ex
	.endif
	invoke memset, addr pehdr.OptionalHeader, 0, sizeof pehdr.OptionalHeader
	movzx eax, pehdr.FileHeader.SizeOfOptionalHeader
	.if (eax > sizeof IMAGE_OPTIONAL_HEADER)
		invoke printf, CStr("Size of PE optional Header too large",lf)
		jmp main_ex
	.endif
	push eax
	invoke fread, addr pehdr.OptionalHeader, 1, eax, pFileInp 
	pop ecx
	.if (eax != ecx)
		invoke printf, CStr("Error reading PE optional Header",lf)
		jmp main_ex
	.endif

	.if (fVerbose)
		invoke printf, CStr("loading object table...",lf)
	.endif

	movzx eax,pehdr.FileHeader.NumberOfSections
	mov ecx,sizeof IMAGE_SECTION_HEADER
	mul ecx
	mov dwObjSize,eax
	invoke malloc, eax
	.if (!eax)
		invoke printf, CStr("error: out of memory",lf)
		jmp main_ex
	.endif
	mov pObjtab, eax
	invoke fread, pObjtab, 1, dwObjSize, pFileInp
	.if (eax != dwObjSize)
		invoke printf, CStr("Couldn't read object table",lf)
		jmp main_ex
	.endif

	invoke malloc, pehdr.OptionalHeader.SizeOfImage
	.if (!eax)
		invoke printf, CStr("error: out of memory (image size=%lX)",lf), pehdr.OptionalHeader.SizeOfImage
		jmp main_ex
	.endif
	mov esi, eax

	movzx ecx, pehdr.FileHeader.NumberOfSections
	mov edi, pObjtab
	.while (ecx)
		push ecx
		.if ([edi].IMAGE_SECTION_HEADER.SizeOfRawData)
			invoke fseek, pFileInp, [edi].IMAGE_SECTION_HEADER.PointerToRawData, SEEK_SET
			mov ecx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
			add ecx, esi
			invoke fread, ecx, 1, [edi].IMAGE_SECTION_HEADER.SizeOfRawData, pFileInp
			.if (eax != [edi].IMAGE_SECTION_HEADER.SizeOfRawData)
				invoke printf, CStr("error reading data of section %.8s; size=%lX, read=%lX",lf), addr [edi].IMAGE_SECTION_HEADER.Name_, [edi].IMAGE_SECTION_HEADER.SizeOfRawData, eax
				jmp main_ex
			.endif
		.endif
		pop ecx
		add edi, sizeof IMAGE_SECTION_HEADER
		dec ecx
	.endw

	invoke fclose, pFileInp
	mov pFileInp, 0

;--- get the section's lower and upper bounds
	mov eax, dwSection
	movzx ecx, pehdr.FileHeader.NumberOfSections
	cmp eax, ecx
	jb @F
	.if ecx
		dec ecx
		invoke printf, CStr("error: section %u does not exist, valid sections=0-%u",lf), eax, ecx
	.else
		invoke printf, CStr("error: section %u does not exist, binary contains no sections",lf), eax
	.endif
	jmp main_ex
@@:
	mov edi, pObjtab
	mov edx, sizeof IMAGE_SECTION_HEADER
	mul edx
	add edi, eax
	mov ecx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
	add ecx, pehdr.OptionalHeader.ImageBase
	mov dwLower, ecx
	add ecx, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
	mov dwUpper, ecx

	.if fVerbose
		invoke printf, CStr("Image Base=%lX, section %u: name=%.8s, RVA=%lX, bounds=%lX-%lX",lf),
			pehdr.OptionalHeader.ImageBase, dwSection, addr [edi].IMAGE_SECTION_HEADER.Name_,
			[edi].IMAGE_SECTION_HEADER.VirtualAddress, dwLower, dwUpper
	.endif

;--- if relocations exist, adjust them
	.if pehdr.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC*sizeof IMAGE_DATA_DIRECTORY].Size_
		invoke handle_relocs, edi
	.endif

	.if bCmd == 'd'
		invoke d_cmd, esi
	.endif

	invoke fopen, pszFileOut, CStr("wb")
	.if (!eax)
		invoke printf, CStr("cannot create file '%s' [%X]",lf), pszFileOut, errno
		jmp main_ex
	.endif
	mov pFileOut, eax

	.if (fWriteStub)
		invoke WriteContent, addr mzhdr, sizeof mzhdr
		mov eax, dwSizeStubOld
		sub eax, 40h
		invoke WriteContent, pOldStub, eax
		.if (fVerbose)
			invoke printf, CStr("MZ header and stub written",lf)
		.endif
	.endif

	.if (fWriteHdr)
		invoke WriteContent, addr pehdr, sizeof pehdr
		.if (fVerbose)
			invoke printf, CStr("PE header written",lf)
		.endif
		movzx ecx, pehdr.FileHeader.NumberOfSections
		mov eax, sizeof IMAGE_SECTION_HEADER
		mul ecx
		invoke WriteContent, pObjtab, eax
		.if (fVerbose)
			invoke printf, CStr("section table written",lf)
		.endif
		invoke fseek, pFileOut, pehdr.OptionalHeader.SizeOfHeaders, SEEK_SET
	.endif

	mov edi, pObjtab
	.if bCmd == 'x'
		mov eax, dwSection
		mov edx, sizeof IMAGE_SECTION_HEADER
		mul edx
		add edi, eax
		.if fAddMZ
			mov mzhdr.e_lfanew, 0
			mov eax, pehdr.OptionalHeader.AddressOfEntryPoint   
			mov edx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
			add edx, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
			.if eax >= [edi].IMAGE_SECTION_HEADER.VirtualAddress && eax < edx
				sub eax, [edi].IMAGE_SECTION_HEADER.VirtualAddress
				mov mzhdr.e_ip, ax
			.endif
			mov eax, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
			mov edx, eax
			shr eax,9
			.if dx & 1ffh
				inc eax
			.endif
			and dx,01ffh
			mov mzhdr.e_cblp, dx
			mov mzhdr.e_cp, ax
			mov eax, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
			shr eax, 4
			mov mzhdr.e_ss, ax
			mov mzhdr.e_sp, 200h
			invoke WriteContent, addr mzhdr, sizeof mzhdr
		.endif
		mov ecx, 1
	.elseif bCmd == 'd'
		movzx ecx, pehdr.FileHeader.NumberOfSections
	.else
		movzx ecx, pehdr.FileHeader.NumberOfSections
	.endif

;--- write ECX sections, starting with EDI
;--- write the physical size if PE header is also written 

	.while (ecx)
		push ecx
		.if ([edi].IMAGE_SECTION_HEADER.SizeOfRawData)
;			 invoke fwrite, addr [edi].IMAGE_SECTION_HEADER.SizeOfRawData, 1, 4, pFileOut 
			mov ecx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
			add ecx, esi
;			invoke fwrite, ecx, 1, [edi].IMAGE_SECTION_HEADER.SizeOfRawData, pFileOut
;			.if (eax != [edi].IMAGE_SECTION_HEADER.SizeOfRawData)
			.if (fWriteHdr)
				invoke WriteContent, ecx, [edi].IMAGE_SECTION_HEADER.SizeOfRawData
			.else
				invoke WriteContent, ecx, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
			.endif
			.if (fVerbose)
				invoke printf, CStr("section %.8s written",lf), addr [edi].IMAGE_SECTION_HEADER.Name_
			.endif
		.endif
		pop ecx
		add edi, sizeof IMAGE_SECTION_HEADER
		dec ecx
	.endw
file_done:
	invoke free, esi

	.if (!fQuiet)
		invoke printf, CStr("editpe: file '%s' processed",lf), pszFileInp
	.endif

	mov bError, 0
main_ex:
	.if ( pFileOut )
		invoke fclose, pFileOut
	.endif
	.if ( pFileInp )
		invoke fclose, pFileInp
	.endif
	mov eax, bError
	ret
displayusage:
	invoke printf, CStr("editpe v1.4: modify/extract contents of/from a PE binary",lf)
	invoke printf, CStr("usage: editpe [options] cmd src_file dst_file",lf)
	invoke printf, CStr("  cmd:",lf)
	invoke printf, CStr("    a n=v: change virtual address of section <n> to <v>",lf)
	invoke printf, CStr("      if relocs exist, all references to this section are adjusted",lf)
	invoke printf, CStr("    d n: delete section <n>",lf)
	invoke printf, CStr("    x n: extract section <n>",lf)
	invoke printf, CStr(" <n> is the section number in decimal, starting with 0",lf)
	invoke printf, CStr(" <v> is a hexadecimal address",lf)
	invoke printf, CStr("  options:",lf)
	invoke printf, CStr("    -h: add PE header to extracted section (cmd x)",lf)
	invoke printf, CStr("    -i: write output as assembly include file",lf)
	invoke printf, CStr("    -m: add MZ header to extracted section (cmd x)",lf)
	invoke printf, CStr("    -q: quiet",lf)
	invoke printf, CStr("    -v: verbose",lf)
	jmp main_ex
main endp

	END

