
;--- implements GetLargestConsoleWindowSize,
;--- SetConsoleScreenBufferSize, SetConsoleWindowInfo

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include wincon.inc
	include dkrnl32.inc
	include macros.inc

?SPMODE		equ 10h
?MAXROWS	equ 60
?MAXCOLS	equ 80

	.CONST

;*** to use 480 scan lines, CRT has to be programmed directly

;--- CRT values for 480 scan lines

if 0
block1	db 9,00
		db 5fh,4Fh,50h,82h
else
block1	db 5,04
endif
		db 55h,81h
		db 0Bh,3eh,00h

;;		db 47h,06h,07h
;;		db 00h,00h				;page start

block2 db 7,10h
		db 0eah,8ch,0dbh,28h,1fh,0e7h,04h

;--- CRT values for 400 scan lines

block3 db 5,04
		db 54h,80h
		db 0BFh,1Fh,00h

block4 db 7,10h
		db 09Ch,8Eh,08fh,28h,1fh,096h,0B9h

parms480 dd offset block1, offset block2
		db 0C0h	;misc output  (480 scan lines, 25.175 MHz)
		db 01h	;sequencer (dot clock = 8)
		db 00h	;attribute controller (register 13h)

parms400 dd offset block3, offset block4
		db 44h	;misc output (400 scan lines, 28.322 MHz)
		db 00h	;sequencer (dot clock = 9)
		db 08h	;attribute controller

;--- description of 80 column modes

MODEDESC struct
bLines	db ?	;screen lines
bPixel	db ?	;cell height in pixels
b480	db ?	;flag if 480 scan lines
MODEDESC ends

modes label MODEDESC
	MODEDESC <25,16,0>
	MODEDESC <28,14,1>
	MODEDESC <30,16,1>
	MODEDESC <34,14,1>
	MODEDESC <50,08,0>
	MODEDESC <60,08,1>
MODESSIZ equ ($ - modes) / sizeof MODEDESC

	.CODE

putcrt proc
	lodsb
	mov cl,al
	lodsb
	.while (cl)
		mov ah,al
		lodsb
		xchg al,ah
		out dx,ax
		inc al
		dec cl
	.endw
	ret
	align 4
putcrt endp

disablewp proc
	mov al,11h			;vertikal retrace end register bit 7 reset
	out dx,al			;= clear write protection for register 0-7
	inc edx
	in al,dx
	and al,7fh
	out dx,al
	dec edx
	ret
	align 4
disablewp endp

enablewp proc
	mov al,11h
	out dx,al
	inc edx
	in al,dx
	or al,80h
	out dx,al
	dec edx
	ret
	align 4
enablewp endp

getinpst1 proc				; get input status register 1
	mov dx,3CCh
	in al,dx
	mov dl,0DAh
	test al,1		; mono?
	jnz @F
	mov dl,0BAh
@@:
	ret
	align 4
getinpst1 endp


setscanlines proc private uses esi pParms:ptr

	@noints

;--------------------------------------		reprogram CRT controller
	mov dx,[VIOCRTPORT]		;get crt port
	call disablewp
	mov esi,pParms
	mov esi,[esi+0]
	call putcrt
	mov esi,pParms
	mov esi,[esi+4]
	call putcrt
	call enablewp
	mov esi,pParms

;-------------------------------------- write misc output register
	mov dx,3cch
	in al,dx
	and al,33h						;reset bits 2,3,6,7
	or al,[esi+8]					;set scan lines
	mov dl,0C2h						;has different output port!
	out dx,al

;-------------------------------------- write sequencer
	mov dl,0C4h
	mov al,1
	out dx,al
	inc edx
	mov ah,al
	in al,dx
	and al,0FEh
	or al,[esi+9]					;set dot clocks (8 or 9)
	out dx,al

	call getinpst1
	in al,dx					;reset attribute controller
	mov dx,3c0h

;-------------------------------------- write attribute controller

;--- todo: write "mode" register (index 10h) as well!


	mov al,13h					;select register
	out dx,al
	mov al,[esi+10]				;write new value
	out dx,al

	mov al,20h					;turn screen on again
	out dx,al

	@restoreints
	ret
	align 4

setscanlines endp

checkvmode proc private
	push edx
	mov dx,3ceh					;graphics controller port
	mov al,6
	out dx,al
	inc edx
	in al,dx
	test al,1					;text mode on?
	jz @F
	mov ax,0003h
	int 10h
@@:
	pop edx
	push edx
	cmp dl,byte ptr [VIOCOLS]	;columns
	jnz @F
	shr edx,16
	dec dl
	cmp dl,byte ptr [VIOROWS]	;rows
@@:
	pop edx
	ret
	align 4
checkvmode endp

SetConsoleWindowInfo proc public hConOut:dword,flag:dword,pRect:dword

local	dwSize:COORD

	xor eax,eax
	mov edx,pRect
	mov ecx,[edx+0]
	mov edx,[edx+4]
	and ecx,ecx
	jnz exit
	add edx,10001h
	mov dwSize, edx
	invoke SetConsoleScreenBufferSize, hConOut, dwSize
exit:
	@strace <"SetConsoleWindowInfo(", hConOut, ", ", flag, ", ", pRect, ")=", eax>
	ret
	align 4

SetConsoleWindowInfo endp

SetConsoleScreenBufferSize proc public uses ebx hConOut:dword, newSize:COORD

	mov eax, hConOut
	call _GetScreenBuffer
	mov dx, newSize.X
	mov cx, newSize.Y
	cmp dx, ?MAXCOLS
	ja error
	cmp cx, ?MAXROWS
	ja error
	test [eax].SCREENBUF.dwFlags, SBF_ISACTIVE
	jnz isactivebuffer
	mov [eax].SCREENBUF.dwSize.X, dx
	mov [eax].SCREENBUF.dwSize.Y, cx
	jmp exit2
isactivebuffer:
	mov edx,newSize
	call checkvmode
	jz exit2					;mode doesnt change, exit
	cmp dx,80
	jnz vesamodes
	shr edx,16
	mov ebx, offset modes
	mov ecx, MODESSIZ
nextitem:
	cmp dl,[ebx].MODEDESC.bLines
	jbe @F
	add ebx, sizeof MODEDESC
	loop nextitem
	jmp error
@@:

;--- set BIOS rows and page size

	dec dl
	mov byte ptr [VIOROWS],dl			;max line#
	push edx
	inc dl

	mov al,80							;columns
	mul dl
	shl eax,1
	cmp ax,1000h
	ja @F
	mov ax,1000h
@@:
	mov word ptr [VIOPAGESIZ],ax	;page size (ROWS * CULUMNS * size WORD)
	push eax

	mov cl,[ebx].MODEDESC.bPixel
	mov [VIOCHARSIZE], cl		;scan lines
	.if (cl == 16)
		mov al,04h + ?SPMODE		;load 8x16 charset
	.elseif (cl == 14)
		mov al,01h + ?SPMODE		;load 8x14 charset
	.else
		mov al,02h + ?SPMODE		;load 8x08 charset
	.endif
	mov ah,11h
	dec cl
	mov ch,cl
	dec ch
	mov word ptr [VIOCSRSHAPE],cx	;cursor form


	push ebx
	mov bl,00
	int 10h
	pop ebx

;--- the font load routine might have modified the BIOS values

	pop eax
	mov [VIOPAGESIZ],ax
	pop edx
	mov [VIOROWS],dl

	.if ([ebx].MODEDESC.b480)
		mov eax, offset parms480
	.else
		mov eax, offset parms400
	.endif
	invoke setscanlines, eax

	jmp done
error:
	xor eax,eax
	jmp exit

vesamodes:
	mov bx,109h
	cmp edx,25 * 10000h + 132	;132x25 (VESA mode 109h)
	jz @F
	inc ebx
	cmp edx,43 * 10000h + 132	;132x43 (VESA mode 10Ah)
	jz @F
	inc ebx
	cmp edx,50 * 10000h + 132	;132x50	(VESA mode 10Bh)
	jz @F
	jmp error
@@:
	mov ax,4F02h
	int 10h
	cmp ax,004Fh
	jnz error
done:
	invoke SetIntensityBackground
exit2:
	@mov eax,1
exit:
	@strace <"SetConsoleScreenBufferSize(", hConOut, ", ", newSize, ")=", eax>
	ret
	align 4

SetConsoleScreenBufferSize endp

GetLargestConsoleWindowSize proc public hConsole:dword
	mov eax,?MAXROWS * 10000h + ?MAXCOLS
	@strace <"GetLargestConsoleWindowSize(", hConsole, ")=", eax>
	ret
	align 4
GetLargestConsoleWindowSize endp

	END

