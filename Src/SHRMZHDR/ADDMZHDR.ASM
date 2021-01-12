
;--- add a binary to a MZ binary
;--- this is done by increasing the header size field in the 
;--- MZ header. No relocations allowed.
;--- this tool is no longer in use!

	.286
	.model small, stdcall
	.dosseg
	.386
	option proc:private

@DosOpen macro pszName, mode
	mov dx,pszName
	mov ax,3D00h + mode
	int 21h
	endm
@DosClose macro hFile
	mov bx,hFile
	mov ah,3Eh
	int 21h
	endm

O_RDONLY equ    0
O_WRONLY equ    1
O_RDWR   equ    2

	.stack 1024

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

	.const

text1   db 'usage: addmzhdr [ options ] file_to_modify file_to_add',13,10
        db 0
text2a  db 'addmzhdr: file ',0
text2b 	db ' not found',13,10,00
text3	db "addmzhdr: header size must be <= 40h bytes",13,10,0
text4   db 'addmzhdr: dos seek error',13,10,00
text5   db 'addmzhdr: dos read error',13,10,00
text6	db "addmzhdr: relocation entries > 1",13,10,0
text7   db 'addmzhdr: dos write error',13,10,00
text8   db 'addmzhdr: not a MZ executable',13,10,00
text9	db 'addmzhdr: binary read error',13,10,0
text10a	db "addmzhdr: ",0
text10b	db " created successfully",13,10,0
if 1
text11	db "addmzhdr: out of memory",13,10,0
else
text11	db "addmzhdr: out of memory ("
msize   db "    )",13,10,0
endif
text12	db "addmzhdr: binary too large (max size is 256 kB-512 bytes)",13,10,0

	.data

wRelocPos	dw 0040h        ;min pos of relocation table
dwFileBuff  dd 0
dwFileSize  dd 0
bVerbose	db 0

	.data?

szDst	db 128 dup (?)	;file to modify
szSrc	db 128 dup (?)	;file to add

mzhdr	IMAGE_DOS_HEADER <>
		db (200h - sizeof IMAGE_DOS_HEADER) dup (?)

	.code

DosRead proc uses ds esi hFile:WORD, pBuffer:far ptr byte, dwSize:DWORD

	xor esi, esi
nextloop:
	lds dx,pBuffer
	mov ecx,dwSize
	cmp ecx,8000h
	jb @F
	mov ecx,8000h
@@:
	sub dwSize, ecx
	add word ptr pBuffer+2,800h
	mov bx,hFile
	mov ah,3Fh
	int 21h
	jc error
	movzx eax,ax
	add esi, eax
	cmp dwSize,0
	jnz nextloop
	push esi
	pop ax
	pop dx
error:
	ret
DosRead endp

DosWrite proc uses ds hFile:WORD, pBuffer:far ptr byte, dwSize:DWORD

nextloop:
	lds dx,pBuffer
	mov ecx,dwSize
	cmp ecx,8000h
	jb @F
	mov ecx,8000h
@@:
	sub dwSize, ecx
	add word ptr pBuffer+2,800h
	mov bx,hFile
	mov ah,40h
	int 21h
	jc error
	cmp dwSize,0
	jnz nextloop
error:
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

StringOut proc uses bx pszString:ptr byte
	mov cx, pszString
	mov bx, cx
	.while (byte ptr [bx])
		inc bx
	.endw
	sub bx, cx
	movzx ebx, bx
	invoke DosWrite, STDOUT, ds::cx, ebx
	ret
StringOut endp

;*** get parameter ***

getpar proc

	mov szDst,0
	mov szSrc,0
	mov bx,0080h
	mov cl,byte ptr es:[bx]
	inc bx
nextparm:
	.while (cl)
		mov al,es:[bx]
		.break .if (al != ' ')
		inc bx
		dec cl
	.endw
	.if (!cl)
		jmp done
	.endif
	.if ((al == '/') || (al == '-'))
		inc bx
		dec cl
		.if (!cl)
			jmp parerr1
		.endif
		mov al,es:[bx]
		or al, 20h
		.if (al == 'v')
			mov bVerbose, 1
		.elseif (al == 'd')
			mov wRelocPos, 001Eh
		.else
			jmp parerr1
		.endif
		dec cl
		jmp nextparm
	.endif
	mov si,offset szDst
	.if (byte ptr [si])
		mov si, offset szSrc
	.endif
	.while (cl)
		mov al,es:[bx]
		.break .if (al == ' ')
		mov [si],al
		inc bx
		inc si
		dec cl
	.endw
	mov byte ptr [si],0
	cmp cl,0
	jnz nextparm
done:
	cmp szSrc,0
	jz parerr1
	mov ax,1
	ret
parerr1:
	xor ax,ax
	ret

getpar endp

if 0
wordout proc
	push ax
	mov  al,ah
	call byteout
	pop  ax
byteout:
	push ax
	shr  al,4
	call nibout
	pop  ax
nibout:
	and  al,0Fh
	add  al,'0'
	cmp  al,'9'
	jbe @F
	add  al,7
@@:
	mov [di],al
	inc di
	ret
wordout endp
endif

;*** shrink header

patch proc

local	rc:WORD
local	dwSize:DWORD
local	hFile:WORD
local	lpSrc:DWORD
local	hFileSrc:WORD

	mov rc, 1
	mov hFile,-1
	mov hFileSrc,-1
	@DosOpen offset szDst, O_RDWR
	.if (CARRY?)
		invoke StringOut, addr text2a
		invoke StringOut, offset szDst
		invoke StringOut, addr text2b
		jmp exit
	.endif
	mov hFile,ax
	@DosOpen offset szSrc, O_RDONLY
	.if (CARRY?)
		invoke StringOut, addr text2a
		invoke StringOut, offset szSrc
		invoke StringOut, addr text2b
		jmp exit
	.endif
	mov hFileSrc,ax

;--- read the file which will be added

	invoke DosSeek, hFileSrc, 0, 2
	.if (dx)
		invoke StringOut, addr text12
		jmp exit
	.endif
	mov word ptr [dwSize+0],ax
	mov word ptr [dwSize+2],dx
	mov bx,ax
	add bx,15
	shr bx,4
	mov ah,48h
	int 21h
	.if (CARRY?)
		invoke StringOut, addr text11
		jmp exit
	.endif
	mov word ptr lpSrc+2, ax
	mov word ptr lpSrc+0, 0
	invoke DosSeek, hFileSrc, 0, 0
	invoke DosRead, hFileSrc, lpSrc, dwSize
	@DosClose hFileSrc
	mov hFileSrc, -1

;--- read the file which will be modified

	mov di, offset mzhdr
	mov cx, 40h/2
	push ds
	pop es
	xor ax,ax
	rep stosw

	invoke DosRead, hFile, addr mzhdr, 20h	;MZ hdr
	.if (CARRY?)
		invoke StringOut, addr text5
		jmp exit
	.endif
	cmp word ptr mzhdr.e_cparhdr,5		;header size must be < 5
	.if (!CARRY?)
		invoke StringOut, addr text3
		jmp exit
	.endif
	mov ax, mzhdr.e_cparhdr
	sub ax, 2
	jbe @F
	shl ax, 4
	movzx eax,ax
	invoke DosRead, hFile, addr mzhdr+20h, eax
@@:

	cmp word ptr mzhdr.e_crlc,2			;relocation entries must be < 2
	.if (!CARRY?)
		invoke StringOut, addr text6
		jmp exit
	.endif

	mov ax, mzhdr.e_cp					;size in 512 bytes units
	cmp ax, 256*2						;file size must be < 256 kB
	.if (!CARRY?)
		invoke StringOut, addr text12
		jmp exit
	.endif
	cmp mzhdr.e_cblp,0
	jz @F
	dec ax					;adjust for last page
@@:
	movzx eax,ax
	shl eax, 9
	movzx ecx, mzhdr.e_cblp	;bytes last page
	add eax, ecx
	movzx ecx, mzhdr.e_cparhdr
	shl ecx, 4
	sub eax, ecx			;subtract size already read
	mov dwFileSize, eax		;size of rest in bytes
	mov ebx, eax
	shr ebx, 4				;bytes -> paragraphs (16)
	inc bx
;	mov si, bx
	mov ah,48h
	int 21h
	.if (CARRY?)
;		mov di, offset msize
;		mov ax, si
;		call wordout
		invoke StringOut, addr text11
		jmp exit
	.endif
	mov word ptr dwFileBuff+2, ax

;--- read the rest of the file which is modified

	invoke DosRead, hFile, dwFileBuff, dwFileSize
	.if (CARRY?)
		invoke StringOut, addr text5
		jmp exit
	.endif
	push dx
	push ax
	pop eax
	cmp eax,dwFileSize
	.if (!ZERO?)
		invoke StringOut, addr text9
		jmp exit
	.endif

;--- both files are read

	mov eax,[dwSize]
	add eax,15
	shr eax,4
	mov [dwSize],eax

;	add mzhdr.e_lfarlc,ax

	mov cx, 4
	sub cx, mzhdr.e_cparhdr
	mov mzhdr.e_cparhdr,4			;size header assumed 40h
	jcxz @F

;--- something to adjust here ???	   

@@:
	add mzhdr.e_cparhdr,ax			;size header in paras
	movzx ebx,mzhdr.e_cp
	.if (mzhdr.e_cblp)
		dec bx
	.endif
	shl ebx,9							;pages -> bytes
	movzx edx,mzhdr.e_cblp
	add ebx,edx

	movzx ecx,cx					;adjust for possible header increments 
	shl ecx, 4
	add ebx, ecx

	movzx eax,ax
	shl eax,4
	add ebx,eax

	mov ax,bx
	and ax,1FFh
	mov mzhdr.e_cblp,ax
	shr ebx,9
	and ax,ax
	jz @F
	inc bx
@@:
	mov mzhdr.e_cp,bx

;--- now write the file

	invoke DosSeek, hFile, 0, 0

	invoke DosWrite, hFile, addr mzhdr, 40h
	.if (CARRY? || (ax != cx))
		invoke StringOut, addr text7
		jmp exit
	.endif
	mov ecx, dwSize
	shl ecx, 4
	invoke DosWrite, hFile, lpSrc, ecx
	.if (CARRY? || (ax != cx))
		invoke StringOut, addr text7
		jmp exit
	.endif

	invoke DosWrite, hFile, dwFileBuff, dwFileSize
	invoke DosWrite, hFile, addr mzhdr, 0	; truncate file 	   

	invoke StringOut, addr text10a
	invoke StringOut, offset szDst
	invoke StringOut, addr text10b
	mov rc,0
exit:
	.if (hFile != -1)
		@DosClose hFile
	.endif
	.if (hFileSrc != -1)
		@DosClose hFileSrc
	.endif
	mov ax,rc
	ret
patch endp

main proc

	invoke getpar
	.if (!ax)
		invoke StringOut, addr text1
		mov ax, 1
		ret
	.endif
	invoke patch
	ret
main endp

start:
	mov  ax,ss
	mov  cx,ds
	sub  ax,cx
	mov  cx,sp
	shr  cx,4
	add  ax,cx
	mov  bx,ax
	mov  ah,4ah
	int  21h
	mov  ax, DGROUP
	mov  ds, ax
	mov  cx, ss
	sub  cx, ax
	shl  cx, 4
	mov  ss, ax
	add  sp, cx
	call main
	mov  ah,4ch
	int  21h

	END start
