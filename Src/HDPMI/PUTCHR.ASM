
;--- output to video/serial
;--- the video output should work for ring 3 as well
;--- (but then SS is != GROUP16)

	.386

	option proc:private

	include hdpmi.inc
	include external.inc
	include debugsys.inc

ifndef ?SLOWDOWN
?SLOWDOWN equ 0
endif

@slowdown macro
if _LTRACE_
 if ?SLOWDOWN
	call slowdown
 endif
endif
endm

if ?DOSOUTPUT
?VIODIROUT equ 0
elseifndef ?VIODIROUT
?VIODIROUT equ 0	;std 0, 1=direct output on VGA screen
endif

if ?VIODIROUT
?CHECKTEXTMODE equ 1	;std 1, 1=display on screen only in text mode
else
?CHECKTEXTMODE equ 0
endif

if ?VIODIROUT
?MONOOUT equ 0	;std 0, 1=output on mono screen (requires ?VIODIROUT=1)
endif

?BIOSOUT equ 1	;std 1, 1=bios output is a fallback
?SEROUT  equ 0	;std 0, 1=output on COMx


if ?VIODIROUT
if ?MONOOUT
?ALTCURPOS	equ 5F0h
?ALTISVALID	equ 0DEB1h
endif
endif

if ?SEROUT
_PORT_		= 3F8h	;COM1
;_PORT_		= 2F8h	;COM2
_XONXOFF_	= 1
XON 		= 11h
XOFF		= 13h
EOT 		= 03H
endif

if ?VIODIROUT

if _SCRNTRACE_
_BRIGHT_	equ 7+8
else
_BRIGHT_	equ 7	;std color
endif

_NORM_		equ 7	;text attribute

BIOSCOLS	equ 44Ah
BIOSPGOFS	equ 44Eh
BIOSCSR		equ 450h
BIOSPAGE	equ 462h
BIOSCRT		equ 463h
BIOSROWS	equ 484h

@getcursorpos macro
if ?MONOOUT
	mov bx,es:[?ALTCURPOS]
	cmp word ptr es:[?ALTCURPOS+2],?ALTISVALID
	jz @F
	xor ebx,ebx
@@:
else
	movzx ebx,byte ptr es:[BIOSPAGE]
	mov bx,es:[EBX*2+BIOSCSR]		;cursorpos (row in BH)
endif
endm

@setcursorpos macro
if ?MONOOUT
	mov es:[?ALTCURPOS],ax
	mov word ptr es:[?ALTCURPOS+2],?ALTISVALID
else
	movzx ebx,byte ptr es:[BIOSPAGE]
	mov es:[EBX*2+BIOSCSR],ax		;set cursor pos 
endif
endm

@getoffsfromcursor macro			;offs -> bx
	mov al,bh					;row in bh
	xchg bl,bh					;col -> bh
if ?MONOOUT
	mov bl,80
else
	mov bl,es:[BIOSCOLS]		;no of cols
endif
	mul bl
	movzx ebx,bh					;col -> bl
	add bx,ax
	add ebx,ebx
ife ?MONOOUT
	add bx,es:[BIOSPGOFS]		;add page offset
endif
	mov edi,ebx
	add edi,esi
endm

@getcursorfromoffs macro
	mov eax,edi
	sub eax,esi
ife ?MONOOUT
	sub ax,es:[BIOSPGOFS]
endif
	shr eax,1
if ?MONOOUT
	mov cl,80
else
	mov cl,es:[BIOSCOLS]	;columns
endif
	div cl					;now row in al, col in ah
	xchg al,ah
endm

endif	;?VIODIROUT

_TEXT32 segment

	assume es:SEG16
	assume ds:SEG16

if ?VIODIROUT

if _LTRACE_
checkpause proc
	pushfd
	push eax
sm1:
	in al,64h		;key from keyboard arrived?
	test al,1
	jz no
	in al,60h
	cmp al,45h		;PAUSE key?
	jnz no
@@:
	in al,64h
	test al,1
	jz @B
	in al,60h
	test al,80h
	jnz @B
no:
	pop eax
	popfd
	ret
checkpause endp
endif

;--- scroll text screen
;--- ES=FLAT, esi=B0000h/B8000h, CL=num rows-1

scroll proc near
if _LTRACE_
	call checkpause
endif
;	push ds
	pushad
;	push es
;	pop ds
if ?MONOOUT
	mov eax,0
else
	movzx eax,word ptr es:[BIOSPGOFS]
endif
	add esi,eax
	mov edi,esi
if ?MONOOUT
	mov eax,80
else
	movzx eax,word ptr es:[BIOSCOLS]
endif
	push eax
	lea esi, [esi+2*eax]
	mul cl
	mov ecx,eax
	rep movsw es:[edi], es:[esi]
	pop ecx
	mov ax,0720h
	rep stosw
	popad
;	pop ds
	ret
scroll endp

if ?CHECKTEXTMODE
IsTextMode proc public	;used also by exception display routine
	push eax
	mov dx,3ceh
	mov al,6
	out dx,al
	inc dx
	in al,dx
	and al,1
	pop eax
	ret
IsTextMode endp
endif

endif	;?VIODIROUT

if _LTRACE_
 if ?SLOWDOWN
slowdown proc
	push ecx
	mov ecx, ?SLOWDOWN
@@:
	in al,61h
	and al,10h
	cmp al,ah
	mov ah,al
	jz @B
	loop @B
	pop ecx
	ret
slowdown endp
 endif
endif

;--- display a char in AL
;--- do not assume SS == GROUP16 here, because this function
;--- may be called by int 41h.
;--- no registers modified
;--- it's public, becaused optionally used by int 41h trap handler

_putchrx proc public

	pushad
ifdef _DEBUG
	mov edx,ss
	cmp dx,byte ptr _SSSEL_		;ring 0 with SS==GROUP16?
 ife ?VIODIROUT
	jnz exit2
 else
	jnz @F
 endif
	test ss:fMode2,FM2_LOG
	jz exit2
@@:
endif
	push es
if ?USEDEBUGOUTPUT	;is active only if ?WDEB386 is on 
	mov edx,ss
	cmp dx,byte ptr _SSSEL_		;ring 0 with SS==GROUP16?
	jnz @F
	test ss:[fDebug],FDEBUG_OUTPFORKD
	jz @F
	mov dl,al
	mov ax,DS_Out_Char
	int Debug_Serv_Int
	jmp exit
@@:
endif
if ?VIODIROUT
  if ?CHECKTEXTMODE
	call IsTextMode
	jnz usebios	;use bios in graphics mode
  endif
	cld
	push byte ptr _FLATSEL_
	pop es
  if ?MONOOUT
	mov esi,0B0000h
  else
	mov esi,0B8000h
	cmp word ptr es:[463h],03B4h
	jnz @F
	xor si,si
@@:
  endif
	@getcursorpos			;get cursor pos in BX
	push eax
	@getoffsfromcursor		;cursor pos in BX -> screen ptr in EDI
	pop eax
	cmp al,cr
	jz putchrex				;skip crs, lf positions at start of next line
	cmp al,lf
	jnz putchrx1

  if ?MONOOUT
	mov bx,80
  else
	mov bx,es:[BIOSCOLS]
  endif
;	add ebx,ebx			:NO (problem if BX=0080h -> BL=0)
	mov eax,edi
	and ax,7FFFh
	div bl				;current row -> al
	shr al,1            ;divide by 2 (neutralises the missing "add ebx,ebx" above)
	xchg al,ah
	mov al,00
	inc ah
  if ?MONOOUT
	cmp ah,24
  else
	cmp ah,byte ptr es:[BIOSROWS]	;rows - 1
  endif
	jbe putchr2
	mov ebx,eax
	@getoffsfromcursor
	jmp putchr1
putchrx1:
	mov ah,_BRIGHT_
	stosw
putchr1:
	@getcursorfromoffs
  if ?MONOOUT
	mov cl,24
  else
	mov cl,byte ptr es:[BIOSROWS]
  endif
	cmp ah,cl
	jbe putchr2
	call scroll
  if ?MONOOUT
	mov ah,24
  else
	mov ah,byte ptr es:[BIOSROWS]
  endif   
	mov al,00h
putchr2:
	@setcursorpos
	@slowdown
	jmp putchrex
endif		;?VIODIROUT
if ?DOSOUTPUT
	push byte ptr _FLATSEL_
	pop es
	mov edx,ss:[dwSDA]
	cmp es:[edx].DOSSDA.bInDOS,0
	jnz usebios
	cmp al,10
	jnz @F
	mov dl,13
	mov ah,2
	@simrmint 21h
	mov al,10
@@:
	mov dl,al
	mov ah,2
	@simrmint 21h
ifdef _DEBUG
	test ss:[bStdout],80h	;no slowdown if stdout is a file
	jz putchrex
endif
	@slowdown
	jmp putchrex
endif
if ?BIOSOUT
usebios:
;	push ds
;	xor ecx,ecx
;	mov ds,ecx
;	mov es,ecx
	mov bx,7
	cmp al,0Ah
	jnz @F
	mov ax,0E0Dh
	@simrmint 10h
	mov al,0Ah
@@:
	mov ah,0Eh		;for graphics mode, use BIOS output routine
	@simrmint 10h
	@slowdown
;	pop ds
endif
putchrex:

if ?SEROUT
 if ?VIODIROUT
	mov al,byte ptr [esp.PUSHADS.rEAX]
 endif
	cmp al,lf
	jnz @F
	mov al,cr
	call _putchrx
	mov al,lf
@@:
	mov dx,_PORT_
	add dx,5			;LSR - Line Status Register
	mov ecx,10000h
	xchg al,ah
@@:
	in al,dx
	test al,40h			;TEMT - transmitter empty?
	loopz @B
 if _XONXOFF_
	test al,1			;char received
	jz putchr_1
	mov dx,_PORT_
	in al,dx
	cmp al,XOFF
	jnz putchr_1
putchr_2:
	add dx,5
@@: 					;wait till new char arrived
	in al,dx
	test al,1
	jz @B
	mov dx,_PORT_
	in al,dx
	cmp al,XON			;wait till XON received
	jnz putchr_2
putchr_1:
  if ?WDEB386
	cmp al,4			;Ctrl-D?
	jnz @F
	mov edx,ss
	cmp dx,byte ptr _SSSEL_
	jnz @F
	or byte ptr ss:[bTrap],1
@@:
  endif
 endif					;_XONXOFF_
	xchg al,ah
	mov dx,_PORT_
	out dx,al
endif					;?SEROUT
exit:
	pop es
exit2:
	popad
	ret
_putchrx endp

getwordfromstack:
	mov ax,[ebp+0]	;get saved value of LOWWORD ebp
	xchg ax,[ebp+2]	;move it up 1 word, get HIGHWORD ebp
	xchg ax,[ebp+4]	;move it up 1 word, get LOWWORD eip
	xchg ax,[ebp+6]	;move it up 1 word, get HIGHWORD eip
	xchg ax,[ebp+8]	;move it up 1 word, get word from stack
	inc ebp
	inc ebp
	ret

;--- printf emulation
;--- format string is located at cs:eip
;--- arguments are onto the stack
;--- all registers preserved, stack cleaned
;--- understands:
;---   %X  : word  hex
;---   %lX : dword hex
;---   %s  : far16 string
;---   %ls : far32 string
;---   %b  : byte  hex
;---   %c  : byte  char

_stroutx proc public
	push ebp
	mov ebp,esp
	pushfd
	cld
	push eax
	push edx
	push esi
ifdef _DEBUG
 if ?DOSOUTPUT and ?USEHOSTPSP
	push 0
	push es
	push byte ptr _FLATSEL_
	pop es
	mov edx,ss:[dwSDA]
	cmp es:[edx].DOSSDA.bInDOS,0
	jnz @F
	mov ax,es:[edx].DOSSDA.wPSP
	mov [esp+4],ax
	push ebx
	mov bx,ss:[wHostPSP]
	mov ah,50h
	@simrmint 21h
	pop ebx
@@:
	pop es
 endif
endif
	mov esi,[ebp+4]
	movzx esi,word ptr cs:[esi]
	add dword ptr [ebp+4],2
nextitem:
	db 2Eh		;CS
	lodsb
	and al,al
	jnz ischar
ifdef _DEBUG
 if ?DOSOUTPUT and ?USEHOSTPSP
	pop eax
	and eax,eax
	jz @F
	push ebx
	mov ebx,eax
	mov ah,50h
	@simrmint 21h
	pop ebx
@@:
 endif
endif
	pop esi
	pop edx
	pop eax
	popfd
	mov esp,ebp
	pop ebp
	ret
ischar:
	push offset nextitem
	cmp al,'%'
	jnz _putchrx		;just display the char
	mov dl,00
	db 2Eh
	lodsb
	cmp al,'X'
	jz stroutx_X
	cmp al,'b'
	jz stroutx_b
	cmp al,'c'
	jz stroutx_c
	cmp al,'l'
	jnz @F
	mov dl,al
	db 2Eh
	lodsb
	cmp al,'X'
	jz stroutx_lX
@@:
	cmp al,'s'
	jz stroutx_s
	push eax
	mov al,'%'
	call _putchrx
	pop eax
	call _putchrx
	retn
stroutx_s:						;%ls or %s get string
	push ds
	push esi
	call getwordfromstack
	mov ds,eax
	call getwordfromstack	;skip the highword of selector part

	call getwordfromstack
	movzx esi,ax
	cmp dl,00
	jz @F
	call getwordfromstack
	push ax
	push si
	pop esi
@@:
	lodsb
	and al,al
	jz @F
	call _putchrx
	jmp @B
@@:
	pop esi
	pop ds
	retn
stroutx_lX:						;%lX get 2 words
	call getwordfromstack		;get low16
	push ax
	call getwordfromstack		;get high16
	shl eax,16
	pop ax
;	test eax,0ffff0000h			;skip high16 if zero
;	jz wordout
	jmp dwordout
stroutx_X:						;%X get 1 word
	call getwordfromstack
	jmp wordout
stroutx_b:						;%b get 1 word
	call getwordfromstack
	jmp byteout
stroutx_c:						;%c get 1 word
	call getwordfromstack
	jmp _putchrx
_stroutx endp

dwordout proc near
	push eax
	shr eax,16
	call wordout
	pop eax
dwordout endp
wordout proc near
	push eax
	mov al,ah
	call byteout
	pop eax
wordout endp
byteout proc near
	pushfd
	push eax
	mov ah,al
	shr al,4
	call nibout
	mov al,ah
	call nibout
	pop eax
	popfd
	ret
nibout:
	and al,0Fh
	cmp al,10
	sbb al,69H
	das
	jmp _putchrx
byteout endp

if ?I41SUPPORT

_getchrx proc near
if ?SEROUT
	pushfd
	push ecx
	push edx

	mov dx,_PORT_+6 	;MSR - modem status register
	in al,dx			;DSR - modem(=DCE) ready?
	and al,20h
	jz getchrx_err
	dec dx				;LSR - Line Status Register
@@:
	in al,dx
	test al,01h			;DR - Data ready?
	jz @B
	mov dx,_PORT_
	in al,dx
	mov ah,00
	jmp getchrx_ex
getchrx_err:
	xor eax,eax
getchrx_ex:
	pop edx
	pop ecx
	popfd
	ret
endif
if ?VIODIROUT
	mov ah,00
	@simrmint 16h
	ret
endif
	mov al,00
	ret
_getchrx endp

endif

_TEXT32 ends

end
