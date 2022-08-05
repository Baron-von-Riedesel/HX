
;*** simple startup code for a 16-bit DPMI client in HX MZ format
;*** will load HDPMI16.EXE if no DPMI server is found

;--- versions created:
;--- + jmppm16.obj: will just call main(), without parameters!
;---   may be useful for assembler programs. 
;--- + jmppm16w.obj: will jump to label _cstart_ and may be used with
;---   Open Watcom. It is restricted to small memory model. Will change
;---   MZ segment fixups to selectors (for DGROUP and CGROUP)
;--- + jmppm16m.obj: will jump to label _astart and may be used with
;---   MS Visual C++. It is restricted to small memory model. Will change
;---   MZ segment fixups to selectors (for DGROUP and CGROUP)


	.286
	.MODEL SMALL
	.DOSSEG
	.386		;currently required by relocs.inc

?LOADSERVER	equ 1
_SFLAGS_	equ 20h

_TEXT16 segment word public 'CODE'
_TEXT16 ends

CGROUP group _TEXT, _TEXT16

ifdef ?OW

;--- WLINK can only pack code segments belonging to the same group

DOSXXX segment word public 'CODE'
DOSXXX ends
CGROUP group DOSXXX
CSEG   segment word public 'CODE'
CSEG   ends
CGROUP group CSEG
endif

ifdef ?MS
;CGROUP group _TEXT, _TEXT16
endif

;externdef _end:abs

EXECRM struct
environ dw ?
cmdline dd ?
fcb1    dd ?
fcb2    dd ?
res1    dd ?
res2    dd ?
EXECRM ends

_TEXT16 segment

main proto near c

_JmpPM proc stdcall

if ?C
  ifdef ?OW
	jmp far ptr CGROUP:$+5  ;workaround for OW 1.3 wlink bug  
  endif
endif  
	pushf
	mov ah,70h
	push ax
	popf
	pushf
	pop ax
	popf
	and ah,0F0h
	js no286				;cpu is a 8086/80186
if ?C
	mov ax,1000h			;set size DGROUP to 64 kB
	mov bx,DGROUP
else
	mov ax,sp
	shr ax,4
	mov bx,ss
endif
	add ax,bx
	mov bx,es
	sub ax,bx
	inc ax
	mov bx,ax
	mov ah,4Ah
	int 21h
if ?C        
	mov dx,offset errstr3
	jc errexit
endif
	mov ax,DGROUP
	mov ds,ax				;DS=DGROUP
	mov bx,ss
	sub bx,ax				;size DGROUP without stack in paras
	shl bx,4				;in bytes
	add bx,sp				;size DGROUP with stack
	mov ss,ax				;SS=DGROUP
	mov sp,bx
if ?C
	push ds
	pop es
externdef c _edata:abs
	mov di,offset _edata	;_edata = start of _BSS
	xor cx,cx
	sub cx,di
	shr cx,1
	xor ax,ax
	cld
	rep stosw				;clear _BSS, stack, near heap
endif
	mov ax,1687h			;DPMI host installed?
	int 2fh
	and ax,ax
if ?LOADSERVER
	jz @F
	call loadserver
	mov ax,1687h			;try again
	int 2fh
	and ax,ax
	jnz nodpmi1 			;still no host, exit
@@:        
else
	jnz nodpmi1 			;no dpmi host, exit
endif
	push es
	push di
	and si,si
	jz sm2
							;alloc memory for dpmi host
	mov ah,48h
	mov bx,si
	int 21h
	jc nodpmi2

	mov es,ax
sm2:
	mov bp,sp
	xor ax,ax				;16 bit application
	call dword ptr [bp]		;initial switch to protected mode
	jc nodpmi3				;C if switch didn't work

if ?C
	call PatchRelocs
endif

if ?C
  ifdef ?OW
	externdef _cstart_:near
	xor si,si
	mov bx,81h
	jmp _cstart_
  elseifdef ?MS
	externdef __astart:near
	jmp __astart
  endif        
else
	xor bp,bp
	call main
	mov ah,4Ch
	int 21h
endif

no286:
	mov dx,offset d80286
	jmp errexit
nodpmi1:
	mov dx,offset errstr1
	jmp errexit
nodpmi2:
nodpmi3:
nodpmi4:
nodpmi5:
nodpmi6:
nodpmi7:
	mov dx,offset errstr2
errexit:
	push cs
	pop ds
	mov ah,09
	int 21h
	mov ax,4CFFh
	int 21h
_JmpPM endp

if ?C
		include relocs.inc
endif

if ?LOADSERVER

;*** this is a real mode proc! ***

loadserver proc stdcall uses ds es si di

local psp:word
local env:word
local cmdline:word
local parmblock:EXECRM
local pgmname[80]:byte

	mov ah,51h
	int 21h
	mov psp,bx
	mov es,bx
	mov ax,es:[002Ch]
	mov env,ax

	CALL searchpath		;search PATH= variable -> SI, SI=0000 if error
	CALL searchpgm		;search HDPMI16
	JB error			;---> error exit "not found"

	mov AX,env
	mov parmblock.environ,ax
	mov cmdline,0D00h
	lea bx,cmdline
	mov word ptr parmblock.cmdline+0,bx
	mov word ptr parmblock.cmdline+2,ss
	mov AX,psp
	mov word ptr parmblock.fcb1+0,5Ch
	mov word ptr parmblock.fcb1+2,ax
	mov word ptr parmblock.fcb1+0,6Ch
	mov word ptr parmblock.fcb2+2,ax

	push SS
	pop DS 					;DS:DX=Path, ES:BX=parameter block
	push SS
	pop ES
	lea DX,pgmname 			;path for DPMISV16/32.EXE
	lea BX,parmblock
	MOV AX,4B00h			;execute server
	INT 21h
	JB error
	mov ax,1
	ret
error:
	mov ax,0
	ret

;*** search HDPMI16 in current directory and directories of PATH ***
;*** Input: SI=address of PATH Variable or NULL (no PATH defined) ***
;***      : DI=name of 

searchpgm:
	push si
	mov si,di
	lea DI,pgmname
	PUSH SS
	POP ES
	mov dx,di
	mov ds,env
nxtc:
	lodsb
	stosb
	cmp al,'\'
	jnz @F
	mov dx,di
@@:
	cmp al,0
	jnz nxtc
	mov di,dx
	pop si
	mov bl,0
L03BD:								;<----
	PUSH CS
	POP DS
	PUSH SI
	mov si,offset srvname			;name "HDPMI16.EXE"
	mov cx,lstr
	rep movsb

	push ss
	pop ds
	lea DX,pgmname
	MOV AX,3D00h or _SFLAGS_	;try to open "HDPMI16.EXE"
	INT 21h
	POP SI
	JNB L0403					;found!
	and bl,bl
	jnz @F
	mov bl,1
	lea di,pgmname				;get current directory
	jmp L03BD
@@:
	AND SI,SI
	JZ L040A					;PATH isnt defined, so were done
	MOV DI,DX
	mov ds,env
L03E1:
	lodsb
	stosb
	CMP AL,';'
	JZ L03F2
	CMP AL,00
	JNZ L03E1					;done, nothing found
	XOR SI,SI
L03F2:
	DEC DI
	CMP Byte Ptr es:[DI-01],5Ch ;'\'
	JZ L03BD
	MOV Byte Ptr es:[DI],5Ch	;'\'
	INC DI
	JMP L03BD

L0403:
	MOV BX,AX
	MOV AH,3Eh					;Close File
	INT 21h
	CLC
	RETN
L040A:
	STC
	RETN

;*** search PATH in environment ***
;*** Out: SI-> behind "PATH=" or 0000 ***
;***      DI-> path of executable in environment

searchpath:
	SUB DI,DI
	xor dx,dx
	MOV ES,env
	PUSH CS
	POP DS
L02FB:
	MOV SI,offset szPath	;"PATH="
	MOV CX,0005
	REPZ CMPSB
	JNZ @F
	mov dx,di
@@:
	mov al,00
	mov ch,7Fh
	repnz scasb
	cmp al,es:[di]
	JNZ L02FB
	add di,3			;so DI points to path of executable now
	mov si,dx
	RETN
loadserver endp

szPath   db   'PATH='

srvname  db 'HDPMI16.EXE',00

lstr equ $ - srvname

endif

d80286	db "80286+ required",13,10,'$'        
errstr1 db "no DPMI server found",13,10,'$'
errstr2 db "DPMI initialization failed",13,10,'$'
if ?C
errstr3 db "memory error",13,10,'$'
endif

_TEXT16 ends

ifndef ?OW
    .STACK
;stack segment word stack 'STACK'
;stack ends
endif        

	end _JmpPM

