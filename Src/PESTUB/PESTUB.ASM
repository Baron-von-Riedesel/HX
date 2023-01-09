
;--- replaces stub of a PE executable

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL small, stdcall
endif
	option casemap:none
	option proc:private

	.nolist
	.nocref
	include windef.inc
	include winbase.inc
	include wincon.inc
	include macros.inc
	include pe64.inc
	.cref
	.list

?WOPT equ 0
?XOPT equ 0
?ZOPT equ 0

LPSTR	typedef ptr BYTE
lf		equ 0Ah

	.DATA

hStdOut 		DWORD 0
hFileOut		DWORD 0		;handle for file to write
hFileInp		DWORD 0		;handle for input file
pszFilename		LPSTR 0
pszStubname		LPSTR 0

pStub			LPSTR 0		;content of new stub file
dwSizeStubNew	DWORD 0		;size of new stub file
dwSizeStubOld	DWORD 0		;size of current stub
pObjtab			LPSTR 0		;dyn allocated memory for object table
dwObjSize		DWORD 0		;size of object table
dwSizeHeader	DWORD 0		;size of header with new stub
dwSizeHeaderOld	DWORD 0		;size of header with old stub (real size)
dwHdrMin		DWORD -1
dwHdrMax		DWORD 0
dwWarnings		DWORD 0
dwWarnings2		DWORD 0
fNoBackup		BYTE 0		;/n dont write a backup file
if ?XOPT
fPX				BYTE 0		;/x patch PE to PX
endif
fVerbose		BYTE 0		;/v display maximum msgs
fAdjustSOH		BYTE 0		;/s adjust SizeOfHeaders (problem with XP!)
fReadOnly		BYTE 0		;/r
fIgnoreWarnings	BYTE 0		;/i
if ?WOPT
fWriteable		BYTE 0		;/w
endif
fQuiet			BYTE 0		;/q
if ?ZOPT
fZ 				BYTE 0		;/z
endif

wvsprintfA proto stdcall :dword, :dword, :dword
;printf proto C a1:LPSTR, a2:VARARG

	.CONST

szLF	db lf,0

tabentry macro x,y
		dd x
		db y,0
		endm

	.CODE

if 1
malloc proc c public dwBytes:DWORD
	invoke GetProcessHeap
	invoke HeapAlloc, eax, 0, dwBytes
	ret
malloc endp
free proc c public pv:DWORD
	invoke GetProcessHeap
	invoke HeapFree, eax, 0, pv
	ret
free endp
else
malloc proto c :dword
endif

printf proc c pszFormat:LPSTR, args:VARARG

local   dwWritten:DWORD
local   szOut[512]:byte

	invoke wvsprintfA, addr szOut, pszFormat, addr args
	invoke lstrlen, addr szOut
	lea ecx, dwWritten
	invoke WriteFile, hStdOut, addr szOut, eax, ecx, 0
	ret
printf  endp

;*** search for section of a rva in section table ***
;*** rc: eax -> IMAGE_SECTION_HEADER

searchsection proc uses esi edi dwObjects:dword, rva:dword

	mov edi,pObjtab
	and edi,edi
	jz notfound
	mov ecx, dwObjects
	mov eax,rva
searchsec_1:
	mov edx, [edi].IMAGE_SECTION_HEADER.VirtualAddress
	cmp eax,edx
	jb @F
	.if ([edi].IMAGE_SECTION_HEADER.Misc.VirtualSize)
		add edx,[edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
	.else
		add edx,[edi].IMAGE_SECTION_HEADER.SizeOfRawData
	.endif
	cmp eax,edx
	jb found
@@:
	add edi,size IMAGE_SECTION_HEADER
	loop searchsec_1
notfound:
	xor eax,eax
	ret
found:
	mov eax,edi
	ret
searchsection endp

CheckImportDirectory proc uses ebx esi edi dwObjects:dword, pImportData:ptr IMAGE_DATA_DIRECTORY, dwHdrSize:dword

local	dwOffs:dword
local	dwSize:dword
local	pImports:dword

	mov pImports, 0
	mov esi, pImportData
	assume esi:ptr IMAGE_DATA_DIRECTORY
	mov edi,[esi].VirtualAddress
	invoke	searchsection, dwObjects, edi
	.if (!eax)
		jmp exit
	.endif
	mov edi,eax
;--- now load the import directory
	mov eax,[esi].VirtualAddress
	sub eax,[edi.IMAGE_SECTION_HEADER.VirtualAddress]
;--- eax = offset in section of import dir
	mov dwOffs, eax
	mov eax,[edi].IMAGE_SECTION_HEADER.SizeOfRawData
	.if (eax < [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize)
		mov eax, [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize
	.endif
	mov dwSize, eax
	invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, eax
	.if (!eax)
		jmp exit
	.endif
	mov pImports,eax
	invoke _llseek, hFileInp, [edi].IMAGE_SECTION_HEADER.PointerToRawData,0
	invoke _lread, hFileInp, pImports, [edi].IMAGE_SECTION_HEADER.SizeOfRawData
	.if eax == 0
		invoke printf, CStr(<"error reading import directory",lf>)
		jmp exit
	.endif
	mov edi, pImports
	add edi, dwOffs
	mov ecx, [esi].Size_
	xor ebx, ebx
	.while (ecx)
		.break .if (![edi].IMAGE_IMPORT_DESCRIPTOR.Name_)
		mov eax, dwHdrSize
		.if ([edi].IMAGE_IMPORT_DESCRIPTOR.Name_ < eax)
			pushad
			invoke printf, CStr(<"warning: RVA of name of import directory entry %u is %X (^ into PE header)",lf>),\
				ebx, [edi].IMAGE_IMPORT_DESCRIPTOR.Name_
			inc dwWarnings
			popad
		.endif
		.if ([edi].IMAGE_IMPORT_DESCRIPTOR.OriginalFirstThunk)
			.if ([edi].IMAGE_IMPORT_DESCRIPTOR.OriginalFirstThunk < eax)
				pushad
				invoke printf, CStr(<"warning: RVA of ILT of import directory entry %u is %X (^ into PE header)",lf>),\
					ebx, [edi].IMAGE_IMPORT_DESCRIPTOR.OriginalFirstThunk
				inc dwWarnings
				popad
			.endif
		.endif
		add edi, sizeof IMAGE_IMPORT_DESCRIPTOR
		inc ebx
		sub ecx, sizeof IMAGE_IMPORT_DESCRIPTOR
		.break .if (CARRY?)
	.endw
;--- edi -> import directory
exit:
	.if (pImports)
		invoke LocalFree, pImports
	.endif
	ret
	assume esi:nothing

CheckImportDirectory endp        

;*** display sections ***

PrintSections proc uses esi edi dwObjects:dword, lpObjTable:ptr

local	szStr[80]:byte

	invoke printf, CStr(<"Name        vSize      RVA    pSize  pOffset  pRelocs nRel    flags",lf>)
	invoke printf, CStr(<"-------------------------------------------------------------------",lf>)
	mov ecx, dwObjects
	mov edi, lpObjTable
objout_1:
	push ecx
	push ebx
	lea ebx,[edi.IMAGE_SECTION_HEADER.Name_]
	invoke printf, CStr("%-8.8s"), ebx

	movzx ecx,[edi].IMAGE_SECTION_HEADER.NumberOfRelocations

	invoke printf, CStr(<" %8X %8X %8X %8X %8X %4X %8X ">),\
			 [edi].IMAGE_SECTION_HEADER.Misc.VirtualSize,\
			 [edi].IMAGE_SECTION_HEADER.VirtualAddress,\
			 [edi].IMAGE_SECTION_HEADER.SizeOfRawData,\
			 [edi].IMAGE_SECTION_HEADER.PointerToRawData,\
			 [edi].IMAGE_SECTION_HEADER.PointerToRelocations,\
			 ecx,[edi].IMAGE_SECTION_HEADER.Characteristics

	invoke printf, addr szLF
	pop ebx
	pop ecx
	add edi,sizeof IMAGE_SECTION_HEADER
	dec ecx
	jnz objout_1
objout_ex:
	ret
PrintSections  endp

;*** patch DataDirectory
;*** if a RVA is in the area of the old header, it has to be adjusted

PatchDataDirectory proc uses ebx esi edi dwDirs:dword, pData:ptr IMAGE_DATA_DIRECTORY, dwHdrSize:dword

	mov ecx, dwDirs
	mov ebx, pData
	.while (ecx)
;		mov eax, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders
		mov eax, dwHdrSize
		mov edi, [ebx].IMAGE_DATA_DIRECTORY.VirtualAddress
		mov edx, [ebx].IMAGE_DATA_DIRECTORY.Size_
		add edx, edi
		.if (edi && (eax >= edi))
			.if 1;(fVerbose)
				pushad
				sub ecx, dwDirs
				neg ecx
				invoke printf, CStr(<"warning: RVA of data directory entry %u is %X (^ into PE header)",lf>),\
					ecx, [ebx].IMAGE_DATA_DIRECTORY.VirtualAddress
				inc dwWarnings
				popad
			.endif
			.if (edi < dwHdrMin)
				 mov dwHdrMin, edi
			.endif
			.if (edx > dwHdrMax)
				 mov dwHdrMax, edx
			.endif
			sub edi,dwSizeStubOld
			add edi,dwSizeStubNew
			mov [ebx].IMAGE_DATA_DIRECTORY.VirtualAddress, edi
		.endif
		add ebx, sizeof IMAGE_DATA_DIRECTORY
		dec ecx
	.endw
	ret

PatchDataDirectory endp

;*** patch object table ***
;*** PointerToRawData has to be modified ***

PatchObjectTable proc uses ebx edi dwObjects:dword, pNewObjTab:ptr, dwHdrSize:DWORD, dwImageSize:dword

	mov ecx, dwObjects
	mov edi, pNewObjTab
	.while (ecx)
		push ecx
;		mov eax, [esi].IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders
		mov eax, dwHdrSize
		mov edx, dwSizeHeader

;---------------------------------- dont change if pointer is NULL
		.if ([edi].IMAGE_SECTION_HEADER.PointerToRawData)
			sub [edi].IMAGE_SECTION_HEADER.PointerToRawData,eax
			add [edi].IMAGE_SECTION_HEADER.PointerToRawData,edx
		.endif
;---------------------------------- dont change if pointer is NULL
		.if ([edi].IMAGE_SECTION_HEADER.PointerToRelocations)
			sub [edi].IMAGE_SECTION_HEADER.PointerToRelocations,eax
			add [edi].IMAGE_SECTION_HEADER.PointerToRelocations,edx
		.endif
if ?WOPT
		.if (fWriteable)
			.if ([edi].IMAGE_SECTION_HEADER.Characteristics & (IMAGE_SCN_MEM_EXECUTE or IMAGE_SCN_CNT_CODE))
				or [edi].IMAGE_SECTION_HEADER.Characteristics, IMAGE_SCN_MEM_WRITE
			.endif
		.endif
endif
		.if ([edi].IMAGE_SECTION_HEADER.Misc.VirtualSize)
			mov eax, [edi].IMAGE_SECTION_HEADER.VirtualAddress
			.if eax >= dwImageSize
				pushad
				invoke printf, CStr(<"warning: RVA of section '%-8.8s' is %X, but image size is %X only",lf>),\
					addr [edi].IMAGE_SECTION_HEADER.Name_, 
					[edi].IMAGE_SECTION_HEADER.VirtualAddress,
					dwImageSize
				inc dwWarnings
				popad
			.endif
		.endif
		pop ecx
		add edi,sizeof IMAGE_SECTION_HEADER
		dec ecx
	.endw

	.if (fVerbose)
		invoke printf, CStr(<lf,"Object table before modification",lf,lf>)
		invoke PrintSections, dwObjects, pObjtab

		invoke printf, CStr(<lf,"Object table after modification",lf,lf>)
		invoke PrintSections, dwObjects, pNewObjTab
		invoke printf, CStr(<lf>)
	.endif
	ret

PatchObjectTable endp

;--- scan command line for options

getoption proc uses esi pszArgument:LPSTR

	mov esi, pszArgument
	mov eax,[esi]
	cmp al,'/'
	jz @F
	cmp al,'-'
	jnz getoption_1
@@:
	shr eax,8
	or al,20h
if ?XOPT
	cmp ax,"x"
	jnz @F
	mov fPX, 1		;patch PE to PX
	jmp done
@@:
endif
if ?ZOPT
	cmp ax,"z"
	jnz @F
	mov fZ, 1
	jmp done
endif
@@:
	cmp ax,"v"
	jnz @F
	mov fVerbose, 1
	jmp done
@@:
	cmp ax,"i"
	jnz @F
	mov fIgnoreWarnings, 1
	jmp done
@@:
	cmp ax,"q"
	jnz @F
	mov fQuiet, 1
	jmp done
@@:
	cmp ax,"r"
	jnz @F
	mov fReadOnly, 1
	jmp done
@@:
	cmp ax,"s"
	jnz @F
	mov fAdjustSOH, 1
	jmp done
@@:
if ?WOPT
	cmp ax,"w"
	jnz @F
	mov fWriteable, 1
	jmp done
@@:
endif
	cmp ax,"n"
	jnz error
	mov fNoBackup, 1
	jmp done
getoption_1:
	.if (!pszFilename)
		mov pszFilename, esi
	.elseif (!pszStubname)
		mov pszStubname, esi
	.else
		jmp error
	.endif
done:        
	clc
	ret
error:
	stc
	ret
getoption endp

;*** main proc ***

main proc c public argc:dword,argv:dword,envp:dword

local	hFileStub:dword
local	pFileBuffer:LPSTR
local	pNewObjTab:ptr
local	dwWritten:DWORD
local	bError:DWORD
local	mzhdr[40h]:BYTE
local	signature:DWORD
local	dwSizeOfHeaders:DWORD
local	filehdr:IMAGE_FILE_HEADER
local	opthdr32:IMAGE_OPTIONAL_HEADER
local	opthdr64:IMAGE_OPTIONAL_HEADER64
local	szPath[MAX_PATH]:byte
local	szFile[MAX_PATH]:byte
local	pszFile:LPSTR
local	szTempFile[MAX_PATH]:byte

	invoke GetStdHandle, STD_OUTPUT_HANDLE
	mov hStdOut, eax

	mov hFileInp,-1
	mov hFileStub,-1
	mov hFileOut, -1
	mov bError, TRUE
	cmp argc,2
	jb displayusage
	mov ecx, 1
	mov ebx,argv
	.while (ecx < argc)
		push ecx
		invoke getoption, dword ptr [ebx+ecx*4]
		pop ecx
		jc displayusage
		inc ecx
	.endw

	invoke malloc, 10000h
	.if (!eax)
		invoke printf, CStr(<"memory error",lf>)
		jmp main_ex
	.endif
	mov pFileBuffer, eax

;--------------------------- open executable
	mov edx,pszFilename
	and edx,edx
	jz displayusage
	.if (fReadOnly)
		invoke _lopen, edx, OF_READ
	.else
		invoke _lopen, edx, OF_READWRITE or OF_SHARE_DENY_WRITE 
	.endif
	mov hFileInp,eax
	.if (eax == -1)
		invoke GetLastError
		push eax
		invoke printf, CStr(<"cannot open file %s [%X]",lf>), pszFilename, eax
		pop eax
		.if (eax == 5)
			invoke printf, CStr(<"no write access permitted",lf>)
		.endif
		jmp main_ex
	.endif
if ?ZOPT
	.if ( fZ )
		jmp nostub
	.endif
endif
;--------------------------- open stub
	mov edx,pszStubname
	.if (!edx)
		mov edx, CStr("dpmist32.bin")
		mov pszStubname, edx
	.endif
	invoke lstrcpy, addr szFile, edx
	invoke _lopen, addr szFile, OF_READ or OF_SHARE_DENY_NONE
	.if (eax == -1)
		.if (fVerbose)
			invoke GetLastError
			invoke printf, CStr(<"open of stub file '%s' failed [%X]",lf>), pszStubname, eax
		.endif
;--------------------------- search stub in directory of executable as well
		invoke lstrlen, pszStubname
		mov ecx, eax
		mov al, '\'
		mov edi, pszStubname
		repnz scasb
		.if (!ZERO?)
			invoke GetModuleFileName, NULL, addr szFile, sizeof szFile
			lea ecx, szFile
			.while (eax)
				.break .if (byte ptr [ecx+eax] == '\')
				dec eax
			.endw
			lea ecx, [ecx+eax+1]
			invoke lstrcpy, ecx, pszStubname
			invoke _lopen, addr szFile, OF_READ or OF_SHARE_DENY_NONE
			.if (eax != -1)
				jmp step1
			.endif
			invoke GetLastError 
			invoke printf, CStr(<"cannot open stub file '%s' [%X]",lf>), addr szFile, eax
		.endif
		jmp main_ex
	.endif
step1:
	mov hFileStub,eax
	.if (fVerbose)
		invoke printf, CStr(<"stub file '%s' found",lf>), addr szFile
	.endif

	invoke GetFileSize, hFileStub, NULL
	.if (eax == -1)
		invoke printf, CStr(<"couldn't get size of %s",lf>), pszStubname
		jmp main_ex
	.endif
	add eax, 4-1
	and al, 0FCh
	mov dwSizeStubNew, eax

	invoke malloc, eax
	.if (!eax)
		invoke printf, CStr(<"memory error",lf>)
		jmp main_ex
	.endif
	mov pStub, eax

	mov ecx, dwSizeStubNew
	and ecx, ecx
	jz main_ex
	lea ecx, [ecx+eax-4]
	mov dword ptr [ecx], 0

;--- read new stub into memory

	invoke _lread, hFileStub, eax, dwSizeStubNew
	add eax, 4-1
	and al, 0fCh
	.if (eax != dwSizeStubNew)
		invoke printf, CStr(<"couldn't read %s",lf>), pszStubname
		jmp main_ex
	.endif
	mov ecx, pStub
	movzx eax,word ptr [ecx]
	.if (eax != "ZM")
		invoke printf, CStr(<"%s isnt a MZ executable",lf>), pszStubname
		jmp main_ex
	.endif
	mov ecx, pStub
	mov eax, dwSizeStubNew
	mov [ecx+3Ch],eax
nostub:

;------------------ so here stub is read into memory and checked

	invoke _lread, hFileInp, addr mzhdr, 40h
	.if (eax != 40h)
		invoke printf, CStr(<"%s is not a valid executable",lf>), pszFilename
		jmp main_ex
	.endif
	movzx eax,word ptr mzhdr
;----------------------------------------- is it a executable?
	.if (eax == "ZM")
		mov eax,dword ptr mzhdr+3Ch
		mov dwSizeStubOld, eax
	.else
		invoke printf, CStr(<"%s is not an MZ binary object",lf>), pszFilename
		jmp main_ex
	.endif
	invoke _llseek, hFileInp, dwSizeStubOld, FILE_BEGIN 
	.if (eax == -1)
		invoke printf, CStr(<"%s is not a PE binary - lseek() failed",lf>),pszFilename
		jmp main_ex
	.endif
	invoke _lread, hFileInp, addr signature, sizeof signature
	.if (eax == 0)
		invoke printf, CStr(<"%s has no valid PE format - read() failed",lf>), pszFilename
		jmp main_ex
	.endif
	mov eax, signature
	.if eax != "EP" && eax != "XP"
		invoke printf, CStr(<"%s has no valid PE|PX format - magic bytes PE|PX not found",lf>), pszFilename
		jmp main_ex
	.endif
if ?ZOPT
	.if ( fZ )
		mov byte ptr signature+1, 'X'
		invoke _llseek, hFileInp, dwSizeStubOld, FILE_BEGIN 
		invoke _lwrite, hFileInp, addr signature, sizeof signature
		.if (eax != sizeof signature)
			invoke GetLastError
			invoke printf, CStr(<"writing '%s' failed [%X]",lf>), pszFilename, eax
			jmp main_ex
		.endif
		invoke _lclose, hFileInp
		xor eax, eax
		jmp @exit
	.endif
endif
	invoke RtlZeroMemory, addr filehdr, sizeof filehdr
	invoke _lread, hFileInp, addr filehdr, sizeof filehdr
	.if eax != sizeof filehdr
		invoke printf, CStr(<"Error reading FileHeader",lf>)
		jmp main_ex
	.endif
if ?XOPT
	.if (fPX) && ( filehdr.Characteristics & IMAGE_FILE_RELOCS_STRIPPED)
		invoke printf, CStr(<"warning: this binary is linked without relocations!",lf>)
		invoke printf, CStr(<"         most likely the HX PE loader cannot load it within a DOS box",lf>)
		invoke printf, CStr(<"         and Windows won't accept it anymore because cmdline option -x was set.",lf>)
		inc dwWarnings2
	.endif
endif
	.if filehdr.Machine != IMAGE_FILE_MACHINE_I386 && filehdr.Machine != IMAGE_FILE_MACHINE_AMD64
		invoke printf, CStr("Error: unknown machine type %X",lf), filehdr.Machine
		jmp main_ex
	.endif

	.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
		movzx eax, filehdr.SizeOfOptionalHeader
		.if eax > sizeof IMAGE_OPTIONAL_HEADER
			invoke printf, CStr(<"Size of optional Header too large",lf>)
			jmp main_ex
		.endif
		push eax
		invoke _lread, hFileInp, addr opthdr32, eax
		pop ecx
		.if (eax != ecx)
			invoke printf, CStr(<"Error reading optional Header",lf>)
			jmp main_ex
		.endif
		mov eax, opthdr32.SizeOfHeaders
		mov dwSizeOfHeaders, eax
	.else
		movzx eax, filehdr.SizeOfOptionalHeader
		.if eax > sizeof IMAGE_OPTIONAL_HEADER64
			invoke printf, CStr(<"Size of optional Header too large",lf>)
			jmp main_ex
		.endif
		push eax
		invoke _lread, hFileInp, addr opthdr64, eax
		pop ecx
		.if (eax != ecx)
			invoke printf, CStr(<"Error reading optional Header",lf>)
			jmp main_ex
		.endif
		mov eax, opthdr64.SizeOfHeaders
		mov dwSizeOfHeaders, eax
	.endif

	invoke GetFullPathName, pszFilename, sizeof szPath, addr szPath, addr pszFile
	.if (eax == 0)
		invoke GetLastError
		invoke printf, CStr(<"GetFullPathName(%s) failed [%X]",lf>), pszFilename, eax
		jmp main_ex
	.endif
	invoke lstrcpy, addr szFile, pszFile
	mov eax, pszFile
	mov byte ptr [eax], 0
	.if (!fReadOnly)
		invoke GetTempFileName, addr szPath, CStr("~"), NULL, addr szTempFile
		invoke _lcreat, addr szTempFile, 0 
		.if (eax == -1)
			invoke GetLastError
			invoke printf, CStr(<"Couldn't create temporary file %s [%X]",lf>), addr szTempFile, eax
			jmp main_ex
		.endif
		mov hFileOut, eax
	.endif

	.if (fVerbose)
		invoke printf, CStr(<"loading object table...",lf>)
	.endif


	movzx eax, filehdr.NumberOfSections
	mov ecx,sizeof IMAGE_SECTION_HEADER
	mul ecx
	mov dwObjSize,eax
	invoke malloc, eax
	.if (!eax)
		invoke printf, CStr(<"memory error",lf>)
		jmp main_ex
	.endif
	mov pObjtab, eax
	invoke _lread, hFileInp, pObjtab, dwObjSize
	.if (!eax)
		invoke printf, CStr(<"Couldn't read object table",lf>)
		jmp main_ex
	.endif

	mov esi, dwSizeOfHeaders
	.if (fVerbose)
		invoke printf, CStr(<"OptionalHeader.SizeOfHeaders=%X",lf>), esi
	.endif

	mov edi, pObjtab
	movzx ecx,filehdr.NumberOfSections
	.if (ecx)
		mov esi,-1
	.endif

	.while (ecx)
		mov edx, [edi].IMAGE_SECTION_HEADER.PointerToRawData
		.if (edx)
			.if (edx < esi)
				mov esi, edx
			.endif
		.endif
		add edi,sizeof IMAGE_SECTION_HEADER
		dec ecx
	.endw
	.if (fVerbose)
		invoke printf, CStr(<"real size of headers=%X",lf>), esi
	.endif
	mov dwSizeHeaderOld, esi

	movzx eax, filehdr.NumberOfSections
	mov ecx, sizeof IMAGE_SECTION_HEADER
	mul ecx
	add eax, 4	; signature
	add eax, sizeof IMAGE_FILE_HEADER
	.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
		add eax, sizeof IMAGE_OPTIONAL_HEADER
	.else
		add eax, sizeof IMAGE_OPTIONAL_HEADER64
	.endif
	add eax, dwSizeStubNew
;-------------------------------- in eax now new header size
	mov edx, esi
	.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
		mov ecx, opthdr32.FileAlignment
	.else
		mov ecx, opthdr64.FileAlignment
	.endif
	.if (eax < edx)
;-------------------------------- new header size is smaller, shrink header
		.while (eax < edx)
			sub edx, ecx
		.endw
		add edx, ecx
	.else
;-------------------------------- new header size is larger, increase header
		.while (eax > edx)
			add edx, ecx
		.endw
	.endif
	mov dwSizeHeader, edx

	.if (fVerbose)
		invoke printf, CStr(<"checking import directory...",lf>)
	.endif
	
	.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
		lea ecx, opthdr32.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY]
	.else
		lea ecx, opthdr64.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT*sizeof IMAGE_DATA_DIRECTORY]
	.endif
	invoke CheckImportDirectory, filehdr.NumberOfSections, ecx, esi

	.if (fVerbose)
		invoke printf, CStr(<"patching data directories...",lf>)
	.endif
	.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
		mov ecx, opthdr32.NumberOfRvaAndSizes
		lea edx, opthdr32.DataDirectory
	.else
		mov ecx, opthdr64.NumberOfRvaAndSizes
		lea edx, opthdr64.DataDirectory
	.endif
	invoke PatchDataDirectory, ecx, edx, esi
	.if (fVerbose)
		invoke printf, CStr(<"patching object table...",lf>)
	.endif
	movzx eax, filehdr.NumberOfSections
	mov ecx, sizeof IMAGE_SECTION_HEADER
	mul ecx
	invoke malloc, eax
	.if (!eax)
		invoke printf, CStr(<"out of memory",lf>)
		jmp main_ex
	.endif
	mov pNewObjTab, eax
	invoke CopyMemory, pNewObjTab, pObjtab, dwObjSize
        
	.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
		mov eax, opthdr32.SizeOfImage
	.else
		mov eax, opthdr64.SizeOfImage
	.endif
	invoke PatchObjectTable, filehdr.NumberOfSections, pNewObjTab, esi, eax

	.if (fReadOnly)
		mov bError, FALSE
		jmp main_ex
	.endif

;--- write new stub

	.if (fVerbose)
		invoke printf, CStr(<"writing new stub [%u bytes] to temporary file...",lf>), dwSizeStubNew
	.endif
	invoke _lwrite, hFileOut, pStub, dwSizeStubNew

;--- changing size of header doesnt work for winxp???

	.if (fAdjustSOH)
		mov eax, dwSizeHeader
		.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
			mov opthdr32.SizeOfHeaders, eax
		.else
			mov opthdr64.SizeOfHeaders, eax
		.endif
	.endif
if ?XOPT
	.if (fPX)
		mov signature, 'XP'
	.endif
endif
	.if (fVerbose)
		invoke printf, CStr(<"writing PE file header [%u bytes] to temporary file...",lf>), 4 + sizeof IMAGE_FILE_HEADER
	.endif

;--- write new PE file header

	invoke _lwrite, hFileOut, addr signature, sizeof dword
	invoke _lwrite, hFileOut, addr filehdr, sizeof filehdr

;	mov filehdr.FileHeader.SizeOfOptionalHeader, sizeof IMAGE_OPTIONAL_HEADER

	.if (fVerbose)
		movzx ecx, filehdr.SizeOfOptionalHeader
		invoke printf, CStr(<"writing PE optional header [%u bytes] to temporary file...",lf>), ecx
	.endif
	movzx ecx, filehdr.SizeOfOptionalHeader

;--- write new PE optional header

	.if filehdr.Machine == IMAGE_FILE_MACHINE_I386
		invoke _lwrite, hFileOut, addr opthdr32, ecx
	.else
		invoke _lwrite, hFileOut, addr opthdr64, ecx
	.endif
	.if (fVerbose)
		invoke printf, CStr(<"writing object table [%u bytes] to temporary file...",lf>), dwObjSize
	.endif

;--- write new section table

	mov ecx, dwObjSize
	invoke _lwrite, hFileOut, pNewObjTab, ecx

;--- write rest of header

	.if (dwHdrMin != -1)
		invoke _llseek, hFileInp, dwHdrMin, 0
		mov ecx, dwHdrMin
		sub ecx, dwSizeStubOld
		add ecx, dwSizeStubNew
		invoke _llseek, hFileOut, ecx, 0
		mov ecx, dwHdrMax
		sub ecx, dwHdrMin
		invoke _lread, hFileInp, pFileBuffer, ecx
		.if (fVerbose)
			push eax
			invoke printf, CStr(<"writing rest of header [%u bytes] to temporary file...",lf>), eax
			pop eax
		.endif
		invoke _lwrite, hFileOut, pFileBuffer, eax			
	.endif
                        
;--- position to begin of sections

	invoke _llseek, hFileInp, dwSizeHeaderOld, 0

if 1
;--- clear room till begin of sections

	invoke _llseek, hFileOut, 0, FILE_CURRENT
	.if (eax < dwSizeHeader)
		mov ecx, dwSizeHeader
		sub ecx, eax
		mov edi, pFileBuffer
		push ecx
		mov ecx, 10000h/4
		xor eax, eax
		rep stosd
		pop ecx
		.while (ecx)
			mov eax, 10000h
			.if (ecx < eax)
				mov eax, ecx
			.endif
			sub ecx, eax
			push ecx
			invoke _lwrite, hFileOut, pFileBuffer, eax
			pop ecx
		.endw
	.endif
endif

	invoke _llseek, hFileOut, dwSizeHeader, 0

	xor esi,esi
	.while (1)
		invoke _lread, hFileInp, pFileBuffer, 10000h
		.break .if (eax == 0)
		add esi, eax
		.if (fVerbose)
			push eax
			invoke printf, CStr(<"writing rest of binary [%u bytes] to temporary file...",cr>), esi
			pop eax
		.endif
		invoke _lwrite, hFileOut, pFileBuffer, eax
	.endw

	.if (fVerbose)
		invoke printf, CStr(lf)
	.endif
	mov bError, FALSE
	jmp main_ex
displayusage:
	invoke printf, CStr(<"pestub v3.3, copyright japheth 2003-2022",lf>)
	invoke printf, CStr(<"pestub may be used to exchange stub of a PE|PX binary, or to",lf>)
	invoke printf, CStr(<"check it for being compatible with HX's PE|PX loader.",lf,lf>)
	invoke printf, CStr(<"usage: pestub [ options ] filename [stubname]",lf>)
	invoke printf, CStr(<"stubname: name of new stub, must be a MZ executable, default=dpmist32.bin",lf>)
	invoke printf, CStr(<"valid options are:",lf>)
	invoke printf, CStr(<" -i = ignore warnings and modify binary nevertheless",lf>)
	invoke printf, CStr(<" -n = no backup, don't copy file to <filename>.BAK",lf>)
	invoke printf, CStr(<" -q = quiet",lf>)
	invoke printf, CStr(<" -r = read only mode, don't modify the binary",lf>)
	invoke printf, CStr(<" -s = adjust field OptionalHeader.SizeOfHeaders",lf>)
	invoke printf, CStr(<" -v = verbose mode",lf>)
if ?WOPT
	invoke printf, CStr(<" -w = make code sections writeable",lf>)
endif
if ?XOPT
	invoke printf, CStr(<" -x = patch PE to PX (same as PatchPE.exe)",lf>)
endif
if ?ZOPT
	invoke printf, CStr(<" -z = don't replace stub (useful for -x)",lf>)
endif
	jmp @exit
main_ex:
	.if (hFileOut != -1)
		invoke _lclose, hFileOut
	.endif
	.if (hFileInp != -1)
		invoke _lclose, hFileInp
	.endif
	.if (hFileStub != -1)
		invoke _lclose, hFileStub
	.endif
	.if (bError)
		;
	.elseif (dwWarnings)
		invoke printf, CStr(<"pestub: this binary is NOT compatible with DPMILD32!",lf>)
	.elseif (fReadOnly)
		invoke printf, CStr(<"pestub: this binary seems to be compatible with DPMILD32",lf>)
	.endif
	mov eax, dwWarnings2
	add dwWarnings, eax
	.if ((bError == FALSE) && (!fReadOnly))
		.if (dwWarnings && (!fIgnoreWarnings))
			invoke printf, CStr(<"pestub: binary not modified due to warnings!",lf>)
			mov eax, 1
		.elseif (!fNoBackup)
			invoke lstrcpy, addr szFile, pszFilename
			invoke lstrlen, addr szFile
			lea ecx, szFile
			.if ((eax > 4) && (byte ptr [ecx+eax-4] == '.'))
				mov dword ptr [ecx+eax-4],"KAB."
			.else
				mov word ptr [ecx+eax],"_"
			.endif
;--------------------------- change original file to .BAK
			.if (fVerbose)
				invoke printf, CStr(<"renaming %s to %s...",lf>), pszFilename, addr szFile
			.endif
			invoke MoveFile, pszFilename, addr szFile
		.else
			.if (fVerbose)
				invoke printf, CStr(<"deleting %s...",lf>), pszFilename
			.endif
			invoke DeleteFile, pszFilename
		.endif
;--------------------------- change temp file to filename
		.if (eax)
			.if (fIgnoreWarnings || (!dwWarnings))
				.if (fVerbose)
					invoke printf, CStr(<"renaming temporary file to %s...",lf>), pszFilename
				.endif
				invoke MoveFile, addr szTempFile, pszFilename
				.if (eax)
					.if (!fQuiet)
						invoke printf, CStr(<"pestub: %s modified successfully",lf>), pszFilename
					.endif
				.else
					invoke printf, CStr(<"renaming temporary file %s failed",lf>), addr szTempFile
				.endif
			.else
				invoke DeleteFile, addr szTempFile
			.endif
		.else
			mov bError, TRUE
			.if (fNoBackup)
				invoke printf, CStr(<"couldn't delete original file",lf>)
			.else
				invoke printf, CStr(<"couldn't rename original file",lf>)
				invoke printf, CStr(<"make sure to delete file %s first",lf>), addr szFile
			.endif
			invoke DeleteFile, addr szTempFile
		.endif
	.endif
	xor eax, eax
	.if (bError && (fQuiet == 0))
;		invoke Beep, 2000, 100
		invoke printf, CStr("%c"), 7
		mov eax, 1
	.endif
@exit:
	ret
main endp

_setargv proto c

start:
	invoke _setargv
	invoke main, eax, edx, 0
	invoke ExitProcess, eax

	END start

