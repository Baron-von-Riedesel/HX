
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
		include wingdi.inc
		include wincon.inc
		include macros.inc
		include duser32.inc

;--- functions included:

;--- AdjustWindowRect
;--- AdjustWindowRectEx
;--- BringWindowToTop
;--- CallWindowProcA
;--- ChildWindowFromPoint
;--- CloseWindow
;--- CreateWindowExA
;--- DefWindowProcA
;--- DestroyWindow
;--- DrawMenuBar
;--- EnableWindow
;--- FindWindowA
;--- FindWindowExA
;--- GetActiveWindow
;--- GetAncestor
;--- GetCapture
;--- GetClientRect
;--- GetDesktopWindow
;--- GetFocus
;--- GetLastActivePopup
;--- GetMenu
;--- GetParent
;--- GetSystemMenu
;--- GetTitleBarInfo
;--- GetTopWindow
;--- GetWindow
;--- GetWindowLongA
;--- GetWindowPlacement
;--- GetWindowRect
;--- GetWindowRgn
;--- GetWindowTextA
;--- GetWindowTextLengthA
;--- GetWindowThreadProcessId
;--- IsChild
;--- IsIconic
;--- IsWindow
;--- IsWindowEnabled
;--- IsWindowVisible
;--- IsWindowUnicode
;--- IsZoomed
;--- MapWindowPoints
;--- MoveWindow
;--- RedrawWindow
;--- ReleaseCapture
;--- SetActiveWindow
;--- SetCapture
;--- SetFocus
;--- SetForegroundWindow
;--- SetMenu
;--- SetParent
;--- SetWindowLongA
;--- SetWindowPlacement
;--- SetWindowPos
;--- SetWindowRgn
;--- SetWindowTextA
;--- ShowOwnedPopups
;--- ShowWindow
;--- UpdateWindow
;--- WindowFromPoint

;--- some functions are dummies.

;--- messages supported:
;--- WM_ACTIVATE
;--- WM_ACTIVATEAPP
;--- WM_CANCELMODE
;--- WM_CLOSE
;--- WM_CREATE
;--- WM_DESTROY
;--- WM_ERASEBKGND
;--- WM_KILLFOCUS
;--- WM_MOVE
;--- WM_PAINT
;--- WM_PALETTECHANGED
;--- WM_SETCURSOR
;--- WM_SETFOCUS
;--- WM_SHOWWINDOW
;--- WM_SIZE
;--- WM_TIMER
;--- WM_WINDOWPOSCHANGED

		.DATA

g_hwndActive	dd 0		;active window (always top-level)
g_hwndFocus		dd 0		;window owning the focus (may be a child window)
g_hwndCapture	dd 0		;window which captured the mouse
g_pWindows 		dd 0		;list of top-level windows (Z order sorted)
g_hwndLock		dd 0		;locked window (LockWindowUpdate)

	public g_pWindows
	public g_hwndCapture

externdef g_SysMenu:MENUOBJ

_ClearOutsideRegion proto hwnd:dword

		.CODE

CreateWindowExA proc public uses ebx dwExStyle:dword,lpszClass:dword,
							lpszName:dword,dwStyle:dword,
							x:dword,y:dword,cx_:dword,cy:dword,
							hwndParent:dword,hMenu:dword,
							hInstance:dword,lpCreateParams:dword
local	pWndClass:DWORD                            

ifdef _DEBUG
		mov ecx,lpszName
		.if (!ecx)
			mov ecx,CStr("NULL")
		.endif
		@strace <"CreateWindowExA(", dwExStyle, ", ", lpszClass, ", ", &ecx, ", style=", dwStyle, ", ", x, ", ", y, ", ", cx_, ", ", cy, ", ...)">
endif
		mov eax, lpszClass
		.if (eax & 0FFFF0000h)
			@strace	<"window class=", &eax>
			invoke FindAtomA, eax
		.endif
		.if (eax)
			invoke _FindClass, eax
			.if (eax)
				mov pWndClass, eax
				mov ecx, sizeof WNDOBJ
				add ecx, [eax].WNDCLASSEX.cbWndExtra
				invoke malloc2, ecx
				and eax,eax
				jz error1
				mov ebx, eax
				mov [ebx].WNDOBJ.dwType, USER_TYPE_HWND
				mov ecx, pWndClass
				mov edx, [ecx].WNDCLASSEX.lpfnWndProc
				mov eax, hInstance
				mov [ebx].WNDOBJ.pWndClass, ecx
				mov [ebx].WNDOBJ.WndProc, edx
				mov [ebx].WNDOBJ.hInstance, eax
				mov eax, dwStyle
				mov ecx, hwndParent
				mov edx, hMenu
				mov [ebx].WNDOBJ.dwStyle, eax
				mov [ebx].WNDOBJ.hwndParent, ecx
				mov [ebx].WNDOBJ.hMenu, edx
				invoke GetCurrentThreadId
				mov [ebx].WNDOBJ.dwThreadId, eax
				mov [ebx].WNDOBJ.bUpdate, TRUE
				mov [ebx].WNDOBJ.bErase, TRUE

;				 .if ((x == CW_USEDEFAULT) || (cx_ == CW_USEDEFAULT))
				.if ((x >= 8000h) || (cx_ == CW_USEDEFAULT))
					invoke GetSystemMetrics, SM_CXSCREEN
					mov edx, eax
				.endif
				mov eax, cx_
;				 .if (eax == CW_USEDEFAULT)
				.if (eax >= 8000h)
					or [ebx].WNDOBJ.dwFlags,FWO_CXDEF
					mov eax, edx
					mov ecx, x
;					 .if (ecx != CW_USEDEFAULT)
					.if (ecx < eax)
						sub eax, ecx
					.endif
					shr eax, 1	;get the half of screen-x - xpos
				.endif
				mov ecx, eax

				mov eax, x
;				 .if (eax == CW_USEDEFAULT)
				.if (eax >= 8000h)
					or [ebx].WNDOBJ.dwFlags,FWO_XDEF
					mov eax, edx
					sub eax, ecx
					jnc @F
					xor eax, eax
@@:
					shr eax, 2
				.endif
				mov [ebx].WNDOBJ.rc.left, eax
				add ecx, eax
				mov [ebx].WNDOBJ.rc.right, ecx

;				 .if ((y == CW_USEDEFAULT) || (cy == CW_USEDEFAULT))
				.if ((y >= 8000h) || (cy >= 8000h))
					invoke GetSystemMetrics, SM_CYSCREEN
					mov edx, eax
				.endif

				mov eax, cy
;				 .if (eax == CW_USEDEFAULT)
				.if (eax >= 8000h)
					or [ebx].WNDOBJ.dwFlags,FWO_CYDEF
					mov eax, edx
					mov ecx, y
;					 .if (ecx != CW_USEDEFAULT)
					.if (ecx < eax)
						sub eax, ecx
					.endif
					shr eax, 1
				.endif
				mov ecx, eax

				mov eax, y
;				 .if (eax == CW_USEDEFAULT)
				.if (eax >= 8000h)
					or [ebx].WNDOBJ.dwFlags,FWO_YDEF
					mov eax, edx
					sub eax, ecx
					jnc @F
					xor eax, eax
@@:
					shr eax, 2
				.endif
				mov [ebx].WNDOBJ.rc.top, eax
				add ecx, eax
				mov [ebx].WNDOBJ.rc.bottom, ecx

				@strace <"CreateWindowEx: hwnd=", ebx, " window pos=", [ebx].WNDOBJ.rc.left, " ", [ebx].WNDOBJ.rc.top, " ", [ebx].WNDOBJ.rc.right, " ", [ebx].WNDOBJ.rc.bottom>

				.if (lpszName)
					invoke lstrlen, lpszName
					inc eax
					invoke malloc, eax
					.if (eax)
						mov [ebx].WNDOBJ.pszText, eax
						invoke lstrcpy, eax, lpszName
					.endif
				.endif

				@serialize_enter
				test dwStyle, WS_CHILD
				.if (ZERO?)
					mov  [ebx].WNDOBJ.pNext, 0
					lea  edx, g_pWindows
					.while (dword ptr [edx])
						mov edx, [edx]
					.endw
					mov  [edx], ebx
				.else
					mov eax, hwndParent
					.if (eax)
						mov ecx,[eax].WNDOBJ.hwndChilds
						mov [eax].WNDOBJ.hwndChilds,ebx
						mov [ebx].WNDOBJ.hwndSibling, ecx
					.endif
				.endif
				@serialize_exit

				@strace <"CreateWindowEx: ebx=", ebx, ", calling WM_CREATE">
;--- expects a CREATESTRUCT structure ptr in LPARAM                
;--- this is a somewhat reversed order of parameters to CreateWindow()
				push dwExStyle
				push lpszClass
				push lpszName
				push dwStyle
				push x
				push y
				push cx_
				push cy
				push hwndParent
				push hMenu
				push hInstance
				push lpCreateParams
				invoke SendMessageA, ebx, WM_CREATE, 0, esp
				add esp, 12*4		; sizeof CREATESTRUCT
				@strace <"CreateWindowEx: WM_CREATE returned ", eax, " ebx=", ebx>
				.if (eax == -1)
					invoke DestroyWindow, ebx
					xor eax, eax
					jmp @exit
				.endif
				test dwStyle, WS_CHILD
				jnz  noswp

				mov eax, SWP_NOMOVE or SWP_NOACTIVATE
				test dwStyle, WS_VISIBLE
				jz @F
				and [ebx].WNDOBJ.dwStyle, not WS_VISIBLE
				or eax, SWP_SHOWWINDOW
				and eax, not SWP_NOACTIVATE
@@:
				mov ecx, [ebx].WNDOBJ.rc.right
				sub ecx, [ebx].WNDOBJ.rc.left
				mov edx, [ebx].WNDOBJ.rc.bottom
				sub edx, [ebx].WNDOBJ.rc.top
				invoke SetWindowPos, ebx, HWND_TOP, -1, -1, ecx, edx, eax
noswp:
				mov eax, ebx
ifdef _DEBUG
			.else
				@strace	<"FindClass failed">
endif
			.endif
ifdef _DEBUG
		.else
			@strace	<"FindAtomA failed">
endif
		.endif
@exit:
		@strace	<"CreateWindowExA()=", eax>
		ret
error1:
		@strace	<"malloc failed">
		xor    eax,eax
		jmp @exit
		align 4

CreateWindowExA endp

;--- save bits of a hdc in a compatible bitmap
;--- or restore bits from a bitmap (if hBM != 0)

SaveBits proc hdc:dword, dwX:dword, dwY:dword, nX:dword, nY:dword, hBM:dword

local	compDC:dword
local	compBM:dword

		invoke CreateCompatibleDC, hdc
		.if (eax)
			mov compDC, eax
			mov eax, hBM
			.if (!eax)
				invoke CreateCompatibleBitmap, compDC, nX, nY
				mov compBM, eax
			.endif
			.if (eax)
				invoke SelectObject, compDC, eax
				.if (hBM)
					invoke BitBlt, hdc, dwX, dwY, nX, nY, compDC, 0, 0, SRCCOPY
				.else
					invoke BitBlt, compDC, 0, 0, nX, nY, hdc, dwX, dwY, SRCCOPY
				.endif
			.endif
			invoke DeleteDC, compDC
			mov eax, compBM
		.endif
exit:
		ret
		align 4

SaveBits endp

DestroyWindow proc public uses ebx hWnd:dword

		@strace <"DestroyWindow(", hWnd, ") enter">
		mov ebx, hWnd
		and ebx, ebx
		jz error
		.if (ebx == g_hwndCapture)
			invoke SetCapture, NULL
		.endif
		invoke	SendMessageA, ebx, WM_DESTROY, 0, 0
		mov edx, g_pTimer
		.while (edx)
			push [edx].UTIMER.pNext
			.if ([edx].UTIMER.hwnd == ebx)
				invoke KillTimer, [edx].UTIMER.hwnd, [edx].UTIMER.dwID 
			.endif
			pop edx
		.endw
		.if (ebx == g_hwndActive)
			mov ecx, g_pWindows
			mov edx, [ecx]
			invoke SetActiveWindow, edx	;edx may be NULL
		.endif
		.if (ebx == g_hwndFocus)
			invoke SetFocus, NULL
		.endif
		@serialize_enter
		test [ebx].WNDOBJ.dwStyle, WS_CHILD
		.if (ZERO?)
			lea ecx, g_pWindows
			mov edx, [ecx]
			.while (edx)
				.if (edx == ebx)
					push [edx].WNDOBJ.pNext
					pop [ecx].WNDOBJ.pNext
					.break
				.endif
				mov ecx, edx
				mov edx, [edx].WNDOBJ.pNext
			.endw
		.else
			mov ecx, [ebx].WNDOBJ.hwndParent
			.if (ecx)
				mov edx, [ecx].WNDOBJ.hwndChilds
				xor eax, eax
				.while (edx)
					.if (edx == ebx)
						push [edx].WNDOBJ.hwndSibling
						.if (eax)
							pop [eax].WNDOBJ.hwndSibling
						.else
							pop [ecx].WNDOBJ.hwndChilds
						.endif
						.break
					.endif
					mov eax, edx
					mov edx,[edx].WNDOBJ.hwndSibling
				.endw
			.endif
		.endif
		@serialize_exit

		.while ([ebx].WNDOBJ.hwndChilds)
			invoke DestroyWindow, [ebx].WNDOBJ.hwndChilds
		.endw

		.if ([ebx].WNDOBJ.pszText)
			invoke free, [ebx].WNDOBJ.pszText
		.endif
		.if ([ebx].WNDOBJ.hRgn)
			invoke DeleteObject, [ebx].WNDOBJ.hRgn
		.endif
		.if ([ebx].WNDOBJ.hbmSaveBits)

			invoke GetDC, 0
			.if (eax)
				push eax
				mov ecx, [ebx].WNDOBJ.rc.right
				mov edx, [ebx].WNDOBJ.rc.bottom
				sub ecx, [ebx].WNDOBJ.rc.left
				sub edx, [ebx].WNDOBJ.rc.top
				invoke SaveBits, eax, [ebx].WNDOBJ.rc.left, [ebx].WNDOBJ.rc.top, ecx, edx, [ebx].WNDOBJ.hbmSaveBits
				mov [ebx].WNDOBJ.hbmSaveBits, eax					
				pop eax
				invoke ReleaseDC, ebx, eax
			.endif
			
			invoke DeleteObject, [ebx].WNDOBJ.hbmSaveBits
			mov [ebx].WNDOBJ.hbmSaveBits, 0
		.endif
		mov [ebx].WNDOBJ.dwType, 0
		invoke free, ebx
exit:
		@strace <"DestroyWindow(", hWnd, ")=", eax>
		ret
error:
		xor eax,eax
		jmp exit
		align 4

DestroyWindow endp

GetForegroundWindow proc public
		invoke GetFocus
		@strace <"GetForegroundWindow()=", eax>
		ret
		align 4
GetForegroundWindow endp

SetForegroundWindow proc public hWnd:dword
		mov eax, hWnd
		invoke SetFocus, eax
		@strace <"SetForegroundWindow(", hWnd, ")=", eax>
		ret
		align 4
SetForegroundWindow endp

GetWindow proc public hWnd:dword, uCmd:dword
		xor eax, eax
		@strace <"GetWindow(", hWnd, ", ", uCmd, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetWindow endp

GetShellWindow proc public
GetShellWindow endp

GetDesktopWindow proc public
		xor eax, eax
		@strace <"GetDesktopWindow()=", eax, " *** unsupp ***">
		ret
		align 4
GetDesktopWindow endp

GetTopWindow proc public hWnd:dword
		xor eax, eax
		@strace <"GetTopWindow(", hWnd, ")=", eax, " *** unsupp ***">
		ret
		align 4
GetTopWindow endp

GetWindowTextA proc public hWnd:dword, pText:ptr byte, nSize:dword
		mov eax, hWnd
		.if (eax)
			mov eax, [eax].WNDOBJ.pszText
			.if (eax)
				invoke lstrcpyn, pText, eax, nSize
				invoke lstrlen, pText
			.endif
		.endif
		@strace <"GetWindowTextA(", hWnd, ", ", pText, ", ", nSize, ")=", eax>
		ret
		align 4
GetWindowTextA endp

SetWindowTextA proc public uses ebx hWnd:HWND, pText:ptr byte
		mov eax, hWnd
		.if (eax)
			mov ebx, eax
			mov ecx, [ebx].WNDOBJ.pszText
			.if (ecx)
				invoke free, ecx
			.endif
			invoke lstrlen, pText
			inc eax
			invoke malloc, eax
			.if (eax)
				mov [ebx].WNDOBJ.pszText, eax
				invoke lstrcpy, eax, pText
			.endif
		.endif
		@strace <"SetWindowTextA(", hWnd, ", ", &pText, ")=", eax>
		ret
		align 4
SetWindowTextA endp

GetWindowTextLengthA proc public hWnd:dword
		mov eax,hWnd
		.if (eax && [eax].WNDOBJ.pszText)  
			invoke lstrlen, [eax].WNDOBJ.pszText
		.endif
		@strace <"GetWindowTextLengthA(", hWnd,")=",eax>
		ret
		align 4
GetWindowTextLengthA endp

;--- get system menu

GetSystemMenu proc public hWnd:DWORD, bRevert:DWORD
		xor eax, eax
		mov ecx, hWnd
		.if (ecx && [ecx].WNDOBJ.dwType == USER_TYPE_HWND)	
			mov eax, [ecx].WNDOBJ.hSysMenu
			.if (!eax)
				mov eax, offset g_SysMenu
			.endif
		.endif
		@strace <"GetSystemMenu(", hWnd, ", ", bRevert, ")=", eax>
		ret
		align 4
GetSystemMenu endp

GetMenu proc public hWnd:DWORD
		mov ecx, hWnd
		xor eax, eax
		.if (ecx && [ecx].WNDOBJ.dwType == USER_TYPE_HWND)
			mov eax, [ecx].WNDOBJ.hMenu
		.endif
		@strace <"GetMenu(", hWnd, ")=", eax>
		ret
		align 4
GetMenu endp

;--- set menu for a window
;--- if ok, return 1

SetMenu proc public hWnd:DWORD, hNewMenu:DWORD
		mov ecx, hWnd
		xor eax, eax
		.if (ecx && [ecx].WNDOBJ.dwType == USER_TYPE_HWND)
			mov edx, hNewMenu
			and edx, edx
			jz @F
			cmp [edx].MENUOBJ.dwType, USER_TYPE_HMENU
			jnz @exit
@@:
			mov [ecx].WNDOBJ.hMenu, edx
			inc eax
		.endif
@exit:
		@strace <"SetMenu(", hWnd, ", ", hNewMenu, ")=", eax>
		ret
		align 4
SetMenu endp

GetParent proc public hWnd:dword
		mov ecx, hWnd
		xor eax, eax
		.if (ecx && [ecx].WNDOBJ.dwType == USER_TYPE_HWND)
			mov eax, [ecx].WNDOBJ.hwndParent
		.endif
		@strace <"GetParent(", hWnd, ")=", eax>
		ret
		align 4
GetParent endp

;--- todo: set the new siblings as well!

SetParent proc public hWnd:dword, hwndNewParent:dword
		mov ecx, hWnd
		xor eax, eax
		.if (ecx && [ecx].WNDOBJ.dwType == USER_TYPE_HWND)
			mov eax, hwndNewParent
			xchg eax, [ecx].WNDOBJ.hwndParent
		.endif
		@strace <"SetParent(", hWnd, ", ", hwndNewParent, ")=", eax>
		ret
		align 4
SetParent endp

;--- return a window objects thread and process ID

GetWindowThreadProcessId proc public uses ebx hWnd:dword, lpdwProcessId:ptr dword
		xor eax, eax
		mov ebx, hWnd
		.if (ebx && [ebx].WNDOBJ.dwType == USER_TYPE_HWND)
			.if (lpdwProcessId)
				invoke GetCurrentProcessId
				mov ecx, lpdwProcessId
				mov [ecx], eax
			.endif
			mov eax, [ebx].WNDOBJ.dwThreadId
		.endif
		@strace <"GetWindowThreadProcessId(", hWnd, ", ", lpdwProcessId, ")=", eax>
		ret
		align 4
GetWindowThreadProcessId endp

;--- test if hWnd is a child of hwndParent

IsChild proc public hWndParent:dword, hWnd:dword
		xor eax, eax
		mov ecx, hWnd
		jecxz exit
		cmp [ecx].WNDOBJ.dwType,USER_TYPE_HWND
		jnz exit
		test [ecx].WNDOBJ.dwStyle, WS_CHILD
		jz exit
		mov eax, hWndParent
		call testchain
exit:
		@strace <"IsChild(", hWnd, ")=", eax>
		ret
		align 4
testchain:
		mov eax, [eax].WNDOBJ.hwndChilds
		.while (eax)
			.if (eax == ecx)
				mov eax,1
				jmp @F
			.endif
			.if ([eax].WNDOBJ.hwndChilds)
				push eax
				call testchain
				pop eax
			.endif
			mov eax,[eax].WNDOBJ.hwndSibling
		.endw
@@:
		retn
		align 4

IsChild endp

IsIconic proc public hWnd:dword
		xor eax, eax			;a duser32 window is never iconic
		@strace <"IsIconic(", hWnd, ")=", eax>
		ret
		align 4
IsIconic endp

IsWindow proc public hWnd:dword
		xor eax, eax
		mov ecx, hWnd
		.if (ecx && ([ecx].WNDOBJ.dwType == USER_TYPE_HWND))
			inc eax
		.endif
		@strace <"IsWindow(", hWnd, ")=", eax>
		ret
		align 4
IsWindow endp

IsWindowVisible proc public hWnd:dword
		xor eax, eax
		mov ecx, hWnd
		.if (ecx && ([ecx].WNDOBJ.dwType == USER_TYPE_HWND) && ([ecx].WNDOBJ.dwStyle & WS_VISIBLE))
			inc eax
		.endif
		@strace <"IsWindowVisible(", hWnd, ")=", eax>
		ret
		align 4
IsWindowVisible endp

IsWindowUnicode proc public hWnd:dword
		xor eax, eax
		@strace <"IsWindowUnicode(", hWnd, ")=", eax>
		ret
		align 4
IsWindowUnicode endp

IsZoomed proc public hWnd:dword
		invoke GetWindowLongA, hWnd, GWL_STYLE
		mov ecx, eax
		xor eax, eax
		test ecx, WS_MAXIMIZE
		setnz al
		@strace <"IsZoomed(", hWnd, ")=", eax>
		ret
		align 4
IsZoomed endp

;--- get HWND which owns a certain POINT
;--- do not return windows which are hidden or disabled!

WindowFromPoint proc public uses ebx point:POINT

		mov eax, g_pWindows
		mov ecx, point.x
		mov edx, point.y
		.while ( eax )
			@strace <"WindowFromPoint, wnd=", eax, " rc=", [eax].WNDOBJ.rc.left, ",", [eax].WNDOBJ.rc.top, ",", [eax].WNDOBJ.rc.right, ",", [eax].WNDOBJ.rc.bottom>
			test [eax].WNDOBJ.dwStyle, WS_DISABLED
			jnz @F
			test [eax].WNDOBJ.dwStyle, WS_VISIBLE
			jz @F
if 0	;a signed comparison is needed
			.if ((ecx >= [eax].WNDOBJ.rc.left) && (ecx < [eax].WNDOBJ.rc.right) && \
				(edx >= [eax].WNDOBJ.rc.top) && (edx < [eax].WNDOBJ.rc.bottom))
				.break
			.endif
endif
			test [eax].WNDOBJ.dwStyle, WS_MAXIMIZE
			jnz found
			cmp ecx,[eax].WNDOBJ.rc.left
			jl @F
			cmp edx,[eax].WNDOBJ.rc.top
			jl @F
			cmp ecx,[eax].WNDOBJ.rc.right
			jge @F
			cmp edx,[eax].WNDOBJ.rc.bottom
			jl found
@@:
			mov eax, [eax].WNDOBJ.pNext
		.endw
found:
		.if (eax)
			mov ebx, [eax].WNDOBJ.hwndChilds
			.if (ebx)
				sub ecx, [eax].WNDOBJ.rc.left
				sub edx, [eax].WNDOBJ.rc.top
				.while (ebx)
					test [ebx].WNDOBJ.dwStyle, WS_DISABLED
					jnz @F
					test [ebx].WNDOBJ.dwStyle, WS_VISIBLE
					jz @F
					cmp ecx,[ebx].WNDOBJ.rc.left
					jl @F
					cmp edx,[ebx].WNDOBJ.rc.top
					jl @F
					cmp ecx,[ebx].WNDOBJ.rc.right
					jge @F
					cmp edx,[ebx].WNDOBJ.rc.bottom
					jge @F
					mov eax, ebx
					jmp found
@@:
					mov ebx, [ebx].WNDOBJ.hwndSibling
				.endw
			.endif
		.endif
		@strace <"WindowFromPoint(", edx, ".", ecx, ")=", eax>
		ret
		align 4
WindowFromPoint endp

ChildWindowFromPoint proc public hWndParent:dword, point:POINT

		invoke WindowFromPoint, point
		.if (eax)
			push eax
			.while (eax && (eax != hWndParent))
				invoke GetParent, eax
			.endw
			pop ecx
			.if (eax)
				mov eax, ecx
			.endif
		.endif
		@strace <"ChildWindowFromPoint(", hWndParent, ", ", <dword ptr point>, ")=", eax>
		ret
		align 4

ChildWindowFromPoint endp

InitGfx proto

_ClearOutsideRegion proc uses ebx esi edi hwnd:dword

local	dwWidth:dword
local	dwHeight:dword
local	rc:RECT


if ?AUTOINIT
		invoke InitGfx
endif
		invoke GetDC, 0
		and eax, eax
		jz exit
		mov edi, eax
		invoke GetStockObject, DKGRAY_BRUSH
		mov esi, eax
		mov ebx, hwnd
		invoke GetSystemMetrics, SM_CXSCREEN
		mov dwWidth, eax
		invoke GetSystemMetrics, SM_CYSCREEN
		mov dwHeight, eax
		.if ([ebx].WNDOBJ.rc.left > 0)
			mov rc.left, 0
			mov rc.top, 0
			mov eax, [ebx].WNDOBJ.rc.left
			mov rc.right, eax
			mov eax, dwHeight
			mov rc.bottom, eax
			invoke FillRect, edi, addr rc, esi
		.endif
		.if ([ebx].WNDOBJ.rc.top > 0)
			mov rc.left, 0
			mov rc.top, 0
			mov eax, dwWidth
			mov rc.right, eax
			mov eax, [ebx].WNDOBJ.rc.top
			mov rc.bottom, eax
			invoke FillRect, edi, addr rc, esi
		.endif
		mov eax, dwWidth
		.if (sdword ptr eax > [ebx].WNDOBJ.rc.right)
			mov rc.right, eax
			mov eax, [ebx].WNDOBJ.rc.right
			.if (sdword ptr eax < 0)
				xor eax, eax
			.endif
			mov rc.left, eax
			mov rc.top, 0
			mov eax, dwHeight
			mov rc.bottom, eax
			invoke FillRect, edi, addr rc, esi
		.endif
		mov eax, dwHeight
		.if (sdword ptr eax > [ebx].WNDOBJ.rc.bottom)
			mov rc.bottom, eax
			mov eax, dwWidth
			mov rc.right, eax
			mov rc.left,0
			mov eax, [ebx].WNDOBJ.rc.bottom
			.if (sdword ptr eax < 0)
				xor eax, eax
			.endif
			mov rc.top, eax
			invoke FillRect, edi, addr rc, esi
		.endif
		invoke ReleaseDC, 0, edi
exit:        
		@strace <"ClearOutsideRegion(", hwnd, ")">
		ret
		align 4
_ClearOutsideRegion endp

SendWPCMsg proc uses ebx esi hwnd:dword, hwndAfter:dword, flags:dword

local	wp:WINDOWPOS

		@strace <"SendWPCMsg(", hwnd, ", ", hwndAfter, ", ", flags, ") enter">
		mov ebx, hwnd
		mov wp.hwnd, ebx
		mov eax, hwndAfter
		mov wp.hwndInsertAfter, eax
		.if ([ebx].WNDOBJ.dwStyle & WS_MAXIMIZE)
			invoke GetSystemMetrics, SM_CYMAXIMIZED
			mov esi, eax
			invoke GetSystemMetrics, SM_CXMAXIMIZED
			xor ecx, ecx
			xor edx, edx
		.else
			mov ecx, [ebx].WNDOBJ.rc.left
			mov edx, [ebx].WNDOBJ.rc.top
			mov eax, [ebx].WNDOBJ.rc.right
			mov esi, [ebx].WNDOBJ.rc.bottom
			sub eax, ecx
			sub esi, edx
		.endif
		mov wp.x, ecx
		mov wp.y, edx
		mov wp.cx_, eax
		mov wp.cy, esi
		mov eax, flags
		mov wp.flags, eax
		invoke SendMessage, ebx, WM_WINDOWPOSCHANGED, 0, addr wp
		@strace <"SendWPCMsg(", hwnd, ", ", hwndAfter, ", ", flags, ") : ", wp.x, ", ", wp.y, ", ", wp.cx_, ", ", wp.cy>
		ret
		align 4
SendWPCMsg endp

SetWindowPos proc public uses ebx hWnd:dword, hwndAfter:dword, x:dword, y:dword, dx_:dword, dy_:dword, flags:dword

		@strace <"SetWindowPos(", hWnd, ", ", hwndAfter, ", ", x, ", ", y, ", ", dx_, ", ", dy_, ", ", flags, ") enter">
		mov eax, hWnd
		and eax, eax
		jz exit
		mov ebx, eax
		mov ecx, flags
		test ecx, SWP_NOMOVE
		jnz @F
		mov eax, x
		mov edx, y
		mov [ebx].WNDOBJ.rc.left, eax
		mov [ebx].WNDOBJ.rc.top, edx
;		 and [ebx].WNDOBJ.dwFlags, not (FWO_XDEF or FWO_YDEF)
@@:
		test ecx, SWP_NOSIZE
		jnz no_size
		mov eax, dx_
		.if ([ebx].WNDOBJ.dwFlags & FWO_XDEF)
			invoke GetSystemMetrics, SM_CXSCREEN
			sub eax, dx_
			jc @F
			shr eax, 1
			mov [ebx].WNDOBJ.rc.left, eax
@@:
			mov eax, dx_
		.endif
		add eax, [ebx].WNDOBJ.rc.left
		mov [ebx].WNDOBJ.rc.right, eax
		mov eax, dy_
		.if ([ebx].WNDOBJ.dwFlags & FWO_YDEF)
			invoke GetSystemMetrics, SM_CYSCREEN
			sub eax, dy_
			jc @F
			shr eax, 1
			mov [ebx].WNDOBJ.rc.top, eax
@@:
			mov eax, dy_
		.endif
		add eax, [ebx].WNDOBJ.rc.top
		mov [ebx].WNDOBJ.rc.bottom, eax
		and [ebx].WNDOBJ.dwFlags, not (FWO_CXDEF or FWO_CYDEF)
no_size:
		mov ecx, flags
		and ecx, SWP_NOMOVE or SWP_NOSIZE
		cmp ecx, SWP_NOMOVE or SWP_NOSIZE
		jz @F
		invoke SendWPCMsg, ebx, hwndAfter, flags
@@:

		test flags, SWP_SHOWWINDOW
		jz @F
		invoke ShowWindow, ebx, SW_SHOWNA
@@: 	   
		test flags, SWP_NOACTIVATE
		jnz @F
		invoke SetActiveWindow, ebx
@@:
		@mov eax, 1
exit:
		@strace <"SetWindowPos(", hWnd, ", ", hwndAfter, ", ", x, ", ", y, ", ", dx_, ", ", dy_, ", ", flags, ")=", eax>
		ret
		align 4
SetWindowPos endp

;--- returns in EAX
;--- 0 if window was previously invisible
;--- >0 if window was previously visible

ShowWindow proc public uses ebx hWnd:dword,nCmdShow:dword

ifdef _DEBUG
		lea edx, [esp+4*4]
endif
		@strace <"ShowWindow(", hWnd, ", ", nCmdShow, ") enter [esp=", edx, "]">
		mov eax, hWnd
		and eax, eax
		jz exit
		mov ebx, eax
		push [ebx].WNDOBJ.dwStyle
		mov edx, nCmdShow
		.if (!edx)						;== SW_HIDE
			.if ([ebx].WNDOBJ.dwStyle & WS_VISIBLE)
				invoke SendMessage, ebx, WM_SHOWWINDOW, 0, 0
			.endif
		.else
			mov ecx, [ebx].WNDOBJ.dwStyle
			.if (edx == SW_MAXIMIZE)
				or [ebx].WNDOBJ.dwStyle, WS_MAXIMIZE
			.else
				and [ebx].WNDOBJ.dwStyle, not WS_MAXIMIZE
			.endif
			mov eax, [ebx].WNDOBJ.dwStyle
			and ecx, WS_MAXIMIZE
			and eax, WS_MAXIMIZE
			.if (ecx != eax)
				invoke SendWPCMsg, ebx, 0, SWP_SHOWWINDOW or SWP_NOZORDER
			.endif
			.if (!([ebx].WNDOBJ.dwStyle & WS_VISIBLE))
				invoke SendMessage, ebx, WM_SHOWWINDOW, 1, 0
			.endif
			mov edx, nCmdShow
			.if (!((edx == SW_SHOWNA) || (edx == SW_SHOWNOACTIVATE) || (edx == SW_SHOWMINNOACTIVE)))
				invoke SetActiveWindow, ebx
			.endif
		.endif
		mov ecx, [ebx].WNDOBJ.hwndChilds
		.while (ecx)
			push [ecx].WNDOBJ.hwndSibling
			invoke ShowWindow, ecx, nCmdShow
			pop ecx
		.endw
		pop eax
		test eax, WS_VISIBLE
		setnz al
		movzx eax,al
exit:
ifdef _DEBUG
		lea edx, [esp+4*4]
endif
		@strace <"ShowWindow(", hWnd, ", ", nCmdShow, ")=", eax, " [esp=", edx, "]">
		ret
		align 4
ShowWindow endp

ShowWindowAsync proc public uses ebx hWnd:dword,nCmdShow:dword
	mov eax, hWnd
	and eax, eax
	jz exit
	mov ebx, eax
	test [ebx].WNDOBJ.dwStyle, WS_VISIBLE
	setnz al
	movzx eax,al
	push eax
	mov edx, nCmdShow
	and edx, edx
	setnz dl
	movzx edx,dl
	invoke PostMessage, ebx, WM_SHOWWINDOW, edx, 0
	pop eax
exit:
	@strace <"ShowWindowAsync(", hWnd, ", ", nCmdShow, ")=", eax>
	ret
	align 4
ShowWindowAsync endp

DefWindowProcA proc public uses ebx hWnd:dword,message:dword,wParam:dword,lParam:dword

		@strace <"DefWindowProc(", hWnd, ", ", message, ", ", wParam, ", ", lParam, ") enter">

		mov eax,message
		mov ecx, hWnd
		push offset exit2
		cmp eax, WM_CLOSE
		jz is_close
		cmp eax, WM_ACTIVATE
		jz is_activate
		cmp eax, WM_SETCURSOR
		jz is_setcursor
		cmp eax, WM_WINDOWPOSCHANGED
		jz is_windowposchanged
		cmp eax, WM_TIMER
		jz is_timer
		cmp eax, WM_SHOWWINDOW
		jz is_showwindow
		cmp eax, WM_ERASEBKGND
		jz is_erasebkgnd
		cmp eax, WM_PAINT
		jz is_paint
		cmp eax, WM_PALETTECHANGED
		jz is_palettechanged
		cmp eax, WM_SYSCOMMAND
		jz is_syscommand
		pop ecx
exit2:
		xor eax, eax
		@strace <"DefWindowProc(", hWnd, ", ", message, ", ", wParam, ", ", lParam, ")=", eax>
		ret
is_syscommand:
		mov eax, wParam
		cmp eax, SC_CLOSE
		jnz @F
		invoke SendMessage, ecx, WM_CLOSE, 0, 0
		retn
@@:
		mov eax, wParam
		cmp eax, SC_MAXIMIZE
		jnz @F
		invoke ShowWindow, ecx, SW_MAXIMIZE
@@:
		retn
is_close:
		invoke DestroyWindow, ecx
		retn
is_paint:
		mov [ecx].WNDOBJ.bUpdate, 0
		retn
is_activate:
		.if (word ptr wParam != WA_INACTIVE)
			invoke SetFocus, ecx
		.endif
		retn
is_setcursor:
		mov eax, [ecx].WNDOBJ.pWndClass
		.if (eax && ([eax].WNDCLASSEX.hCursor))
			invoke SetCursor, [eax].WNDCLASSEX.hCursor
		.endif
		retn
is_showwindow:
		mov ebx, ecx
		.if (wParam)
			or [ebx].WNDOBJ.dwStyle, WS_VISIBLE
if 0
			mov [ebx].WNDOBJ.bUpdate, TRUE
			mov [ebx].WNDOBJ.bErase, TRUE
endif
			mov ecx, [ebx].WNDOBJ.pWndClass
			.if ([ecx].WNDCLASS.style & CS_SAVEBITS)
				.if ([ebx].WNDOBJ.hbmSaveBits)
					invoke DeleteObject, [ebx].WNDOBJ.hbmSaveBits
					mov [ebx].WNDOBJ.hbmSaveBits, 0
				.endif
				invoke GetDC, ebx
				push eax
				mov ecx, [ebx].WNDOBJ.rc.right
				mov edx, [ebx].WNDOBJ.rc.bottom
				sub ecx, [ebx].WNDOBJ.rc.left
				sub edx, [ebx].WNDOBJ.rc.top
				invoke SaveBits, eax, [ebx].WNDOBJ.rc.left, [ebx].WNDOBJ.rc.top, ecx, edx, 0
				mov [ebx].WNDOBJ.hbmSaveBits, eax
				pop eax
				invoke ReleaseDC, ebx, eax
			.endif
if 1
			.if ([ebx].WNDOBJ.bErase)
				invoke GetDC, ebx
				push eax
				invoke SendMessage, ebx, WM_ERASEBKGND, eax, 0
				.if (eax)
					mov [ebx].WNDOBJ.bErase, 0
				.endif
				pop eax
				invoke ReleaseDC, ebx, eax
			.endif
endif
			.if ([ebx].WNDOBJ.bUpdate)
				invoke PostMessage, ebx, WM_PAINT, 0, 0
			.endif
		.else
			and [ebx].WNDOBJ.dwStyle, not WS_VISIBLE
		.endif
		retn
is_erasebkgnd:
		xor eax, eax
		test [ecx].WNDOBJ.dwStyle, WS_VISIBLE
		jz @F
		mov eax, [ecx].WNDOBJ.pWndClass
		.if (eax && [eax].WNDCLASSEX.hbrBackground)
			mov ebx, eax
			invoke SelectObject, wParam, [ebx].WNDCLASSEX.hbrBackground
			push eax
			mov ecx, hWnd
			mov edx, [ecx].WNDOBJ.rc.right
			sub edx, [ecx].WNDOBJ.rc.left
			mov eax, [ecx].WNDOBJ.rc.bottom
			sub eax, [ecx].WNDOBJ.rc.top
			invoke PatBlt, wParam, 0, 0, edx, eax, PATCOPY
			pop eax
			invoke SelectObject, wParam, eax
		.endif
;		 invoke _ClearOutsideRegion, hWnd
@@:
		@mov eax, 1
		retn
is_windowposchanged:
		mov edx, lParam
		test [edx].WINDOWPOS.flags, SWP_NOMOVE
		jnz @F
		mov eax, [edx].WINDOWPOS.y
		shl eax, 16
		mov ax, word ptr [edx].WINDOWPOS.x
		push ecx
		invoke SendMessage, ecx, WM_MOVE, 0, eax
		pop ecx
@@:
		mov edx, lParam
		test [edx].WINDOWPOS.flags, SWP_NOSIZE
		jnz @F
		mov eax, [edx].WINDOWPOS.cy
		shl eax, 16
		mov ax, word ptr [edx].WINDOWPOS.cx_
		mov edx, SIZE_RESTORED
		.if ([ecx].WNDOBJ.dwStyle & WS_MAXIMIZE)
			mov edx, SIZE_MAXIMIZED
		.endif
		push ecx
		invoke SendMessage, ecx, WM_SIZE, edx, eax
		pop ecx
@@:
if 1
		test [ecx].WNDOBJ.dwStyle, WS_VISIBLE
		jz @F
		test [ecx].WNDOBJ.dwStyle, WS_MAXIMIZE
		jnz @F
		invoke _ClearOutsideRegion, ecx
@@:
endif
		retn
is_timer:
		mov edx, ecx
		mov ebx, g_pTimer
		mov ecx, wParam
		.while (ebx)
			.if ((ecx == [ebx].UTIMER.dwID) && (edx == [ebx].UTIMER.hwnd))
				.if ([ebx].UTIMER.pProc)
					invoke GetTickCount
					invoke [ebx].UTIMER.pProc, hWnd, message, wParam, eax
				.endif
				.break
			.endif
			mov ebx, [ebx].UTIMER.pNext
		.endw
		retn
is_palettechanged:        
		cmp ecx, g_hwndActive
		jnz @F
		test [ecx].WNDOBJ.dwStyle, WS_VISIBLE
		jz @F
		invoke _ClearOutsideRegion, ecx
@@:
		retn
		align 4

DefWindowProcA endp

GetActiveWindow proc public
		mov eax, g_hwndActive
		@strace <"GetActiveWindow()=", eax>
		ret
		align 4

GetActiveWindow endp

;--- SetActiveWindow(hwnd)
;--- returns 0 if function fails
;--- else returns previously active window
;--- hwnd parameter may be NULL or a child window handle!

SetActiveWindow proc public uses ebx hwnd:DWORD

		@strace <"SetActiveWindow(", hwnd, ") enter">
		xor eax, eax
		mov ebx, hwnd
if 0
		and ebx, ebx
		jz @F
		test [ebx].WNDOBJ.dwStyle, WS_CHILD
		jnz exit
endif
@@:
		cmp ebx, g_hwndActive
		jz exit2
		.if (g_hwndActive)
			invoke SendMessage, g_hwndActive, WM_ACTIVATE, WA_INACTIVE, ebx
		.elseif (ebx)
;			invoke SendMessage, g_hwndActive, WM_ACTIVATEAPP, 1, 0
			invoke SendMessage, ebx, WM_ACTIVATEAPP, 1, 0
		.endif
		mov ecx, ebx
		xchg ecx, g_hwndActive
		push ecx

		.if (ebx)
			@serialize_enter
if 1
			.while ([ebx].WNDOBJ.dwStyle & WS_CHILD)
				mov ebx,[ebx].WNDOBJ.hwndParent
			.endw
endif
			mov ecx, g_pWindows
			.if (ebx != ecx)
				mov g_pWindows, ebx
				mov eax, [ebx]
				mov [ebx], ecx
				.while (ecx)
					.if (ebx == [ecx])
						mov [ecx], eax
						.break
					.endif
					mov ecx, [ecx]
				.endw
			.endif
			push ecx
			@serialize_exit
			pop ecx
			invoke SendMessage, ebx, WM_ACTIVATE, WA_ACTIVE, ecx
if 1
;--- ensure that a window now has the focus
			invoke GetFocus
			.if (!eax)
				invoke SetFocus, g_pWindows
			.endif
endif
		.endif
		pop ebx	;get previously active window
exit2:
		mov eax, ebx
exit:
		@strace <"SetActiveWindow(", hwnd, ")=", eax>
		ret
		align 4

SetActiveWindow endp

GetWindowRect proc public hWnd:DWORD, lpRect:ptr RECT

		mov ecx, hWnd
		.if ( ecx && (!([ecx].WNDOBJ.dwStyle & WS_MAXIMIZE)))
			invoke CopyRect, lpRect, addr [ecx].WNDOBJ.rc
		.else	;HWND_DESKTOP
			invoke GetSystemMetrics, SM_CXFULLSCREEN
			push eax
			invoke GetSystemMetrics, SM_CYFULLSCREEN
			pop edx
			mov ecx, lpRect
			mov [ecx].RECT.right, edx
			mov [ecx].RECT.bottom, eax
			xor eax, eax
			mov [ecx].RECT.left, eax
			mov [ecx].RECT.top, eax
			inc eax
		.endif
		@strace <"GetWindowRect(", hWnd, ", ", lpRect, ")=", eax>
		ret
		align 4

GetWindowRect endp

GetClientRect proc public hWnd:DWORD, lpRect:ptr RECT

		mov eax, hWnd
		and eax, eax		;hWnd==0 (HWND_DESKTOP)
		jz exit
		mov edx, lpRect
		mov [edx].RECT.left, 0
		mov [edx].RECT.top, 0
		.if ([eax].WNDOBJ.dwStyle & WS_MAXIMIZE)
			invoke GetSystemMetrics, SM_CXMAXIMIZED
			push eax
			invoke GetSystemMetrics, SM_CYMAXIMIZED
			mov edx, lpRect
			pop [edx].RECT.right
			mov [edx].RECT.bottom, eax
		.else
			mov ecx, eax
			mov eax, [ecx].WNDOBJ.rc.right
			sub eax, [ecx].WNDOBJ.rc.left
			mov [edx].RECT.right, eax
			mov eax, [ecx].WNDOBJ.rc.bottom
			sub eax, [ecx].WNDOBJ.rc.top 
			mov [edx].RECT.bottom, eax
		.endif
		@mov eax, 1
exit:
ifdef _DEBUG
		.if (eax)
			@strace <"GetClientRect(", hWnd, ", ", lpRect, "[", [edx].RECT.left, " ", [edx].RECT.top, " ", [edx].RECT.right, " ", [edx].RECT.bottom, "])=", eax>
		.else
			@strace <"GetClientRect(", hWnd, ", ", lpRect, ")=", eax>
		.endif
endif
		ret
		align 4
GetClientRect endp

ClientToScreen proc public hWnd:DWORD, lpPoint:ptr POINT

		mov eax, hWnd
		and eax, eax
		jz exit
		mov ecx, eax
		mov edx, lpPoint
ifdef _DEBUG
		push [edx].POINT.y
		push [edx].POINT.x
endif
		.if (!([ecx].WNDOBJ.dwStyle & WS_MAXIMIZE))
			mov eax, [ecx].WNDOBJ.rc.left
			add [edx].POINT.x, eax
			mov eax, [ecx].WNDOBJ.rc.top
			add [edx].POINT.y, eax
			@strace	<"ClientToScreen: wnd.x,y=", [ecx].WNDOBJ.rc.left, ", ", [ecx].WNDOBJ.rc.top>
		.endif
		@mov eax, 1
exit:
ifdef _DEBUG
		.if (eax)
			mov ecx, esp
			@strace	<"ClientToScreen(", hWnd, ", ", lpPoint, " [", [ecx].POINT.x, ", ", [ecx].POINT.y, "-}", [edx].POINT.x, ", ", [edx].POINT.y, "])=", eax>
			add esp,2*4
		.else
			@strace	<"ClientToScreen(", hWnd, ", ", lpPoint, ")=", eax>
		.endif
endif
		ret
		align 4
ClientToScreen endp

ScreenToClient proc public hWnd:DWORD, lpPoint:ptr POINT

		mov ecx, hWnd		;HWND_DESKTOP is valid
		jecxz @F
		.if (!([ecx].WNDOBJ.dwStyle & WS_MAXIMIZE))
			mov edx, lpPoint
			mov eax, [ecx].WNDOBJ.rc.left
			sub [edx].POINT.x, eax
			mov eax, [ecx].WNDOBJ.rc.top
			sub [edx].POINT.y, eax
		.endif
@@:
		@mov eax, 1
		@strace <"ScreenToClient(", hWnd, ", ", lpPoint, ")=", eax>
		ret
		align 4
ScreenToClient endp

;--- check if (negative) window offset (in ECX is known)

checkwndofs proc
		xor eax, eax
		test ecx,ecx
		js @F			;negative values?
		ret
@@:
		cmp ecx, GWL_WNDPROC
		jnz @F
		push 0 - sizeof WNDOBJ + WNDOBJ.WndProc
		pop ecx
		ret
@@:
		cmp ecx, GWL_USERDATA
		jnz @F
		push 0 - sizeof WNDOBJ + WNDOBJ.dwUserData
		pop ecx
		ret
@@:
		cmp ecx, GWL_HINSTANCE
		jnz @F
		push 0 - sizeof WNDOBJ + WNDOBJ.hInstance
		pop ecx
		ret
@@:
		cmp ecx, GWL_STYLE
		jnz @F
		push 0 - sizeof WNDOBJ + WNDOBJ.dwStyle
		pop ecx
		ret
@@:
		stc
		ret
		align 4
checkwndofs endp

GetWindowWord proc public hWnd:HWND, nIndex:dword
GetWindowWord endp

GetWindowLongA proc public hWnd:HWND, nIndex:dword

		mov ecx, nIndex
		call checkwndofs
		jc @F
		mov eax, hWnd
		.if (eax)
			mov eax, [eax + sizeof WNDOBJ + ecx]
		.endif
@@:
ifdef _DEBUG
		lea edx, [esp+4*4]
endif
		@strace <"GetWindowLongA(", hWnd, ", ", nIndex, ")=", eax, " esp=", edx> 
		ret
		align 4
GetWindowLongA endp

SetWindowWord proc public hWnd:HWND, nIndex:dword, dwNewWord:dword
SetWindowWord endp

SetWindowLongA proc public hWnd:HWND, nIndex:dword, dwNewLong:dword
		mov ecx, nIndex
		call checkwndofs
		jc @F
		mov eax, hWnd
		.if (eax)
			mov edx, dwNewLong
			xchg edx, [eax + sizeof WNDOBJ + ecx]
			mov eax, edx
		.endif
@@:
		@strace <"SetWindowLongA(", hWnd, ", ", nIndex, ", ", dwNewLong, ")=", eax>
		ret
		align 4
SetWindowLongA endp

protoWNDPROC typedef proto :DWORD, :DWORD, :DWORD, :DWORD
LPFNWNDPROC typedef ptr protoWNDPROC

CallWindowProcA proc public lpPrevWndProc:LPFNWNDPROC, hWnd:HWND, msg:DWORD, wParam:DWORD, lParam:DWORD
		@strace <"CallWindowProcA(", lpPrevWndProc, ", ", hWnd, ", ", msg, ", ", wParam, ", ", lParam, ")">
		invoke lpPrevWndProc, hWnd, msg, wParam, lParam
		ret
		align 4
CallWindowProcA endp

GetFocus proc public
	mov eax, g_hwndFocus
	@strace <"GetFocus()=", eax>
	ret
	align 4
GetFocus endp

SetFocus proc public uses ebx hWnd:HWND
	mov eax, hWnd
	.if (g_hwndFocus && (eax != g_hwndFocus))
		push eax
		invoke SendMessage, g_hwndFocus, WM_KILLFOCUS, hWnd, 0
		pop eax
	.endif
	xchg eax, g_hwndFocus
	push eax
	.if (hWnd)
		invoke SendMessage, hWnd, WM_SETFOCUS, eax, 0
if 1
		.if (1)
			invoke GetDC, hWnd
			mov ebx, eax
			invoke GetDeviceCaps, ebx, RASTERCAPS
			push eax
			invoke ReleaseDC, hWnd, ebx
			pop eax
			.if (eax & RC_PALETTE)
				invoke SendMessage, hWnd, WM_QUERYNEWPALETTE, 0, 0
				.if (eax)
					invoke SendMessage, HWND_BROADCAST, WM_PALETTECHANGED, hWnd, 0
				.endif
			.endif
		.endif
endif
	.endif
	pop eax
	@strace <"SetFocus(", hWnd, ")=", eax>
	ret
	align 4
SetFocus endp

SetCapture proc public hWnd:HANDLE
	mov eax, hWnd
	xchg eax, g_hwndCapture
	@strace <"SetCapture(", hWnd, ")=", eax>
	ret
	align 4
SetCapture endp

GetCapture proc public
	mov eax, g_hwndCapture
	@strace <"GetCapture()=", eax>
	ret
	align 4
GetCapture endp

ReleaseCapture proc public
	xor eax, eax
	xchg eax, g_hwndCapture
	@strace <"ReleaseCapture()=", eax>
	ret
	align 4
ReleaseCapture endp

AdjustWindowRect proc public pRect:ptr RECT, dwStyle:DWORD, bMenu:DWORD
	@mov eax, 1	;just do nothing, no system areas to be considered
	@strace <"AdjustWindowRect(", pRect, ", ", dwStyle, ", ", bMenu, ")=", eax>
	ret
	align 4
AdjustWindowRect endp

AdjustWindowRectEx proc public pRect:ptr RECT, dwStyle:DWORD, bMenu:DWORD, dwExStyle:DWORD
	@mov eax, 1
	@strace <"AdjustWindowRectEx(", pRect, ", ", dwStyle, ", ", bMenu, ", ", dwExStyle, ")=", eax>
	ret
	align 4
AdjustWindowRectEx endp

;--- hwndFrom may be NULL (== HWND_DESKTOP)

MapWindowPoints proc public uses ebx esi edi hwndFrom:DWORD, hwndTo:DWORD, lpPoints:ptr POINT, cbPoints:DWORD

	mov ecx, cbPoints
	mov esi, lpPoints
	mov edi, hwndFrom
	mov ebx, hwndTo
	xor eax, eax
	xor edx, edx
	.if (edi)
		mov edx, [edi].WNDOBJ.rc.left
		mov eax, [edi].WNDOBJ.rc.top
	.endif
	.if (ebx)
		sub edx, [ebx].WNDOBJ.rc.left
		sub eax, [ebx].WNDOBJ.rc.top
	.endif

	.while (ecx)
		add [esi+0], edx
		add [esi+4], eax
		add esi, 2*4
		dec ecx
	.endw

	shl eax, 16
	mov ax, dx

	@strace <"MapWindowPoints(", hwndFrom , ", ", hwndTo, ", ", lpPoints, ", ", cbPoints, ")=", eax>
	ret
	align 4
MapWindowPoints endp

GetAncestor proc public hwnd:DWORD, dwFlags:DWORD
	xor eax, eax
	@strace <"GetAncestor(", hwnd , ", ", dwFlags, ")=", eax>
	ret
	align 4
GetAncestor endp

RemovePaintMsg proto stdcall :DWORD

UpdateWindow proc public hwnd:HWND
	xor eax, eax
	mov ecx, hwnd
	jecxz exit
	.if ([ecx].WNDOBJ.bUpdate)
		invoke RemovePaintMsg, hwnd
		invoke SendMessage, hwnd, WM_PAINT, 0, 0
	.endif
	@mov eax,1
exit:
	@strace <"UpdateWindow(", hwnd , ")=", eax>
	ret
	align 4
UpdateWindow endp

MoveWindow proc public hwnd:HWND, X:dword, Y:dword, nWidth:dword, nHeight:dword, bRepaint:dword
	mov ecx, hwnd
	.if (!bRepaint)
		mov edx, SWP_NOREDRAW
	.endif
	or edx, SWP_NOZORDER or SWP_NOACTIVATE
	invoke SetWindowPos, hwnd, 0, X, Y, nWidth, nHeight, edx
	@strace <"MoveWindow(", hwnd , ", ", X, ", ", Y, ", ", nWidth, ", ", nHeight, ", ", bRepaint, ")=", eax>
	ret
	align 4
MoveWindow endp

SetWindowPlacement proc public uses ebx hwnd:HWND, lpwndpl:ptr WINDOWPLACEMENT
	mov eax, hwnd
	mov edx, lpwndpl
	.if (eax)
		mov ebx,eax
		invoke CopyRect, addr [ebx].WNDOBJ.rc, addr [edx].WINDOWPLACEMENT.rcNormalPosition
	.endif
	@strace <"SetWindowPlacement(", hwnd , ", ", lpwndpl, ")=", eax>
	ret
	align 4
SetWindowPlacement endp

GetWindowPlacement proc public uses ebx hwnd:HWND, lpwndpl:ptr WINDOWPLACEMENT

	mov ebx, hwnd
	mov edx, lpwndpl
	xor ecx, ecx
	mov eax, ecx
	cmp ebx, eax
	jz exit
	mov [edx].WINDOWPLACEMENT.flags, ecx
	mov [edx].WINDOWPLACEMENT.showCmd, ecx

	mov [edx].WINDOWPLACEMENT.ptMinPosition.x, ecx
	mov [edx].WINDOWPLACEMENT.ptMinPosition.y, ecx
	mov [edx].WINDOWPLACEMENT.ptMaxPosition.x, ecx
	mov [edx].WINDOWPLACEMENT.ptMaxPosition.y, ecx

	invoke CopyRect, addr [edx].WINDOWPLACEMENT.rcNormalPosition, addr [ebx].WNDOBJ.rc
exit:
	@strace <"GetWindowPlacement(", hwnd , ", ", lpwndpl, ")=", eax>
	ret
	align 4

GetWindowPlacement endp

;--- returns 1 if window was disabled, else 0

EnableWindow proc public hwnd:HWND, bEnable:dword

	cmp bEnable, edx
	setnz dl
	mov ecx, hwnd
	test [ecx].WNDOBJ.dwStyle, WS_DISABLED
	setnz al
	.if (dl)
		and [ecx].WNDOBJ.dwStyle, not WS_DISABLED
	.else
		or	[ecx].WNDOBJ.dwStyle, WS_DISABLED
	.endif
	mov ah,al
	or ah,dl
	.if (ZERO?)	;zero if window is changing to disabled state
		push eax
		invoke SendMessage, ecx, WM_CANCELMODE, 0, 0
		pop eax
	.endif
	movzx eax,al
	@strace <"EnableWindow(", hwnd , ", ", bEnable, ")=", eax>
	ret
	align 4
EnableWindow endp

IsWindowEnabled proc public hwnd:HWND
	mov ecx, hwnd
	xor eax, eax
	test [ecx].WNDOBJ.dwStyle, WS_DISABLED
	setz al
	@strace <"IsWindowEnabled(", hwnd , ")=", eax>
	ret
	align 4
IsWindowEnabled endp

CloseWindow proc public hwnd:HWND
	xor eax, eax
	@strace <"CloseWindow(", hwnd , ")=", eax>
	ret
	align 4
CloseWindow endp

GetUpdateRect proc public uses ebx hwnd:HWND, lpRect:ptr RECT, bErase:DWORD
	mov ebx, hwnd
	movzx eax, [ebx].WNDOBJ.bUpdate
	mov edx, lpRect
	.if (edx)
		push eax
		.if (eax)
			invoke CopyRect, edx, addr [ebx].WNDOBJ.rc
			.if (bErase)
				invoke GetDC, ebx
				push eax
				invoke SendMessage, ebx, WM_ERASEBKGND, eax, 0
				.if (eax)
					mov [ebx].WNDOBJ.bErase, 0
				.endif
				pop eax
				invoke ReleaseDC, ebx, eax
			.endif
		.else
			invoke SetRectEmpty, edx
		.endif
		pop eax
	.endif
	@strace <"GetUpdateRect(", hwnd , ", ", lpRect, ", ", bErase, ")=", eax>
	ret
	align 4
GetUpdateRect endp

FindWindowA proc public uses ebx esi lpClassName:ptr BYTE, lpWindowName:ptr BYTE

local	cntCmp:dword
local	szName[MAX_PATH]:byte

	mov esi, g_pWindows
	xor ebx, ebx
	xor ecx, ecx
	cmp lpClassName, 1
	adc ebx, ecx
	cmp lpWindowName, 1
	adc ebx, ecx
	mov cntCmp, ebx
	and ebx, ebx
	jz found
	.while (esi)
		mov ebx, cntCmp
		mov edx, lpClassName
		.if (edx)
			mov ecx, [esi].WNDOBJ.pWndClass
			test edx, 0FFFF0000h
			.if (ZERO?)
				.if (edx == [ecx].WNDCLASS.lpszClassName)
					dec ebx
					jz found
				.endif
			.else
				invoke GetAtomNameA, [ecx].WNDCLASS.lpszClassName, addr szName, sizeof szName
				invoke lstrcmpi, lpClassName, addr szName
				and eax, eax
				.if (ZERO?)
					dec ebx
					jz found
				.endif
			.endif
		.endif
		.if (lpWindowName)
			invoke lstrcmpi, lpWindowName, [esi].WNDOBJ.pszText
			.if (!eax)
				dec ebx
				jz found
			.endif
		.endif
		mov esi, [esi].WNDOBJ.pNext
	.endw
found:
	mov eax, esi
ifdef _DEBUG
	mov ecx, lpClassName
	and ecx, ecx
	jnz @F
	mov ecx, CStr("NULL")
@@:
	mov edx, lpWindowName
	and edx, edx
	jnz @F
	mov edx, CStr("NULL")
@@:
	@strace <"FindWindowA(", &ecx , ", ", &edx, ")=", eax>
endif
	ret
	align 4
FindWindowA endp

FindWindowExA proc public hwndParent:DWORD, hwndChildAfter:DWORD, lpClassName:ptr BYTE, lpWindowName:ptr BYTE
	xor eax, eax
	.if ((!hwndParent) && (!hwndChildAfter))
		invoke FindWindowA, lpClassName, lpWindowName
	.endif
	@strace <"FindWindowExA(", hwndParent, ", ", hwndChildAfter, ", ", lpClassName , ", ", lpWindowName, ")=", eax>
	ret
	align 4
FindWindowExA endp

GetLastActivePopup proc public hwndParent:DWORD
	xor eax, eax
	@strace <"GetLastActivePopup(", hwndParent, ")=", eax, " *** unsupp ***">
	ret
	align 4
GetLastActivePopup endp

ShowOwnedPopups proc public hwndParent:DWORD, fShow:DWORD
	xor eax, eax
	@strace <"ShowOwnedPopups(", hwndParent, ", ", fShow, ")=", eax, " *** unsupp ***">
	ret
	align 4
ShowOwnedPopups endp

RedrawWindow proc public hwnd:DWORD, lprcUpdate:ptr, hrgnUpdate:DWORD, flags:DWORD
	xor eax, eax
	.if (hrgnUpdate)
		invoke InvalidateRect, hwnd, 0, 1
	.elseif (lprcUpdate)
		invoke InvalidateRect, hwnd, 0, 1
	.else
		invoke InvalidateRect, hwnd, 0, 1
	.endif
	@strace <"RedrawWindow(", hwnd, ", ", lprcUpdate, ", ", hrgnUpdate, ", ", flags, ")=", eax, " *** unsupp ***">
	ret
	align 4
RedrawWindow endp

GetTitleBarInfo proc public hwnd:DWORD, lpBar:ptr
	xor eax, eax
	@strace <"GetTitleBarInfo(", hwnd, ", ", lpBar, ")=", eax, " *** unsupp ***">
	ret
	align 4
GetTitleBarInfo endp

BringWindowToTop proc public hwnd:DWORD
	invoke SetWindowPos, hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE  or SWP_NOACTIVATE
	@strace <"BringWindowToTop(", hwnd, ")=", eax>
	ret
	align 4
BringWindowToTop endp

GetWindowRgn proc public uses ebx hwnd:DWORD, hRgn:ptr
	mov eax, ERROR
	mov ebx, hwnd
	.if (ebx && ([ebx].WNDOBJ.dwType == USER_TYPE_HWND))
		.if (1)
			invoke SetRectRgn, hRgn, [ebx].WNDOBJ.rc.left, [ebx].WNDOBJ.rc.top,\
				[ebx].WNDOBJ.rc.right, [ebx].WNDOBJ.rc.bottom
			mov eax, SIMPLEREGION
		.else
			mov eax, ERROR
		.endif
	.endif
	@strace <"GetWindowRgn(", hwnd, ", ", hRgn, ")=", eax>
	ret
	align 4
GetWindowRgn endp

SetWindowRgn proc public uses ebx hwnd:DWORD, hRgn:ptr, bRedraw:DWORD

local	rc:RECT
local	rgndata:RGNDATA

	xor eax, eax
	mov ebx, hwnd
	.if (ebx && ([ebx].WNDOBJ.dwType == USER_TYPE_HWND))
		.if ([ebx].WNDOBJ.hRgn)
			invoke DeleteObject, [ebx].WNDOBJ.hRgn
		.endif
		mov ecx, hRgn
		mov [ebx].WNDOBJ.hRgn, ecx
		.if (1)
			invoke GetRegionData, hRgn, sizeof RGNDATAHEADER + sizeof RECT, addr rgndata
			mov eax, rgndata.rdh.rcBound.left
			mov edx, rgndata.rdh.rcBound.top
			mov [ebx].WNDOBJ.rc.left, eax
			mov [ebx].WNDOBJ.rc.top, edx
			mov eax, rgndata.rdh.rcBound.right
			mov edx, rgndata.rdh.rcBound.bottom
			mov [ebx].WNDOBJ.rc.right, eax
			mov [ebx].WNDOBJ.rc.bottom, edx
		.endif
		@mov eax, 1
	.endif
	@strace <"SetWindowRgn(", hwnd, ", ", hRgn, ", ", bRedraw, ")=", eax>
	ret
	align 4
SetWindowRgn endp

LockWindowUpdate proc public hwnd:DWORD
	@serialize_enter
	mov ecx,hwnd
	xor eax, eax
	mov edx, g_hwndLock
	.if (ecx)
		.if ((!edx) && ([ecx].WNDOBJ.dwType == USER_TYPE_HWND))
			mov g_hwndLock, ecx
			inc eax
		.endif
	.elseif (edx)
		mov g_hwndLock, ecx
		inc eax
	.endif
	@serialize_exit
	@strace <"LockWindowUpdate(", hwnd, ")=", eax>
	ret
	align 4
LockWindowUpdate endp

DrawMenuBar proc public hwnd:DWORD

	xor eax, eax
	@strace <"DrawMenuBar(", hwnd, ")=", eax, "*** unsupp ***">
	ret
	align 4
DrawMenuBar endp

;--- OpenIcon restores a minimized window

OpenIcon proc public hwnd:DWORD
	invoke ShowWindow, hwnd, SW_RESTORE
	@strace <"OpenIcon(", hwnd, ")=", eax>
	ret
	align 4
OpenIcon endp

;--- DrawAnimatedRects is a eye candy, pretty useless

DrawAnimatedRects proc public hwnd:DWORD, idAni:DWORD, lprcFrom:ptr RECT, lprcTo:ptr RECT
	xor eax, eax
	@strace <"DrawAnimatedRects(", hwnd, ",", idAni, ", ", lprcFrom, ", ", lprcTo, ")=", eax>
	ret
	align 4
DrawAnimatedRects endp

;--- 

GetWindowInfo proc public uses ebx edi hwnd:DWORD, pwi:ptr WINDOWINFO
	xor eax, eax
	mov ebx, hwnd
	.if ( ebx && [ebx].WNDOBJ.dwType == USER_TYPE_HWND )
		mov edi, pwi
		invoke CopyRect, addr [edi].WINDOWINFO.rcWindow, addr [ebx].WNDOBJ.rc
		invoke CopyRect, addr [edi].WINDOWINFO.rcClient, addr [ebx].WNDOBJ.rc
		mov eax, [ebx].WNDOBJ.dwStyle
		mov ecx, 0
		mov edx, 0
		mov [edi].WINDOWINFO.dwStyle, eax
		mov [edi].WINDOWINFO.dwExStyle, ecx
		mov [edi].WINDOWINFO.dwWindowStatus, edx
		mov [edi].WINDOWINFO.cxWindowBorders, 0
		mov [edi].WINDOWINFO.cyWindowBorders, 0
		mov eax, [ebx].WNDOBJ.pWndClass
		mov eax, [eax].WNDCLASS.lpszClassName
		mov [edi].WINDOWINFO.atomWindowType, ax
		mov [edi].WINDOWINFO.wCreatorVersion, 0
	.endif
	@strace <"GetWindowInfo(", hwnd, ",", pwi, ")=", eax>
	ret
	align 4
GetWindowInfo endp

SetScrollRange proc public hwnd:DWORD, dw1:DWORD, dw2:DWORD, dw3:DWORD, b1:BOOL
	@strace <"SetScrollRange(", hwnd, ",", dw1, ", ", dw2, ", ", dw3, ", ", b1, ")=", eax, "*** unsupp ***">
	ret
	align 4
SetScrollRange endp

SetScrollPos proc public hwnd:DWORD, dw1:DWORD, dw2:DWORD, b1:BOOL
	@strace <"SetScrollPos(", hwnd, ",", dw1, ", ", dw2, ", ", b1, ")=", eax, "*** unsupp ***">
	ret
	align 4
SetScrollPos endp

	end

