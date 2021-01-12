
;--- set mz header so file will just be loaded until stack

	.386
	.model flat, stdcall
	option proc:private

fopen proto c :ptr, :ptr
fclose proto c :dword
fread proto c :ptr, :dword, :dword, :dword
fwrite proto c :ptr, :dword, :dword, :dword
fseek proto c :ptr, :dword, :dword
printf proto c :ptr, :vararg

SEEK_SET equ 0

lf equ 10

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

pszFN dd 0
bQuiet db 0

	.data?

pFile dd ?
mzhdr	IMAGE_DOS_HEADER <>
		db (200h - sizeof IMAGE_DOS_HEADER) dup (?)

	.code

;*** get parameter ***

getoption proc uses ebx pszOption:ptr byte

	mov ebx, pszOption
	mov al,[ebx]
	.if ((al == '/') || (al == '-'))
		inc ebx
		mov ax,[ebx]
		or al, 20h
		.if (ax == 'q')
			mov bQuiet, 1
			clc
			ret
		.else
			stc
			ret
		.endif
	.endif
	.if !pszFN
		mov pszFN, ebx
		clc
	.else
		stc
	.endif
	ret

getoption endp

;*** set mz header fields SP and SS

patch proc pszFile:ptr byte

local	rc:DWORD

	mov rc, 1
	invoke fopen, pszFile, CStr("rb+")
	.if (eax == 0)
		invoke printf, CStr("setmzhdr: file %s not found",lf), pszFile
		mov eax, rc
		ret
	.endif
	mov pFile,eax
	invoke fread, addr mzhdr, 1, 20h, pFile
	.if (eax != 20h)
		invoke printf, CStr("setmzhdr: read error",lf)
		jmp exit
	.endif

;--- 1. task: set a sp of 0x200 if it's zero

	movzx eax, mzhdr.e_sp
	and eax, eax
	jnz @F
	mov ax, 200h
	mov mzhdr.e_sp, ax
	cmp bQuiet,0
	jnz @F
	push eax
	invoke printf, CStr("setmzhdr: SP set to %xh",lf), eax
	pop eax
@@:
	mov ecx, eax
	and ecx, 0Fh
	shr eax, 4
	jecxz @F
	inc eax
@@:
;--- the stack value can safely be set as heap min as well.
	mov mzhdr.e_minalloc, ax

;--- 2. task: reduce size of memory image. Just the 16bit part
;--- of the binary is to be loaded by the DOS loader.
;--- Usually SS can be used to get the 16bit size.
;--- However, for WLink this isn't true, because
;--- that linker won't set this field if stack size is zero!

	movzx eax, mzhdr.e_ss
	and eax, eax
	jnz @F
	invoke printf, CStr('setmzhdr: field SS in header is ZERO.',lf)
	jmp exit
@@:
	add ax, mzhdr.e_cparhdr	;add size of header
	mov ecx, eax
	and ecx, 1Fh
	shr eax, 5
	jecxz @F
	inc eax
@@:
	mov mzhdr.e_cp,ax
	shl ecx, 4
	mov mzhdr.e_cblp,cx

	invoke fseek, pFile, 0, SEEK_SET
	invoke fwrite, addr mzhdr, 1, 20h, pFile
	.if (eax != 20h)
		invoke printf, CStr('setmzhdr: write error',lf)
		jmp exit
	.endif
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
		jc usage
		inc ecx
	.endw
	.if !pszFN
		jmp usage
	.endif
	invoke patch, pszFN
	ret
usage:
	invoke printf, CStr('usage: setmzhdr [-q] filename',lf)
	mov eax,1
	ret
main endp

	END
