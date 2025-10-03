
;*** 1. load hdpmi16.exe if no dpmi host detected
;*** 2. skip first parameter of cmdline
;*** 3. then start windows krnl386.exe

	.286
	.MODEL tiny, stdcall
	.386
	.dosseg
	.stack 1024		;size aligned to paragraphs

CHECKHOST equ 1 ;1=check if DPMI host active before trying to load hdpmi16
ifndef ENHANCED
ENHANCED equ 0 ;1=load HDPMI16e instead of HDPMI16
endif

?FULLPATH equ 1 ;1=get full path of krnl386.exe

;--- ?XMSHOOK: 1=install an XMS hook to make HDPMI16 compatible with WSWAP.EXE.
;--- It's needed if XMS memory is <= 64MB, and it's recommended if XMS memory is <= 128MB.
;--- It doesn't really work, though - it's better to set environment variable HDPMI=64.
?XMSHOOK equ 0

;--- ?DISABLEHOST: 1=disable DPMI host; disabled by hooking int 2Fh!
?DISABLEHOST equ 0

;--- ?LOADHOST: 1=load hdpmi16.exe; 0=don't try to load, it's assumed to be loaded already
ifndef ?LOADHOST
?LOADHOST equ 1
endif

	.DATA

wEnviron dw 0

parmb   label byte	; parameter block for krnl386.exe
envir   dw 0
pcmdl   dw 80h
scmdl   dw ?
        dw 5Ch
sfcb1   dw ?
        dw 6Ch
sfcb2   dw ?

parmbs  label byte	; parameter block for hdpmi16.exe
        dw 0
        dw offset cmdline
scmdls  dw ?
        dw 5Ch
sfcb1s  dw ?
        dw 6Ch
sfcb2s  dw ?

	.const

cmdline	db 0,0Dh

if ?LOADHOST
szPath	db "PATH="
SIZPATH equ $ - szPath

svrname label byte
if ENHANCED
        db "HDPMI16e.EXE",0
else
        db "HDPMI16.EXE",0
endif
SIZSVRNAME equ $ - svrname
endif

if ?FULLPATH
prg     db "KRNL386.EXE",0
else
prg     db "SYSTEM\KRNL386.EXE",0
endif
szErr1	db "cannot launch KRNL386.EXE",13,10,'$'
if ?LOADHOST
szErr2	db "HDPMI16.EXE not found",13,10,'$'
else
szErr2	db "no DPMI host loaded",13,10,'$'
endif

	.CODE

if ?LOADHOST

;--- search PATH key in environment
;--- returns DI != 0 if found, else DI=0

SearchPath proc
	SUB DI,DI
	MOV ES,wEnviron
nextitem:
	MOV SI,offset szPath
	MOV CX,SIZPATH
	REPZ CMPSB
	JZ found
	mov al,00
	mov ch,7Fh
	repnz scasb
	cmp al,es:[di]
	JNZ nextitem
	sub di,di
found:
	RET
SearchPath endp

;--- search hdpmi16.exe

SearchSvr proc

	mov DI,BP
	PUSH DS
	POP ES
nextitem:						;<----
	PUSH SI
	push es
	pop ds
	mov si,offset svrname
	mov cx,SIZSVRNAME
	rep movsb
	mov es:[di],cl

	mov DX,BP
	MOV AX,3D00h
	INT 21h
	POP SI
	JNB found					;jmp if found!
	AND SI,SI
	JZ notfound					;PATH not defined, so we are done
	MOV DI,DX
	mov ds,wEnviron
@@:
	lodsb
	stosb
	CMP AL,';'
	JZ @F
	CMP AL,00
	JNZ @B		 				;done, nothing found
	XOR SI,SI
@@:
	DEC DI
	CMP Byte Ptr es:[DI-01],'\'
	JZ nextitem
	MOV Byte Ptr es:[DI],'\'
	INC DI
	JMP nextitem
found:
	MOV BX,AX
	MOV AH,3Eh					;close file
	INT 21h
	CLC
	RET
notfound:
	STC
	RET
SearchSvr endp
endif

if ?XMSHOOK

XMSHook proc

	jmp @F
	nop
	nop
	nop
@@:
	cmp ah,88h		; query free extended memory
	jz is88
	cmp ah,89h		; allocate extended memory block
	jz is89
default:
	db 0eah
oldhook	dd 0
is88:
	call cs:[oldhook]
	cmp eax,10000h
	jnc exit
	mov ah, 8
	call cs:[oldhook]
	movzx eax, ax
	movzx edx, dx
exit:
	retf
is89:
	cmp edx,10000h		;is call xms 2+ compatible
	jnc default 		;no, pass thru
if 0
	call cs:[oldhook]	;first try with ah=89h
	cmp ax,1			;succeeded?
	jz exit				;then exit
endif
	mov ah,09			;try with xms 2+ call
	jmp default
XMSHook endp

PF16 typedef far16 ptr

;--- wswap grabs up to 65535 kB of XMS memory
;--- and installs a XMS hook. But it doesn't understand
;--- XMS v3.0 function ah=89h and HDPMI usually uses it if
;--- a 3+ driver is installed, making both tools incompatible.
;--- this code installs another XMS hook which tries to
;--- make them work together.

InstallXMSHook proc

local	xmsaddr:PF16

	mov ax,4300h
	int 2Fh
	cmp al,80h
	jnz exit

	mov ax,4310h
	int 2Fh
	mov word ptr xmsaddr+0,bx
	mov word ptr xmsaddr+2,es
	mov ah,0
	call xmsaddr
	cmp ah,3		;is a version 3+ driver installed?
	jb exit		;no, then exit

	les bx,[xmsaddr]
@@:
	cmp byte ptr es:[bx],0EBh
	jz @F
	les bx,es:[bx+1]
	jmp @B
@@:
	mov byte ptr es:[bx+0],0EAh
	mov es:[bx+1],offset XMSHook
	mov es:[bx+3],cs
	add bx,5
	mov word ptr [oldhook+0],bx
	mov word ptr [oldhook+2],es
exit:
	ret

InstallXMSHook endp

RemoveXMSHook proc

	push cs
	pop ds
	les di,[oldhook]
	mov ax,es
	or ax,di
	jz @F
	cld
	mov si,offset XMSHook
	mov cx,5
	sub di,cx
	rep movsb
@@:
	ret

RemoveXMSHook endp

endif

if ?DISABLEHOST
myint2f proc
	cmp ax,1687h
	jz @F
old2f:
	db 0eah
oldint2f dd 0
@@:
	dec cs:[wCnt]
	jz old2f
	iret
wCnt dw 1
myint2f endp
endif

;--- main: DS=dgroup, es=PSP

main proc c

	sub sp,128
	mov bp,sp
	mov ax, es:[2Ch]
	mov wEnviron, ax

	mov word ptr scmdl, es
	mov word ptr sfcb1, es
	mov word ptr sfcb2, es

	mov word ptr scmdls, ds
	mov word ptr sfcb1s, es
	mov word ptr sfcb2s, es

if ?XMSHOOK
	call InstallXMSHook
endif

if 0        ; display interrupt vector 1Ch (hooked by wswap.exe)
	.data
ivx  db "int 1C="
ivx1 db "....:....",13,10,'$'
	.code
	pusha
	mov ax,351Ch
	int 21h
	mov di, offset ivx1
	push es
	call wordout
	inc di
	push bx
	call wordout
	mov dx, offset ivx
	mov ah, 9
	int 21h
	mov ah, 10h
	int 16h
	popa
endif

if CHECKHOST
	mov ax,1687h
	int 2fh
	and ax,ax
	jz @F
endif
;--------------------- load HDPMI16(e) if no dpmi host present
if ?LOADHOST
	call SearchPath
	mov si,di
	call SearchSvr
	jc error2
	mov bx,offset parmbs
	push ds
	pop es
	mov dx,BP
	mov ax,4B00h
	int 21h
	jnc @F
endif
error2:
	mov ah,9
	mov dx,offset szErr2
	int 21h
	jmp done
@@:

;--------------------- skip first parameter of the cmdline
	pusha
	push ds
	lds si,dword ptr pcmdl

if 0   ; display the cmdline
	pusha
	mov ax,3
	int 10h
	lodsb
	mov cl,al
	.while (cl)
		lodsb
		mov dl,al
		mov ah,2
		int 21h
		dec cl
	.endw
	mov dl,13
	mov ah,2
	int 21h
	mov dl,10
	mov ah,2
	int 21h
	mov ah,0
	int 16h
	popa
endif

	mov bx,si
	lodsb
	mov cl,al
	mov ch,00
	mov [bx],ch
	mov di,si
	inc cx			;copy terminating 0D as well
	mov dl,1
	.while (cx)
		lodsb
		.if (dl)
		   .if (al > ' ')
				mov dl,2
		   .elseif (dl == 2)
				mov dl,0
				dec si
				.continue
		   .endif
		.else
			mov [di],al
			inc di
			.if (al != 13)
				inc byte ptr [bx]
			.endif
		.endif
		dec cx
	.endw
	pop ds
	popa

if ?DISABLEHOST
	mov ax,352Fh
	int 21h
	mov word ptr [oldint2f+0],bx
	mov word ptr [oldint2f+2],es
	mov dx,offset myint2f
	mov ax,252fh
	int 21h
endif

;--- either get the full path for DOSX.EXE - or assume we're in the Windows directory.

if ?FULLPATH
	mov es,[wEnviron]
	xor di,di
	mov cx,-1
	mov al,0
@@:
	repnz scasb
	scasb
	jnz @B
	add di,2	;skip the 01 00 sequence
	mov si,di
	mov di,bp
	mov ax,es
	mov cx,ds
	mov ds,ax
	mov es,cx
	mov dx,di
nextchr:
	lodsb
	stosb
	cmp al,'\'
	jnz @F
	mov dx,di
@@:
	and al,al
	jnz nextchr
	mov ds,cx
	mov di,dx
	mov si,offset prg
	mov cx,sizeof prg
	rep movsb
	mov dx,bp
else
	mov dx,offset prg
endif

;--------------------- now call KRNL386.EXE

	mov bx,offset parmb
	push ds
	pop es
int 3
	mov ax,4B00h
	int 21h
	jnc @F
	mov ah,9
	mov dx,offset szErr1
	int 21h
@@:
if ?DISABLEHOST
	lds dx,[oldint2f]
	mov ax,252Fh
	int 21h
	push cs
	pop ds
endif
done:
if ?XMSHOOK
	call RemoveXMSHook
endif
	add sp,128
	ret

if 0	; activate if a word is to be displayed
wordout:
	pop cx
	pop ax
	push cx
	push ax
	mov al,ah
	call byteout
	pop ax
byteout:
	mov ah, al
	shr al, 4
	call nibout
	mov al, ah
nibout:
	and al, 0fh
	add al, '0'
	cmp al, '9'
	jbe @F
	add al, 7
@@:
	mov [di], al
	inc di
	ret
endif

main endp

start:
	mov ax, cs
	mov ds, ax
	mov cx, ss
	sub cx, ax
	shl cx, 4
	push ds
	pop ss
	add sp, cx       ;SS=DS=CS

	mov bx, ax
	mov cx, es
	sub bx, cx
	mov cx, sp
	shr cx, 4
	add bx, cx
	mov ah,4Ah
	int 21h
	call main
	mov ah,4ch
	int 21h

	END start
