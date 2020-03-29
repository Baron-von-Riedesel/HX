
;--- functions included:
;--- PostMessageA
;--- SendMessageA
;--- PostQuitMessage
;--- PostThreadMessageA
;--- DispatchMessageA
;--- TranslateMessage
;--- PeekMessageA
;--- GetMessageA
;--- MsgWaitForMultipleObjects
;--- AttachThreadInput
;--- ReplyMessage
;--- BroadcastSystemMessage

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include wincon.inc
	include macros.inc
	include duser32.inc

?SETRL	equ 0	;

	.DATA

g_dwOldButtonState	dd 0

g_hConInp dd -1
g_bPauseExpected db 0

externdef g_keypress:dword
externdef g_keytoggle:dword

externdef g_pWindows:DWORD
externdef g_hwndCapture:DWORD

EVNTQUEUE struct
hEvent	dd ?
pRead	dd ?
pWrite	dd ?
pStart	dd ?
pEnd	dd ?
EVNTQUEUE ends

;--- currently the event queue is global
;--- (should be thread attached)

ife ?THREADQUEUE
g_Queue		EVNTQUEUE <0, offset start_of_queue, offset start_of_queue, offset start_of_queue, offset end_of_queue>
else
g_TLSSlot	dd -1
endif

	.DATA?

ife ?THREADQUEUE
start_of_queue label dword
	MSG 256 dup (<>)
end_of_queue label dword
endif

	.CODE

;--- if DINPUT acquires keyboard/mouse

_ClearQueue proc

	@serialize_enter
	push g_Queue.pWrite
	pop g_Queue.pRead
	@serialize_exit
	ret
	align 4

_ClearQueue endp

_PostMessage proc uses ebx threadId:dword, hWnd:dword, message:dword, wParam:dword, lParam:dword, point:POINT

	.if (!g_Queue.hEvent)
		invoke CreateEvent, 0, TRUE, 0, 0
		mov g_Queue.hEvent, eax
	.endif
	@serialize_enter
	mov ebx, g_Queue.pWrite
	mov eax,hWnd
	mov edx,message
	mov ecx,wParam
	mov [ebx].MSG.hwnd,eax
	mov [ebx].MSG.message,edx
	mov [ebx].MSG.wParam,ecx
	mov eax,lParam
	mov [ebx].MSG.lParam,eax
	lea edx, [ebx+sizeof MSG]
	cmp edx, g_Queue.pEnd
	jb @F
	mov edx, g_Queue.pStart
@@:
	mov g_Queue.pWrite, edx
	invoke GetTickCount
	mov [ebx].MSG.time, eax
	mov ecx, point.x
	mov edx, point.y
	mov [ebx].MSG.pt.x, ecx
	mov [ebx].MSG.pt.y, edx
	@serialize_exit
	invoke SetEvent, g_Queue.hEvent
	ret
	align 4

_PostMessage endp

;--- PostMessage
;--- hWnd parameter may be HWND_BROADCAST
;--- and it may be NULL (then it is like PostThreadMessage)

PostMessageA proc public hWnd:dword,message:dword,wParam:dword,lParam:dword

local	pnt:POINT

	invoke GetCursorPos, addr pnt
	invoke _PostMessage, 0, hWnd, message, wParam, lParam, pnt
	@strace <"PostMessageA(", hWnd, ", ", message, ", ", wParam, ", ", lParam, ")=", eax>
	ret
	align 4

PostMessageA endp

;--- currently there is just a global message queue

PostThreadMessageA proc public idThread:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

local	pnt:POINT

	invoke GetCursorPos, addr pnt
	invoke _PostMessage, idThread, 0, msg, wParam, lParam, pnt
	@strace <"PostThreadMessage(", idThread, ", ", msg, ", ", wParam, ", ", lParam, ")=", eax>
	ret
	align 4

PostThreadMessageA endp

SendMessageA proc public hWnd:dword,message:dword,wParam:dword,lParam:dword

	@strace	<"SendMessageA(", hWnd, ", ", message, ", ", wParam, ", ", lParam, ") enter">
	mov eax,hWnd
	.if (eax == HWND_BROADCAST)
		mov eax, g_pWindows
		.while (eax)
			push [eax].WNDOBJ.pNext
			invoke [eax].WNDOBJ.WndProc, eax, message, wParam, lParam
			pop eax
		.endw
	.elseif (eax)
		invoke [eax].WNDOBJ.WndProc, eax, message, wParam, lParam
	.endif
	@strace <"SendMessageA(", hWnd, ", ", message, ", ", wParam, ", ", lParam, ")=", eax>
	ret
	align 4

SendMessageA endp

PostQuitMessage proc public rc:dword

	invoke _ClearQueue
	invoke PostMessage, 0, WM_QUIT, rc, 0
	@strace <"PostQuitMessage(", rc, ")">
	ret
	align 4

PostQuitMessage endp

DispatchMessageA proc public pMsg:ptr MSG

	mov eax,pMsg
	mov ecx,[eax].MSG.hwnd
ifdef _DEBUG
	.if (ecx)
		@strace <"DispatchMessageA(", pMsg, ") hwnd=", ecx, " wndproc=", [ecx].WNDOBJ.WndProc>
	.else
		@strace <"DispatchMessageA(", pMsg, ") hwnd=", ecx>
	.endif
endif
	jecxz @exit
	.if ([ecx].WNDOBJ.dwType == USER_TYPE_HWND)
		push [eax.MSG.lParam]
		push [eax.MSG.wParam]
		push [eax.MSG.message]
		push ecx
		call [ecx].WNDOBJ.WndProc
	.endif
@exit:
	ret
	align 4

DispatchMessageA endp

;--- win32 documentation is unclear what to return in case the message
;--- is WM_KEYDOWN|WM_KEYUP but no translation took place
        
TranslateMessage proc public uses ebx pMsg:dword

local	wAscii:WORD

	mov ebx, pMsg
	mov edx, [ebx].MSG.message
	xor eax, eax
	.if ((edx == WM_KEYDOWN) || (edx == WM_SYSKEYDOWN))
		movzx edx, byte ptr [ebx].MSG.lParam+2
		invoke ToAscii, [ebx].MSG.wParam, edx, 0, addr wAscii, 0
		.if (eax)
			movzx eax, byte ptr wAscii
			mov ecx, [ebx].MSG.message
			;--- WM_KEYDOWN -> WM_CHAR, WM_SYSKEYDOWN -> WM_SYSCHAR
			add ecx, 2
			invoke PostMessage, [ebx].MSG.hwnd, ecx, eax, [ebx].MSG.lParam
		.endif
		@mov eax, 1
	.elseif ((edx == WM_KEYUP) || (edx == WM_SYSKEYUP))
		@mov eax, 1
	.endif
	@strace <"TranslateMessage(", pMsg, ")=", eax>
	ret
	align 4

TranslateMessage endp

_IsHotKey proto :ptr INPUT_RECORD

;--- put console msgs in message queue

PostConsoleMsgs proc uses ebx

local	rc:DWORD
local	hwnd:dword
local	point:POINT
local	msg:MSG

if 0
local	ir:INPUT_RECORD
	mov ebx, g_hConInp
	invoke GetNumberOfConsoleInputEvents, ebx, addr rc
	and eax,eax
	jz exit
	xor eax, eax
	cmp eax, rc
	jz exit
	invoke ReadConsoleInputA, ebx, addr ir, 1, addr rc
	lea ebx, ir
endif   
	.if ([ebx].INPUT_RECORD.EventType == KEY_EVENT)
		movzx ecx,[ebx].INPUT_RECORD.Event.KeyEvent.wVirtualKeyCode
		.if ([ebx].INPUT_RECORD.Event.KeyEvent.bKeyDown == 0)
			mov eax,WM_KEYUP
		.else
			mov eax,WM_KEYDOWN
		.endif
		mov msg.message,eax
		mov msg.wParam,ecx
		mov cx, [ebx].INPUT_RECORD.Event.KeyEvent.wVirtualScanCode
		.if (cx == 61h)
			mov g_bPauseExpected, 1
			jmp exit
		.endif
		.if (g_bPauseExpected)
			.if (cx == 1Dh)
				jmp exit
			.else
				mov g_bPauseExpected, 0
				.if (cx == 45h)
					mov	msg.wParam, VK_PAUSE
				.endif
			.endif
		.endif
		test [ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState, ENHANCED_KEY
		setnz ch

;--- skip the "extended shift" event which is generated for extended keys if
;--- NUMLOCK is on
		.if (ch && ([ebx].INPUT_RECORD.Event.KeyEvent.wVirtualScanCode == 2Ah))
			jmp exit
		.endif
		.if ([ebx].INPUT_RECORD.Event.KeyEvent.wVirtualScanCode == 38h)
if 1        
			.if (ch && (!([ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState & (LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED))))
				.if (eax == WM_KEYDOWN)
					bt g_keypress, VK_MENU
					jc exit
				.endif
				pushad
				sub esp, sizeof INPUT_RECORD
				mov [esp].INPUT_RECORD.EventType, KEY_EVENT
				mov eax, [ebx].INPUT_RECORD.Event.KeyEvent.bKeyDown
				mov [esp].INPUT_RECORD.Event.KeyEvent.bKeyDown, eax
				mov [esp].INPUT_RECORD.Event.KeyEvent.wVirtualScanCode, 1Dh
				mov [esp].INPUT_RECORD.Event.KeyEvent.wVirtualKeyCode, VK_CONTROL
				mov eax, [ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState
				and eax, not (ENHANCED_KEY or RIGHT_ALT_PRESSED)
				or eax, LEFT_CTRL_PRESSED
				mov [esp].INPUT_RECORD.Event.KeyEvent.dwControlKeyState, eax
				mov ebx, esp
				invoke PostConsoleMsgs
				add esp, sizeof INPUT_RECORD
				popad
				or [ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState, LEFT_CTRL_PRESSED
			.endif
endif
;			.if ([ebx].INPUT_RECORD.Event.KeyEvent.bKeyDown)
;				or ch,20h
;			.endif
		.endif
		.if (eax == WM_KEYUP)
			or ch,0C0h	;these bits are always 1 for WM_KEYUP
		.endif
		shl ecx, 16
		inc ecx					;set repeat count (bits 0-15) to 1
		mov msg.lParam,ecx
		movzx ecx, byte ptr [ebx].INPUT_RECORD.Event.KeyEvent.wVirtualKeyCode
;;		  and cl,7Fh
if ?SETRL       
		xor edx, edx
		.if (ecx == VK_CONTROL)
			mov edx, VK_LCONTROL
			test [ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState, ENHANCED_KEY
			jz @F
			mov edx, VK_RCONTROL
		.elseif (ecx == VK_MENU)
			mov edx, VK_LMENU
			test [ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState, ENHANCED_KEY
			jz @F
			mov edx, VK_RMENU
		.elseif (ecx == VK_SHIFT)
			mov edx, VK_LSHIFT
			cmp [ebx].INPUT_RECORD.Event.KeyEvent.wVirtualScanCode, 2Ah
			jz @F
			mov edx, VK_RSHIFT
		.endif
@@:            
endif       
		.if (eax == WM_KEYDOWN)
			bts g_keypress, ecx
if ?SETRL
			.if (edx)
				bts g_keypress, edx
			.endif
endif           
			setc al
			shl al,6
;--- set bit 30 (the "repeated key" flag)
			or byte ptr msg.lParam+3,al
;--- does the "press" state change? then flip toggle bit
			.if (!al)
			   btc g_keytoggle, ecx
if ?SETRL
			   .if (edx)
				  btc g_keytoggle, edx
			   .endif
endif
			.endif
		.else
			btr g_keypress, ecx
if ?SETRL
			.if (edx)
				btr g_keypress, edx
			.endif
endif
		.endif
		invoke _IsHotKey, ebx
		.if (eax)
			.if (edx)
				invoke PostMessage, eax, WM_HOTKEY, edx, ecx
			.endif
			jmp exit
		.endif
;--- releasing the ALT key
		mov cx, word ptr msg.lParam+2
		and cx, 0C1FFh
		cmp cx, 0C038h
		jz @F
		.if (g_hwndFocus && (!([ebx].INPUT_RECORD.Event.KeyEvent.dwControlKeyState & LEFT_ALT_PRESSED)))
			invoke PostMessage, g_hwndFocus, msg.message, msg.wParam, msg.lParam
		.else
			.if (g_hwndFocus)
				or byte ptr msg.lParam+3,20h	;set context code (ALT pressed)
			.endif
@@:
;--- WM_KEYDOWN -> WM_SYSKEYDOWN, WM_KEYUP -> WM_SYSKEYUP            
			add msg.message,4
if 1
			.if (g_hwndFocus)
				invoke PostMessage, g_hwndFocus, msg.message, msg.wParam, msg.lParam
			.else
endif
				invoke PostMessage, g_hwndActive, msg.message, msg.wParam, msg.lParam
if 1
			.endif
endif
		.endif
	.elseif ([ebx].INPUT_RECORD.EventType == MOUSE_EVENT)
		movsx eax,word ptr [ebx].INPUT_RECORD.Event.MouseEvent.dwMousePosition+2
		movsx ecx,word ptr [ebx].INPUT_RECORD.Event.MouseEvent.dwMousePosition+0
		mov point.y, eax
		mov point.x, ecx
		invoke WindowFromPoint, point
		mov hwnd, eax
		mov msg.hwnd, eax
		mov eax, g_hwndCapture
		.if (eax)
			mov msg.hwnd,eax
		.endif

;--- if the mouse pointer is not in a window and it is not captured, skip msg

		mov eax,msg.hwnd
		and eax,eax
		jz exit

		movzx edx, dx
		.if ([ebx].INPUT_RECORD.Event.MouseEvent.dwEventFlags == MOUSE_MOVED)
			mov eax,WM_MOUSEMOVE
		.elseif ([ebx].INPUT_RECORD.Event.MouseEvent.dwEventFlags == 0)
			mov ecx, [ebx].INPUT_RECORD.Event.MouseEvent.dwButtonState
			xor ecx, g_dwOldButtonState
			.if (ecx & FROM_LEFT_1ST_BUTTON_PRESSED)
				.if (g_dwOldButtonState & FROM_LEFT_1ST_BUTTON_PRESSED)
					mov eax,WM_LBUTTONUP
				.else
					mov eax,WM_LBUTTONDOWN
				.endif
			.elseif (ecx & RIGHTMOST_BUTTON_PRESSED)
				.if (g_dwOldButtonState & RIGHTMOST_BUTTON_PRESSED)
					mov eax,WM_RBUTTONUP
				.else
					mov eax,WM_RBUTTONDOWN
				.endif
			.elseif (ecx & FROM_LEFT_2ND_BUTTON_PRESSED)
				.if (g_dwOldButtonState & FROM_LEFT_2ND_BUTTON_PRESSED)
					mov eax,WM_MBUTTONUP
				.else
					mov eax,WM_MBUTTONDOWN
				.endif
			.else
				xor eax, eax
				jmp exit
			.endif
		.elseif ([ebx].INPUT_RECORD.Event.MouseEvent.dwEventFlags == MOUSE_WHEELED)
			mov edx, [ebx].INPUT_RECORD.Event.MouseEvent.dwButtonState
			mov eax,WM_MOUSEWHEEL
		.elseif ([ebx].INPUT_RECORD.Event.MouseEvent.dwEventFlags == DOUBLE_CLICK)
			mov ecx, [ebx].INPUT_RECORD.Event.MouseEvent.dwButtonState
			and ecx, g_dwOldButtonState
			.if (ecx & FROM_LEFT_1ST_BUTTON_PRESSED)
				mov eax,WM_LBUTTONDBLCLK
			.elseif (ecx & RIGHTMOST_BUTTON_PRESSED)
				mov eax,WM_RBUTTONDBLCLK
			.elseif (ecx & FROM_LEFT_2ND_BUTTON_PRESSED)
				mov eax,WM_MBUTTONDBLCLK
			.endif
		.else
			xor eax, eax
			jmp exit
		.endif
		mov msg.message, eax
		mov ecx, [ebx].INPUT_RECORD.Event.MouseEvent.dwButtonState
		mov g_dwOldButtonState, ecx
		movzx dx, cl
		and dl, MK_LBUTTON or MK_RBUTTON	;same as FROM_LEFT_1ST_BUTTON_PRESSED + RIGHTMOST_BUTTON_PRESSED
if 0
		test cl,FROM_LEFT_2ND_BUTTON_PRESSED
		jz @F
		or dl, MK_MBUTTON
@@:
endif
		mov ecx, [ebx].INPUT_RECORD.Event.MouseEvent.dwControlKeyState
		test cl, LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED
		jz @F
		or dl, MK_CONTROL
@@:
		test cl, SHIFT_PRESSED
		jz @F
		or dl, MK_SHIFT
@@:
		mov msg.wParam, edx
		push eax
		invoke ScreenToClient, msg.hwnd, addr point
		pop eax
		mov ecx, point.y
		shl ecx, 16
		mov cx, word ptr point.x
		mov msg.lParam, ecx
		.if (eax == WM_MOUSEMOVE)
;--- wParam of WM_SETCURSOR: hwnd of window which contains the cursor
;--- lParam of WM_SETCURSOR: HIWORD==mouse msg, LOWORD=hittest code
			shl eax, 16				;mov mouse msg to upper word
			.if (hwnd)
			   mov ax, HTCLIENT
			.else
			   mov ax, HTNOWHERE
			.endif
			invoke _PostMessage, 0, msg.hwnd, WM_SETCURSOR, hwnd, eax, point
		.endif
		invoke _PostMessage, 0, msg.hwnd, msg.message, msg.wParam, msg.lParam, point
	.endif
exit:
	ret
	align 4

PostConsoleMsgs endp

PostTimerMsgs proc uses ebx

	mov ebx, g_pTimer
	.while (ebx)
		invoke WaitForSingleObject, [ebx].UTIMER.hTimer, 0
		.if (eax == 0)
			invoke PostMessage, [ebx].UTIMER.hwnd, WM_TIMER, [ebx].UTIMER.dwID, [ebx].UTIMER.pProc
			invoke SetWaitableTimer, [ebx].UTIMER.hTimer, addr [ebx].UTIMER.time, 0, NULL, 0, 0
		.endif
		mov ebx,[ebx].UTIMER.pNext
	.endw
	ret
	align 4

PostTimerMsgs endp

;--- set global vars g_hConInp and g_Queue.hEvent

GetStdInpHandles proc        

	.if (g_hConInp == -1)
		invoke GetStdHandle,STD_INPUT_HANDLE
		mov g_hConInp, eax
	.endif
	.if (!g_Queue.hEvent)
		invoke CreateEvent, 0, TRUE, 0, 0
		mov g_Queue.hEvent, eax
	.endif
	ret
	align 4

GetStdInpHandles endp        

;--- remove WM_PAINT messages for a window

RemovePaintMsg proc public uses esi edi hWnd:dword

	@serialize_enter
	mov eax, hWnd
	mov edi, g_Queue.pRead
	mov esi, edi
	.while (edi != g_Queue.pWrite)
		lea edx, [edi + sizeof MSG]
		cmp edx, g_Queue.pEnd
		jnz @F
		mov edx, g_Queue.pStart
@@:
		.if ((eax == [edi].MSG.hwnd) && ([edi].MSG.message == WM_PAINT))
		.else
			.if (edi != esi)
				mov ecx, sizeof MSG/4
				rep movsd
			.else
				add esi, sizeof MSG
			.endif
			cmp esi, g_Queue.pEnd
			jnz @F
			mov esi, g_Queue.pStart
@@:
		.endif
		mov edi, edx
	.endw
	mov g_Queue.pWrite, esi
	@serialize_exit
	ret
	align 4

RemovePaintMsg endp

;--- called by PeekMessage, GetMessage, WaitMessage
;--- returns WM_xxx in EAX or NULL

GetQueueMsg proc uses ebx pMsg:ptr MSG, hwnd:dword, bRemove:dword, bWait:dword

nexttry:
	.if (g_Queue.hEvent)
		invoke ResetEvent, g_Queue.hEvent
	.endif
	@serialize_enter
	xor eax, eax
	mov edx, hwnd
	mov ecx, g_Queue.pRead
nextitem:
	cmp ecx, g_Queue.pWrite
	jz queue_empty
	cmp edx,0
	jz @F
	cmp edx,[ecx].MSG.hwnd
	jz @F
	cmp [ecx].MSG.hwnd,0
	jz @F
	push ecx
	push edx
	invoke IsChild, [ecx].MSG.hwnd, edx
	pop edx
	pop ecx
	and eax, eax
	jnz @F
	add ecx,sizeof MSG
	jmp nextitem
@@:
	pushad
	mov edi, pMsg
	mov esi, ecx
	mov ecx, sizeof MSG/4
	rep movsd
	popad
	mov eax,[ecx].MSG.message
	.if (bRemove == PM_REMOVE)
		.if (ecx != g_Queue.pRead)
			pushad
			mov edi, g_Queue.pRead
			mov esi, ecx
			mov ecx, sizeof MSG / 4
@@:
			lodsd
			xchg eax,[edi]
			mov [esi-4],eax
			add edi, 4
			loop @B
			popad
		.endif
		add ecx, sizeof MSG
		cmp ecx, g_Queue.pEnd
		jnz @F
		mov ecx, g_Queue.pStart
@@:
		mov g_Queue.pRead, ecx
	.endif
	@serialize_exit
	ret
queue_empty:

;--- the queue is empty. now test if a key is ready at the console.

	@serialize_exit

	invoke GetStdInpHandles
	mov ebx, esp
	xor ecx, ecx
	mov edx, g_pTimer
	.while (edx)
		.if ([edx].UTIMER.hTimer)
			push [edx].UTIMER.hTimer
			inc ecx
		.endif
		mov edx,[edx].UTIMER.pNext
	.endw
	cmp g_hwndFocus, NULL	;if focus is unowned, don't scan keyboard!
	jz @F
	push g_hConInp		;1
	inc ecx
@@:
	push g_Queue.hEvent	;0
	inc ecx
	mov edx, esp
	invoke WaitForMultipleObjects, ecx, edx, FALSE, bWait
	mov esp, ebx
	cmp eax, WAIT_TIMEOUT
	jz nomsg
	.if (eax == 1 && g_hwndFocus)
		mov ebx, g_hConInp
if 0
		push 0
		invoke GetNumberOfConsoleInputEvents, ebx, esp
		pop ecx
		and eax,eax
		jz nexttry
		and ecx, ecx
		jz nexttry
endif
		@strace <"GetQueueMsg: console msg received">
		sub esp, sizeof INPUT_RECORD
		mov edx, esp
		push 0
		invoke ReadConsoleInputA, ebx, edx, 1, esp
		pop ecx
		mov ebx, esp
		invoke PostConsoleMsgs
		add esp, sizeof INPUT_RECORD
	.elseif (eax)
		invoke PostTimerMsgs
	.endif
	jmp nexttry
nomsg:
	xor eax,eax
exit:
	ret
	align 4

GetQueueMsg endp


PeekMessageA proc public pMsg:dword, hWnd:dword, dwMin:dword, dwMax:dword, flags:dword

	invoke GetQueueMsg, pMsg, hWnd, flags, 0
	and eax, eax
	setnz al
	movzx eax,al

if 0;def _DEBUG
	@strace	<"PeekMessageA(", pMsg, ", ", hWnd, ", ",dwMin, ", ", dwMax, ")=", eax>
	.if (eax)
		mov edx, pMsg
		@strace <"Msg content: ", [edx].MSG.hwnd, " ", [edx].MSG.message, " ", [edx].MSG.wParam, " ", [edx].MSG.lParam>
	.endif
endif
	ret
	align 4

PeekMessageA endp

GetMessageA proc public pMsg:dword, hWnd:dword, dwMin:dword, dwMax:dword

	@strace <"GetMessageA(", pMsg, ", ", hWnd, ", ", dwMin, ", ", dwMax, ") enter">

	invoke GetQueueMsg, pMsg, hWnd, PM_REMOVE, INFINITE
	sub eax, WM_QUIT
ifdef _DEBUG
	mov edx, pMsg
	@strace <"GetMessageA: msg content: ", [edx].MSG.hwnd, " ", [edx].MSG.message, " ", [edx].MSG.wParam, " ", [edx].MSG.lParam>
endif
	ret
	align 4

GetMessageA endp

MsgWaitForMultipleObjects proc public nCount:DWORD, pHandles:ptr, fWaitAll:DWORD, dwMS:DWORD, dwWakeMask:DWORD

local	dwEsp:dword

	mov dwEsp, esp

	invoke GetStdInpHandles
        
	.if (dwWakeMask & (QS_POSTMESSAGE or QS_PAINT))
		push g_Queue.hEvent
	.endif
	.if (dwWakeMask & QS_INPUT)
		push g_hConInp
	.endif
	.if (dwWakeMask & QS_TIMER)
		mov edx, g_pTimer
		.while (edx)
			.if ([edx].UTIMER.hTimer)
				push [edx].UTIMER.hTimer
				inc ecx
			.endif
			mov edx,[edx].UTIMER.pNext
		.endw
	.endif
	mov ecx, nCount
	mov edx, pHandles
	.while (ecx)
		dec ecx
		mov eax,[edx+ecx*4]
		push eax
	.endw
	mov ecx, dwEsp
	sub ecx, esp
	shr ecx, 2
	mov edx, esp
	invoke WaitForMultipleObjects, ecx, edx, fWaitAll, dwMS
	mov esp, dwEsp
	cmp eax, WAIT_TIMEOUT
	jz exit
	.if (eax > nCount)
		mov eax, nCount
	.endif
exit:
;	@strace <"MsgWaitForMultipleObjects(", nCount, ", ", pHandles, ", ", fWaitAll, ", ",  dwMS, ", ", dwWakeMask, ")=", eax>
	ret
	align 4

MsgWaitForMultipleObjects endp

InSendMessage proc public
	xor eax, eax
	@strace <"InSendMessage()=", eax, " *** unsupp ***">
	ret
	align 4
InSendMessage endp

WaitMessage proc public

local	msg:MSG

	invoke GetQueueMsg, addr msg, 0, 0, INFINITE
	@strace <"WaitMessage()=", eax>
	ret
	align 4

WaitMessage endp

GetMessageTime proc public

	mov ecx, g_Queue.pRead
	cmp ecx, g_Queue.pStart
	jnz @F
	mov ecx, g_Queue.pEnd
@@:
	mov eax, [ecx-sizeof MSG].MSG.time        
	@strace <"GetMessageTime()=", eax>
	ret
	align 4

GetMessageTime endp

GetQueueStatus proc public dwFlags:DWORD

	xor eax, eax
	@strace <"GetQueueStatus(", dwFlags, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetQueueStatus endp

RegisterWindowMessageA proc public lpString:ptr BYTE

	invoke FindAtomA, lpString
	.if (!eax)
		invoke AddAtomA, lpString
	.endif
	@strace <"RegisterWindowMessageA(", lpString, ")=", eax>
	ret
	align 4

RegisterWindowMessageA endp

WaitForInputIdle proc public hProcess:DWORD, dwMilliSeconds:DWORD

	xor eax, eax
	@strace <"WaitForInputIdle(", hProcess, ", ", dwMilliSeconds, ")=", eax, " *** unsupp ***">
	ret
	align 4

WaitForInputIdle endp

GetMessagePos proc public

	mov ecx, g_Queue.pRead
	.if (ecx == g_Queue.pStart)
		mov ecx, g_Queue.pEnd
	.endif
	mov eax, [ecx-sizeof MSG].MSG.pt.y
	shl eax, 16
	mov  ax, word ptr [ecx-sizeof MSG].MSG.pt.x
	@strace <"GetMessagePos()=", eax>
	ret
	align 4

GetMessagePos endp

;--- the bScan parameter is not used according to win32 docs!

keybd_event proc public uses ebx bVk:dword, bScan:dword, dwFlags:dword, dwExtraInfo:dword

local	ir:INPUT_RECORD

	mov eax, bVk
	mov ecx, bScan
	mov ir.EventType, KEY_EVENT
	.if (dwFlags & KEYEVENTF_KEYUP)
		mov ir.Event.KeyEvent.bKeyDown, 0
	.else
		mov ir.Event.KeyEvent.bKeyDown, 1
	.endif
	mov ir.Event.KeyEvent.wVirtualKeyCode, ax
	mov ir.Event.KeyEvent.wVirtualScanCode, cx
	xor eax, eax
	.if (dwFlags & KEYEVENTF_EXTENDEDKEY)
		or eax, ENHANCED_KEY
	.endif
	mov ir.Event.KeyEvent.dwControlKeyState, eax
	lea ebx, ir
	invoke PostConsoleMsgs
	@strace	<"keybd_event(", bVk, ", ", bScan, ", ", dwFlags, ", ", dwExtraInfo, ")=void">
	ret
	align 4

keybd_event endp

AttachThreadInput proc public idAttach:DWORD, idAttachTo:DWORD, fAttach:DWORD

	xor eax, eax
	@strace <"AttachThreadInput(", idAttach, ", ", idAttachTo, ", ", fAttach, ")=", eax, " *** unsupp ***">
	ret
	align 4

AttachThreadInput endp

ReplyMessage proc public lResult:DWORD

	xor eax, eax
	@strace <"ReplyMessage(", lResult, ")=", eax, " *** unsupp ***">
	ret
	align 4

ReplyMessage endp

BroadcastSystemMessage proc public dwFlags:DWORD, lpdwRecipients:ptr DWORD, uiMessage:DWORD, wParam:WPARAM, lParam:LPARAM

	xor eax, eax
	@strace <"BroadcastSystemMessage(", dwFlags, ", ", lpdwRecipients, ", ", uiMessage, ", ", wParam, ", ", lParam, ")=", eax, " *** unsupp ***">
	ret
	align 4

BroadcastSystemMessage endp

GetLastInputInfo proc public lpii:ptr

	xor eax, eax
	@strace <"GetLastInputInfo(", lpii, ")=", eax, " *** unsupp ***">
	ret
	align 4

GetLastInputInfo endp

	end

