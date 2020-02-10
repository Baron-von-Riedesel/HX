
;*** low level console input functions ***
;--- implements
;--- PeekConsoleInputA
;--- ReadConsoleInputA
;--- WriteConsoleInputA
;--- GetNumberOfConsoleInputEvents
;--- FlushConsoleInputBuffer

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP GROUP _TEXT
endif

?FKEYS			equ 1	;1=no FKEY retranslation required
?RIGHTALTCTRL	equ 1	;1=pressing right ALT also sets LEFT_CTRL_PRESSED

	option proc:private
	option casemap:none
	option dotname

	include winbase.inc
	include wincon.inc
	include keyboard.inc
	include dkrnl32.inc
	include macros.inc

extern	__DEFCTRLHANDLER:abs

externdef g_asciitable:byte

;--- numpad-'/' and numpad-Enter both return scancodes E0, so 
;--- they are extended keys!

	.DATA

g_pQueue			dd 0
g_bLastcntlstate	db 0
if ?LOWLEVEL_CTRLBRK
externdef	g_bCtrlBrk:byte
endif

	.CODE

numpadx	db VK_NUMPAD7, VK_NUMPAD8, VK_NUMPAD9, VK_SUBTRACT
		db VK_NUMPAD4, VK_NUMPAD5, VK_NUMPAD6, VK_ADD
		db VK_NUMPAD1, VK_NUMPAD2, VK_NUMPAD3
		db VK_NUMPAD0, VK_DECIMAL
        
;--- get control key state in CX 
;--- inp: edi=keyevent
;---      dx=virtual scan code
;---      al=virtual key code if a key is pressed

GetCtrlKeyState proc
	xor ecx,ecx
	test [edi].KEYEVNT.bStat17,3
	jz @F
	or cl,SHIFT_PRESSED
@@:
	test [edi].KEYEVNT.bStat17,10h
	jz @F
	or cl,SCROLLLOCK_ON
@@:
	test [edi].KEYEVNT.bStat17,20h
	jz @F
	or cl,NUMLOCK_ON
if 1
;--- translate VK_HOME - VK_DELETE to VK_NUMPAD0-VK_NUMPAD9
	test [edi].KEYEVNT.bStat96,2	;enhanced key?
	jnz @F
	cmp dl,47h   ;home
	jb @F
	cmp dl,53h   ;separator
	ja @F
	movzx eax,dl
	sub al,47h
	mov al,[eax+numpadx]
endif
@@:
	test [edi].KEYEVNT.bStat17,40h
	jz @F
	or cl,CAPSLOCK_ON
@@:
	test [edi].KEYEVNT.bStat96,4
	jz @F
	or cl,RIGHT_CTRL_PRESSED
@@:
	test [edi].KEYEVNT.bStat96,8
	jz @F
if ?RIGHTALTCTRL
	or cl,RIGHT_ALT_PRESSED or LEFT_CTRL_PRESSED
else
	or cl,RIGHT_ALT_PRESSED
endif
@@:
	test [edi].KEYEVNT.bStat18,1
	jz @F
	or cl,LEFT_CTRL_PRESSED
@@:
	test [edi].KEYEVNT.bStat18,2
	jz @F
	or cl,LEFT_ALT_PRESSED
@@:
;	test [edi].KEYEVNT.bStat96,1+2
	test [edi].KEYEVNT.bStat96,2
	jz @F
	or ch,1	;ENHANCED_KEY
@@:
	ret
	align 4

GetCtrlKeyState endp

statuskeytab label byte
	db __SHIFT_LEFT_MAKE
	db __SHIFT_RIGHT_MAKE
	db __CNTL_LEFT_MAKE
	db __CNTL_RIGHT_MAKE
	db __ALT_LEFT_MAKE
	db __ALT_RIGHT_MAKE
	db __CAPSLOCK_SCAN
	db __NUMLOCK_SCAN
	db __SCROLL_SCAN
SIZESTATUSKEYTAB equ ($ - statuskeytab)

;--- 

IsStatusKey proc uses edi eax

	mov edi, offset statuskeytab
	mov ecx, SIZESTATUSKEYTAB
	mov al, [eax].KEYEVNT.bScan
	and al, 7Fh
	repnz scasb
	ret
	align 4

IsStatusKey endp

;*** virtual key code translation table

	include vktable.inc

;*** Inp: AL=scan code, AH=ascii code **
;--- edi = KEY_EVNT
;*** Out: AL=virtual key code ***

getvirtualkeycode proc uses edi

	cmp al, lvksize
	ja notab
	cmp al,56h		;the 102. key ("<" on german kbd)?
	jnz @F
	cmp ah,0
	jz @F
	mov al,VK_OEM_102
	jmp done
@@:
	cmp al,35h		;one of the divide keys? ("/" or numpad-"/")?
	jnz @F
	test [edi].KEYEVNT.bStat96,2	;extended key?
	jz @F
	mov al,VK_DIVIDE
	jmp done
@@:
	cmp al,53h		;numpad-"." ?
	jnz @F
	and ah,ah		;numlock on?
	jz @F
	mov al,VK_DECIMAL
	jmp done
@@:
	movzx edi, al
	mov al, [edi + vktable]
	and al, al
	jnz done
	mov al, ah
	cmp ah,'A'
	jb @F
	cmp ah,'Z'
	jbe done
@@:
	cmp al,'a'
	jb @F
	cmp al,'z'
	ja @F
	sub al,20h
	jmp done
@@:
	cmp al,01h	;Ctrl-A - Ctrl-Z?
	jb @F
	cmp al,1Ah
	ja @F
	add al,40h
@@:
done:
	ret
notab:
	xor al, al
	ret
	align 4

getvirtualkeycode endp

;--- this table helps to undo some of the scan code translations
;--- the keyboard driver has done. dkrnl32 relies on the installed keyboard
;--- driver to some extent. As a disadvantage some of the scancode
;--- translations of control keys must now be undone

ytab label byte
	db __CTRL_TAB_MAKE
	db __CTRL_CURSOR_UP,__CTRL_CURSOR_DOWN,__CTRL_CURSOR_LEFT,__CTRL_CURSOR_RIGHT
	db __CTRL_INS_MAKE,__CTRL_DEL_MAKE
	db __CTRL_HOME_MAKE,__CTRL_END_MAKE
	db __CTRL_PAGE_UP,__CTRL_PAGE_DOWN
	db __CTRL_NUMPAD5_MAKE
	db __CTRL_GREYMINUS, __CTRL_GREYPLUS, __CTRL_GREYMULTIPLY
	db __F11_SCAN, __F12_SCAN
ife ?FKEYS
	db __F11_SHIFT,__F12_SHIFT
	db __F11_CTRL, __F12_CTRL
endif

lytab equ $ - ytab

	db __TAB_MAKE
	db __CURSOR_UP, __CURSOR_DOWN, __CURSOR_LEFT, __CURSOR_RIGHT
	db __INS_MAKE,__DEL_MAKE
	db __HOME_MAKE, __END_MAKE
	db __PAGE_UP,__PAGE_DOWN
	db __NUMPAD5_MAKE
	db __GREYMINUS, __GREYPLUS, __GREYMULTIPLY
	db __F11_MAKE,__F12_MAKE	;57h,58h
ife ?FKEYS
	db __F11_MAKE,__F12_MAKE
	db __F11_MAKE,__F12_MAKE
endif
	align 4

;--- in: scan code in AL, ascii in AH
;--- out: new scan code in DX and AL

getvirtualscancode proc

	cmp al,__CTRL_GREYDIVIDE
	jz @F
	cmp al,__GREYRETURN	;numpad-Enter / numpad-/ ? 
	jnz nogreyextkey
@@:
	mov al,__RETURN_MAKE  
	cmp ah,0Dh			;numpad-Enter?
	jz exit
	cmp ah,0Ah			;Ctrl-numpad-Enter?
	jz exit
	mov al,35h
	cmp ah,'/'
	jz exit
nogreyextkey:
	cmp al,56h			;be careful with VK_OEM_102 key
	jnz @F
	and ah,ah			;if it has an ascii code, do nothing
	jnz exit
@@:
ife ?FKEYS
	cmp al,__F1_CTRL
	jb @F
	cmp al,__F10_CTRL
	jbe fxctrl
@@:
	cmp al,__F1_SHIFT
	jb @F
	cmp al,__F10_SHIFT
	jbe fxshift
@@:
endif
	cmp al, __ALT_1			;ALT-1 ... ALT-0, ALT-á, ALT-'
	jb @F					;this is with Alt-Gr key
	cmp al, __ALT_1 + 11
	jbe altnumber
@@:
	push edi
	mov edi,offset ytab
	mov ecx,lytab
	repnz scasb
	jnz @F
	mov al,[edi+lytab-1]
@@:
	pop edi
	jmp exit
ife ?FKEYS
fxctrl:
	add al,__F1_MAKE - __F1_CTRL
	jmp exit
fxshift:
	add al,__F1_MAKE - __F1_SHIFT
	jmp exit
endif
altnumber:
	sub al, __ALT_1 - 2
	jmp exit
exit:
	movzx edx,al
	ret
	align 4

getvirtualscancode endp

setascii:
	cmp al,0E0h
	jz retnull
	cmp al,0F0h
	jz retnull2
	ret
retnull:
retnull2:
	xor al,al
	ret
	align 4

WriteSystemQueue proc pRecord:ptr

	invoke EnterSerialization
	mov ecx, offset g_pQueue
	mov edx, [ecx]
	.while (edx)
		mov ecx, edx
		mov edx,[edx+0]
	.endw
	mov edx, pRecord
	mov [ecx], edx
	invoke LeaveSerialization
	ret
	align 4

WriteSystemQueue endp

PeekSystemQueue proc pBuffer:ptr, index:dword, bRemove:dword

	invoke EnterSerialization
	mov eax,index
	mov ecx, offset g_pQueue
	mov edx, [ecx]
	.while (eax && edx)
		mov ecx, edx
		mov edx,[edx+0]
		dec eax
	.endw
	xor eax,eax
	.if (edx)
		pushad
		mov edi, pBuffer
		lea esi, [edx+4]
		mov ebx, ecx
		mov ecx, sizeof INPUT_RECORD/4
		rep movsd
		.if (bRemove)
			mov eax,[edx]
			mov [ebx],eax
			invoke LocalFree, edx
		.endif
		popad
		inc eax
	.endif
	invoke LeaveSerialization
	ret
	align 4

PeekSystemQueue endp

_GetNumberOfQueuedEvents proc

	mov ecx,g_pQueue
	xor eax,eax
	.while (ecx)
		inc eax
		mov ecx,[ecx+0]
	.endw
	ret
	align 4

_GetNumberOfQueuedEvents endp

;--- fill a KEYEVNT struct with BIOS values
;--- AH=scancode

FillKeyState proc
	mov [edi].KEYEVNT.bScan,ah
	mov ah, @flat:[417h]
	mov [edi].KEYEVNT.bStat17,ah
	mov ah, @flat:[418h]
	mov [edi].KEYEVNT.bStat18,ah
	mov ah, @flat:[496h]
	mov [edi].KEYEVNT.bStat96,ah
	ret
	align 4
FillKeyState endp

;--- main worker proc for 
;--- PeekConsoleInputA, ReadConsoleInputA
;--- out: eax==1 if an event has been read, eax==0 if not

PeekKbdDevice proc uses ebx edi handle:dword, pBuffer:dword, index:dword, bRemove:dword

local	tmpevnt:KEYEVNT

if 0;?LOWLEVEL_CTRLBRK
	.if (g_bCtrlBrk & 1)
		and g_bCtrlBrk,not 1
		or byte ptr @flat:[471h],80h		;set bios flag
		int 23h
	.endif
endif
	.if (bRemove)
		invoke _GetKbdEvent
	.else
		invoke _PeekKbdEvent, index
	.endif
	mov edi, eax
	and eax, eax
	jz nokeyevent1			;dont exit, may be someone has modified
							;the BIOS key buffer
	call IsStatusKey
	mov al,00				;no ascii
	jz setvalues
	movzx eax,[edi].KEYEVNT.bScan
	test al,80h
	jz @F
	and al,7Fh
	mov al, [eax + g_asciitable]
	jmp setvalues
@@:
	mov ah,al
	mov al,[edi].KEYEVNT.bAscii
	movzx ebx,word ptr @flat:[041Ah]
	cmp BX,@flat:[041Ch]
	jz setvalues
	mov al,@flat:[ebx+400h]
	call setascii
	cmp al,[edi].KEYEVNT.bAscii
	jz @F
	mov al,[edi].KEYEVNT.bAscii
	jmp setvalues
nokeyevent1:
	movzx ebx,word ptr @flat:[041Ah]
	cmp BX,@flat:[041Ch]
	jz nokeyevent2
	mov ax,@flat:[ebx+400h]
@@:
if ?NONULLHDL
	movzx edx, word ptr handle
else
	mov edx, handle
endif
	bt g_bProcessed, edx
	setc dl
	.if (al == 3)
		inc dl
ife ?LOWLEVEL_CTRLBRK
	.elseif (!ax)				;this is ctrl-break	
		mov dl,2				;always signal
endif
	.endif
	.if (bRemove || (dl == 2))
		INC ebx
		INC ebx
		CMP BX,@flat:[0482h]
		JNZ @F
		MOV BX,@flat:[0480h]
@@:
		MOV @flat:[041Ah],BX
	.endif
	.if (dl == 2)
		int 23h			;and exec int 23h
		jmp nokeyevent2
	.endif
	.if (!edi)
		lea edi, tmpevnt
		call FillKeyState
	.endif
setvalues:
;--- ascii in AL
	mov ebx,pBuffer
	mov [ebx].INPUT_RECORD.Event.KeyEvent.bKeyDown,TRUE
	test [edi].KEYEVNT.bScan,80h
	jz @F
	mov [ebx].INPUT_RECORD.Event.KeyEvent.bKeyDown,FALSE
@@:
	call setascii
	mov ah,0
	mov [ebx].INPUT_RECORD.Event.KeyEvent.AsciiChar,ax
	mov ah,al
	mov al,[edi].KEYEVNT.bScan
	and al,7Fh
	call getvirtualscancode
	mov [ebx].INPUT_RECORD.Event.KeyEvent.wVirtualScanCode, dx
	call getvirtualkeycode
	mov ah,00
	call GetCtrlKeyState
	mov [ebx].INPUT_RECORD.EventType,KEY_EVENT
	mov [ebx].INPUT_RECORD.Event.KeyEvent.wVirtualKeyCode,ax
	mov [ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState,ecx
	@mov eax,1
	mov [ebx].INPUT_RECORD.Event.KeyEvent.wRepeatCount,ax
	jmp exit
nokeyevent2:
	xor eax,eax
exit:
	ret
	align 4

PeekKbdDevice endp

PeekMouDevice proc uses ebx edi handle:dword, pBuffer:dword, index:dword, bRemove:dword

local	tmpevnt:KEYEVNT

	.if (bRemove)
		invoke _GetMouEvent
	.else
		invoke _PeekMouEvent, index
	.endif
	and eax, eax
	jz exit
	mov edi, eax
	mov ebx, pBuffer
	mov [ebx].INPUT_RECORD.EventType, MOUSE_EVENT
	mov edx, dword ptr [edi].MOUEVNT.wPosX	;XPos & YPos

;--- the wheel pos is returned in the hiword(buttonstate)
	mov ax, [edi].MOUEVNT.wPosZ
	shl eax,16
	mov ax, [edi].MOUEVNT.wState
	mov [ebx].INPUT_RECORD.Event.MouseEvent.dwMousePosition, edx
	mov [ebx].INPUT_RECORD.Event.MouseEvent.dwButtonState, eax
	mov [ebx].INPUT_RECORD.Event.MouseEvent.dwEventFlags, 0
	test [edi].MOUEVNT.wMask,80h
	jz @F
	mov [ebx].INPUT_RECORD.Event.MouseEvent.dwEventFlags, MOUSE_WHEELED
	jmp done
@@:
	test [edi].MOUEVNT.wMask,1
	jz done
	mov [ebx].INPUT_RECORD.Event.MouseEvent.dwEventFlags, MOUSE_MOVED
done::
	lea edi, tmpevnt
	call FillKeyState
	call GetCtrlKeyState
	mov [ebx].INPUT_RECORD.Event.MouseEvent.dwControlKeyState,ecx
	@mov eax,1
exit:
	ret
	align 4

PeekMouDevice endp

PeekConsoleInputA proc public uses esi ebx edi handle:dword, pBuffer:ptr INPUT_RECORD, nSize:dword, pRead:ptr dword

	xor edi, edi
	xor esi, esi
	mov ebx, pBuffer
	.while (edi < nSize)
		invoke PeekKbdDevice, handle, ebx, esi, FALSE
		.break .if (!eax)
		add ebx, sizeof INPUT_RECORD
		inc esi
		inc edi
	.endw
	xor esi, esi
	.while (edi < nSize)
		invoke PeekMouDevice, handle, ebx, esi, FALSE
		.break .if (!eax)
		add ebx, sizeof INPUT_RECORD
		inc esi
		inc edi
	.endw
	xor esi, esi
	.while (edi < nSize)
		invoke PeekSystemQueue, ebx, esi, FALSE
		.break .if (!eax)
		add ebx, sizeof INPUT_RECORD
		inc esi
		inc edi
	.endw
	mov ecx,pRead
	mov [ecx], edi
	@mov eax, 1
ifdef _DEBUG
	mov edx, pBuffer
endif
	@straceF DBGF_CIN,<"PeekConsoleInputA(", handle, ", ", edx, "[", dword ptr [edx+0], " ", dword ptr [edx+4], " ", dword ptr [edx+8], " ", dword ptr [edx+12], "], ", nSize, ", ", pRead, " [", edi, "])=", eax>
	ret
	align 4

PeekConsoleInputA endp

;--- read all queued events until buffer is full
;--- return only if at least 1 event has been read

ReadConsoleInputA proc public uses ebx esi handle:dword, pBuffer:ptr INPUT_RECORD, nSize:dword, pRead:ptr dword

	mov ecx, pRead
	mov dword ptr [ecx],0
	mov ebx, pBuffer
	mov esi, nSize
	.while (esi)
		invoke PeekKbdDevice, handle, ebx, 0, TRUE
		.if (!eax)
			invoke PeekMouDevice, handle, ebx, 0, TRUE
			.if (!eax)
				invoke PeekSystemQueue, ebx, 0, TRUE
			.endif
		.endif
		.if (eax)
			mov ecx,pRead
			inc dword ptr [ecx]
if 1
			xor eax, eax
			call [g_dwBoostProc]		;boost current thread
endif
			add ebx, sizeof INPUT_RECORD
			dec esi
		.else
			.break .if (esi != nSize)
			invoke Sleep, 0
		.endif
	.endw
	@mov eax,1
ifdef _DEBUG
	mov ebx, pBuffer
	movzx ecx, [ebx].INPUT_RECORD.EventType
	mov edx, dword ptr [ebx].INPUT_RECORD.Event.KeyEvent.wVirtualScanCode
endif
	@straceF DBGF_CIN,<"ReadConsoleInputA(", handle, ", ", pBuffer, ", ", nSize, ", ", pRead, ")=", eax, " [", ecx, ", ", edx, "]">
	ret
	align 4

ReadConsoleInputA endp

;*** get the number of current kbd + mou events

GetNumberOfConsoleInputEvents proc public uses ebx handle:dword,pEvents:dword

local   buffer:INPUT_RECORD

	invoke _GetNumberOfKbdEvents
	mov ebx, eax
	invoke _GetNumberOfMouEvents
	add ebx, eax
	invoke _GetNumberOfQueuedEvents
	add ebx, eax
	mov ecx, pEvents
	mov [ecx],ebx
	@mov eax, 1
	@straceF DBGF_CIN, <"GetNumberOfConsoleInputEvents(", handle, ", ", pEvents, "[", dword ptr [ecx], "])=", eax>
	ret
	align 4

GetNumberOfConsoleInputEvents endp

FlushConsoleInputBuffer proc public handle:dword

local	inprec:INPUT_RECORD

@@:
	invoke PeekKbdDevice, handle, addr inprec, 1, TRUE
	and eax, eax
	jnz @B
@@:
	invoke PeekMouDevice, handle, addr inprec, 1, TRUE
	and eax, eax
	jnz @B
@@:
	invoke PeekSystemQueue, addr inprec, 1, TRUE
	and eax, eax
	jnz @B
	mov ax,0C0Bh
	int 21h
	@straceF DBGF_CIN, <"FlushConsoleInputBuffer(", handle, ")=", eax>
	ret
	align 4

FlushConsoleInputBuffer endp

WriteConsoleInputA proc public uses esi edi handle:dword, lpBuffer:ptr INPUT_RECORD, nLength:DWORD, lpWritten:ptr DWORD

	mov esi, lpBuffer
	mov ecx, nLength
	.while (ecx)
		push ecx
		invoke LocalAlloc, LMEM_FIXED, sizeof INPUT_RECORD + 4
		.break .if (!eax)
		mov edi, eax
		push eax
		xor eax, eax
		stosd
		mov ecx, sizeof INPUT_RECORD
		rep movsb
		pop eax
		invoke WriteSystemQueue, eax
		add esi, sizeof INPUT_RECORD
		pop ecx
		dec ecx
	.endw
	@mov eax,1
	@straceF DBGF_CIN, <"WriteConsoleInputA(", handle, ", ", lpBuffer, ", ", nLength, ", ", lpWritten, ")=", eax>
	ret
	align 4

WriteConsoleInputA endp

	end
