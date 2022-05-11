
;--- MessageBox()
;--- since in windows a console app can always
;--- display a message box, it should work
;--- for HX even in text mode.

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

?GUI	equ 1

if ?GUI
		.DATA

g_bInit	db 0

		.const

MBTYPE struct
bType	db ?
pszText dd ?
bSize	db ?
bNumKeys db ?
pKeys	dd ?
MBTYPE ends
		
szMsgBoxClass db "MsgBoxClass",0

keyOk		db IDOK, 13, ' ', -1
keyCancel	db IDCANCEL, 1Bh, 'C', -1
keyYes		db IDYES, 13, ' ', 'Y', -1
keyNo		db IDNO, 1B, 'N', -1

szOk	db 'Ok'
sizeOk equ $ - szOk
keysOk dd keyOk

szOkCancel	db 'Ok    Cancel'
sizeOkCancel equ $ - szOkCancel
keysOkCancel dd keyOk, keyCancel

szYesNo			db 'Yes    No'
sizeYesNo equ $ - szYesNo
keysYesNo dd keyYes, keyNo

szYesNoCancel	db 'Yes   No   Cancel'
sizeYesNoCancel equ $ - szYesNoCancel
keysYesNoCancel dd keyYes, keyNo, keyCancel

mbtypes	label MBTYPE
		MBTYPE <MB_OK, offset szOk, sizeOk, 1, keysOk>
		MBTYPE <MB_OKCANCEL, offset szOkCancel, sizeOkCancel, 2, keysOkCancel>
		MBTYPE <MB_YESNO, offset szYesNo, sizeYesNo, 2, keysYesNo>
		MBTYPE <MB_YESNOCANCEL, offset szYesNoCancel, sizeYesNoCancel, 3, keysYesNoCancel>
?SIZEMBTYPE equ ($ - mbtypes) / sizeof MBTYPE

endif
		.code

if ?GUI

MSGBOXPARAM struct
pszText		dd ?
dwSize		dd ?
dwLines		dd ?
dwFlags		dd ?
dwExitCode	dd ?
pMBType		dd ?
MSGBOXPARAM ends

MsgBoxWndProc proc uses ebx esi hWnd:dword, msg:dword, wParam:dword, lParam:dword

local	dwY:dword
local	dwMaxLine:dword
local	ps:PAINTSTRUCT

		mov eax, msg
		.if (eax == WM_CREATE)
			mov ecx, lParam
			mov eax, [ecx].CREATESTRUCTA.lpCreateParams
			invoke SetWindowLongA, hWnd, GWL_USERDATA, eax
		.elseif (eax == WM_DESTROY)
			invoke PostQuitMessage, 0
		.elseif (eax == WM_KEYDOWN)
			invoke GetWindowLongA, hWnd, GWL_USERDATA
			mov ebx, [eax].MSGBOXPARAM.pMBType
			mov edx, eax
			movzx eax, word ptr wParam
			movzx ecx, [ebx].MBTYPE.bNumKeys
			mov esi, [ebx].MBTYPE.pKeys
			.while (ecx)
				mov ebx, [esi]
				mov ah, [ebx]
				inc ebx
				.while (byte ptr [ebx] != -1)
					.if (al == [ebx])
						movzx eax,ah
						mov [edx].MSGBOXPARAM.dwExitCode, eax
						invoke PostMessage, hWnd, WM_CLOSE, 0, 0
						jmp keydone
					.endif
					inc ebx
				.endw
				add esi, 4
				dec ecx
			.endw
keydone:
		.elseif (eax == WM_PAINT)
			.if (1)
				invoke BeginPaint, hWnd, addr ps
				invoke SetBkMode, ps.hdc, TRANSPARENT
				invoke GetWindowLongA, hWnd, GWL_USERDATA
				mov ebx, eax
				mov edx, [eax].MSGBOXPARAM.dwSize
				.if (edx)
					mov ecx, [eax].MSGBOXPARAM.dwLines
					mov esi, [eax].MSGBOXPARAM.pszText
					mov dwY, 8
					mov dwMaxLine, 0
					.while (ecx)
						push ecx
						mov edx, esi
						mov ah,0
						.while (ah < 80)
							mov al,[edx]
							.break .if ((al == 0) || (al == 10))
							inc edx
							inc ah
						.endw
						push edx
						sub edx, esi
						.if (edx > dwMaxLine)
							mov dwMaxLine, edx
						.endif
						.if (edx && (byte ptr [esi+edx-1] == 13))
							dec edx
						.endif
						invoke TabbedTextOutA, ps.hdc, 8*2, dwY, esi, edx, 0, 0, 0
						pop esi
						.if (byte ptr [esi] == 10)
							inc esi
						.endif
						add dwY, 16
						pop ecx
						dec ecx
					.endw
					add dwY, 8
					mov eax, [ebx].MSGBOXPARAM.pMBType
					mov ecx, [eax].MBTYPE.pszText
					movzx eax, [eax].MBTYPE.bSize
					mov edx, dwMaxLine
					sub edx, eax
					jc @F
					shr edx, 1
					add edx, 2
					shl edx, 3
					invoke TextOutA, ps.hdc, edx, dwY, ecx, eax
@@:
				.endif
				invoke EndPaint, hWnd, addr ps
			.endif
		.endif
		invoke DefWindowProc, hWnd, msg, wParam, lParam
		@strace	<"MessageBoxWndProc(", hWnd, ", ", msg, ", ", wParam, ", ", lParam, ")=", eax>
		ret
		align 4
MsgBoxWndProc endp
endif

TextMessage proc pszStr:dword, pStr2:dword, flags:dword

local	dwWritten:dword
local	buffer[2]:BYTE

		invoke GetStdHandle, STD_OUTPUT_HANDLE
		mov ebx, eax
		.if (pStr2)
			invoke lstrlen, pStr2
			lea ecx, dwWritten
			invoke WriteConsole, ebx, pStr2, eax, ecx, 0
			invoke WriteConsole, ebx, CStr(<13,10>), 2, addr dwWritten, 0
		.endif
		.if (pszStr)
			invoke lstrlen, pszStr
			lea ecx, dwWritten
			invoke WriteConsole, ebx, pszStr, eax, ecx, 0
			invoke WriteConsole, ebx, CStr(<13,10>), 2, addr dwWritten, 0
		.endif
		invoke GetStdHandle, STD_INPUT_HANDLE
		mov ebx, eax
nexttry:
		invoke ReadConsole, ebx, addr buffer, 1, addr dwWritten, 0
		.if (eax)
			mov ecx, flags
			mov al, buffer
			.if ((al >= 'A') && (al <= 'Z'))
				or al,20h
			.endif
			.if (ecx == MB_OK)
				.if ((al == ' ') || (al == 13))
					mov eax, IDOK
				.else
					jmp nexttry
				.endif
			.elseif (ecx == MB_YESNO)
				.if ((al == ' ') || (al == 13) || (al == 'y'))
					mov eax, IDYES
				.elseif ((al == 1Bh) || (al == 'n'))
					mov eax, IDNO
				.else
					jmp nexttry
				.endif
			.elseif (ecx == MB_YESNOCANCEL)
				.if ((al == ' ') || (al == 13) || (al == 'y'))
					mov eax, IDYES
				.elseif (al == 1B)
					mov eax, IDCANCEL
				.elseif (al == 'n')
					mov eax, IDNO
				.else
					jmp nexttry
				.endif
			.endif
		.endif
		ret
		align 4
TextMessage endp

MessageBoxA proc public uses ebx esi hWnd:dword, pszStr:dword, pStr2:dword, flags:dword

ife ?GUI
		invoke TextMessage, pszStr, pStr2, flags
else
local	hInstance:DWORD
local	msg:MSG
local	wc:WNDCLASS
local	Parms:MSGBOXPARAM

ifdef _DEBUG
		mov ecx, pszStr
		.if (!ecx)
			mov ecx, CStr("")
		.endif
		@strace	<"MessageBoxA(", hWnd, ", ", pszStr, " [", &ecx, "], ", pStr2, ", ", flags, ") enter">
endif
		invoke GetModuleHandle, NULL
		mov hInstance, eax
		.if (!g_bInit)
			mov g_bInit, TRUE
			;--- if hxguihlp isn't loaded, we assume we are in text mode
			invoke GetModuleHandle, CStr("HXGUIHLP")
			.if !eax
				invoke TextMessage, pszStr, pStr2, flags
				ret
			.endif
			invoke RtlZeroMemory, addr wc, sizeof WNDCLASS
			mov eax, hInstance
			mov wc.hInstance, eax
			invoke GetStockObject, LTGRAY_BRUSH
			mov wc.hbrBackground, eax
			mov wc.lpszClassName, offset szMsgBoxClass
			mov wc.lpfnWndProc, offset MsgBoxWndProc
			invoke RegisterClassA, addr wc
		.endif
		mov Parms.dwSize, 0
		.if (pszStr)
			mov esi, pszStr
			xor ecx, ecx
			xor ebx, ebx
			xor edx, edx

;--- calc number of lines (ecx) and max line width (ebx)

			.while (byte ptr [esi])
				lodsb
				inc edx
				.if ((al == 10) || (edx >= 80))
					inc ecx
					.if (edx > ebx)
						mov ebx, edx
					.endif
					xor edx, edx
				.elseif (al == 9)
					add edx, 8
				.endif
			.endw
			.if (edx > ebx)
				mov ebx, edx
			.endif
			inc ecx
			mov Parms.dwLines,ecx
			sub esi, pszStr
			mov Parms.dwSize, esi
;--- if the message is larger than 256 bytes, dump it to stderr
			.if (esi > 256)
				invoke GetStdHandle, STD_ERROR_HANDLE
				push 0
				mov edx, esp
				invoke WriteFile, eax, pszStr, Parms.dwSize, edx, 0
				pop ecx
			.endif
		.endif

		mov eax, flags
		mov ecx, pszStr
		xor edx, edx
		mov Parms.dwFlags,eax
		mov Parms.pszText,ecx
		mov Parms.dwExitCode, edx
		and al, 0Fh
		mov edx, offset mbtypes
		mov Parms.pMBType, edx
		mov ecx, ?SIZEMBTYPE
		.while (ecx)
			.if (al == [edx].MBTYPE.bType)
				mov Parms.pMBType, edx
				.break
			.endif
			add edx, sizeof MBTYPE
			dec ecx
		.endw

;--- calc width of window
		
;		mov ecx, Parms.dwSize
		mov ecx, ebx
		.if (ecx < 12)
			mov ecx, 12
		.endif
		add ecx, 4
		shl ecx, 3

		mov edx, Parms.dwLines
		shl edx, 4
		add edx, 40
		invoke CreateWindowEx, 0, addr szMsgBoxClass, pStr2, WS_OVERLAPPED or WS_VISIBLE,\
			CW_USEDEFAULT, CW_USEDEFAULT, ecx, edx, hWnd, 0, hInstance, addr Parms
		.if (eax)
			.while (1)
				invoke GetMessage, addr msg, 0, 0, 0
				.break .if (!eax)
				invoke DispatchMessage, addr msg
			.endw
		.endif
		invoke SetFocus, hWnd
		mov eax, Parms.dwExitCode
endif
		@strace	<"MessageBoxA(", hWnd, ", ", pszStr, ", ", pStr2, ", ", flags, ")=", eax>
		ret
		align 4
MessageBoxA endp

MessageBoxExA proc public hWnd:dword, pStr:dword, pStr2:dword, flags:dword, wLangId:word
		invoke	MessageBoxA, hWnd, pStr, pStr2, flags
ifdef _DEBUG
		movzx ecx, wLangId
		@strace	<"MessageBoxExA(", hWnd, ", ", pStr, ", ", pStr2, ", ", flags, ", ", ecx, ")=", eax>
endif
		ret
		align 4
MessageBoxExA endp

MessageBoxIndirectA proc public lpMsgBoxParams:ptr MSGBOXPARAMSA

		mov ecx, lpMsgBoxParams
		assume ecx:ptr MSGBOXPARAMSA
		invoke MessageBoxA, [ecx].hwndOwner, [ecx].lpszText, [ecx].lpszCaption, [ecx].dwStyle
		@strace	<"MessageBoxIndirectA(", lpMsgBoxParams, ")=", eax>
		assume ecx:nothing
		ret
		align 4

MessageBoxIndirectA endp

		end
