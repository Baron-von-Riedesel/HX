
;--- extract section contents from a MZ binary
;--- the MZ binary is extraced full (without MZ header)
;--- Public Domain.

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

fVerbose	BYTE 0		;display maximum msgs
fQuiet		BYTE 0		;no displays
fInclude	BYTE 0		;generate include file

_errno	dd 0

	.CONST

szLF	db lf,0

	.CODE

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
	cmp ax,"v"
	jnz @F
	mov fVerbose, 1
	jmp done
@@:
	cmp ax,"q"
	jnz @F
	mov fQuiet, 1
	jmp done
@@:
	cmp ax,"i"
	jnz @F
	mov fInclude, 1	;transform to include file
	jmp done
@@:
	jmp error
getoption_1:
	.if (!pszFileInp)
		mov pszFileInp, esi
	.elseif (!pszFileOut)
		mov pszFileOut, esi
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
local	bError:DWORD
local	mzhdr[20h]:BYTE

	mov pFileInp, 0
	mov pFileOut, 0
	mov bError, 1
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
	.if (eax != sizeof mzhdr)
		invoke printf, CStr("%s is not a valid executable",lf), pszFileInp
		jmp main_ex
	.endif
;----------------------------------------- is it a MZ executable?
	movzx eax,word ptr mzhdr
	.if (eax != "ZM")
		invoke printf, CStr("%s is not an MZ binary object",lf), pszFileInp
		jmp main_ex
	.endif

	movzx eax,word ptr [mzhdr+8]	;size of header
	shl eax,4
	push eax
	invoke fseek, pFileInp, eax, SEEK_SET
	movzx eax,word ptr [mzhdr+4]
	dec eax
	shl eax,9
	movzx ecx,[word ptr mzhdr+2]
	add eax, ecx
	pop ecx
	sub eax, ecx
	mov ebx, eax
	invoke malloc, eax
	.if (!eax)
		invoke printf, CStr("out of memory",lf)
		jmp main_ex
	.endif
	mov esi, eax
	invoke fread, esi, 1, ebx, pFileInp 
	invoke fclose, pFileInp
	mov pFileInp, 0
	invoke fopen, pszFileOut, CStr("wb")
	.if (!eax)
		invoke printf, CStr("cannot create file '%s' [%X]",lf), pszFileOut, errno
		jmp main_ex
	.endif
	mov pFileOut, eax
	invoke WriteContent, esi, ebx

file_done:
	invoke free, esi

	.if (!fQuiet)
		invoke printf, CStr("extrmz: file '%s' processed",lf), pszFileInp
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
	invoke printf, CStr("extrmz v1.0: modifies/extract contents of/from a MZ binary",lf)
	invoke printf, CStr("usage: extrmz [options] src_file dst_file",lf)
	invoke printf, CStr("  options:",lf)
	invoke printf, CStr("    -i: create ASM include as output",lf)
	invoke printf, CStr("    -q: quiet",lf)
	invoke printf, CStr("    -v: verbose",lf)
	jmp main_ex
main endp

	END

