
;*** keyboard queue handler ***

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP group _TEXT
endif

	option proc:private
	option casemap:none
	option dotname

	include winbase.inc
	include wincon.inc
	include keyboard.inc
	include dkrnl32.inc
	include macros.inc

?CREATE61SC	equ 1	;must match value of same constant in keyboard.asm

if ?CREATE61SC
?EXTENDED	equ <2>
else
?EXTENDED	equ <1+2>
endif


protoKbdEventHandler typedef proto :DWORD, :DWORD
LPFNKBDEVENTHANDLER typedef ptr protoKbdEventHandler

	.DATA

externdef g_bExtState:byte

	public g_asciitable

	align 4

g_keytable dd 8 dup (0)	;2*128 bits (first are standard, second are extended)

g_asciitable db 128 dup (0)

g_pEvntQWrite	dd offset g_evntqueue
g_pEvntQRead	dd offset g_evntqueue
g_lpfnHandlerProc	LPFNKBDEVENTHANDLER 0
g_dwCookie		dd 0

	.DATA?

g_evntqueue KEYEVNT 32 dup (<>)
end_of_eventqueue label byte

	.CODE

setascii proc
	cmp al,0F0h		;NUMPAD-5?
	jz noascii
	cmp al,0E0h
	jnz @F
	test [ebx].KEYEVNT.bStat96,2
	jz @F
noascii:
	mov al,00
@@:
	ret
	align 4
setascii endp

;--- called from keyboard.asm, from inside IRQ 1 handler.
;--- all registers except EAX must be preserved!

_WriteKbdEvent proc public uses ebx
	mov ebx, g_pEvntQWrite
	mov [ebx].KEYEVNT.bScan,ah
	mov al,@flat:[417h]
	mov [ebx].KEYEVNT.bStat17,al
	mov al,@flat:[418h]
	mov [ebx].KEYEVNT.bStat18,al
	mov al,@flat:[496h]
	and al,not ?EXTENDED
	or al, g_bExtState
	mov [ebx].KEYEVNT.bStat96,al
	mov g_bExtState,0
	mov [ebx].KEYEVNT.bAscii,0
	movzx eax,word ptr [esp+2+4+4]		;get old [41Ch] (bufend)
	cmp ax,@flat:[41Ch]
	jz noascii
	mov al,@flat:[eax+400h]
	call setascii
	mov [ebx].KEYEVNT.bAscii,al
	push ecx
	movzx ecx, [ebx].KEYEVNT.bScan
	and cl,7Fh
	mov [ecx + g_asciitable],al
	pop ecx
noascii:
	mov ah,[ebx].KEYEVNT.bScan
	test [ebx].KEYEVNT.bStat96,?EXTENDED
	setne al
	cmp g_lpfnHandlerProc, 0
	jz @F
	pushad
	invoke g_lpfnHandlerProc, g_dwCookie, ebx
	push word ptr @flat:[41Ah]
	pop word ptr @flat:[41Ch]
	popad
	jnc dontqueueevent
@@:
	add ebx,sizeof KEYEVNT
	cmp ebx, offset end_of_eventqueue
	jnz @F
	mov ebx, offset g_evntqueue
@@:
	mov g_pEvntQWrite, ebx
dontqueueevent:
	shl al,7
	movzx ebx,ah
	and bl,7Fh
	or bl,al
	test ah,80h
	jz @F
	btr g_keytable, ebx
	jmp keytable_set
@@:
	bts g_keytable, ebx
keytable_set:
	ret
	align 4
_WriteKbdEvent endp

;--- get next KEYEVNT struct in EAX or NULL

_GetKbdEvent proc public
	mov eax, g_pEvntQRead
	cmp eax, g_pEvntQWrite
	jz queue_empty
	mov ecx, eax
	add ecx, sizeof KEYEVNT
	cmp ecx, offset end_of_eventqueue
	jnz @F
	mov ecx, offset g_evntqueue
@@:
	mov g_pEvntQRead, ecx
	ret
queue_empty:
	xor eax, eax
	ret
	align 4
_GetKbdEvent endp

;--- get a KEYEVNT struct in EAX or NULL

_PeekKbdEvent proc public dwIndex:DWORD
	mov ecx, dwIndex
	mov eax, g_pEvntQRead
	.repeat
		cmp eax, g_pEvntQWrite
		jz queue_empty
		jecxz done
		add eax, sizeof KEYEVNT
		cmp eax, offset end_of_eventqueue
		jnz @F
		mov eax, offset g_evntqueue
@@:
		dec ecx
	.until (0)
done:
	ret
queue_empty:
	xor eax, eax
	ret
	align 4
_PeekKbdEvent endp

;--- get number of events in queue in EAX

_GetNumberOfKbdEvents proc public
	mov ecx, g_pEvntQRead
	xor eax, eax
@@:
	cmp ecx, g_pEvntQWrite
	jz @F
	inc eax
	add ecx, sizeof KEYEVNT
	cmp ecx, offset end_of_eventqueue
	jnz @B
	mov ecx, offset g_evntqueue
	jmp @B
@@:
	ret
	align 4
_GetNumberOfKbdEvents endp

;--- get current values of key tables in EDX and EAX

_GetKeyTable proc public
	mov eax, offset g_keytable
	mov edx, offset g_asciitable
	ret
	align 4
_GetKeyTable endp

;--- used by DirectInput

_SetKbdEventHandler proc public pHandlerProc:dword, dwCookie:dword
	.if (pHandlerProc == -1)
		mov eax, g_lpfnHandlerProc
		mov edx, g_dwCookie
		jmp exit
	.endif
	@noints
	mov edx, dwCookie
	mov ecx, pHandlerProc
	xchg edx, g_dwCookie
	xchg ecx, g_lpfnHandlerProc
	@restoreints
	mov eax, ecx
exit:
	ret
	align 4
_SetKbdEventHandler endp

	end
