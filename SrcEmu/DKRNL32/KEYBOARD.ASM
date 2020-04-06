
;*** keyboard (IRQ 1) interrupt handler ***

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP	group _TEXT 	   
endif

	option proc:private
	option casemap:none
	option dotname

	include winbase.inc
	include wincon.inc
	include keyboard.inc
	include dkrnl32.inc
	include macros.inc

?ASYNC_CTRLBRK		equ 1	;1=call int 23h from IRQ 1 if indosflag=0
?PAUSE				equ 1	;1=special PAUSE handling for GUI apps
;--- on Windows, break code 0E1h causes a key event of 61h to be generated
;--- (ascii=0, VK=0) (console applications)
?CREATE61SC			equ 1	;must match value in kbdqueue.asm!
?FKEYS				equ 1	;F1-F10 special handling
?HOOKINT15			equ 0	;hook int 15 real-mode
?HANDLEE0E1			equ 0	;handle E0+E1 internally
?SETBREAK			equ 0	;std=0, 1=disable ctrl-c checking in DOS
?DISABLEKBD			equ 0	;1=support for disable kbd before reading port 60h

if ?CREATE61SC
?EXTENDED	equ <2>
else
?EXTENDED	equ <1+2>
endif

.BASE$IA	segment dword public 'DATA'
		dd install
.BASE$IA	ends	
.BASE$XA	segment dword public 'DATA'
		dd deinstall
.BASE$XA	ends	

BKEYSTAT	equ 417h
BKEYSTAT2	equ 418h
BBRKFLAG	equ 471h
BKEYFLAGS	equ 496h

;--- numpad-'/' and numpad-Enter both return scancodes E0, so 
;--- they are extended keys!
        
	.DATA

if ?CLEARHIGHEBP
g_oldirq1	PF16 0
else
g_oldirq1	PF32 0
endif
if ?LOWLEVEL_CTRLBRK
	public g_bCtrlBrk
g_bCtrlBrk	db 0
endif
	public g_bExtState
g_bExtState	db 0	;bit 1: flag from BKEYFLAG (496h)
if ?SETBREAK
g_bOldCheck db 0	;old value of ctrl-c check status received from DOS
endif
if ?PAUSE
g_wSubsystem dw 0
endif

	align 4

	.CODE

_WriteKbdEvent proto

handler_disabled:			;jmt to previous IRQ1 handler
	jmp cs:[g_oldirq1]
	align 4

myirq1 proc
	cmp cs:[g_bIsActive],1
	jb handler_disabled
if ?FLAT
	test byte ptr cs:[497h],40h	;LED update in progress?
	jnz handler_disabled
endif
	push ds
	mov ds, cs:[g_csalias]
ife ?FLAT
	push @flat
	mov @flat,[g_flatsel]
endif
	push eax
if ?DISABLEKBD
	test byte ptr [g_dwFlags],DKF_DISABLEKBD
	jz @F
	mov al,0ADh
	out 64h, al
@@:
endif
	in al,60h
if ?HANDLEE0E1
	cmp al,0E0h
	jz isE0
	cmp al,0E1h
	jz isE1
endif
	push dword ptr @flat:[41Ah]	;save the queue start/end pointers
	mov ah,al
	and al,7Fh
	push eax
if ?LOWLEVEL_CTRLBRK
	cmp al,46h					;scroll/ctrl-break?
	jz is46
else
	btr word ptr @flat:[BBRKFLAG],7
endif
if ?PAUSE
	cmp al,45h					;pause/numlock key?
	jz is45
endif
if ?FKEYS
	cmp al,3Bh
	jb @F
	cmp al,44h
	jbe fkeys
	cmp al,57h
	jb @F
	cmp al,58h
	jbe fkeys
@@:
endif
	test byte ptr @flat:[BKEYSTAT+1],2	;left alt pressed?
	jz notaltmode
	cmp al,37h					;print key?
	jz normalmode
	cmp al,38h					;alt key?
	jz normalmode
ife ?PAUSE
	cmp al,45h					;pause/numlock key?
	jz normalmode
endif
	cmp al,53h					;del key?
	jz is53					;possibly normalmode (ctrl-alt-del)
notnormal: ;<--- for 46h (scroll lock) and 53h without ctrl
	mov ax,@flat:[BKEYSTAT]
	and ax,208h 				;17:8 (any ALT), 18:2 (left alt)
	push eax
	and word ptr @flat:[BKEYSTAT],not 208h
	@pushf
	call [g_oldirq1]
	pop eax
	or word ptr @flat:[BKEYSTAT],ax
	jmp after_processing
if ?FKEYS
fkeys:
	mov ax,@flat:[BKEYSTAT]
	and ax,30Fh					;reset ALT, SHIFT, CTRL
	push eax
	and word ptr @flat:[BKEYSTAT],not 30Fh
	@pushf
	call [g_oldirq1]
	pop eax
	or word ptr @flat:[BKEYSTAT],ax
	jmp after_processing
endif
if ?HANDLEE0E1
isE0:
	or byte ptr @flat:[BKEYFLAGS],02h
	or byte ptr g_bExtState,02h
	jmp exit_with_eoi
isE1:
	or byte ptr @flat:[BKEYFLAGS],01h
	jmp exit_with_eoi
endif
if ?PAUSE
is45:
	test byte ptr @flat:[BKEYFLAGS],1	;last byte E1?
	jz normalmode						;no (then it is NUMLOCK)
	cmp g_wSubsystem, IMAGE_SUBSYSTEM_WINDOWS_GUI
	jnz @F
	mov al,20h
	out 20h,al
	sti
	jmp after_processing
@@:
if ?DISABLEKBD
	call ReenableKbd
endif
	pop eax
	call _WriteKbdEvent		;expects [esp+4] == ds:[41Ah]
	pop eax  ;skip saved @flat:[41a]
	pop eax
ife ?FLAT
	pop @flat
endif
	pop ds
	jmp handler_disabled
endif

if ?LOWLEVEL_CTRLBRK
is46:
	test byte ptr @flat:[BKEYFLAGS],02h	;last byte E0?
	jz notnormal
	and byte ptr @flat:[BKEYFLAGS],not 02	;reset E0 flag
	mov g_bExtState,0
	test ah,80h
	pop eax
	pop eax
	jz exit_with_eoi	;ignore press event!
	or g_bCtrlBrk,2	;ok, but wait for ctrl-release event!
exit_with_eoi:
if ?DISABLEKBD
	call ReenableKbd
endif
	mov al,20h
	out 20h,al
	pop eax
ife ?FLAT
	pop @flat
endif
	pop ds
	sti
	@iret

handle_ctrl_break:
	and g_bCtrlBrk, not 2
	or byte ptr @flat:[BBRKFLAG],80h
;;	mov g_lpfnHandlerProc, 0
	pop eax
	pop eax
ife ?FLAT
	pop @flat
endif
	pop ds
	sti
	nop
	int 23h
	@iret
endif	;?LOWLEVEL_CTRLBRK

is53:	 ;alt+del key
	test byte ptr ds:[BKEYSTAT],4	;either ctrl pressed?
	jz notnormal
normalmode:

notaltmode:
	@pushf
	call g_oldirq1
after_processing:

if ?DISABLEKBD
	call ReenableKbd
endif

	pop eax		;get make/break code

ife ?HANDLEE0E1
	cmp ah,0E0h
  if ?CREATE61SC
	jnz @F
  else
	jc @F
  endif
	mov al,@flat:[BKEYFLAGS]
	and al,?EXTENDED
	mov g_bExtState,al
	jmp nokeyevnt
@@:
endif
	call _WriteKbdEvent
if ?LOWLEVEL_CTRLBRK
	test g_bCtrlBrk,2
	jnz handle_ctrl_break
else
	btr word ptr @flat:[BBRKFLAG],7
	jnc @F
	sti
	nop
	int 23h
@@:
endif
nokeyevnt:
	pop eax  ;skip saved @flat:[41a]
	pop eax
ife ?FLAT
	pop @flat
endif
	pop ds
	@iret
	align 4

if ?DISABLEKBD
ReenableKbd:
	test byte ptr [g_dwFlags],DKF_DISABLEKBD
	jz @F
	mov al,0AEh
	out 64h, al
@@:
	ret
endif
	align 4

myirq1 endp

;--- install an IRQ1 handler
;--- purpose is to reset "ALT-pressed" flags before
;--- org handler is called, so it doesnt do any translations
;--- concerning these flags

install proc uses ebx

	mov bl,byte ptr g_wPics+1
	inc bl
	mov ax,0204h
	int 31h
if ?CLEARHIGHEBP
	mov word ptr g_oldirq1+0,dx
	mov word ptr g_oldirq1+2,cx
else
	mov dword ptr g_oldirq1+0,edx
	mov word ptr g_oldirq1+4,cx
endif
	mov ecx, cs
	mov edx, offset myirq1
	mov ax,0205h
	int 31h
if ?HOOKINT15
	mov bl,15h
	mov ax,0200h
	int 31h
	mov dword ptr @flat:[5F0h+0],754FFC80h;cmp ah,4F; jnz $+5
	mov dword ptr @flat:[5F0h+4],0FA22E03h;mov cs:[000F],al 	
	mov word  ptr @flat:[5F0h+8],0EA00h	;jmp xxxx:xxxx
	mov word ptr  @flat:[5F0h+10],dx
	mov word ptr  @flat:[5F0h+12],cx
	mov dx,0
	mov cx,5Fh
	mov bl,15h
	mov ax,0201h
	int 31h
endif

if ?PAUSE
if ?FLAT
	invoke GetModuleHandle, 0
	.if (eax)
		mov ecx, [eax+3Ch]
		lea ecx, [ecx+eax]
		mov ax,[ecx].IMAGE_NT_HEADERS.OptionalHeader.Subsystem
		mov g_wSubsystem,ax
	.endif
endif
endif

if ?SETBREAK
;--- this is located here because it is the only console constructor

	mov dl,0		;limited checks
;	mov ax,3301h	;set ctrl-c check
	mov ax,3302h	;get/set ctrl-c check
	int 21h
	mov g_bOldCheck,dl
endif
	ret
	align 4
install endp

deinstall proc uses ebx

	@strace <"keyboard destructor enter">
if ?SETBREAK
	mov dl,g_bOldCheck
	mov ax,3302h	;get/set ctrl-c check
	int 21h
endif
if ?CLEARHIGHEBP
	mov cx,word ptr g_oldirq1+2
else
	mov cx,word ptr g_oldirq1+4
endif
	jcxz @F
	mov edx, dword ptr g_oldirq1+0
	mov bl,byte ptr g_wPics+1
	inc bl
	mov ax,0205h
	int 31h
@@:
if ?HOOKINT15
	mov dx,word ptr ds:[5F0h+10]
	mov cx,word ptr ds:[5F0h+12]
	mov bl,15h
	mov ax,0201h
	int 31h
endif
	ret
	align 4
deinstall endp

	end
