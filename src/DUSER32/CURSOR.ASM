
;--- cursor functions:
;--- ClipCursor
;--- CreateCursor
;--- DestroyCursor
;--- GetCursor
;--- GetCursorPos
;--- LoadCursorA
;--- LoadCursorW
;--- SetCursor
;--- SetCursorPos
;--- ShowCursor
;--- best viewed with tabsize 4

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
	include winuser.inc
	include wingdi.inc
	include duser32.inc
	include macros.inc
	include dpmi.inc

	.DATA

g_hCurrCursor	HANDLE 0	;current cursor handle
g_cntMouse		SDWORD -1	;cursor count maintained by ShowCursor()
g_bMouse		db 0		;1=mouse driver is installed
g_bInit			db 0		;1=initialised

externdef g_hInstance:HINSTANCE

	.CODE

CreateCursor proc public uses ebx hInst:DWORD, xHotSpot:DWORD, yHotSpot:DWORD,
			nWidth:DWORD, nHeight:DWORD, pvANDPlane:ptr, pvXORPlane:ptr

local	dwSize:DWORD

	mov eax, nWidth
	mul nHeight
	shr eax, 3
	mov dwSize, eax
	shl eax, 1
	add eax, sizeof LOCALHEADER + sizeof BITMAPINFOHEADER + 2*4
	invoke malloc2, eax
	.if (eax)
		mov ebx, eax
		mov ecx, xHotSpot
		mov [ebx].LOCALHEADER.xHotSpot, cx
		mov ecx, yHotSpot
		mov [ebx].LOCALHEADER.yHotSpot, cx
		add ebx, sizeof LOCALHEADER
		mov [ebx].BITMAPINFOHEADER.biSize, sizeof BITMAPINFOHEADER
		mov [ebx].BITMAPINFOHEADER.biBitCount, 1
		mov ecx, nWidth
		mov [ebx].BITMAPINFOHEADER.biWidth, ecx
		mov ecx, nHeight
		shl ecx, 1
		neg ecx
		mov [ebx].BITMAPINFOHEADER.biHeight, ecx
		mov [ebx].BITMAPINFOHEADER.biCompression, BI_RGB
		mov [ebx].BITMAPINFOHEADER.biClrUsed, 0
		mov dword ptr [ebx+sizeof BITMAPINFOHEADER+0], 0
		mov dword ptr [ebx+sizeof BITMAPINFOHEADER+4], 0FFFFFFh
		pushad
		lea edi, [ebx+sizeof BITMAPINFOHEADER+2*4]
		mov esi, pvANDPlane
		mov ecx, dwSize
		rep movsb
		mov esi, pvXORPlane
		mov ecx, dwSize
		rep movsb
		popad
	.endif
	@strace <"CreateCursor(", hInst, ", ", xHotSpot, ", ", yHotSpot, ", ", nWidth, ", ", nHeight, ", ", pvANDPlane, ", ", pvXORPlane, ")=", eax>
	ret
	align 4
CreateCursor endp

DestroyCursor proc public hCursor:HANDLE
	invoke free, hCursor
	@strace <"DestroyCursor(", hCursor, ")=", eax>
	ret
	align 4
DestroyCursor endp

if ?FLAT

LoadCursorA proc public uses ebx hInstance:HINSTANCE, lpCursorName:ptr BYTE

	mov ebx, lpCursorName
	.if (!hInstance)
		mov ecx, g_hInstance
		mov hInstance, ecx
		test ebx, 0FFFF0000h
		.if (ZERO?)
			.if (ebx <= 32516)
				sub ebx, 32512 - 100;512-516 -> 100-104
			.elseif (ebx < 32642)	;IDC_SIZE + IDC_ICON obsolete
			.elseif (ebx <= 32646)	;642-646 -> 105-109
				sub ebx, 32642 - 105
			.else
				sub ebx, 32648 - 110;648-xxx -> 110-xxx
			.endif
		.endif
	.endif
	invoke FindResource, hInstance, ebx, RT_GROUP_CURSOR
	.if (eax)
		invoke LoadResource, hInstance, eax
		.if (eax)
			mov ebx, eax
			add ebx, sizeof NEWHEADER
			movzx eax, [ebx].RESDIR.IconCursorId
			invoke FindResource, hInstance, eax, RT_CURSOR
			.if (eax)
				invoke LoadResource, hInstance, eax
			.endif
		.endif
	.endif
	@strace <"LoadCursorA(", hInstance, ", ", lpCursorName, ")=", eax>
	ret
	align 4
LoadCursorA endp

LoadCursorW proc public hInstance:HINSTANCE, lpCursorName:ptr BYTE
	mov eax, lpCursorName
	.if ( eax > 0ffffh )
		call ConvertWStr
	.endif
	invoke LoadCursorA, hInstance, eax
	ret
	align 4
LoadCursorW endp

endif

DisableMouseInput proc uses ebx
	invoke GetStdHandle, STD_INPUT_HANDLE
	mov ebx, eax
	push eax
	invoke GetConsoleMode, ebx, esp
	pop ecx
	and cl, not ENABLE_MOUSE_INPUT
	invoke SetConsoleMode, ebx, ecx
	ret
	align 4
DisableMouseInput endp

;--- this should be done for HX's DirectDraw support

EnableMouseInput proc uses ebx
	invoke GetStdHandle, STD_INPUT_HANDLE
	mov ebx, eax
	push eax
	invoke GetConsoleMode, ebx, esp
	pop ecx
	.if (!(cl & ENABLE_MOUSE_INPUT))
		or cl, ENABLE_MOUSE_INPUT
		invoke SetConsoleMode, ebx, ecx
		invoke atexit, offset DisableMouseInput
	.endif
	ret
	align 4
EnableMouseInput endp

;--- theoretically one could add VesaMouseExit directly
;--- to the atexit procs, but vesa32 seems to vanish too early.
;--- So do it safely, check if vesa32 is still loaded, then call
;--- VesaMouseExit

externdef g_hVesa32:dword

_MouseExit proc
	invoke GetModuleHandle, CStr("vesa32")
	.if (eax == g_hVesa32)
		invoke g_lpfnVesaMouseExit
	.endif
	ret
	align 4
_MouseExit endp

InitMouse proc uses ebx
	.if (!g_bInit)
		mov g_bInit, TRUE
		invoke EnableMouseInput
		invoke _GetVesaProcs
		.if (g_lpfnVesaMouseInit)
			call g_lpfnVesaMouseInit
			and eax, eax
			jz notinst
			.if (g_lpfnVesaMouseExit)
;				invoke atexit, g_lpfnVesaMouseExit
				invoke atexit, _MouseExit
			.endif
		.else
			mov bx, 0000h
			mov ax, 0024h
			int 33h
			cmp ax,-1
			jz notinst
			cmp bx,0
			jz notinst
		.endif
		mov g_bMouse, TRUE
		invoke ShowCursor, 1
notinst:
	.endif
	ret
	align 4
InitMouse endp

ShowMouse proc
	.if (g_bMouse)
		mov ax,1
		int 33h
	.endif
	ret
	align 4
ShowMouse endp

HideMouse proc
	.if (g_bMouse)
		mov ax,2
		int 33h
	.endif
	ret
	align 4
HideMouse endp

;--- call int 33h, ax=0012
;--- this call should be catched by vesa32 (or dkrnl32)
;--- the mouse driver expects a top-down bitmap, the
;--- screen (AND) bitmap must come first

SetGraphicsMouseCsr proc uses ebx hCursor:HANDLE			   

local	dwHeight:DWORD
local	dwEsp:DWORD

	mov dwEsp, esp
	mov ebx, hCursor
	lea ebx, [ebx+sizeof LOCALHEADER]
	.if ([ebx].BITMAPINFOHEADER.biBitCount == 1)

		mov eax, [ebx].BITMAPINFOHEADER.biHeight
		.if (SDWORD ptr eax < 0)
			neg eax
			mov dwHeight, eax
			lea edx, [ebx+sizeof BITMAPINFOHEADER+2*4]
		.else

;--- if bitmap is bottom-up, convert it

			mov dwHeight, eax
			mov ecx, [ebx].BITMAPINFOHEADER.biWidth
			shr ecx, 3	;do this before MUL
			mul ecx
			sub esp, eax
			mov edx, esp
			call convert
		.endif
		mov cl, byte ptr [ebx].LOCALHEADER.yHotSpot-sizeof LOCALHEADER
		mov ch, byte ptr dwHeight
		shr ch, 1			;2 images
		mov al, byte ptr [ebx].LOCALHEADER.xHotSpot-sizeof LOCALHEADER
		mov ah, byte ptr [ebx].BITMAPINFOHEADER.biWidth
		shr ah, 4			;bits -> words
		mov ebx, eax
		mov ax,0012h
		int 33h
	.endif
	mov esp, dwEsp
	ret
convert:			;eax = size of bitmap, edx=start of converted bitmap
	push esi
	push edi
	push edx
	mov edi, edx
	lea esi, [ebx+sizeof BITMAPINFOHEADER+2*4]
	add esi, eax
	sub esi, ecx
	mov edx, dwHeight
	.while (edx)
		push ecx
		rep movsb
		pop ecx
		sub esi, ecx
		sub esi, ecx
		dec edx
	.endw
	pop edx
	pop edi
	pop esi
	retn
	align 4
SetGraphicsMouseCsr endp

;--- hCursor consists of:
;--- LOCALHEADER 4 bytes
;--- BITMAPINFO

SetCursor proc public hCursor:HANDLE
	mov eax, hCursor
	xchg eax, g_hCurrCursor
	.if (eax != g_hCurrCursor)
		push eax
		invoke InitMouse
		.if (g_bMouse)
			.if (hCursor)
				invoke SetGraphicsMouseCsr, hCursor
			.else
				push ebx
				mov cx,0		;height in CH
				mov bx,0		;width in words in BH
				mov ax,0012h
				int 33h
				pop ebx
			.endif
		.endif
		pop eax
	.endif
	@strace <"SetCursor(", hCursor, ")=", eax>
	ret
	align 4
SetCursor endp

ShowCursor proc public fBool:dword
	call InitMouse
	.if (fBool)
		inc g_cntMouse
		.if (ZERO?)
			invoke ShowMouse
		.endif
	.else
		dec g_cntMouse
		.if (g_cntMouse == -1)
			invoke HideMouse
		.endif
	.endif
	mov eax,g_cntMouse
	@strace <"ShowCursor(", fBool, ")=", eax>
	ret
	align 4
ShowCursor endp

GetCursor proc public
	mov eax, g_hCurrCursor
	@strace <"GetCursor()=",eax>
	ret
	align 4
GetCursor endp

ClipCursor proc public pRect:ptr RECT

	call InitMouse
	.if (!g_bMouse)
		 xor eax, eax
		 jmp exit
	.endif
	mov ecx, pRect
	.if (ecx)
		@strace <"Mouse clipping: X=", [ecx].RECT.left, "-", [ecx].RECT.right, " Y=", [ecx].RECT.top, "-", [ecx].RECT.bottom>
		mov edx, [ecx].RECT.right
		dec edx
		mov ecx, [ecx].RECT.left
		mov ax,7
		int 33h
		mov ecx, pRect
		mov edx, [ecx].RECT.bottom
		dec edx
		mov ecx, [ecx].RECT.top
		mov ax,8
		int 33h
	.else
		invoke GetSystemMetrics, SM_CXSCREEN
		mov edx, eax
		xor ecx, ecx
		mov ax,7
		int 33h
		invoke GetSystemMetrics, SM_CYSCREEN
		mov edx, eax
		xor ecx, ecx
		mov ax,8
		int 33h
	.endif
	@mov eax, 1
exit:
	@strace <"ClipCursor(",pRect,")=", eax>
	ret
	align 4
ClipCursor endp

GetCursorPos proc public lpPoint:ptr POINT
	xor eax, eax
	.if (g_bMouse)
		push ebx
		mov ax,3
		int 33h
		pop ebx
		mov eax, lpPoint
		movsx ecx, cx
		movsx edx, dx
		mov [eax].POINT.x, ecx
		mov [eax].POINT.y, edx
		@mov eax, 1
	.else
		mov ecx, lpPoint
		mov [ecx].POINT.x, eax
		mov [ecx].POINT.y, eax
	.endif
ifdef _DEBUG
	mov edx, lpPoint
endif
	@strace <"GetCursorPos(",lpPoint, "[", [edx].POINT.x, " ", [edx].POINT.y, "])=", eax>
	ret
	align 4
GetCursorPos endp

SetCursorPos proc public x:dword, y:dword
	xor eax, eax
	.if (g_bMouse)
		mov ecx, x
		mov edx, y
		mov ax,4
		int 33h
		@mov eax, 1
	.endif
	@strace <"SetCursorPos(",x, ", ", y, ")=", eax>
	ret
	align 4
SetCursorPos endp

	end

