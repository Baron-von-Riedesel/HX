
;--- output to video/serial
;--- the video output should work for ring 3 as well
;--- (but then SS is != GROUP16)

	.386

	option proc:private

	include hdpmi.inc
	include external.inc
	include debugsys.inc

if ?DOSOUTPUT
?VIDOUT			= 0
?CHECKTEXTMODE	= 0
else
?VIDOUT			= 0	;std 0, 1=direct output on VGA screen
?CHECKTEXTMODE	= 1	;std 1, 1=display on screen only in text mode
endif
?BIOSOUT		= 1	;std 1, 1=bios output is a fallback
?SEROUT			= 0	;std 0, 1=output on COMx
if ?VIDOUT
?MONOOUT		= 0	;std 0, 1=output on mono screen (requires ?VIDOUT=1)
endif

if ?VIDOUT
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


@seg	SEG16
@seg	_TEXT32

if ?VIDOUT

if _SCRNTRACE_
_BRIGHT_	equ 9
else
_BRIGHT_	equ 7	;std color
endif

_NORM_		equ 7	;text attribute

BIOSCOLS	equ 44Ah
BIOSPGOFS	equ 44Eh
BIOSCSR 	equ 450h
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

endif	;?VIDOUT

_TEXT32 segment

	assume es:SEG16
	assume ds:SEG16

if ?VIDOUT

;--- scroll text screen
;--- ES=FLAT, esi=B0000h/B8000h, CL=num rows-1

scroll proc near
	push ds
	pushad
	push es
	pop ds
if ?MONOOUT
	mov eax,0
else
	movzx eax,word ptr ds:[BIOSPGOFS]
endif
	add esi,eax
	mov edi,esi
if ?MONOOUT
	mov eax,80
else
	movzx eax,word ptr ds:[BIOSCOLS]
endif
	push eax
	lea esi, [esi+2*eax]
	mul cl
	mov ecx,eax
	rep movsw
	pop ecx
	mov ax,0720h
	rep stosw
	popad
	pop ds
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

endif	;?VIDOUT

;--- display a char in AL
;--- do not assume SS == GROUP16 here!
;--- no registers modified
;--- it's public, becaused optionally used by int 41h trap handler

_putchrx proc public

	push es
	pushad
if ?USEDEBUGOUTPUT	;is active only if ?WDEB386 is on 
	mov edx,ss
	cmp dx,_SSSEL_		;ring 0 with SS==GROUP16?
	jnz @F
	test ss:[fDebug],FDEBUG_OUTPFORKD
	jz @F
	mov dl,al
	mov ax,DS_Out_Char
	int Debug_Serv_Int
	jmp exit
@@:
endif
if ?VIDOUT
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
	jz putchrex
	cmp al,lf
	jnz putchrx1

  if ?MONOOUT
	mov bx,80
  else
	mov bx,es:[BIOSCOLS]
  endif
	add ebx,ebx
	mov eax,edi
	and ax,7FFFh
	div bl				;current row -> al
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
	jmp putchrex
endif		;?VIDOUT
if ?DOSOUTPUT
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
	jmp putchrex
endif
if ?BIOSOUT
usebios:
	push ds
	xor ecx,ecx
	mov ds,ecx
	mov es,ecx
	mov bx,7
	cmp al,0Ah
	jnz @F
	mov ax,0E0Dh
	@simrmint 10h
	mov al,0Ah
@@:
	mov ah,0Eh		;for graphics mode, use BIOS output routine
	@simrmint 10h
	pop ds
endif
putchrex:

if ?SEROUT
 if ?VIDOUT
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
	cmp dx,_SSSEL_
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
	popad
	pop es
	ret
_putchrx endp

;--- used by except.asm
;--- display string in cs:[esi]
;--- out: esi -> behind 00
;--- modifies ESI

_stroutesi proc public
	push eax
@@:
	db 2Eh		;seg CS
	lodsb
	and al,al
	jz @F
	call _putchrx
	jmp @B
@@:
	pop eax
	ret
_stroutesi endp

getwordfromstack:
	mov ax,[ebp+0]	;get saved value of LOWWORD(ebp)
	xchg ax,[ebp+2]	;move it up 1 word, get HIGHWORD(ebp)
	xchg ax,[ebp+4]	;move it up 1 word, get LOWWORD(eip)
	xchg ax,[ebp+6]	;move it up 1 word, get HIGHWORD(eip)
	xchg ax,[ebp+8]	;move it up 1 word, get word from stack
	inc ebp
	inc ebp
	ret

;--- printf emulation
;--- format string is located at cs:eip
;--- arguments are onto the stack
;--- all registers preserved, stack cleaned
;--- understands %X, %lX and %s (far16)

_stroutx proc public
	push ebp
	mov ebp,esp
	pushfd
	cld
	push eax
	push edx
	push esi
	mov esi,[ebp+4]
	movzx esi,word ptr cs:[esi]
	add dword ptr [ebp+4],2
nextitem:
	db 2Eh		;CS
	lodsb
	and al,al
	jnz @F
	pop esi
	pop edx
	pop eax
	popfd
	mov esp,ebp
	pop ebp
	ret
@@:
	push offset nextitem
	cmp al,'%'
	jnz _putchrx		;just display the char
	mov dl,00
	db 2Eh
	lodsb
	cmp al,'X'
	jz stroutx_X
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
	call getwordfromstack
	push eax
	call getwordfromstack
	call wordout
	pop eax
	jmp wordout
stroutx_X:						;%X get 1 word
	call getwordfromstack
	jmp wordout
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

_charout proc stdcall public arg:dword
_charout endp
	mov eax, [esp+4]
	call _putchrx
	ret 4

_byteout proc stdcall public arg:dword
_byteout endp
	mov eax,[esp+4]
	call byteout
	ret 4

_wordout proc stdcall public arg:dword
_wordout endp
	mov eax,[esp+4]
	call wordout
	ret 4

_dwordout proc stdcall public arg:dword
_dwordout endp
	mov eax,[esp+4]
	call dwordout
	ret 4

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
if ?VIDOUT
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
