
;--- tool to modify NE binaries:
;--- + set application flags
;--- + set OS 
;--- + exchange MZ stub
;--- normally this is the linker's job, but they don't
;--- always understand HX's requirements

;--- this is DOS 16-bit source code

	.286
	.model small, stdcall
	option proc:private
	.dosseg

;	include fcntl.inc
O_RDWR	equ 2

@DosOpen macro pszName, mode
	mov al,mode
	mov dx,pszName
	mov ah,3Dh
	int 21h
	endm

@DosCreate macro pszName, attrib
	mov dx,pszName
	mov cx,attrib
	mov ah,3Ch
	int 21h
	endm

@DosClose macro hFile
	mov bx,hFile
	mov ah,3Eh
	int 21h
	endm

	.stack 800h

	.data
        
bOS			db 5	;default: DPMI 16 
bIsNE32		db 0	;mark NE as a 32bit DPMI client (bOS = 6)
bVerbose	db 0
bAppType 	db 0
bAppMask	db 0F8h	;reset bits 0+1+2 in application flags
bStub		db 0


	.const

szDPMISt16 db "DPMIST16.BIN",0

text1   db 'HX patchNE v1.6 (C) japheth 2005-2009',13,10
        db 'usage: patchNE [ options ] filename',13,10
        db '  options are:',13,10 
        db '    -32: mark as 32bit DPMI client',13,10
        db "    -n: don't change application type",13,10
        db '    -r: make DPMILD16 load the binary the way RTM does',13,10
        db "    -s: replace MZ stub of binary by DPMIST16.BIN",13,10
        db '    -v: verbose',13,10
        db 0
text2   db 'patchNE: file not found',13,10,00
text3   db 'patchNE: dos create error',13,10,00
text4   db 'patchNE: dos seek error',13,10,00
text5   db 'patchNE: dos read error',13,10,00
text6   db 'patchNE: not a MZ binary',13,10,00
text7   db 'patchNE: dos write error',13,10,00
text8   db 'patchNE: not a NE binary',13,10,00
text9   db 'patchNE: ',00
text91  db ' patched',13,10,00
text10  db 'patchNE: cannot open DPMIST16.BIN',13,10,0
text11  db 'patchNE: MZ stub replaced by DPMIST16.BIN',13,10,0

	.data?

szTmpFile db 128 dup (?)
buffer	db 2000h dup (?)        

	.code

DosRead proc hFile:WORD, pBuffer:ptr byte, wSize:WORD
	mov cx,wSize
	mov dx,pBuffer
	mov bx,hFile
	mov ax,3F00h
	int 21h
	ret
DosRead endp

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

GetBinPath proc pszBin:ptr byte
	mov ah,51h
	int 21h
	mov es,bx
	mov es,es:[002Ch]
	xor di,di
	mov cx,-1
	mov al,0
@@:
	repnz scasb
	scasb
	jnz @B
	add di,2
	mov si,pszBin
	.while (1)
		mov al,es:[di]
		mov [si],al
		.break .if (al == 0)
		inc di
		inc si
	.endw
	sub si,pszBin
	mov ax,si
	ret
GetBinPath endp

ReplaceStub proc pszFN:ptr byte, hFile:word

local	hFileOut:word
local	hStub:word
local	wStubSize:word
local	dwOldStubSize:dword
local	bError:byte
local	szBin[128]:byte

	mov bError,1
	@DosOpen <offset szDPMISt16>, 0
	.if (CARRY?)
		invoke GetBinPath, addr szBin
		push ds
		pop es
		lea di, szBin
		add di, ax
		.while (1)
			.break .if (byte ptr [di-1] == '\')
			dec di
		.endw
		mov si, offset szDPMISt16
@@:
		lodsb
		stosb
		and al,al
		jnz @B
		lea di, szBin
		@DosOpen di, 0
		.if (CARRY?)
			invoke StringOut, addr text10
			ret
		.endif
	.endif
	mov hStub,ax

	mov si,pszFN
	mov di,offset szTmpFile
	push ds
	pop es
	mov bx,di
	.while (1)
		lodsb
		stosb
		.break .if (al == 0)
		.if (al == '.')
			mov bx,di
		.endif
	.endw
	mov word ptr [bx+0],"MT"
	mov word ptr [bx+2],"P"
	@DosCreate <offset szTmpFile>, 0
	.if (CARRY?)
		invoke StringOut, addr text3
		jmp exit
	.endif
	mov hFileOut,ax

;--- read current MZ stub

	invoke DosRead, hFile, addr buffer, 64
	.if (CARRY?)
		invoke StringOut, addr text5
		jmp exit2
	.endif

	mov ax,word ptr [buffer+3Ch]
	mov dx,word ptr [buffer+3Eh]
	mov word ptr dwOldStubSize+0,ax
	mov word ptr dwOldStubSize+2,dx

;--- copy DPMIST16 to new NE binary 

	invoke DosRead, hStub, addr buffer, sizeof buffer
	.if (CARRY?)
		invoke StringOut, addr text5
		jmp exit2
	.endif
	mov wStubSize,ax
	mov ax,word ptr [dwOldStubSize+0]
	mov dx,word ptr [dwOldStubSize+2]
	mov word ptr [buffer+3Ch],ax
	mov word ptr [buffer+3Eh],dx
	invoke DosWrite, hFileOut, addr buffer, wStubSize
	.if (CARRY?)
		invoke StringOut, addr text7
		jmp exit2
	.endif

;--- read current NE header, patch it, write it to new file

	invoke DosSeek, hFile, [dwOldStubSize], 0
	.if (CARRY?)
		invoke StringOut, addr text4
		jmp exit2
	.endif

	mov di, offset buffer
	push ds
	pop es
	mov cx, sizeof buffer
	mov al,0
	rep stosb
	mov cx,word ptr dwOldStubSize
	sub cx,wStubSize
	jc done
	.while (cx)
		mov ax,cx
		cmp ax, sizeof buffer
		jc @F
		mov ax, sizeof buffer
@@:
		sub cx, ax
		push cx
		invoke DosWrite, hFileOut, addr buffer, ax
		.if (CARRY?)
			invoke StringOut, addr text7
			jmp exit2
		.endif
		pop cx
	.endw
done:
if 0
	invoke DosRead, hFile, addr buffer, 64
	.if (CARRY?)
		invoke StringOut, addr text5
		jmp exit2
	.endif
	mov di,ax
	mov ax,word ptr [buffer+2Ch+0]	;address of nonresident names
	mov dx,word ptr [buffer+2Ch+2]
	mov cx,ax
	or cx,dx
	jcxz @F
	sub ax,word ptr [dwOldStubSize+0]
	sbb dx,word ptr [dwOldStubSize+2]
	add ax,word ptr wStubSize
	adc dx,0
	mov word ptr [buffer+2Ch+0],ax
	mov word ptr [buffer+2Ch+2],dx
@@:
	invoke DosWrite, hFileOut, addr buffer, di
	.if (CARRY?)
		invoke StringOut, addr text7
		jmp exit2
	.endif
endif

;--- copy rest of binary

	.while (1)
		invoke DosRead, hFile, addr buffer, sizeof buffer
		.if (CARRY?)
			invoke StringOut, addr text5
			jmp exit2
		.endif
		mov si,ax
		invoke DosWrite, hFileOut, addr buffer, ax
		.if (CARRY?)
			invoke StringOut, addr text7
			jmp exit2
		.endif
		.break .if (si != sizeof buffer)
	.endw
	mov bError,0
exit2:
	@DosClose hFileOut
exit:
	@DosClose hStub
	mov al,bError
	ret
ReplaceStub endp

;*** get cmdline parameter

getpar  proc pszFN:ptr byte

	mov bx,0080h
	mov cl,byte ptr es:[bx]
	.if (!cl)
		jmp parerr1
	.endif
	inc bx
	.while (cl)
		mov al,es:[bx]
		.if ((al == '-') || (al == '/'))
			.if (cl > 1)
				inc bx
				dec cl
				mov al,es:[bx]
				or al,20h
				.if (al == 'n')
					or bAppMask, 1+2+4
				.elseif (al == 'v')
					mov bVerbose, 1
				.elseif (al == 'r')
					or bAppType, 10h
				.elseif (al == 's')
					or bStub, 1
				.elseif ((al == '3') && (cl > 1) && (byte ptr es:[bx+1] == '2'))
					inc bx
					dec cl
					mov bIsNE32, 1
					mov bOS, 6
				.else
					jmp parerr1
				.endif
			.else
				jmp parerr1
			.endif
		.else
			.break .if (al != ' ')
		.endif
		inc bx
		dec cl
	.endw
	.if (!cl)
		jmp parerr1
	.endif
	mov si,pszFN
	.while (cl)
		mov al,es:[bx]
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

;*** patch the file

patch proc pszFN:ptr byte

local	hFile:WORD
local	bType:BYTE
local	bError:BYTE
local	wMagic:WORD
local	mzhdr[64]:byte

	mov bError,1
	@DosOpen pszFN, O_RDWR
	.if (CARRY?)
		invoke StringOut, addr text2
		ret
	.endif
	mov hFile,ax
	invoke DosRead, hFile, addr mzhdr, 64
	.if (CARRY?)
		invoke StringOut, addr text5
		jmp exit
	.endif
	cmp word ptr [mzhdr+0],"ZM"
	.if (!ZERO?)
		invoke StringOut, addr text6
		jmp exit
	.endif

	mov ax,word ptr [mzhdr+3Ch]	;get position of NE header
	mov dx,word ptr [mzhdr+3Eh]

	invoke DosSeek, hFile, dx::ax, 0
	.if (CARRY?)
		invoke StringOut, addr text4
		jmp exit
	.endif
	invoke DosRead, hFile, addr wMagic, 2
	.if (CARRY?)
		invoke StringOut, addr text5
		jmp exit
	.endif
?POS = 2
	.if (wMagic == "EN")
		invoke DosSeek, hFile, 0Dh - ?POS, 1;app flags is at offset 000Dh
		.if (CARRY?)
			invoke StringOut, addr text4
			jmp exit
		.endif
?POS = 0Dh
		invoke DosRead, hFile, addr bType, 1
		.if (CARRY?)
			invoke StringOut, addr text5
			jmp exit
		.endif
?POS = 0Eh
		.if ((bAppMask != -1) || (bAppType != 0))
			invoke DosSeek, hFile, -1, 1
			.if (CARRY?)
				invoke StringOut, addr text4
				jmp exit
			.endif
			mov al,bType
			and al,bAppMask
			or	al,bAppType
			mov bType,al
			invoke DosWrite, hFile, addr bType, 1
		.endif

		invoke DosSeek, hFile, 36h - ?POS, 1;OS is a offset 0036H
		.if (CARRY?)
			invoke StringOut, addr text4
			jmp exit
		.endif
		invoke DosWrite, hFile, addr bOS, 1
		.if (CARRY?)
			invoke StringOut, addr text7
			jmp exit
		.endif
		.if (bStub)
			invoke DosSeek, hFile, 0, 0
			.if (CARRY?)
				invoke StringOut, addr text4
				jmp exit
			.endif
			invoke ReplaceStub, pszFN, hFile
			mov bError,al
			.if ((!al) && (bVerbose))
				invoke StringOut, addr text11
			.endif
		.endif
		.if (bVerbose)
			invoke StringOut, addr text9
			invoke StringOut, pszFN
			invoke StringOut, addr text91
		.endif
	.else
		invoke StringOut, addr text8
	.endif
exit:
	@DosClose hFile
	.if (bStub && (!bError))
		mov ah,41h
		mov dx,pszFN
		int 21h
		mov dx,offset szTmpFile
		mov di,pszFN
		push ds
		pop es
		mov ah,56h
		int 21h
	.endif
	ret
patch endp

;--- main

main proc

local	szFN[128]:byte

	invoke getpar, addr szFN		;get parameters
	.if (!ax)
		invoke StringOut, addr text1
		mov al,01
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
	shl dx, 4
	add dx, sp
	mov ss, ax
	mov sp, dx
	call main
	mov ah,4ch
	int 21h

	END start
