
;***  implements A20 gate handling

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

?USEGLOBAL		equ 0	;1=use xms A20 "global" functions
?ENABLEONCE		equ 1	;1=put _enableA20() in _ITEXT16 (depends when it is called)
?GETA20PUBLIC	equ 0	;1=make _GetA20State() public
?VCPI_NOA20HOOK	equ 0	;1=ignore A20 stuff in VCPI mode

@seg _DATA16
@seg _TEXT16
if ?ENABLEONCE
@seg _ITEXT16
endif

@wait macro
	endm

if ?USEGLOBAL
?ENABLE  equ 3
?DISABLE equ 4
else
?ENABLE  equ 5
?DISABLE equ 6
endif

_DATA16 SEGMENT
oldxms  dd 0
_DATA16 ENDS

if 0

@seg _TEXT32

_TEXT32 SEGMENT

_GetA20State_pm proc

	push ebx
	push ds
	push byte ptr _FLATSEL_
	pop ds
	mov ebx,100000h

	mov cx,1
	mov ah,ds:[bx]
	mov al,0AAh
@@:
	mov ds:[bx],al
	cmp al,ds:[ebx]
	jnz @F
	xor al,0FFh
	mov ds:[bx],al
	cmp al,ds:[ebx]
	jnz @F
	dec cx
@@:
	mov ds:[bx],ah
	mov ax,cx
	pop ds
	pop ebx
	ret
_GetA20State_pm endp

_TEXT32 ENDS

endif

_TEXT16 segment

;--- XMS hook proc
;--- it catches the A20 enable/disable calls.
;--- this is done even if no client is running.
;--- might be a good idea to change this

myxmshandler proc

	jmp @F
	nop
	nop
	nop
@@:
if 0
	test cs:[fMode], FM_DISABLED
	jnz @F
endif
	cmp ah,?ENABLE
	jz retsuccess
	cmp ah,?DISABLE
	jz retsuccess
@@:
	jmp dword ptr cs:[oldxms]
retsuccess:
	mov ax,1	;do not set BL for these XMS functions!
	retf

myxmshandler endp

	@ResetTrace

;--- get A20 state in ax (0 or 1)
ife ?GETA20PUBLIC
_ITEXT16 segment
endif

if ?GETA20PUBLIC
_GetA20State proc near public
else
_GetA20State proc near
endif

	pushf
	push ds
	cli
	xor bx,bx
	push bx
	pop ds
;	push 0FFFFh
	push -1
	pop es
	mov cx,1
	mov ah,[bx]
	mov al,0FFh
@@:
	mov [bx],al
	cmp al,es:[0010h]
	jnz @F
	dec al
	jnz @B
	dec cx
@@:
	mov [bx],ah
	mov ax,cx
	pop ds
	popf
	ret
_GetA20State endp

ife ?GETA20PUBLIC
_ITEXT16 ends
endif

if ?ENABLEONCE
_ITEXT16 segment
endif

_ChangeA20 proc near stdcall mode:word

	call _GetA20State
	cmp al,byte ptr mode
	jz exit
	stc
	mov ax,2403h
	int 15h
	jc nobiossupp
	and ah,ah
	jnz nobiossupp
	test bl,2			;is port 92h method ok?
	jz usekbdc			;if no, just try keyboard method
nobiossupp:
						;first try the (fast) PS/2 method
	mov ah,byte ptr mode
	in al,92h
	shl ah,1			;bit 1 (02) is interesting	
	and ah,2
	and al,not 2
	or al,ah
	out 92h,al			;new mode set

	call _GetA20State
	cmp al,byte ptr mode
	jz exit

usekbdc:
	pushf
	cli
	mov ah,0ADh 		;disable keyboard
	call writep64
	mov ah,0D0h 		;read output port
	call writep64
	call waitr			 ;wait until a byte received
	jz timerr
	in al,60h		   ;read byte
	and al,0DDh 		;Bit 1 reset
	or al,0D1h			;???
	mov ah,byte ptr mode
	shl ah,1
	or al,ah
	mov dl,al
	mov ah,0D1h 		;write output port
	call writep64
	call w8042			 ;wait until it has been sent
	mov al,dl
	out 60h,al
	mov ah,0FFh			;???
	call writep64

	mov al,01
	db 0b9h				;mov cx, xxxx
timerr:
	mov al,00
	mov ah,00
	push ax
	mov ah,0AEh			;enable keyboard
	call writep64
	pop ax
	popf
exit:
	ret

writep64:
	call w8042
	jnz @F
	mov al,ah
	out 64h,al
	retn
@@:
	pop ax
	jmp timerr

waitr:
	xor cx,cx
@@:
	@wait
	in al,64h
	and al,01	;output buffer full?
	loopz @B	;no read access until bit is 1
	retn
w8042:
	xor cx,cx
@@:
	@wait
	in al,64h
	and al,02	;input buffer full?
	loopnz @B	;no write access until bit is 0
	retn

_ChangeA20 endp

;*** hook XMS chain
;*** is this necessary if a VCPI host has been detected?
;*** IIRC a VCPI host will always have A20 enabled and
;*** at best emulate the "A20 disable" behaviour

setmyxmshandler proc

	les bx,[xmsaddr]
@@:
	mov al,es:[bx]
	cmp al,0EBh
	jz @F
	les bx,es:[bx+1]
	cmp al,0EAh		;is XMS chain corrupted?
	jz @B			;since v3.12 this error is detected
					;(but not reported)
if 0
	and [fHost], not FH_XMS
endif
	ret
@@:
	mov byte ptr es:[bx+0],0EAh
	mov es:[bx+1],offset myxmshandler
	mov es:[bx+3],cs
	add bx,5
	mov word ptr [oldxms+0],bx
	mov word ptr [oldxms+2],es
	ret

setmyxmshandler endp

;--- returns AX != 0 if no error occurs

_enablea20 proc near public

	assume DS:GROUP16

if ?VCPI_NOA20HOOK
	mov al,1
	test [fHost], FH_VCPI
	jnz exit
endif
	test [fHost], FH_XMS
	jnz @F
	invoke _ChangeA20,1
	call _GetA20State
	ret
@@:
	@stroutrm <"-calling XMS enable A20",lf>
	mov ah,?ENABLE
	call [xmsaddr]
	@stroutrm <"-install XMS hook",lf>
	call setmyxmshandler
exit:
	ret
_enablea20 endp

if ?ENABLEONCE
_ITEXT16 ends
endif

;--- es may be modified here, but preserve di, si
;--- DS=GROUP16

_disablea20 proc public

	@stroutrm <"-disable a20 enter",lf>
	push di
	les di,[oldxms]	;dont test FH_XMS here, may have been cleared
	mov ax,es
	or ax,di
	jz @F
	@stroutrm <"-uninstall XMS hook, previous addr=%X:%X",lf>,es,bx
	cld
	push si
	mov si,offset myxmshandler
	mov cx,5
	sub di,cx
	rep movsb
	pop si
	@stroutrm <"-calling XMS disable A20",lf>
	mov ah,?DISABLE
	call [xmsaddr]
@@:
	@stroutrm <"-disable A20 exit",lf>
	pop di
	ret
_disablea20 endp

_TEXT16 ends

	end
