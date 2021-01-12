
;--- shrink mz header to the smallest possible size 
;--- should work with any DOS MZ binary linked with MS link
;--- as long as size is < 64 kB

	.386
	.model flat, stdcall
	option proc:private

fopen proto c :ptr, :ptr
fclose proto c :dword
fread proto c :ptr, :dword, :dword, :dword
fwrite proto c :ptr, :dword, :dword, :dword
fseek proto c :ptr, :dword, :dword
printf proto c :ptr, :vararg
malloc proto c :dword

SEEK_SET equ 0

CStr macro text:VARARG
local x
	.const
x	db text,0
	.code
	exitm <offset x>
endm

;--- structure MZ header (copied from winnt.inc)
        
IMAGE_DOS_HEADER STRUCT
  e_magic           WORD      ?		;+0		"MZ"
  e_cblp            WORD      ?		;+2		number of bytes in last page
  e_cp              WORD      ?		;+4		number of pages
  e_crlc            WORD      ?		;+6		number of relocation records
  e_cparhdr         WORD      ?		;+8		size header in paragraphs
  e_minalloc        WORD      ?		;+10
  e_maxalloc        WORD      ?		;+12
  e_ss              WORD      ?		;+14
  e_sp              WORD      ?		;+16
  e_csum            WORD      ?		;+18
  e_ip              WORD      ?		;+20
  e_cs              WORD      ?		;+22
  e_lfarlc          WORD      ?		;+24	begin relocation records
  e_ovno            WORD      ?		;+26
  e_res             WORD   4 dup(?)	;+28
  e_oemid           WORD      ?		;+36
  e_oeminfo         WORD      ?		;+38
  e_res2            WORD  10 dup(?)	;+40
  e_lfanew          DWORD      ?	;+60	
IMAGE_DOS_HEADER ENDS

	.data

pszFN	dd 0
dwFileBuff  dd 0
wRelocPos	dw 0040h        ;min pos of relocation table
wFileSize   dw 0

	.data?
        
mzhdr	IMAGE_DOS_HEADER <>
		db (200h - sizeof IMAGE_DOS_HEADER) dup (?)

	.code

;*** get cmdline option ***

getoption proc uses ebx pszOption:ptr byte

	mov ebx, pszOption
	mov al,[ebx]
	.if ((al == '/') || (al == '-'))
		inc ebx
		mov al,[ebx]
		or al, 20h
		.if (al == 'd')
			mov wRelocPos, 001Eh
			mov eax,1
		.else
			xor eax,eax
		.endif
	.elseif pszFN == 0
		mov pszFN, ebx
		mov eax,1
	.else
		xor eax,eax
	.endif
	ret

getoption endp

;*** shrink header

patch proc

local	rc:DWORD
local	pFile:DWORD

	mov rc, 1
	invoke fopen, pszFN, CStr("rb+")
	.if (eax == 0)
		invoke printf, CStr('shrmzhdr: file %s not found',10), pszFN
		mov eax, rc
		ret
	.endif
	mov pFile,eax
	invoke fread, addr mzhdr, 1, 200h, pFile
	.if (eax != 200h)
		invoke printf, CStr('shrmzhdr: dos read error',10)
		jmp exit
	.endif
	cmp word ptr mzhdr.e_cparhdr,20h	;header size must be 20h
	.if (!ZERO?)
		invoke printf, CStr("shrmzhdr: header size not 200h bytes",10)
		jmp exit
	.endif
if 0
	cmp word ptr mzhdr.e_crlc,0h		;relocation entries must be 0
	.if (!ZERO?)
		invoke printf, CStr("shrmzhdr: relocation entries not 0",10)
		jmp exit
	.endif
endif
	mov ax, mzhdr.e_cp					;size in 512 bytes units
	cmp ax, 64*2						;file size must be < 64 kB
	.if (!CARRY?)
		invoke printf, CStr("shrmzhdr: binary too large (max size is 65536-512 bytes)",10)
		jmp exit
	.endif
	cmp mzhdr.e_cblp,0
	jz @F
	dec ax					;adjust for last page
@@:
	dec ax					;dont count header
	shl ax, 9
	add ax, mzhdr.e_cblp
	mov wFileSize, ax		;size in bytes without header
	mov bx, ax
	shr bx, 4				;bytes -> paragraphs (16)
	inc bx

	movzx ebx,bx
	shl ebx,4
	invoke malloc, ebx
	.if eax == 0
		invoke printf, CStr("shrmzhdr: out of memory",10)
		jmp exit
	.endif
	mov dwFileBuff, eax

	invoke fseek, pFile, 200h, SEEK_SET
if 0
	.if ???
		invoke printf, CStr('shrmzhdr: dos seek error',10)
		jmp exit
	.endif
endif
	invoke fread, dwFileBuff, 1, wFileSize, pFile
	.if ax != wFileSize
		invoke printf, CStr('shrmzhdr: binary must be at least 1C0h size',10)
		jmp exit
	.endif

;	mov ax, wRelocPos
;	mov mzhdr.e_lfarlc,ax				;set begin relocs
;	mov mzhdr.e_cblp,0					;set bytes last page = 0
	mov ax,mzhdr.e_crlc					;no of relocations
	.if (ax)
		shl ax,2						;each reloc requires 4 bytes
		add ax, mzhdr.e_lfarlc
	.else
		mov ax, wRelocPos
	.endif
	test al,0Fh
	jz @F
	and al,0F0h
	add ax,10h
@@:            
	shr ax, 4
	mov cx, mzhdr.e_cparhdr
	mov mzhdr.e_cparhdr,ax				;size header in paras

	shl ax,4
	add ax, wFileSize
	mov cx, ax
	shr ax, 9
	and cx, 01FFh
	jcxz @F
	inc ax
@@:
	mov mzhdr.e_cblp,cx
	mov mzhdr.e_cp,ax

	invoke fseek, pFile, 0, SEEK_SET
	mov ax, mzhdr.e_cparhdr
	shl ax, 4
	movzx ecx, ax

	push ecx
	invoke fwrite, addr mzhdr, 1, ecx, pFile
	pop ecx
	.if eax != ecx
		invoke printf, CStr('shrmzhdr: dos write error',10)
		jmp exit
	.endif
	movzx ecx, wFileSize
	invoke fwrite, dwFileBuff, 1, ecx, pFile
	invoke fwrite, dwFileBuff, 1, 0, pFile	; truncate file

	invoke printf, CStr("shrmzhdr: %s shrinked successfully",10), pszFN
	mov rc,0
exit:
	invoke fclose, pFile
	mov eax,rc
	ret
patch endp

main proc c public argc:dword, argv:ptr

	mov ecx, 1
	mov ebx, argv
	.while ecx < argc
		push ecx
		invoke getoption, dword ptr [ebx+ecx*4]
		pop ecx
		cmp eax,1
		jc usage
		inc ecx
	.endw
	cmp pszFN,0
	jz usage
	invoke patch
	ret
usage:
	invoke printf, CStr('usage: shrmzhdr [ options ] filename',10)
	invoke printf, CStr('   -d: start relocation table may be below 0x40',10)
	mov eax, 1
	ret
main endp

	END
