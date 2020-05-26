
;*** search dpmiserver HDPMI and execute it ***

;--- there are 2 versions. the standard one searches 
;--- the PATH variable in environment and scans all
;--- directories for HDPMI32.EXE.
;--- the other one just includes HDPMI32.INC

ifndef ?HDPMI		;assume HDPMI32 is included?
?HDPMI = 0
endif

_SFLAGS_   = 20h    ;open with "deny write"

	.386
;	.model small, stdcall

ife ?HDPMI
EXECRM struct
environ dw ?
cmdline dd ?
fcb1    dd ?
fcb2    dd ?
res1    dd ?
res2    dd ?
EXECRM ends
endif

if ?HDPMI
HDPMI segment use16 para public '16_CODE'
hostcode:
	include ..\HDPMI\STUB32\HDPMI32.INC
	align 16
HDPMI ends

CGROUP16 group HDPMI, _TEXT16

endif

_TEXT16 segment use16 word public '16_CODE'

;*** this is a real mode proc! ***

loadserver  proc stdcall uses ds es si di

ife ?HDPMI
local   psp:word
local   env:word
local   parmblock:EXECRM
local   szCmdLine[2]:byte
local   pgmname[80]:byte
endif

	mov ah,51h
	int 21h
	mov es,bx
	assume es:_TEXT16
ife ?HDPMI
	mov ax,es:[002Ch]
	mov psp,bx
	mov env,ax
	CALL searchpath	;search PATH= variable -> SI, SI=0000 if error
	CALL searchpgm	;search HDPMI32
	JB error		;---> error exit "not found"

	mov AX,env
	mov [parmblock.environ],ax
	mov AX,psp
	shl eax,16
	mov ax,5ch
	mov [parmblock.EXECRM.fcb1],eax
	mov [parmblock.EXECRM.fcb2],eax
	lea ax,szCmdLine
	mov word ptr szCmdLine,0
	mov word ptr [parmblock.EXECRM.cmdline+0],ax
	mov word ptr [parmblock.EXECRM.cmdline+2],ss

	push SS
	pop DS					;DS:DX=Path, ES:BX=parameter block
	push SS
	pop ES
	lea DX,pgmname			;path for DPMISV16/32.EXE
	lea BX,parmblock
	MOV AX,4B00h			;execute server
	INT 21h
	JB error
	xor dx,dx
	mov ax,1
	ret
error:
	xor ax,ax
	ret
else
	push bp
	push cs
	call hostcode
	pop bp
	cmp al,4
	mov ax,1
	jc exit
	dec ax
exit:
	ret
endif

ife ?HDPMI

;*** search HDPMI32 in current directory and directories of PATH ***
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
nextline:						;<----
	PUSH CS
	POP DS
	PUSH SI
	mov si,offset srvname	;name "HDPMI32.EXE"
	mov cx,lstr
	rep movsb

	push ss
	pop ds
	lea DX,pgmname
	MOV AX,3D00h or _SFLAGS_;try to open "HDPMI32.EXE"
	INT 21h
	POP SI
	JNB found
	and bl,bl
	jnz @F
	mov bl,1
	lea di,pgmname			;get current directory
	jmp nextline
@@:
	AND SI,SI
	JZ failed  			;PATH isnt defined, so were done
	MOV DI,DX
	mov ds,env
@@:
	lodsb
	stosb
	CMP AL,';'
	JZ @F
	CMP AL,00
	JNZ @B					;done, nothing found
	XOR SI,SI
@@:
	DEC DI
	CMP Byte Ptr es:[DI-01],'\'
	JZ nextline
	MOV Byte Ptr es:[DI],'\'
	INC DI
	JMP nextline
found:
	MOV BX,AX
	MOV AH,3Eh				;Close File
	INT 21h
	CLC
	RETN
failed:
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
nextvar:
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
	JNZ nextvar
	add di,3			;so DI points to path of executable now
	mov si,dx
	RETN
endif

loadserver endp

ife ?HDPMI
szPath   db 'PATH='
srvname  db 'HDPMI32.EXE',00
lstr    equ $ - srvname
endif

_TEXT16 ends

