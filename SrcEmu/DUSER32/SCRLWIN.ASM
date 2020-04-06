
;--- ScrollWindow
;--- ScrollWindowEx

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

	.code

;--- param clip rect is ignored (assumed NULL)

ScrollWindow proc public uses ebx edi hwnd:DWORD, XAmount:DWORD, YAmount:DWORD, lpRect:ptr RECT, lpClipRect:ptr RECT

local rect:RECT
local dst:POINT

	invoke GetDC, hwnd
	.if ( eax )
		mov ebx, eax
		mov edi, lpRect
		.if ( edi == 0 )
			lea edi, rect
			invoke GetClientRect, hwnd, edi
		.endif
		mov eax, [edi].RECT.left
		mov ecx, [edi].RECT.top
		add eax, XAmount
		add ecx, YAmount
		mov dst.x, eax
		mov dst.y, ecx
		mov eax, [edi].RECT.right
		mov ecx, [edi].RECT.bottom
		sub eax, [edi].RECT.left
		sub ecx, [edi].RECT.top
		invoke BitBlt, ebx, dst.x, dst.y, eax, ecx, 
			ebx, [edi].RECT.left, [edi].RECT.top, SRCCOPY
		invoke ReleaseDC, hwnd, ebx
		@mov eax, 1
	.endif
	@strace <"ScrollWindow(", hwnd, ",", XAmount, ", ", YAmount, ", ", lpRect, ", ", lpClipRect, ")=", eax>
	ret
	align 4
ScrollWindow endp

ScrollWindowEx proc public hwnd:dword, dx_:dword, dy_:dword, prcScroll:ptr, prcClip:ptr, hrgnUpdate:ptr, prcUpdate:ptr, flags:dword
	xor eax, eax
	@strace <"SrollWindowEx(", hwnd, ", ", dx_, ", ", dy_, ", ", prcScroll, ", ", prcClip, ", ", hrgnUpdate, ", ", prcUpdate, ", ", flags, ")=", eax, " *** unsupp ***">
	ret
	align 4
ScrollWindowEx endp

	end
