
;--- run a GUI Win32 app with HX

;--- HXGUIHLP.DLL is loaded by DPMILD32 automatically if 
;--- it detects a Win32 GUI app to be loaded. This gives
;--- HXGUIHLP a chance to set up an appropriate environment.
;--- this is:
;--- 1. set an initial graphics mode (optional)
;--- 2. load some fonts (optional)
;--- 3. pass some parameters from its .INI file to VESA32.DLL
;--- 4. set a Ctrl-Break handler routine

	.386
	.Model flat,stdcall
	option casemap:none

	include winbase.inc
	include wincon.inc
	include winuser.inc
	include wingdi.inc
	include vesa32.inc
	include macros.inc
	include dpmi.inc

?USEVALLOC	equ 0	;1=use VirtualAlloc, 0=use LocalAlloc
?LOGSTDERR	equ 1	;1=log output to stderr to a file

SAVESTATE	struct
dwMode		DWORD ?
dwVState	DWORD ?
dwVMemory	DWORD ?
SAVESTATE	ends

	.data

g_hVesa		DWORD 0
g_hWnd		DWORD 0
g_dwWidth	DWORD 640
g_dwHeight	DWORD 480
g_dwXMax	DWORD -1
g_dwYMax	DWORD -1
g_dwBpp 	DWORD 8
g_dwMode	DWORD -1
g_hwndHlp	DWORD 0
if ?LOGSTDERR
g_hStdErr	DWORD -1
g_hStdErrOld DWORD -1
endif

g_bWait 	DWORD 0
g_bSave 	DWORD 0
g_bClear	DWORD 0
g_fMenu 	DWORD 1

g_savestate	SAVESTATE <-1,0,0>
g_Vesa32Options VESA32OPTIONS <sizeof VESA32OPTIONS, 0, 0>

g_dwFileIdx	DWORD 0
g_bMode		BYTE 3
g_bCtrl		BYTE -1

	.data?

szIni		db MAX_PATH dup (?)
if ?LOGSTDERR
szStdErr	db MAX_PATH dup (?)
endif

lp		LOGPALETTE {}
		PALETTEENTRY 255 dup (<?>)

	.const

szName	  db "hxguihlp.ini",0
szDisplay db "display",0
szOptions db "options",0
szHxGuiHlpClass db "hxguihlpwndcls",0

fonts label dword
	dd CStr("boot"), CStr("oemfonts.fon")
	dd CStr("boot"), CStr("fixedfon.fon")
	dd CStr("boot"), CStr("fonts.fon")
	dd 0

dispres label dword

;------------0----5----0----5----0----5----0
dwFormat dd 00000000000000000011111111000000b 

options label dword
	dd offset szDisplay, CStr("xres"), offset g_dwWidth
	dd offset szDisplay, CStr("yres"), offset g_dwHeight
	dd offset szDisplay, CStr("bpp") , offset g_dwBpp
	dd offset szDisplay, CStr("xmax"), offset g_dwXMax 
	dd offset szDisplay, CStr("ymax"), offset g_dwYMax	
	dd offset szDisplay, CStr("mode"), offset g_dwMode

	dd offset szOptions, CStr("wait"), offset g_bWait
	dd offset szOptions, CStr("save"), offset g_bSave
	dd offset szOptions, CStr("menu"), offset g_fMenu
	dd offset szOptions, CStr("clear"), offset g_bClear
	dd offset szOptions, CStr("NoVsyncWait"), offset g_Vesa32Options.bNoVSyncWait
	dd offset szOptions, CStr("UsePMTab"), offset g_Vesa32Options.bUsePMTable
	dd offset szOptions, CStr("FlipStatus"), offset g_Vesa32Options.bFlipStatus
	dd offset szOptions, CStr("DirectDACAccess"), offset g_Vesa32Options.bHandleDAC
	dd 0

	include hxguihlp.inc

	.code

printf	proto c :ptr byte, :VARARG
sprintf	proto c :ptr byte, :ptr byte, :VARARG
atol	proto c :ptr byte

;--- get an entry from hxguihlp.ini
;--- not used currently

GetProfileString proc public pszSection:ptr BYTE, pszKey:ptr BYTE, pszBuffer:ptr BYTE, cbLen:DWORD

	invoke GetPrivateProfileString, pszSection, pszKey, CStr(""),\
		pszBuffer, cbLen, addr szIni
	ret
GetProfileString endp

;--- enumerate VESA video modes callback
;--- searches for the best suited video mode 

mycb proc vmode:dword, psvga:ptr SVGAINFO, parmx:dword

	mov ecx, psvga
	movzx eax, [ecx].SVGAINFO.XResolution
	movzx edx, [ecx].SVGAINFO.YResolution
	test [ecx].SVGAINFO.ModeAttributes, VESAATTR_LFB_SUPPORTED
	jz @F
	.if ((eax == g_dwWidth) && (edx == g_dwHeight))
		movzx eax, [ecx].SVGAINFO.BitsPerPixel
		.if ((eax == g_dwBpp) || (!g_dwBpp))
			mov eax, vmode
			ret
		.endif
	.endif
@@:
	xor eax, eax
	ret
mycb endp

;--- save the current video state to be able to restore it later

_SaveVideoState proc uses ebx pSaveState:ptr SAVESTATE

	@strace <"HXGUIHLP::SaveVideoState enter">
	mov ebx, pSaveState
	invoke GetVesaStateBufferSize
	.if (eax)
		push eax
		invoke LocalAlloc, LMEM_FIXED, eax
		pop ecx
		mov [ebx].SAVESTATE.dwVState, eax
		.if (eax)
			invoke SaveVesaVideoState, eax, ecx
		.endif
		invoke GetVesaMode
		mov [ebx].SAVESTATE.dwMode, eax
		invoke GetVesaMemoryBufferSize, eax
		push eax
if ?USEVALLOC
		invoke VirtualAlloc, 0, eax, MEM_COMMIT, PAGE_READWRITE
else
		invoke LocalAlloc, LMEM_FIXED, eax
endif
		pop ecx
		mov [ebx].SAVESTATE.dwVMemory, eax
		.if (eax)
			invoke SaveVesaVideoMemory, eax, ecx
		.endif
	.endif
	@strace <"HXGUIHLP::SaveVideoState exit: mode=", [ebx].SAVESTATE.dwMode, ", pState=", [ebx].SAVESTATE.dwVState, ", pVMem=", [ebx].SAVESTATE.dwVMemory>
	ret
_SaveVideoState endp

;--- load a saved video state
;--- used when opening a DOS shell or when terminating

_LoadVideoState proc uses ebx pSaveState:ptr SAVESTATE, bFree:DWORD

	@strace <"HXGUIHLP::LoadVideoState enter">
	mov ebx, pSaveState
	mov ecx, [ebx].SAVESTATE.dwMode
	or ch,80h						;preserve video memory on mode change
	invoke SetVesaMode, ecx
	mov ecx, [ebx].SAVESTATE.dwVState
	.if (ecx)
		invoke RestoreVesaVideoState, ecx
		.if (bFree)
			invoke LocalFree, [ebx].SAVESTATE.dwVState
			mov [ebx].SAVESTATE.dwVState, 0
		.endif
	.endif
	mov ecx, [ebx].SAVESTATE.dwVMemory
	.if (ecx)
		invoke RestoreVesaVideoMemory, ecx
		.if (bFree)
if ?USEVALLOC
			invoke VirtualFree, [ebx].SAVESTATE.dwVMemory, 0, MEM_RELEASE
else
			invoke LocalFree, [ebx].SAVESTATE.dwVMemory
endif
			mov [ebx].SAVESTATE.dwVMemory, 0
		.endif
	.endif
	@strace <"HXGUIHLP::LoadVideoState exit">
	ret
_LoadVideoState endp

;--- save bits of a hdc in a compatible bitmap

SaveBits proc hdc:dword, dwX:dword, dwY:dword, nX:dword, nY:dword, hBM:dword

local	compDC:dword
local	compBM:dword
local	hPalPrev:DWORD
local	pe[255]:PALETTEENTRY
local	LogPal:LOGPALETTE

	invoke CreateCompatibleDC, hdc
	.if (eax)
		mov compBM, 0
		mov compDC, eax
		mov eax, hBM
		.if (!eax)
			invoke CreateCompatibleBitmap, hdc, nX, nY
			mov compBM, eax
		.endif
		.if (eax)
			invoke SelectObject, compDC, eax	;select bitmap into DC
			.if (hBM)
				invoke BitBlt, hdc, dwX, dwY, nX, nY, compDC, 0, 0, SRCCOPY
			.else
				invoke BitBlt, compDC, 0, 0, nX, nY, hdc, dwX, dwY, SRCCOPY
			.endif
		.endif
		invoke DeleteDC, compDC
		mov eax, compBM
	.endif
	ret
SaveBits endp

;--- save content of a DC into a file

SaveDCtoFile proc uses ebx hdc:DWORD, lpRect:ptr RECT, bUsePalette:dword

local	dwHeight:DWORD
local	dwWidth:DWORD
local	dwSize:DWORD
local	dwSizeClr:DWORD
local	dwWritten:DWORD
local	hPal:DWORD
local	dwOldUse:DWORD
local	dwOldPal:DWORD
local	hFile:DWORD
local	lpBits:DWORD
local	szTempPath[MAX_PATH]:byte
local	szTempName[MAX_PATH]:byte
local	rgbquad[255]:RGBQUAD
local	bmi:BITMAPINFO
local	bmfh:BITMAPFILEHEADER

	invoke GetTempPath, MAX_PATH, addr szTempPath
	.while (1)
		inc g_dwFileIdx
		invoke sprintf, addr szTempName, CStr("%s~hx%u.BMP"), addr szTempPath, g_dwFileIdx
		invoke CreateFile, addr szTempName, GENERIC_WRITE, 0, 0, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0
		.break .if (eax != -1)
		invoke GetLastError
		.if (eax != ERROR_FILE_EXISTS)
			jmp exit
		.endif
	.endw
	mov hFile, eax

	.if (bUsePalette)
		invoke SetSystemPaletteUse, hdc, SYSPAL_NOSTATIC256
		mov dwOldUse, eax
		mov lp.palVersion, 0300h
		mov lp.palNumEntries, 256
		invoke CreatePalette, addr lp
		mov hPal, eax
		.if (eax)
			invoke SelectPalette, hdc, eax, 0
			mov dwOldPal, eax
		.endif
	.endif

	.if (lpRect)
		mov ecx, lpRect
		mov eax, [ecx].RECT.right
		sub eax, [ecx].RECT.left
		mov edx, [ecx].RECT.bottom
		sub edx, [ecx].RECT.top
		mov dwWidth, eax
		mov dwHeight, edx
		invoke SaveBits, hdc, [ecx].RECT.left, [ecx].RECT.top, eax, edx, 0
	.else
		invoke GetDeviceCaps, hdc, HORZRES
		mov dwWidth, eax
		push eax
		invoke GetDeviceCaps, hdc, VERTRES
		mov dwHeight, eax
		pop edx
		invoke SaveBits, hdc, 0, 0, edx, eax, 0
	.endif

	push eax
	.if (bUsePalette)
		.if (hPal)
			invoke SelectPalette, hdc, dwOldPal, 0
			invoke DeleteObject, hPal
		.endif
		invoke SetSystemPaletteUse, hdc, dwOldUse
	.endif
	pop eax

	.if (eax)
		mov ebx, eax	;save bitmap handle in ebx
;---
		invoke RtlZeroMemory, addr bmfh, sizeof BITMAPFILEHEADER
		invoke RtlZeroMemory, addr bmi.bmiHeader, sizeof BITMAPINFOHEADER
		mov bmi.bmiHeader.biSize,sizeof BITMAPINFOHEADER

;--- call GetDIBits with lpvBits=0 and biBitCount=0, this will
;--- cause GetDIBits to fill the BITMAPINFOHEADER

		invoke GetDIBits, hdc, ebx, 0, 0, 0, addr bmi, DIB_RGB_COLORS

		mov eax,dwWidth
		mov bmi.bmiHeader.biWidth,eax
		mov eax,dwHeight
		and eax, eax
		jns @F
		neg eax
@@:
		mov bmi.bmiHeader.biHeight,eax

;--- now this call with biBitCount filled should copy the color table
;--- the return value is not quite clear (win9x returns 0 on success!)

		invoke RtlZeroMemory, addr rgbquad, sizeof rgbquad
		invoke GetDIBits, hdc, ebx, 0, dwHeight, 0, addr bmi, DIB_RGB_COLORS
		.if (eax)
			mov eax, bmi.bmiHeader.biHeight
			and eax, eax
			jns @F
			neg eax
			mov bmi.bmiHeader.biHeight, eax
@@:
			mul bmi.bmiHeader.biWidth
			movzx ecx, bmi.bmiHeader.biBitCount
			mul ecx
			shr eax, 3
			mov dwSize, eax

			mov bmfh.bfType, "MB"
			.if (bmi.bmiHeader.biBitCount == 8)
				mov eax, sizeof RGBQUAD * 256
			.elseif (bmi.bmiHeader.biCompression == BI_BITFIELDS)
				mov eax, sizeof DWORD * 3
			.else
				xor eax, eax
			.endif
			mov dwSizeClr, eax

			lea eax, [eax + sizeof BITMAPFILEHEADER + sizeof BITMAPINFOHEADER]
			mov bmfh.bfOffBits, eax
			add eax, dwSize
			mov bmfh.bfSize, eax
			invoke WriteFile, hFile, addr bmfh, sizeof BITMAPFILEHEADER, addr dwWritten, 0

			invoke WriteFile, hFile, addr bmi.bmiHeader, sizeof BITMAPINFOHEADER, addr dwWritten, 0
			.if (dwSizeClr)
				invoke WriteFile, hFile, addr bmi.bmiColors, dwSizeClr, addr dwWritten, 0
			.endif
			invoke LocalAlloc, LMEM_FIXED, dwSize
			.if (eax)
				mov lpBits, eax
				invoke GetDIBits, hdc, ebx, 0, dwHeight, lpBits, addr bmi, DIB_RGB_COLORS
				invoke WriteFile, hFile, lpBits, dwSize, addr dwWritten, 0
				invoke LocalFree, lpBits
			.endif
		.endif

		invoke DeleteObject, ebx
	.endif
	invoke CloseHandle, hFile
exit:
	ret
SaveDCtoFile endp

;--- start a DOS shell

StartShell proc

local	bSoundPaused:BYTE
local	sinfo:STARTUPINFOA
local	pi:PROCESS_INFORMATION
local	savestate:SAVESTATE
local	szPath[MAX_PATH]:byte

	@strace <"HXGUIHlp StartShell enter">
	invoke GetEnvironmentVariableA, CStr("COMSPEC"), addr szPath, sizeof szPath
	.if (eax)
		mov bSoundPaused, 0
		invoke GetModuleHandle, CStr("WINMM")
		.if (eax)
			invoke GetProcAddress, eax, CStr("SBPause")
			.if (eax)
				call eax
				.if (eax)
					mov bSoundPaused, 1
				.endif
			.endif
		.endif
		.if (g_hStdErr != -1)
			invoke FlushFileBuffers, g_hStdErr
		.endif
		invoke VesaMouseExit
		.if (g_bSave)
			invoke _SaveVideoState, addr savestate
			invoke _LoadVideoState, addr g_savestate, 1
		.else
			mov ah,0
			mov al,g_bMode
			int 10h
		.endif
		invoke RtlZeroMemory, addr sinfo, sizeof STARTUPINFOA
		mov sinfo.cb, sizeof STARTUPINFOA
		invoke CreateProcess, NULL, addr szPath, 0, 0, 0, 0, 0, 0, addr sinfo, addr pi 
		.if (eax)
			invoke CloseHandle, pi.hThread
			invoke CloseHandle, pi.hProcess
		.endif
		.if (g_bSave)
			invoke _SaveVideoState, addr g_savestate
			invoke _LoadVideoState, addr savestate, 1
		.else
			invoke SetVesaMode, g_dwMode
			invoke GetActiveWindow
			.if (eax)
				invoke InvalidateRect, eax, 0, 1
			.endif
		.endif
		invoke VesaMouseInit
		.if (bSoundPaused)
			invoke GetModuleHandle, CStr("WINMM")
			.if (eax)
				invoke GetProcAddress, eax, CStr("SBReinitSound")
				.if (eax)
					call eax
				.endif
			.endif
		.endif
	.endif
	@strace <"HXGUIHlp StartShell exit">
	ret
StartShell endp

;--- show the hxguihlp menu (when APPS or Ctrl-Break has been pressed)

ShowMenu proc uses ebx esi edi

local	hBM:dword
local	bPalette:dword
local	dwRead:Dword
local	rect:RECT
local	nX:dword
local	nY:dword
local	dwXPos:dword
local	dwYPos:dword
local	dwXSize:dword
local	dwYSize:dword
local	hPal:dword
local	hPalOld:dword
local	lpfnSetKbdHdlr:DWORD
local	dwOldHandler:DWORD
local	dwCookie:DWORD
local	hFontOld:dword
local	ir:INPUT_RECORD
local	bSysPalUse:DWORD
local	tm:TEXTMETRICA

	@strace <"HXGUIHlp ShowMenu enter">

	mov lpfnSetKbdHdlr, 0
	inc g_bCtrl
	jnz exit
	invoke GetModuleHandle, CStr("KERNEL32")
	.if (eax)
		invoke GetProcAddress, eax, CStr("_SetKbdEventHandler")
		.if (eax)
			mov lpfnSetKbdHdlr, eax
			push 0
			push 0
			call eax
			mov dwOldHandler, eax
			mov dwCookie, edx
		.endif
	.endif

	invoke CreateDCA, CStr("DISPLAY"),0,0,0
	mov esi, eax

	invoke GetDeviceCaps, esi, HORZRES
	mov nX, eax
	invoke GetDeviceCaps, esi, VERTRES
	mov nY, eax

	invoke GetStockObject, OEM_FIXED_FONT
	invoke SelectObject, esi, eax
	mov hFontOld, eax
	invoke GetTextMetricsA, esi, addr tm

	invoke GetDeviceCaps, esi, RASTERCAPS
	.if (eax & RC_PALETTE)
		mov bPalette, 1
		invoke GetSystemPaletteEntries, esi, 0, 256, addr lp.palPalEntry
		invoke SetSystemPaletteUse, esi, SYSPAL_NOSTATIC256
		mov lp.palVersion, 0300h
		mov lp.palNumEntries, 256
		invoke CreatePalette, addr lp
		mov hPal, eax
		.if (eax)
			invoke SelectPalette, esi, eax, 0
			mov hPalOld, eax
			invoke RealizePalette, esi
		.endif
	.else
		mov bPalette, 0
	.endif

	mov eax, tm.tmAveCharWidth
	mov ecx, MSG1LINESIZE
	mul ecx
if 0
	add eax,8	;add a small buffer
endif
	mov dwXSize, eax

	mov ecx, nX
	sub ecx, eax
	shr ecx, 1
	mov dwXPos, ecx

	mov eax, tm.tmHeight
	mov ecx, MSG1LINES
	mul ecx
	mov dwYSize, eax

	mov ecx, nY
	sub ecx, eax
	shr ecx, 1
	mov dwYPos, ecx

	invoke SaveBits, esi, dwXPos, dwYPos, dwXSize, dwYSize, 0
	mov hBM, eax

	mov ecx, MSG1LINES
	mov edi, offset msg1a
	mov edx, dwYPos
	.while (ecx)
		push ecx
		push edx
		invoke TextOutA, esi, dwXPos, edx, edi, MSG1LINESIZE
		pop edx
		pop ecx
		add edx, tm.tmHeight
		add edi, MSG1LINESIZE
		dec ecx
	.endw
	invoke SelectObject, esi, hFontOld

	invoke GetStdHandle, STD_INPUT_HANDLE
	mov ebx, eax
waitkey:
	invoke ReadConsoleInput, ebx, addr ir, 1, addr dwRead
	cmp ir.EventType, KEY_EVENT
	jnz waitkey
	cmp ir.Event.KeyEvent.bKeyDown,0
	jnz waitkey
	mov ax, ir.Event.KeyEvent.wVirtualKeyCode
	mov edi, offset actions
	mov ecx, NUMACTIONS
	repnz scasb
	jnz waitkey
	call restorescreen
	sub edi, offset actions + 1
	jmp [edi*4+offset cmds]

actions label byte
	db VK_ESCAPE
	db VK_APPS
	db VK_F3
	db VK_F4
	db VK_F5
	db VK_F6
	db VK_F9
	db VK_F12
NUMACTIONS equ $ - actions

cmds label dword
	dd doescape
	dd doapps
	dd dof3
	dd dof4
	dd dof5
	dd dof6
	dd dof9
	dd dof12

doescape:
	jmp exit
doapps:
	test g_fMenu,1
	jz waitkey
	jmp exit
dof3:
	invoke GetActiveWindow
	.if (eax)
		mov g_bWait, 0
		invoke PostMessage, eax, WM_SYSCOMMAND, SC_MAXIMIZE, 0
	.endif
	jmp exit
dof4:
	invoke GetActiveWindow
	.if (eax)
		mov g_bWait, 0
		invoke PostMessage, eax, WM_SYSCOMMAND, SC_CLOSE, 0
	.endif
	jmp exit
dof5:
	invoke SaveDCtoFile, esi, 0, bPalette
	jmp exit
dof6:
	invoke GetActiveWindow
	.if (eax)
		mov edi, eax
		invoke GetWindowRect, edi, addr rect
		invoke SaveDCtoFile, esi, addr rect, bPalette
	.endif
	jmp exit
dof9:
	invoke StartShell
	jmp exit
dof12:
	call clearresources
	mov g_bWait, 0
	invoke ExitProcess, -1

exit:
	call clearresources

	.if (lpfnSetKbdHdlr)
		push dwCookie
		push dwOldHandler
		call lpfnSetKbdHdlr
	.endif
	dec g_bCtrl
	@mov eax, 1
	@strace <"HXGUIHlp ShowMenu exit">
	ret
restorescreen:
	.if (hBM)
		invoke SaveBits, esi, dwXPos, dwYPos, dwXSize, dwYSize, hBM
		invoke DeleteObject, hBM
	.endif
	retn
clearresources:
	.if (bPalette && hPal)
		invoke DeleteObject, hPal
	.endif
	invoke DeleteDC, esi
	retn
ShowMenu endp

;--- test if al contains a valid hex digit

IsHexDigit proc
	or al,20h
	cmp al,'0'
	jb nohex
	sub al,'0'
	cmp al,9
	jbe ishex
	sub al,27h
	jb nohex
	cmp al,0Fh
	jbe ishex
nohex:
	stc
	ret
ishex:
	clc
	ret
IsHexDigit endp

;--- translate a string into a number

gethex proc uses esi pszText:ptr byte
	xor edx, edx
	xor eax, eax
	mov esi, pszText
	.while (byte ptr [esi])
		lodsb
		call IsHexDigit
		jc done
		shl edx, 4
		or dl,al
	.endw
done:
	mov eax, edx
	ret
gethex endp

;--- show menu when Ctrl-Break has been pressed

ctrlproc proc event:dword
	invoke ShowMenu
	ret
ctrlproc endp

;--- show menu when APPS has been pressed

wndproc proc hwnd:DWORD, msg:DWORD, wParam:DWORD, lParam:DWORD

	.if (msg == WM_HOTKEY)

		invoke GetCurrentThread
		push eax
		invoke GetThreadPriority, eax
		push eax
		mov ecx, [esp+4]
		invoke SetThreadPriority, ecx, THREAD_PRIORITY_TIME_CRITICAL * 2
		invoke ShowMenu
		pop eax
		pop ecx
		invoke SetThreadPriority, ecx, eax
	.else
		invoke DefWindowProc, hwnd, msg, wParam, lParam
	.endif
	ret
wndproc endp

;--- register a window class and create a window
;--- to get WM_HOTKEY messages

CreateHelperWindow proc

local	wc:WNDCLASS

	invoke RtlZeroMemory, addr wc, sizeof WNDCLASS
	invoke GetModuleHandle, NULL
	mov wc.hInstance, eax
	mov wc.lpszClassName, offset szHxGuiHlpClass
	mov wc.lpfnWndProc, offset wndproc
	invoke RegisterClass, addr wc
	.if (eax)
		invoke CreateWindowEx, 0, addr szHxGuiHlpClass, CStr(""), WS_POPUP,\
			0, 0, 0, 0, 0, 0, wc.hInstance, 0
		mov g_hWnd, eax
	.endif
	ret
CreateHelperWindow endp

;--- dll init. scan hxguihlp.ini and do all the initialisation

Init proc uses esi ebx

local	dwSize:DWORD
local	bOption:BYTE
local	rect:RECT
local	devmode:DEVMODEA
local	szFont[MAX_PATH]:byte

;--- set default values

	@strace <"HXGUIHlp Init enter">
	invoke GetStdHandle, STD_INPUT_HANDLE
	invoke SetConsoleMode, eax, ENABLE_MOUSE_INPUT
	invoke VesaMouseInit

	invoke lstrcpy, addr szIni, addr szName
	invoke _lopen, addr szIni, OF_READ
	.if (eax == -1)
		invoke GetModuleHandle, CStr("hxguihlp")
		mov ecx, eax
		invoke GetModuleFileNameA, ecx, addr szIni, sizeof szIni
		lea ecx, szIni
		.while (eax)
			.break .if (byte ptr [ecx+eax-1] == '\')
			dec eax
		.endw
		add ecx, eax
		invoke lstrcpy, ecx, addr szName
	.else
		invoke CloseHandle, eax
	.endif

	mov esi, offset options
	xor ebx, ebx
	.while (dword ptr [esi])
		lodsd
		mov ecx, eax
		lodsd
		mov edx, eax
		invoke GetPrivateProfileString, ecx, edx, CStr(""),\
			addr szFont, sizeof szFont, addr szIni
		.if (eax)
			.if (word ptr szFont == "x0")
				invoke gethex, addr szFont+2
			.else
				invoke atol, addr szFont
			.endif
			mov ecx, [esi]
			bt [dwFormat], ebx
			.if (CARRY?)
				mov [ecx], al
			.else
				mov [ecx], eax
			.endif
		.endif
		add esi, 4
	.endw

if ?LOGSTDERR
	invoke GetPrivateProfileString, offset szOptions, CStr("stderr"), CStr(""),\
			addr szFont, sizeof szFont, addr szIni
	.if (eax)
		invoke ExpandEnvironmentStringsA, addr szFont, addr szStdErr, sizeof szStdErr
		invoke CreateFile, addr szStdErr, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
		.if (eax != -1)
			mov g_hStdErr, eax
			invoke GetStdHandle, STD_ERROR_HANDLE
			mov g_hStdErrOld, eax
			invoke SetStdHandle, STD_ERROR_HANDLE, g_hStdErr
		.endif
	.else
		invoke GetStdHandle, STD_OUTPUT_HANDLE
		push eax
		invoke GetFileType, eax
		pop ecx
		.if (eax == FILE_TYPE_DISK)
			invoke SetStdHandle, STD_ERROR_HANDLE, ecx
		.endif
	.endif
endif

	.if ((g_dwXMax != -1) || (g_dwYMax != -1))
		invoke SetMaxVideoResolution, g_dwXMax, g_dwYMax, -1
	.endif
	invoke SetVesa32Options, addr g_Vesa32Options

	mov eax, g_dwMode
	.if (eax == -1)
		.if ((!g_dwWidth) || (!g_dwHeight))
			jmp noreschange
		.endif
		invoke EnumVesaModes, offset mycb, 0
		.if (!eax)
			.if (g_dwBpp)
				invoke printf, CStr(<"video mode %ux%ux%u with LFB not supported",10>), g_dwWidth, g_dwHeight, g_dwBpp
			.else
				invoke printf, CStr(<"video mode %ux%u with LFB not supported",10>), g_dwWidth, g_dwHeight
			.endif
			mov g_dwHeight, 0
			invoke ExitProcess, -1
		.endif
	.endif

	or ah,40h		;use LFB
	mov g_dwMode, eax
	mov esi, eax
 
	.if (g_bSave) 
		invoke _SaveVideoState, addr g_savestate
	.else
		mov ah,0Fh
		int 10h
		mov g_bMode, al
	.endif

	invoke SetVesaMode, esi
	.if (!eax)
		invoke printf, CStr(<"setting video mode %X failed",10>), esi
		invoke ExitProcess, -1
	.endif
if 0
	invoke GetModuleHandle, CStr("USER32")
	.if (eax)
		invoke GetProcAddress, eax, CStr("_ClearDCCache")
		.if (eax)
			call eax
		.endif
	.endif
	invoke GetModuleHandle, CStr("GDI32")
	.if (eax)
		invoke GetProcAddress, eax, CStr("_ClearFontStock")
		.if (eax)
			call eax
		.endif
	.endif
endif
noreschange:

	invoke LoadCursor, NULL, IDC_ARROW
	.if (eax)
		invoke SetCursor, eax
	.endif

	mov esi, offset fonts
	.while (dword ptr [esi])
		lodsd
		mov edx, eax
		lodsd
		mov ecx, eax
		invoke GetPrivateProfileString, edx, ecx, CStr(""),\
			addr szFont, sizeof szFont, addr szIni
		.if (eax)
			invoke AddFontResourceA, addr szFont
		.endif
	.endw
if 1        
;--- load additional fonts in [fonts] 
	sub esp,256
	mov esi, esp
	invoke GetPrivateProfileString, CStr("fonts"), 0, CStr(""),\
		esi, 256, addr szIni
	.if (eax)
		.while (byte ptr [esi])
			invoke GetPrivateProfileString, CStr("fonts"), esi, CStr(""),\
				addr szFont, sizeof szFont, addr szIni
			.if (eax)
				invoke AddFontResourceA, addr szFont
			.endif
			invoke lstrlen, esi
			lea esi, [esi+eax+1]
		.endw
	.endif
	add esp,256
endif

	.if (g_bClear)
		invoke GetDC, 0
		mov esi, eax
		mov rect.left, 0
		mov rect.top, 0
		invoke GetSystemMetrics, SM_CXSCREEN
		mov rect.right, eax
		invoke GetSystemMetrics, SM_CYSCREEN
		mov rect.bottom, eax
		invoke GetStockObject, DKGRAY_BRUSH
		invoke FillRect, esi, addr rect, eax
		invoke ReleaseDC, 0, esi
	.endif

	.if (g_fMenu & 1)
		invoke CreateHelperWindow
		.if (eax)
			mov g_hwndHlp, eax
			invoke RegisterHotKey, eax, 500h, 0, VK_APPS
		.endif
	.endif
	.if (g_fMenu & 2)
		invoke SetConsoleCtrlHandler, offset ctrlproc, 1
	.endif
exit:
	@strace <"HXGUIHlp Init exit">
	ret

Init endp

;--- hxguihlp dll is unloading. cleanup things

Deinit proc uses ebx esi edi

local	dwMode:dword
local	dwEsp:dword

	@strace <"HXGUIHlp Deinit enter">
if 1
	invoke VesaMouseExit
	invoke GetStdHandle, STD_INPUT_HANDLE
	mov esi, eax
	invoke GetConsoleMode, esi, addr dwMode
	and dwMode, not ENABLE_MOUSE_INPUT
	invoke SetConsoleMode, esi, dwMode
endif
	xor ecx, ecx
	xchg ecx, g_hwndHlp
	jecxz @F
	invoke DestroyWindow, ecx
@@:

	.if ((g_dwWidth) && (g_dwHeight))
		.if (g_bWait)
@@:
			mov ah,00
			int 16h
			cmp al,13
			jnz @B
		.endif
		.if (g_savestate.dwMode != -1)
			invoke _LoadVideoState, addr g_savestate, 1
		.else
			mov al, g_bMode
			mov ah, 0
			int 10h
		.endif
	.endif
if ?LOGSTDERR
	.if (g_hStdErr != -1)
		invoke GetFileSize, g_hStdErr, NULL
		mov ebx, eax
		invoke SetStdHandle, STD_ERROR_HANDLE, g_hStdErrOld
		invoke CloseHandle, g_hStdErr
		.if ((!ebx) || (ebx == -1))
			invoke DeleteFile, addr szStdErr
		.else
			invoke CreateFile, addr szStdErr, GENERIC_READ, 0, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
			mov esi, eax
			.if (eax != -1)
				mov dwEsp,esp
				.if (ebx < 12*80)
					mov eax, ebx
					add eax, 4
					and al,0FCh
					sub esp, eax
					mov edi, esp
					invoke ReadFile, esi, edi, ebx, addr dwMode, 0
				.else
					sub esp, 256+32
					mov edi, esp
					invoke sprintf, edi, CStr(<"errors logged in %s!",13,10>), addr szStdErr
				.endif
				invoke CloseHandle, esi
				invoke GetStdHandle, STD_OUTPUT_HANDLE
				mov esi, eax
				invoke lstrlen, edi
				lea ecx, dwMode
				invoke WriteConsole, esi, edi, eax, ecx, 0
				mov esp, dwEsp
			.endif
		.endif
	.endif
endif
	@strace <"HXGUIHlp Deinit exit">
	ret

Deinit endp

externdef c _ioinit:near
;--- dll entry

DllMain proc public handle:dword,reason:dword, dwReserved:dword

	.if (reason == DLL_PROCESS_ATTACH)
		call _ioinit	;added v2.18, 16.2.2020
		invoke Init
		@mov eax,1
	.elseif (reason == DLL_PROCESS_DETACH)
		invoke Deinit
	.endif
	ret
DllMain endp

	end DllMain

