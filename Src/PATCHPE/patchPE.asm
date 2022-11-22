
;--- tool to change a PE binary to PX
;--- this will ensure it is not loaded as Win32 app
;--- optionally the patch may be reverted ( -r option)
;--- finally, the tool may make code sections writable (for debugging)

	.386
	.model flat, stdcall
	option proc:private

?REBASE equ 0

fopen  proto c :ptr, :ptr
fclose proto c :dword
fread  proto c :ptr, :dword, :dword, :dword
fwrite proto c :ptr, :dword, :dword, :dword
fseek  proto c :ptr, :dword, :dword
printf proto c :ptr, :vararg

SEEK_SET equ 0

	include winnt.inc

CStr macro text:VARARG
local sym
	.const
  ifidni <text>,<"">
sym db 0
  else
sym db text,0
  endif
	.code
	exitm <offset sym>
endm

?MAXSEC equ 24
        
	.data

pszFN dd 0

if ?REBASE
dwBase dd 0
endif
dwStkRes dd 0
dwStkCommit dd -1
dwHeapRes dd 0
dwHeapCommit dd -1

if ?REBASE
bBase db 0
endif
bCodeWriteable db 0
bHeap db 0
bModified db 0
bPatchPE db 0
bPatchPX db 0
wSubSys dw -1
bStack db 0
bVerbose db 0
bOptions db 0

	.data?

MZ_hdr	db 40h dup (?)        
PE_hdr	IMAGE_NT_HEADERS <>        
	dd 12 dup (?)
Sections db ?MAXSEC * sizeof IMAGE_SECTION_HEADER dup (?)

	.code

;*** patch a file

patch proc

local	pFile:DWORD
local	dwRead:dword
local	dwPEPos:DWORD
local	dwSectionSize:DWORD
local	dwSections:DWORD

	invoke fopen, pszFN, CStr("rb+")
	.if eax == 0
		invoke printf, CStr("file '%s' not found",10), pszFN
		ret
	.endif
	mov pFile,eax
	invoke fread, addr MZ_hdr, 1, sizeof MZ_hdr, pFile
	.if eax != sizeof MZ_hdr
		invoke printf, CStr('dos read error',10)
		jmp exit
	.endif
	.if (word ptr MZ_Hdr+0 != "ZM")
		invoke printf, CStr('Not a MZ binary: %s',10), pszFN
		jmp exit
	.endif
if 0
	.if (word ptr MZ_Hdr+18h < 40h)		;relocation table offset < 40h?
		invoke printf, CStr('Not a PE/PX binary: %s',10), pszFN
		jmp exit
	.endif
endif
	mov eax, dword ptr MZ_hdr+3ch
	mov dwPEPos, eax
	invoke fseek, pFile, dwPEPos, SEEK_SET
	.if eax == -1
		invoke printf, CStr('cannot position to PE/PX header',10)
		jmp exit
	.endif
	mov dwRead, 4 + sizeof IMAGE_FILE_HEADER
	invoke fread, addr PE_hdr, 1, 4 + sizeof IMAGE_FILE_HEADER, pFile
	.if eax != 4 + sizeof IMAGE_FILE_HEADER
		invoke printf, CStr('cannot read PE/PX header',10)
		jmp exit
	.endif
	.if ((PE_Hdr.Signature == "EP") || (PE_Hdr.Signature == "XP"))
		invoke fread, addr PE_Hdr.OptionalHeader, 1, PE_Hdr.FileHeader.SizeofOptionalHeader, pFile
		.if ax != PE_Hdr.FileHeader.SizeofOptionalHeader
			invoke printf, CStr('cannot read PE/PX optional header',10)
			jmp exit
		.endif
		add dwRead, eax
if 0
		.if (PE_Hdr.OptionalHeader.Subsystem == IMAGE_SUBSYSTEM_WINDOWS_GUI)
			invoke printf, CStr("aborted, because this is a Win32 GUI app!",10)
			jmp exit
		.endif
endif
		.if bStack
			mov eax,dwStkRes
			mov PE_Hdr.OptionalHeader.SizeOfStackReserve, eax
			mov eax,dwStkCommit
			.if eax != -1
				mov PE_Hdr.OptionalHeader.SizeOfStackCommit, eax
			.endif
			;--- don't allow reserve to be < commit
			mov eax, PE_Hdr.OptionalHeader.SizeOfStackReserve
			.if eax < PE_Hdr.OptionalHeader.SizeOfStackCommit
				mov PE_Hdr.OptionalHeader.SizeOfStackCommit, eax
			.endif
		.endif
if ?REBASE
		.if bBase
			;--- read the relocs and rebase
			mov eax,dwBase
			mov PE_Hdr.OptionalHeader.ImageBase, eax
		.endif
endif
		.if bHeap
			mov eax,dwHeapRes
			mov PE_Hdr.OptionalHeader.SizeOfHeapReserve, eax
			mov eax,dwHeapCommit
			.if eax != -1
				mov PE_Hdr.OptionalHeader.SizeOfHeapCommit, eax
			.endif
			;--- don't allow reserve to be < commit
			mov eax, PE_Hdr.OptionalHeader.SizeOfHeapReserve
			.if eax < PE_Hdr.OptionalHeader.SizeOfHeapCommit
				mov PE_Hdr.OptionalHeader.SizeOfHeapCommit, eax
			.endif
		.endif
		.if bCodeWriteable
			movzx ecx, PE_Hdr.FileHeader.NumberOfSections
			.if (ecx > ?MAXSEC)
				invoke printf, CStr("too many sections in binary, will not check all of them",10)
				mov ecx, ?MAXSEC
			.endif
			mov dwSections,ecx
			mov eax, sizeof IMAGE_SECTION_HEADER
			mul ecx
			mov dwSectionSize, eax
			invoke fread, addr Sections, 1, eax, pFile
			.if eax != dwSectionSize
				invoke printf, CStr("cannot read object table",10)
				jmp exit
			.endif
			mov esi,offset Sections
			mov ecx, dwSections
			.while ecx
				mov eax, [esi].IMAGE_SECTION_HEADER.Characteristics
				.if (eax & IMAGE_SCN_MEM_EXECUTE)
					.if (!(eax & IMAGE_SCN_MEM_WRITE))
						or [esi].IMAGE_SECTION_HEADER.Characteristics, IMAGE_SCN_MEM_WRITE
						mov bModified, 1
					.endif
				.endif
				add esi, sizeof IMAGE_SECTION_HEADER
				dec ecx
			.endw
			.if bModified
				mov eax, dwPEPos
				movzx ecx, PE_hdr.FileHeader.SizeOfOptionalHeader
				add ecx, sizeof IMAGE_FILE_HEADER
				add ecx, 4
				add eax, ecx
				invoke fseek, pFile, eax, SEEK_SET
				.if eax == -1
					invoke printf, CStr("fseek error",10)
					jmp exit
				.endif
				invoke fwrite, addr Sections, 1, dwSectionSize, pFile
				.if eax != dwSectionSize
					invoke printf, CStr('write error',10)
					jmp exit
				.endif
			.endif
		.endif

		.if bPatchPE
			mov byte ptr PE_Hdr.Signature+1, 'E'
		.elseif bPatchPX || bOptions == 0
			mov byte ptr PE_Hdr.Signature+1, 'X'
			.if PE_Hdr.FileHeader.Characteristics & IMAGE_FILE_RELOCS_STRIPPED
				invoke printf, CStr("Warning: relocations stripped.",10)
				invoke printf, CStr("Binary won't run with all DPMI hosts.",10)
			.endif
		.endif
		.if wSubSys != -1
			mov ax, wSubSys
			mov PE_Hdr.OptionalHeader.Subsystem, ax
		.endif
		invoke fseek, pFile, dwPEPos, SEEK_SET
		.if eax == -1
			invoke printf, CStr("fseek error",10)
			jmp exit
		.endif
		invoke fwrite, addr PE_Hdr, 1, dwRead, pFile
		.if eax != dwRead
			invoke printf, CStr('write error',10)
			jmp exit
		.endif
	.else
		invoke printf, CStr('not a PE/PX binary: %s',10), pszFN
	.endif
exit:
	invoke fclose, pFile
	ret
patch endp

chkdigit proc
	movzx eax,al
	sub al,'0'
	jb done
	cmp al,10
	jb check
	sub al,7
	and al,not 20h
check:
	cmp edi,eax
done:
	ret
chkdigit endp

getnum proc uses esi edi
	xor esi,esi
	mov edi,10
	mov ch,0
	mov ax,[ebx]
	cmp ax,"x0"
	jnz @F
	add ebx,2
	mov edi,16
@@:
	mov al,[ebx]
	call chkdigit
	jc done
	movzx eax,al
	imul esi,edi
	add esi,eax
	inc ch
	inc ebx
	jmp @B
done:
	mov eax,esi
	cmp ch,1
	ret
getnum endp

getoption proc uses ebx pszOption:ptr byte

	mov ebx, pszOption
	mov al,[ebx]
	.if ((al == '/') || (al == '-'))
		inc ebx
		mov ax,[ebx]
		or al, 20h
		.if (ax == '?')
			stc
if ?REBASE
		.elseif (ax == ':b')
			add ebx,2
			call getnum
			jc exit
			mov dwBase, eax
			or bBase,1
			cmp byte ptr [ebx],1
			cmc
endif
		.elseif (ax == 'e')
			or bPatchPE, 1
		.elseif (ax == ':h')
			add ebx,2
			call getnum
			jc exit
			mov dwHeapRes, eax
			.if byte ptr [ebx] == ','
				inc ebx
				call getnum
				jc exit
				mov dwHeapCommit, eax
			.endif
			or bHeap,1
			cmp byte ptr [ebx],1
			cmc
		.elseif (ax == ':s')
			add ebx,2
			call getnum
			jc exit
			mov dwStkRes, eax
			.if byte ptr [ebx] == ','
				inc ebx
				call getnum
				jc exit
				mov dwStkCommit, eax
			.endif
			or bStack,1
			cmp byte ptr [ebx],1
			cmc
		.elseif (ax == 'v')
			or bVerbose, 1
		.elseif ax == 'w'
			or bCodeWriteable,1
		.elseif ax == 'x'
			or bPatchPX, 1
		.elseif ax == ':y'
			add ebx,2
			call getnum
			jc exit
			mov wSubSys, ax
		.else
			jmp err
		.endif
		inc bOptions
		ret
	.endif
	.if !pszFN
		mov pszFN, ebx
		clc
	.else
err:
		stc
	.endif
exit:
	ret

getoption endp

;--- main

main proc c public argc:dword, argv:ptr

	mov ecx, 1
	mov ebx, argv
	.while ecx < argc
		push ecx
		invoke getoption, dword ptr [ebx+ecx*4]
		pop ecx
		jc usage
		inc ecx
	.endw
	.if !pszFN
		jmp usage
	.endif
	invoke patch
	xor eax,eax
	ret
usage:
	invoke printf, CStr("patchPE v2.1 Copyright Japheth 2005-2022",10)
	invoke printf, CStr(" allows to change a few attributes of PE/PX binaries",10)
	invoke printf, CStr(" usage: patchPE [ options ] filename",10)
	invoke printf, CStr(" options are:",10)
if ?REBASE
	invoke printf, CStr("  -b:base   set image base address",10)
endif
	invoke printf, CStr("  -e   patch header to 'PE'.",10)
	invoke printf, CStr("  -h:reserve[,commit]   set heap size",10)
	invoke printf, CStr("  -s:reserve[,commit]   set stack size",10)
	invoke printf, CStr("  -w   make all code sections writeable",10)
	invoke printf, CStr("  -x   patch header to 'PX'.",10)
	invoke printf, CStr("  -y:subsystem   set subsystem",10)
	invoke printf, CStr(" if no option is given, -x is assumed",10)
	ret
main endp

	END
