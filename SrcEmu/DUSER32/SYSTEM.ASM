
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
		include macros.inc
		include duser32.inc

		.code


GetSystemMetrics proc public uses ebx edi dwType:dword

		mov eax, dwType
		mov edi, offset smetrics
		mov ecx, NUMSM
		repnz scasd
		.if (ZERO?)
			call dword ptr [edi+NUMSM*4-4]
		.else
			xor eax,eax
		.endif
		@strace	<"GetSystemMetrics(", dwType, ")=", eax>
		ret
		align 4
smetrics label dword
	dd SM_CXSCREEN
	dd SM_CYSCREEN
	dd SM_CXFULLSCREEN
	dd SM_CYFULLSCREEN
	dd SM_CXMAXIMIZED
	dd SM_CYMAXIMIZED
	dd SM_CXCURSOR
	dd SM_CYCURSOR
	dd SM_MOUSEPRESENT
	dd SM_CMOUSEBUTTONS
NUMSM equ ($ - smetrics)/4
slabels label dword    
	dd _screen
	dd _screen
	dd _fullscreen
	dd _fullscreen
	dd _maximized
	dd _maximized
	dd _cursor
	dd _cursor
	dd _mousepresent
	dd _mousebutton
		align 4
_screen:
_fullscreen:
_maximized:
			invoke GetDC, 0
			mov ebx, eax
			mov ecx, dwType
			.if ((ecx == SM_CXSCREEN) || (ecx == SM_CXFULLSCREEN) || (ecx == SM_CXMAXIMIZED))
				invoke GetDeviceCaps, eax, HORZRES
			.else
				invoke GetDeviceCaps, eax, VERTRES
			.endif
			push eax
			invoke ReleaseDC, 0, ebx
			pop eax
		retn
_cursor:
		mov eax, 32
		retn
_mousepresent:
		movzx eax, g_bMouse
		retn
_mousebutton:
		push 0
		invoke GetNumberOfConsoleMouseButtons, esp
		pop ecx
		.if (eax)
			mov eax, ecx
		.endif
		retn
		align 4
GetSystemMetrics endp

SystemParametersInfoA proc public uses edi uiAction:dword, uiParam:dword, pvParam:dword, fWinIni:dword

		mov ecx, spi_tab_size
		mov edi, offset spi_tab
		mov eax, uiAction
		repnz scasd
		jnz failed
		call dword ptr [edi+spi_tab_size*4-4]
		mov eax,1
		jmp done
failed:
		xor eax, eax
done:
		@strace	<"SystemParametersInfoA(", uiAction, ", ", uiParam, ", ", pvParam, ", ", fWinIni, ")=", eax, " *** unsupp">
		ret
screensaveactive:
		mov ecx,pvParam
		mov dword ptr [ecx],0
		retn
getworkarea:
		mov edi,pvParam
		mov [edi].RECT.left,0
		invoke GetSystemMetrics, SM_CXSCREEN
		mov [edi].RECT.right, eax
		mov [edi].RECT.top,0
		invoke GetSystemMetrics, SM_CYSCREEN
		mov [edi].RECT.bottom, eax
		retn

		align 4

spi_tab label dword
		dd SPI_GETSCREENSAVEACTIVE
		dd SPI_GETWORKAREA
spi_tab_size equ ($ - spi_tab) / 4
		dd screensaveactive
		dd getworkarea

SystemParametersInfoA endp

SystemParametersInfoW proc public uiAction:dword, uiParam:dword, pvParam:dword, fWinIni:dword
		invoke SystemParametersInfoA, uiAction, uiParam, pvParam, fWinIni
		ret
		align 4
SystemParametersInfoW endp

GetDoubleClickTime proc public
		mov eax, 400
		@strace	<"GetDoubleClickTime()=", eax>
		ret
		align 4
GetDoubleClickTime endp

		end
