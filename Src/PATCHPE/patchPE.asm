
;--- tool to change a PE binary to PX
;--- this will ensure it is not loaded as Win32 app

;--- this is DOS 16bit source code

	.286
	.model small, stdcall
	option proc:private
	.dosseg
	.386

	include winnt.inc
;	include macros.inc

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

?MAXSEC	equ 24
        
O_RDWR	equ 2

@DosOpen macro pszName, mode
	mov al,mode
	mov dx,pszName
	mov ah,3Dh
	int 21h
	endm

@DosClose macro hFile
	mov bx,hFile
	mov ah,3Eh
	int 21h
	endm

	.const

text1   db 'patchPE V1.5 Copyright Japheth 2005-2009',13,10
        db 'changes signature of PE files to PX',13,10
        db 'usage: patchPE <-w> filename',13,10
        db '   -w: make all code sections writeable',13,10
        db 0
text2   db 'file "',00
text2a  db '" not found',13,10,00
text4   db 'dos seek error',13,10,00
text5   db 'dos read error',13,10,00
text6   db 'Not a MZ binary',13,10,00
text7   db 'dos write error',13,10,00
text8   db 'Not a PE/PX binary',13,10,00

	.data

bCodeWriteable	db 0
bModified		db 0

	.data?

MZ_hdr	db 40h dup (?)        
PE_hdr	IMAGE_NT_HEADERS <>        

Sections db ?MAXSEC * sizeof IMAGE_SECTION_HEADER dup (?)

	.code

DosRead proc hFile:WORD, pBuffer:ptr byte, wSize:WORD
	mov cx,wSize
	mov dx,pBuffer
	mov bx,hFile
	mov ax,3F00h
	int 21h
	ret
DosRead	endp

DosWrite proc hFile:WORD, pBuffer:ptr byte, wSize:WORD
	mov cx,wSize
	mov dx,pBuffer
	mov bx,hFile
	mov ax,4000h
	int 21h
	ret
DosWrite endp

DosSeek proc hFile:WORD, dwOffs:DWORD, wMethod:WORD
	mov bx,hFile
	mov cx,word ptr dwOffs+2
	mov dx,word ptr dwOffs+0
	mov al,byte ptr wMethod
	mov ah,42h
	int 21h
	ret
DosSeek endp

STDOUT	equ 1

StringOut proc pszString:ptr byte
	mov bx,pszString
	mov cx,0
	.while (1)
		.break .if (byte ptr [bx] == 0)
		inc bx
		inc cx
	.endw
	invoke DosWrite, STDOUT, pszString, cx
	ret
StringOut endp

StringOutX proc pszString:ptr byte
	invoke StringOut, CStr("patchPE: ")
	invoke StringOut, pszString
	ret
StringOutX endp


;*** get cmdline parameter

getpar  proc pszFN:ptr byte

		mov bx,0080h
		mov cl,byte ptr es:[bx]
		.if (!cl)
			jmp parerr1
		.endif
		inc bx
nextparm:
		.while (cl)
			mov al,es:[bx]
			.break .if (al != ' ')
			inc bx
			dec cl
		.endw
		.if (!cl)
			jmp parerr1
		.endif
		.if ((al == '/') || (al == '-'))
			inc bx
			dec cl
			.if (!cl)
				jmp parerr1
			.endif
			mov al,es:[bx]
			or al,20h
			.if (al == 'w')
				or bCodeWriteable,1
			.else
				jmp parerr1
			.endif
			inc bx
			dec cl
			jmp nextparm
		.endif
		mov si,pszFN
		mov ah,0
		.if (al == '"')
			inc bx
			dec cl
			inc ah
		.endif
		.while (cl)
			mov al,es:[bx]
			.if ((al == '"') && ah)
				inc bx
				dec cl
				.break
			.endif
			mov [si],al
			inc bx
			inc si
			dec cl
		.endw
		mov byte ptr [si],0
		mov ax,1
		ret
parerr1:
		xor ax,ax
		ret

getpar  endp

;*** patch a file

patch proc pszFN:ptr byte

local	hFile:WORD
local	dwPEPos:DWORD
local	wSections:WORD
local	wSectionSize:WORD

	@DosOpen pszFN, O_RDWR
	.if (CARRY?)
		invoke StringOutX, addr text2	;file xxx not found
		invoke StringOut, pszFN
		invoke StringOut, addr text2a
		ret
	.endif
	mov hFile,ax
	invoke DosRead, hFile, addr MZ_hdr, sizeof MZ_hdr
	.if (CARRY? || (ax != cx))
		invoke StringOutX, addr text5	;dos read error
		jmp exit
	.endif
	.if (word ptr MZ_Hdr+0 != "ZM")
		invoke StringOutX, addr text6	;not a MZ binary
		jmp exit
	.endif
if 0
	.if (word ptr MZ_Hdr+18h < 40h)		;relocation table offset < 40h?
		invoke StringOutX, addr text8	;then it is not a PE binary
		jmp exit
	.endif
endif
	mov eax, dword ptr MZ_hdr+3ch
	mov dwPEPos, eax
	invoke DosSeek, hFile, dwPEPos, 0
	.if (CARRY?)
		invoke StringOutX, addr text8	;not a PE/PX binary
		jmp exit
	.endif
	invoke DosRead, hFile, addr PE_hdr, 4 + sizeof IMAGE_FILE_HEADER
	.if (CARRY? || (ax != cx))
		invoke StringOutX, addr text8	;not a PE/PX binary
		jmp exit
	.endif
	.if ((PE_Hdr.Signature == "EP") || (PE_Hdr.Signature == "XP"))
		mov cx, PE_Hdr.FileHeader.SizeOfOptionalHeader
		invoke DosRead, hFile, addr PE_Hdr.OptionalHeader, cx
		.if (CARRY? || (ax != cx))
			invoke StringOutX, addr text8	;not a PE/PX binary
			jmp exit
		.endif
		.if (ax > IMAGE_OPTIONAL_HEADER.Subsystem)
			.if (PE_Hdr.OptionalHeader.Subsystem == IMAGE_SUBSYSTEM_WINDOWS_GUI)
				invoke StringOutX, CStr(<"aborted, because this is a Win32 GUI app!",13,10>)
				jmp exit
			.endif
		.endif
		.if (bCodeWriteable)
			mov cx, PE_Hdr.FileHeader.NumberOfSections
			.if (cx > ?MAXSEC)
				invoke StringOutX, CStr(<"too many sections in binary, will not check all of them",13,10>)
				mov cx, ?MAXSEC
			.endif
			mov wSections,cx
			mov ax, sizeof IMAGE_SECTION_HEADER
			mul cx
			mov wSectionSize, ax
			invoke DosRead, hFile, addr Sections, ax
			.if (CARRY? || (ax != cx))
				invoke StringOutX, addr text8
				jmp exit
			.endif
			mov si,offset Sections
			mov cx, wSections
			.while (cx)
				mov eax, [si].IMAGE_SECTION_HEADER.Characteristics
				.if (eax & IMAGE_SCN_MEM_EXECUTE)
					.if (!(eax & IMAGE_SCN_MEM_WRITE))
						or [si].IMAGE_SECTION_HEADER.Characteristics, IMAGE_SCN_MEM_WRITE
						mov bModified, 1
					.endif
				.endif
				add si, sizeof IMAGE_SECTION_HEADER
				dec cx
			.endw
			.if (bModified)
				mov eax, dwPEPos
				movzx ecx, PE_hdr.FileHeader.SizeOfOptionalHeader
				add ecx, sizeof IMAGE_FILE_HEADER
				add ecx, 4
				add eax, ecx
				invoke DosSeek, hFile, eax, 0
				.if (CARRY?)
					invoke StringOutX, addr text8
					jmp exit
				.endif
				invoke DosWrite, hFile, addr Sections, wSectionSize
				.if ((CARRY?) || (ax != cx))
					invoke StringOutX, addr text7
					jmp exit
				.endif
			.endif
		.endif

		mov byte ptr PE_Hdr.Signature+1, 'X'
		invoke DosSeek, hFile, dwPEPos, 0
		.if (CARRY?)
			invoke StringOutX, addr text4	;dos seek error
			jmp exit
		.endif
		invoke DosWrite, hFile, addr PE_Hdr, 2
		.if (CARRY?)
			invoke StringOutX, addr text7	;dos write error
			jmp exit
		.endif
	.else
		invoke StringOutX, addr text8		;not a PE/PX binary
	.endif
exit:
	@DosClose hFile
	ret
patch endp

;--- main

main proc

local	szFN[128]:byte

	invoke getpar, addr szFN
	.if (!ax)
		invoke StringOut, addr text1
		mov al,1
		ret
	.endif
	invoke patch, addr szFN
	mov  al,00
	ret
main endp

start:
	mov ax, DGROUP
	mov ds, ax
	mov dx, ss
	sub dx, ax
	shl dx,4
	add dx,sp
	mov ss, ax
	mov sp, dx
	call main
	mov ah,4ch
	int 21h

	.stack 400h

	END start
