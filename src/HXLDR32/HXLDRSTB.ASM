
;*** tsr to load dpmild32 if app is PE
;--- this module becomes a MZ-Stub for HXLDR32.EXE
;*** best view with TABSIZE 4

	.286
	.model small
	.386
	option casemap:none

ifdef __JWASM__
	option mz:40h		;full MZ header
endif

	include winnt.inc
	include hxldr32.inc

?DRIVER		= 1			;1, 1=support to install as device driver
?SFLAGS		= 20h		;20h open executable with "deny write"
?DBGBREAK	= 0			;0, 1=set some breakpoints 
?BREAK4C	= 0			;0, 1=breakpoint on int 21, ah=4Ch
?CHECKSUBSYS = 1		;1, 1=check for cpu 386
?CHECKGUI    = 0		;0, 1=check for GUI subsys
?SAVESP      = 0		;0, 1=save SP (required by VC?)
?SAVEFL      = 1		;1, 1=don't modify Flags
?HIDE4B01    = 1		;1, 1=dont use INT for 4B01 call
?CONTEXECERR = 1		;1, 1=continue on exec DPMILD32.EXE errors 

	.code

if ?DRIVER

IODAT   struct				;structure for dos device drivers
cmdlen  db      ?           ;+0
unit    db      ?			;+1	
cmd     db      ?           ;+2
status  dw      ?           ;+3
        db      8 dup (?)	;+5
media   db      ?           ;+13
trans   dd      ?           ;+14
count   dw      ?           ;+18
start   dw      ?           ;+20
drive   db      ?           ;+23
IODAT   ends

	dw 0ffffh
	dw 0ffffh
	dw 8000h				  ;attribute
	dw offset devstrat		  ;device strategy
vDev dw offset devint		  ;device interrupt
	db 'HXLDR32$'			  ;device name 8 chars (use carefully)

saveptr dd 1 dup(0)

devstrat proc far
	mov cs:word ptr[saveptr],bx
	mov cs:word ptr[saveptr+2],es
	ret
devstrat endp

devintx proc far
	push ds
	push bx
	lds bx,cs:[saveptr]
	mov [bx.IODAT.status],8103h
	pop bx
	pop ds
	ret
devintx endp

endif

myint21 proc
if ?SAVEFL
	pushf
endif
	cmp ax,4b00h
	jz is4b00
if ?BREAK4C
	cmp ah,4ch
	jnz @F
	int 3
@@:
endif
if ?SAVEFL
	popf
endif
default:
	db  0eah
oldint21 dd 0			;old int 21h vector

oldvecofs equ oldint21 - myint21

	.errnz oldvecofs - ?OLDVECOFS, <constant ?OLDVECOFS must be adjusted>

notape:
	mov ah,3eh
	int 21h
dodefault_1:
	pop ds
dodefault:
	popa
	jmp default
execerror:
	pop es
if ?CONTEXECERR
	jmp dodefault_1
else
	pop ds
	mov bp,sp
	mov [bp+0Eh],ax
	or byte ptr [bp+10h+4],1
	popa
	iret
endif
is4b00:
if ?SAVEFL
	popf
endif
	pusha		;stack: pusha, IP, CS, FL
	mov bp,sp
rBX equ <[bp+8]>
rDX equ <[bp+10]>
rDS equ <[bp-2]>
	mov ax, 3d00h + ?SFLAGS
	int 21h
	jc dodefault
	push ds
	push cs
	pop ds
	assume ds:_TEXT
	mov bx,ax
	mov di,offset ReadBuffer
	mov dx,di
	mov cx,40h				;read MZ header
	mov ah,3Fh
	int 21h
	jc notape
	cmp ax,cx
	jnz notape
	cmp word ptr [di],"ZM"
	jnz notape
	cmp word ptr [di+6],0h		;num reloc entries
	jz @F
	cmp word ptr [di+18h],40h	;no PE if relocs start before offs 40h
	jb notape
@@:
	mov dx,word ptr [di+3Ch]
	mov cx,word ptr [di+3Eh]
	mov ax,4200h
	int 21h
	jc notape
	mov dx,di
if ?CHECKSUBSYS
	mov cx,SIZERB
else
	mov cx,4		;just read the Signature and rely on DPMILD32
endif
	mov ah,3Fh
	int 21h
	jc notape
	cmp ax,cx
	jnz notape
	cmp [di].IMAGE_NT_HEADERS.Signature,"EP"
	jnz notape
if ?CHECKSUBSYS        
	cmp [di].IMAGE_NT_HEADERS.FileHeader.Machine,IMAGE_FILE_MACHINE_I386
	jnz notape
endif
if ?CHECKGUI
	cmp [di].IMAGE_NT_HEADERS.OptionalHeader.Subsystem,IMAGE_SUBSYSTEM_WINDOWS_GUI
	jz notape			;is a windows GUI app
endif
	mov ah,3eh
	int 21h

	push es				;save original es

	mov si, rBX
	push es
	pop ds
	push cs
	pop es
	cld
;	mov di,offset LEXEC	;LEXEC IS ReadBuffer
	mov bx,di
	mov cx,7
	rep movsw			;copy exec parm block

	mov si, rDX
	mov ds, rDS
	mov di, offset szPgm
	mov cl, sizeof szPgm
@@:
	lodsb
	stosb
	and al,al
	loopnz @B

	push cs
	pop ds

if ?DBGBREAK
	int 3
endif
	mov dx,offset szLdrPath
	mov ax,4b01h		;load but do not execute
if ?HIDE4B01
	push word ptr [bp+10h+4]	;push the current flags
	call cs:[oldint21]
else
	int 21h
endif
ifndef _DEBUG
	jc execerror
else
	jnc loadok
	mov si,offset szLdrPath		;in debug mode display loader path
@@:
	lodsb
	and al,al
	jz @F
	mov dl,al
	mov ah,2
	int 21h
	jmp @B
@@:
	mov dx,offset szError3
	mov ah,9
	int 21h
	jmp execerror
loadok:
endif
ife ?SAVESP
	lss sp, [sssp]	;get SS:SP of DPMILD32.EXE
endif
	mov ah,62h
	int 21h
	mov es,bx
;------------------------- vector 22 at psp:[000A] must be adjusted
	mov word ptr es:[000Ah], offset myret
	mov word ptr es:[000Ch], cs
  if ?SAVESP
	mov bx,[cOffs]
	mov [bx],sp
	add [cOffs],2
	lss sp, [sssp]
  endif
	pop ax				;for subfunc 01 the value for AX is pushed

						;as overlay, dpmild32 expects 
						;ds:dx : full path to dpmild32 
						;ds:bx : path to program to execute
	mov dx, offset szLdrPath
	mov bx, offset szPgm
	push word ptr [csip+2]
	push 0
	retf
myint21 endp

;--- this code runs after the program has terminated.
;--- DOS should have restored SS:SP from the value
;--- found at PSP:[002Eh] (DosBox does this not correctly!)

myret proc
if ?DBGBREAK
	int 3
endif
if ?SAVESP
	mov bx,cs:[cOffs]
	mov sp,cs:[bx-2]
	dec bx
	dec bx
	mov cs:[cOffs],bx
endif
	pop es
	pop ds
	mov bp,sp
	mov [bp+0Eh],ax
	lahf
	mov byte ptr [bp+10h+4],ah
	popa
	iret
myret endp

ifdef _DEBUG
szError3 db " can't be loaded.",13,10,'$' 
endif

;*** variables ***

if ?CHECKGUI or ?CHECKSUBSYS
SIZERB	equ 4 + sizeof IMAGE_FILE_HEADER + IMAGE_OPTIONAL_HEADER.Subsystem + 2
endif

ReadBuffer label byte	;size SIZERB (==5Eh)!
LEXEC	label word		;a exec parameter block for ax=4b01!
		dw 0            ;+0 environment
		dd 0            ;+2 cmdline
		dd 0            ;+6 fcb 1
		dd 0            ;+10 fcb 2
sssp	dd 0            ;+14
csip	dd 0			;+18
szPgm	db 80 dup (0)	;program to execute (full path, 2+64+1+12+1)

if ?SAVESP
cOffs		dw offset stackptrs
stackptrs	dw 8 dup (0)
endif

szLdrPath	db 80 dup (0)	;store full path of DPMILD32 here

resident	equ $

	assume ds:nothing

;*** search Variable PATH in environment
;*** in: ES = environment segment
;*** out: DI-> behind "PATH=" or NULL

SearchPath proc
	SUB DI,DI
	PUSH CS
	POP DS
nextitem:
	mov dx,di
	MOV SI,offset szPath
	MOV CX,0005
	REPZ CMPSB
	JZ found
	mov di,dx
	mov al,00
	mov ch,7Fh
	repnz scasb
	cmp al,es:[di]
	JNZ nextitem
	sub di,di
found:
	RET
SearchPath endp

;--- get current drive/dir to DS:SI

getcurrentdir proc
	mov ah,19h
	int 21h
	mov dl,al
	inc dl
	add al,'A'
	mov [si],al
	mov ax,"\:"
	mov [si+1],ax
	add si,3
	mov ah,47h
	int 21h
	mov ah,-1
@@:
	lodsb
	inc ah
	and al,al
	jnz @B
	dec si
	and ah,ah
	jz @F
	mov word ptr [si],"\"
	inc si
@@:
	ret
getcurrentdir endp

;*** search DPMILDR, first in current dir, then in dirs from PATH ***
;*** in: ES = environment segment
;*** in: SI = points to PATH= value or is NULL (no PATH)

SearchLoader proc

	mov DI,offset szLdrPath
	push es					;save environment

	PUSH CS
	POP ES

	push si
	mov si, di 
	call getcurrentdir
	mov di, si
	pop si
nextdir:							;check next directory in path
	PUSH CS
	POP DS
	PUSH SI
	mov si,offset szLoader
	mov cx,LSZLOADER
	rep movsb
	mov [di],cl
	POP SI

	mov DX,offset szLdrPath
	MOV AX,3D00h or ?SFLAGS	;try to open "DPMILD32.EXE"
	INT 21h
	JNB found
	AND SI,SI				;is PATH done?
	JZ notfound				;yes, loader not found
	pop ds					;get environment segment into DS
	push ds
	MOV DI,DX
@@:
	lodsb
	stosb
	CMP AL,';'
	JZ nextpathdone
	CMP AL,00
	JNZ @B
	XOR SI,SI
nextpathdone:
	DEC DI
	CMP byte ptr es:[DI-01],'\'
	JZ nextdir
	MOV byte ptr es:[DI],'\'
	INC DI
	JMP nextdir
found:
	pop es
	MOV BX,AX
	MOV AH,3Eh				;close file
	INT 21h
	CLC
	RET
notfound:
	pop es
	STC
	RET
SearchLoader endp

;--- just install here

main proc

	mov ax,3521h			;install int 21h handler proc
	int 21h
	push cs
	pop ds
	mov word ptr [oldint21+0],bx
	mov word ptr [oldint21+2],es
	mov dx, offset myint21
	mov ax, 2521h
	int 21h
	mov dx,offset szSuccess
	mov ah,9
	int 21h
	ret

main endp

;--- entry point when loaded from the command line

start proc
	mov si,80h
	cld
	lodsb
	mov cl,al
	.while (cl)
		lodsb
		.if ((cl > 1) && ((al == '-') || (al == '/')))
			lodsb
			dec cl
			or al,20h
			.if (al == 'u')
				mov dx, offset szError4
				mov al,1
				jmp exit
			.elseif (al == 'q')
				mov cs:szSuccess,'$'
			.else
printhelp:
				mov dx, offset szHelp
				mov al,0
				jmp exit
			.endif
		.elseif ((al == ' ') || (al == 9))
		.else
			jmp printhelp
		.endif
		dec cl
	.endw
	push es
	MOV ES,es:[002Ch]
	CALL SearchPath		;search PATH var, DI=0000 if not found
	MOV SI,DI			;init SI with value of PATH (or NULL)
	CALL SearchLoader	;search DPMILD32
	pop es
	jc error
	push es
	call main
	pop es
	xor bx,bx			;free environment now
	xchg bx,es:[2ch]
	mov es,bx
	mov ah,49h
	int 21h

	xor bx,bx
	.while (bx < 20)
		mov ah,3Eh
		int 21h
		inc bx
	.endw

	mov bx, offset szLdrPath
	.while (byte ptr cs:[bx])
		inc bx
	.endw
	inc bx		;add the terminating 0
	mov dx,bx
	add dx,100h
	mov al,dl
	shr dx,4
	test al,0Fh
	jz @F
	inc dx
@@:
	mov ah,31h
	int 21h
error:
	MOV DX,offset szError1
	mov al,1
exit:
	push ax
	call errout
	pop ax
	mov ah,4ch			;dont go resident in case of errors	
	int 21h

start endp

errout:
	push cs
	pop ds
	mov [szError2],' '
	MOV AH,09h
	INT 21h
	stc
	ret

if ?DRIVER

ignname proc near
	.while (byte ptr [si] == ' ')
		inc si
	.endw
	.while (byte ptr [si] != ' ')
		inc si
	.endw
	.while (byte ptr [si] == ' ')
		inc si
	.endw
	ret
ignname endp

devint  proc far
	pusha
	push ds
	push es
	cld
	lds bx,cs:[saveptr]
	mov [bx.IODAT.status],8103h
	cmp [bx.IODAT.cmd],00
	jnz devi1
	mov [bx.IODAT.status],0100h
	mov word ptr [bx.IODAT.trans+0],0
	mov word ptr [bx.IODAT.trans+2],cs
	mov cs:[vDev],devintx
	lds si,dword ptr [bx.IODAT.count]
	call ignname 		;skip driver name
	push cs
	pop es
	mov ax,[si]
	.if ((al == '-') || (al == '/'))
		or ah,20h
		.if (ah == 'q')
			mov cs:szSuccess,'$'
			inc si
			inc si
			.while (byte ptr [si] == ' ')
;				mov dl,[si]
;				mov ah,2
;				int 21h
				inc si
			.endw
		.endif
	.endif
	mov di,offset szLdrPath
	mov dx,di
	mov cx,sizeof szLdrPath-1
@@:
	lodsb
	cmp al,' '
	jbe @F
	stosb
	loop @B
@@:
	mov al,0
	stosb
	push cs
	pop ds

	MOV AX,3D00h or ?SFLAGS	;try to open "DPMILD32.EXE"
	INT 21h
	jnc @F
	mov si,dx
	.if (!(byte ptr [si]))
		mov si,offset szLoader
	.endif
	.while (1)
		lodsb
		.break .if (!al)
		mov dl,al
		mov ah,2
		int 21h
	.endw
	mov dx,offset szError2
	call errout
	jmp devi1
@@:
	lds bx,cs:[saveptr]
	mov word ptr [bx.IODAT.trans+0],di	;offset resident
	mov bx,ax
	mov ah,3eh
	int 21h
	call main
devi1:
	pop es
	pop ds
	popa
	ret
devint endp

endif

szSuccess	db "HXLdr32 V",?VERSION
			db " installed. Win32 console apps may possibly run now in DOS",13,10,'$'
szPath		db 'PATH='
szError1:
if ?32BIT
szLoader	db 'DPMILD32.EXE'
else
szLoader	db 'DPMILD16.EXE'
endif
LSZLOADER	equ $ - szLoader
szError2	db 0
			db 'not found. Unable to install.',13,10,'$'
szError4	db 'HXLdr32 is not installed',13,10,'$'        
szHelp		db 'HXLdr32 V',?VERSION,13,10
			db 'usage: HXLdr32 <-u> <-h>',13,10
			db '   -u: uninstall HXLdr32 (must have been installed as TSR, not as device driver)',13,10
			db '   -h: display this help',13,10
			db '   else (without an option) HXLdr32 will install as TSR',13,10
			db '$'
            

	.stack 400h
            
	end start
