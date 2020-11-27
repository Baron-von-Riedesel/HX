
;--- MZ stub for HX DOS extended applications
;--- this stub loads the NE/PE loader DPMILD16/32.
;--- to be assembled with Masm or JWasm

_SFLAGS_   = 20h	;open with "deny write"

?MINMEM	 = 600h		;min free paragraphs for DPMILDxx
MAXDIR   = 64+4		;max length of a directory path (including 00h)
MAXPATH  = MAXDIR+12
?BESAFE  = 1
?DOSMEMCHK = 1		;0=check for sufficient DOS memory

	.286

ifdef __JWASM__
	option MZ:40h
endif

cr		equ 13
lf		equ 10

_TEXT   segment public 'CODE'

;--- the "16STUB" string is required by TDX.EXE
;--- but not sufficient!!!

ife ?32BIT
ifdef ?POWERPACK
	db "16STUB"
	db 0CAh dup (0)
endif
endif

;--- load DPMILDxx at start of memory block, then run it.
;--- ES=PSP, DS=start of memory block, CS=SS=top of memory
;--- CX=0, BP=frame

szPgm   equ [bp+00h]     ;execute program name ("DPMIDLXX.EXE")
szParm  equ [bp-MAXPATH] ;application name (from environment)

launch proc

	xor DX,DX
	mov cl,20h
	mov ah,3Fh		;read the MZ header
	int 21h
	jc readerror

if ?BESAFE

;--- additional tests

	xor si,si
	lodsw
	cmp ax,"ZM"
	jnz formerror
	add si,4		;skip "bytes last page" + "no of pages"
	lodsw			;no of relocation entries
	mov di,ax
	and ax,ax
	jz norelocs
	push ax
	xor cx,cx
	mov dx,[si+16]	;begin relocations
	mov ax,4200h
	int 21h
	pop cx
	shl cx,2		;4 byte for 1 reloc
	sub sp,cx
	mov dx,sp
	push ds
	push ss
	pop ds
	mov ah,3Fh		;read relocs at SS:SP
	int 21h
	pop ds
	jc formerror
norelocs:
	lodsw			;size of header in paragraphs
	shl ax,4
	mov dx,ax
	xor cx,cx
	mov ax,4200h
	int 21h
	xor dx,dx
endif

	MOV AH,3Fh		;read the true DPMILD32.EXE
	mov cx,?MINMEM shl 4
	INT 21h
	JC readerror	;---> error "read error"
if ?BESAFE        
	cmp ax,cx		;DPMILD32 binary must be < 24 kB
	jnc formerror
endif
	mov ah,3Eh
	int 21h
if ?BESAFE
	mov cx,di		;some relocs to resolve?
	jcxz norelocs2
	mov di,sp
	mov ax,ds
@@:
	mov bx,ss:[di+2]
	shl bx,4		;size of loader is <= 24 kB, so no overflow possible
	add bx,ss:[di+0]
	add [bx],ax
	add di,4
	loop @B
	mov sp,di
norelocs2:
endif
	mov bx,sp		;=lea bx,szParm	;name of application to start

	push ds
	push dx

	mov dx,bp		;full path of 'DPMILDXX.EXE'

	push ss
	pop ds
	retf
launch endp

if ?BESAFE
formerror:
	mov dx,offset dFormError
	jmp error1
endif

readerror:
	mov dx,offset dReadError
error1:
if 0
;--- close file? Will be done by DOS.
	mov ah,3Eh
	int 21h
endif
errorX: 				;<--- errors
	push cs
	pop ds
	call DispError
	MOV DX,offset dFatal
	call DispError
	mov ax,4CF0h	;error code F0h
	int 21h
DispError:				;display error msg in DX
	MOV AH,09h
	INT 21h
	ret

dFatal		db cr,lf,'program loading aborted',cr,lf,'$'
dReadError	db cr,lf,"read error",'$'
if ?BESAFE
dFormError	db cr,lf,"bad loader file",'$'
endif

endcopy label byte

main proc

;--- setup stack at end of memory block

	cld
	mov ax,ds:[0002]
ife ?DOSMEMCHK        
	mov bp,es
	push ax
	sub ax,bp
	cmp ax,?MINMEM+30h	;enough free memory in this block?
	pop ax
	mov dx,offset dMemory
	jc errorX
endif
	sub ax,30h
	mov ss,ax
	mov sp,300h-MAXPATH

;--- setup BP stack frame

	mov BP,SP
	sub SP,MAXPATH

;--- fill szParm with application name

	mov SI,SP    		;SI=szParm
	push es				;save PSP
	mov es,es:[002Ch]	;ES=environment
	CALL GetAppName

	push cs
	pop ds

;--- search "PATH=", DI=NULL if it doesn't exist

	CALL SearchPath
	MOV SI,DI			;set SI to start of PATH= value

;--- fill szPgm (search DPMILDxx)

	push SS
	pop DS
	CALL SearchLdr
	MOV DX,offset dNotFnd
	JB errorX  			;---> error "not found"

;--- copy the final code to end of memory block

	mov cx,offset endcopy
	push ss
	pop es
	xor di,di
	xor si,si
	db 2Eh			;CS prefix
	rep movsb

	pop es			;restore PSP

	push ds
	push cx			;CX is 0

	push cs
	pop ds
	retf

main endp

;--- search name of app in environment
;--- the name may be a full path or not
;--- depending on caller
;--- in: ES=environment, SS:SI=dest
;--- modifies AX,CX,SI,DI

GetAppName proc
	SUB DI,DI
	mov al,00
	mov cx,-1
@@:
	repnz scasb		;search end of environ (00,00)
	scasb
	jnz @B
	inc di			;skip 0001
	inc di

@@:
	mov al,es:[di]
	mov ss:[si],al
	inc si
	inc di
	and al,al
	jnz @B
	RET
GetAppName endp

;--- search PATH= in Environment
;--- In: ES=environment
;--- Out: DI-> behind "PATH=" or NULL
;--- modifies AX,CX,SI,DI

SearchPath proc
	SUB DI,DI
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

;--- search DPMILDxx, first in current Dir, then scan PATH
;--- Input: ES=environ, SI=address PATH variable or 0000 (no PATH exists)
;--- Output: NC if found, C if error
;--- full loader path in szPgm
;--- modifies AX,BX,CX,DX,SI,DI

SearchLdr proc
	lea DI,szPgm
	mov dx,di
nextentry:								;<----
	PUSH SI
	mov si,offset ldrname			;Name "DPMILDXX.EXE"
	mov cx,SIZLDRNAME
@@:
	db 2Eh		;CS prefix
	lodsb
	mov [di],al
	inc di
	loop @B
	mov [di],cl

	MOV AX,3D00h or _SFLAGS_		;open DPMILDXX.EXE
	INT 21h
	POP SI
	JNB ldrfound					;jmp if found!
	AND SI,SI
	stc
	JZ notfound					;PATH not defined, so we are done
	MOV DI,DX
	mov cx,MAXDIR
@@:
	mov al,es:[si]
	mov [di],al
	inc si
	inc di
	CMP AL,';'
	JZ @F
	CMP AL,00
	LOOPNZ @B						;PATH done
	XOR SI,SI
@@:
	DEC DI
	CMP Byte Ptr [DI-01],'\'
	JZ nextentry
	MOV Byte Ptr [DI],'\'
	INC DI
	JMP nextentry
ldrfound:
	XCHG ax,bx			;=MOV BX,AX
;	MOV AH,3Eh			;close file
;	INT 21h
;	CLC
notfound:
	RET
SearchLdr endp

szPath  db   'PATH='
SIZPATH equ $ - szPath

dNotFnd db cr,lf,'cannot find loader '
ldrname	label byte
if ?32BIT
	db 'DPMILD32.EXE'
else
	db 'DPMILD16.EXE'
endif
SIZLDRNAME equ $ - ldrname
	db '$'

ife ?DOSMEMCHK
dMemory	db cr,lf,"insufficient memory",'$'
endif

ifndef ?POWERPACK
	org 1C0h
endif

_TEXT ends

if ?DOSMEMCHK
_BSS segment public 'DATA'
	db (?MINMEM+14h) * 16 dup (?)
_BSS ends
endif

	end main
