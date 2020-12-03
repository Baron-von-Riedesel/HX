        
;--- initialization for simple DPMI apps in MZ format.
;--- loads hdpmi if no host found.
;--- switches to protected-mode, then calls _start16.
;--- assumes a TINY model!

	.386
	option casemap:none
	option proc:private

?LOADSERVER	equ 1	;try to find HDPMI if no DPMI host has been found
?TEST386	equ 1		;1=test for 386 cpu (needed?)

_TEXT segment use16 dword public 'CODE'
externdef c start16:near
_TEXT ends

_TEXT16 segment use16 word public 'CODE'

;--- this is the real mode entry with functions
;--- 1. check if DPMI is there
;--- 2. if not, try to load HDPMI16 (in UMBs if available)
;--- 3. switch to PM as 16bit dpmi client
;--- 4. set segment registers CS,SS,DS to FLAT, ES=PSP
;--- 5. jump to label _start16.

start:

sizep	equ [bp-2]
status1	equ [bp-4]
status2	equ [bp-6]
lpproc	equ [bp-10]

InitPM proc

if ?TEST386
	PUSHF
	mov AH,70h
	PUSH AX
	POPF				; on a 80386 in real-mode, bits 15..12
	PUSHF				; should be 7, on a 8086 they are F,
	POP AX				; on a 80286 they are 0
	POPF
	and ah,0F0h
	JS @F
	JNZ IS386
@@:
	mov dx,offset errmsg0
	jmp error
IS386:
endif
	mov ax,sp
	add ax,16-1
	shr ax,4
	mov bx,ss
	add bx,ax
	mov ax,es
	mov si,bx
	sub bx,ax
	mov ah,4Ah		;resize memory block to free DOS memory
	int 21h

	mov bp,sp

	mov ax,seg _TEXT
	sub si,ax
	push si				;store size DGROUP (paragraphs)

	mov ax,5802h		;save status umb
	int 21h
	xor ah,ah
	push ax				;status 1
	mov ax,5800h		;save memory alloc strategy
	int 21h
	xor ah,ah
	push ax				;status 2
	mov bx,0081h		;first high,then low
	mov cx,0001h		;include umbs
	call setumbstatus

	mov ax,1687h		;is DPMI existing?
	int 2fh
	and ax,ax
if ?LOADSERVER
	jz @F
	call loadserver
	mov ax,1687h
	int 2fh
	and ax,ax
	jnz nodpmihost
@@:
else
	jnz nodpmihost 		;error: no DPMI host
endif
	push es
	push di				;lpproc

	and si,si
	jz nomemneeded
							;alloc req real mode mem
	mov ah,48h
	mov bx,si
	int 21h
	jc outofmem

	mov es,ax
nomemneeded:
	call restoreumbstatus
	mov si,seg _TEXT
	mov ds,si
	mov ax,0000 			;16 bit application
	call dword ptr [lpproc]	;jump to PM
	jc initfailed			;error: jmp to pm didnt work

;--- here es=PSP, ds=_TEXT (=DGROUP), cs=TEXT16, ss=stack
;--- limits are 0FFFFh, except for PSP
;--- size of DGROUP in paragraphs in sizep
;--- SI=segment address of DGROUP

;--- convert SS to DGROUP
	mov ax,sizep
	shl ax,4
	push ax
	dec ax
	mov dx,ax
	mov cx,0
	mov bx,ds
	mov ax,8			;set limit of DGROUP
	int 31h
	pop ax
	mov bx,ss
	push ds
	pop ss
	mov sp,ax

;--- setup 16-bit CS (size DGROUP)
	movzx esi, si
	shl esi, 4
	push esi
	pop dx
	pop cx
	mov ax,7			;set base CS
	int 31h
	mov dx,sp
	dec dx
	mov cx,0
	mov ax,8			;set limit CS
	int 31h
	mov cx,cs
	lar ecx,ecx
	shr ecx,8
	mov ax,9
	int 31h

	push bx
	push start16
	retf

restoreumbstatus:
	mov cx,status1
	mov bx,status2
setumbstatus:
	push cx
	mov ax,5801h		;memory alloc strat restore
	int 21h
	pop bx
	mov ax,5803h		;umb link restore
	int 21h
	retn

nodpmihost:
	call restoreumbstatus
	mov dx,offset errmsg1
	jmp error
outofmem:
	call restoreumbstatus
initfailed:
nodescriptor:
	mov dx,offset errmsg2
error:
	push cs
	pop ds
	mov ah,09		;display error msg
	int 21h
	mov ax,4CFFh	;and exit to DOS
	int 21h
InitPM endp

if ?TEST386
errmsg0 db "80386 needed",13,10,'$'
endif
errmsg1 db "no DPMI host found",13,10,'$'
errmsg2 db "DPMI initialization failed",13,10,'$'

if ?LOADSERVER

;--- there are 2 versions. the standard one searches 
;--- the PATH variable in environment and scans all
;--- directories for HDPMI32.EXE.
;--- the other one just includes HDPMI32.INC

_SFLAGS_   = 20h    ;open with "deny write"

;	.model small, stdcall

EXECRM struct
environ dw ?
cmdline dd ?
fcb1    dd ?
fcb2    dd ?
res1    dd ?
res2    dd ?
EXECRM ends

;*** this is a real mode proc! ***

loadserver  proc stdcall uses ds es si di

local   psp:word
local   env:word
local   parmblock:EXECRM
local   szCmdLine[2]:byte
local   pgmname[80]:byte

	mov ah,51h
	int 21h
	mov es,bx
	assume es:_TEXT16
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

loadserver endp

szPath   db 'PATH='
srvname  db 'HDPMI16.EXE',00
lstr    equ $ - srvname

endif

_TEXT16 ends


	END start
