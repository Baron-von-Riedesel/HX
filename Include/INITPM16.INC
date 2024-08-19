
;*** startup code to run a 16-bit program as DPMI client;
;*** will try to load HDPMI if no DPMI host is active.
;--- requires: DS & SS setup for tiny/small model,
;--- DOS memory freed already

ifndef ?LIMITCS
?LIMITCS equ 1  ; 1=limit CS to real code size (small model)
endif
ifndef ?LOADSERVER
?LOADSERVER equ 1 ; 1=load HDPMI if no DPMI host detected
endif
ifndef ?32BIT
?32BIT equ 0    ; 1=run as 32-bit client
endif
ifndef ?INT41
?INT41 equ 0    ; 1=use int 41h debug API
endif

EXECRM struct
environ dw ?
cmdline dd ?
fcb1    dd ?
fcb2    dd ?
res1    dd ?
res2    dd ?
EXECRM ends

    .const

szPath db 'PATH='

if ?LOADSERVER
 if ?32BIT
szHDPMI db 'HDPMI32.EXE',00
 else
szHDPMI db 'HDPMI16.EXE',00
 endif
LHDPMI  equ $ - szHDPMI
endif

errNoHost db "no DPMI host found",13,10,'$'
errInit   db "DPMI initialization failed",13,10,'$'

    .code

;--- DPMI initialization

initpm proc

    mov ax, 1687h           ; DPMI host installed?
    int 2fh
if ?LOADSERVER
    and ax, ax
    jz @F
    call loadserver
    mov ax, 1687h           ; try again
    int 2fh
endif
    and ax, ax
    jnz nodpmi              ; still no host, exit
@@:        
    push es
    push di
    and si, si
    jz @F
                            ; alloc memory for dpmi host
    mov ah, 48h
    mov bx, si
    int 21h
    jc memerr
    mov es, ax
@@:
if @Model ne 1              ; not for tiny model
 if ?LIMITCS
    mov dx, ds
    inc dx                  ; one paragraph more since start of DGROUP may be within code
    mov cx, cs
    sub dx, cx
    shl dx, 4
    dec dx
 endif
endif
    mov bp, sp
if ?32BIT
    mov ax, 1               ; run as 32-bit client
else
    xor ax, ax              ; run as 16-bit client
endif
    call dword ptr [bp]
    jc initerr
if @Model ne 1              ; not for tiny model
 if ?LIMITCS
    mov bx, cs
    xor cx, cx
    mov ax, 8
    int 31h
 endif
endif
    add sp, 4
if ?INT41
	mov ax, 4Fh
	int 41h
	cmp ax, 0f386h
	jnz @F
	int 3
@@:
endif
    ret

nodpmi:
    mov dx, offset errNoHost
    jmp errexit
memerr:
initerr:
    mov dx, offset errInit
errexit:
    mov ah, 9
    int 21h
    mov ax, 4CFFh
    int 21h
initpm endp

if ?LOADSERVER

;*** search and load hdpmixx.exe

loadserver proc

local psp:word
local env:word
local cmdline:word
local parmblock:EXECRM
local pgmname[80]:byte

    mov ah, 51h
    int 21h
    mov psp, bx
    mov es, bx
    mov ax, es:[002Ch]
    mov env, ax

    call searchpath                  ; search PATH= variable -> SI, SI=0000 if error
    call searchpgm                   ; search HDPMIxx
    jb error                         ; error "not found"

    mov AX, env
    mov parmblock.environ, ax
    mov cmdline, 0D00h
    lea bx, cmdline
    mov word ptr parmblock.cmdline+0, bx
    mov word ptr parmblock.cmdline+2, ss
    mov AX, psp
    mov word ptr parmblock.fcb1+0, 5Ch
    mov word ptr parmblock.fcb1+2, ax
    mov word ptr parmblock.fcb1+0, 6Ch
    mov word ptr parmblock.fcb2+2, ax

    push ss
    pop es
    lea dx, pgmname
    lea bx, parmblock
    mov ax, 4B00h                    ; execute dpmi host executable
    int 21h
error:
    ret

;*** search HDPMIxx in current directory and directories of PATH
;*** Input: SI=address of PATH Variable or NULL (no PATH defined)
;***      : DI=name/path of executable

searchpgm:
    push si
    mov si, di
    lea di, pgmname
    push ds
    pop es
    mov dx, di
    push ds
    mov ds, env
nxtc:
    lodsb
    stosb
    cmp al, '\'
    jnz @F
    mov dx, di      ; remember last '\'
@@:
    cmp al, 0
    jnz nxtc
    pop ds
    mov di, dx
    pop si
    mov bl, 0
nexttry:                       ; <----
    push si
    mov si, offset szHDPMI
    mov cx, LHDPMI
    rep movsb

    lea dx, pgmname
    mov ax, 3d00h
    int 21h
    pop si
    jnb hostfound                    ; found!
    and bl, bl
    jnz @F
    mov bl, 1
    lea di, pgmname                  ; get current directory
    jmp nexttry
@@:
    and si, si
    jz nohost                        ; PATH isnt defined, so were done
    mov di, dx
    push ds
    mov ds, env
@@:
    lodsb
    stosb
    cmp al, ';'
    jz @f
    cmp al, 00
    jnz @b
    xor si, si		; done with PATH
@@:
    pop ds
    dec di
    cmp byte ptr es:[di-01], '\'
    jz nexttry
    mov byte ptr es:[di], '\'
    inc di
    jmp nexttry

hostfound:
    mov bx, ax
    mov ah, 3eh                      ; close file
    int 21h
    clc
    retn
nohost:
    stc
    retn

;*** search PATH in environment
;*** Out: SI-> behind "PATH=" or 0000
;***      DI-> path of executable in environment

searchpath:
    sub di, di
    xor dx, dx
    mov es, env
nextvar:
    mov SI, offset szPath   ; "PATH="
    mov cx, 0005
    repz cmpsb
    jnz @f
    mov dx, di
@@:
    mov al, 00
    or cx, -1
    repnz scasb
    cmp al, es:[di]
    jnz nextvar
    add di, 3               ; so DI points to path of executable now
    mov si, dx
    retn

loadserver endp

endif
