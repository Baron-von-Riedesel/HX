
;--- handling DC stuff

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
        include duser32.inc
        include macros.inc


?DCITEMS	equ 5

DCCACHEITEM struct
hDC		dd ?
hwnd	dd ?
bUsed	db ?
DCCACHEITEM ends

		.DATA

		public g_dwOldRealizePalette

g_dwOldRealizePalette dd 0
if ?AUTOINIT
g_hxlib	dd 0
endif

g_dccache	DCCACHEITEM ?DCITEMS dup (<0,0>)

g_bInit	db 0

		.CODE

BeginPaint proc public hWnd:HWND, lpPS:ptr PAINTSTRUCT

        invoke GetDC, hWnd
        mov ecx, lpPS
        mov [ecx].PAINTSTRUCT.hdc, eax
        mov [ecx].PAINTSTRUCT.fErase, 1
        push eax
        invoke GetClientRect, hWnd, addr [ecx].PAINTSTRUCT.rcPaint
        pop eax
		mov ecx, hWnd
        .if ([ecx].WNDOBJ.bErase)
        	push eax
        	invoke SendMessage, ecx, WM_ERASEBKGND, eax, 0
            .if (eax)
            	mov ecx, hWnd
                mov [ecx].WNDOBJ.bErase, 0
            .endif
            pop eax
        .endif
		@strace	<"BeginPaint(", hWnd, ", ", lpPS, ")=", eax>
		ret
        align 4
BeginPaint endp

EndPaint proc public hWnd:HWND, lpPS:ptr PAINTSTRUCT
        mov ecx, lpPS
        invoke ReleaseDC, hWnd, [ecx].PAINTSTRUCT.hdc
        mov ecx, hWnd
        mov [ecx].WNDOBJ.bUpdate, 0
		@strace	<"EndPaint(", hWnd, ", ", lpPS, ")=", eax>
		ret
        align 4
EndPaint endp

_ClearDCCache proc public uses ebx
		mov ebx, offset g_dccache
        mov ecx, ?DCITEMS
        .while (ecx)
			.if (([ebx].DCCACHEITEM.hDC) && ([ebx].DCCACHEITEM.bUsed == FALSE))
            	push ecx
                xor eax, eax
                xchg eax, [ebx].DCCACHEITEM.hDC
			    invoke DeleteDC, eax
                pop ecx
            .endif
            add ebx, sizeof DCCACHEITEM
            dec ecx
        .endw
		@strace	<"_ClearDCCache">
        ret
        align 4
_ClearDCCache endp

DeinitDC proc uses ebx 

		invoke _ClearDCCache
if ?AUTOINIT        
        .if (g_hxlib)
        	invoke FreeLibrary, g_hxlib
        .endif
endif        
		@strace	<"DeinitDC">
		ret
        align 4
DeinitDC endp

if ?AUTOINIT

InGraphicsMode proc
		push edx
        mov dx, 3ceh
        in al, dx		;save index register
        mov ah, al
        mov al, 6
        out dx, al
        inc dx
        in al, dx
        xchg ah, al
        dec dx
        out dx, al		;restore index register
        pop edx
        and ah,1
        movzx eax,ah
        ret
	    align 4
InGraphicsMode endp        

InitGfx proc public

        test g_bInit, 2
        jnz @F
       	or  g_bInit, 2
		invoke InGraphicsMode
        .if (!eax)
           	invoke LoadLibrary, CStr("HXGUIHLP")
            mov g_hxlib, eax
        .endif
@@:
        ret
InitGfx endp

endif

InitDC proc public
		invoke GetModuleHandle, CStr("GDI32")
        .if (eax)
		   	invoke GetProcAddress, eax, CStr("pfnRealizePalette")
			.if (eax)
				mov ecx, [eax]
				mov g_dwOldRealizePalette, ecx
				mov [eax], offset UserRealizePalette
			.endif
		.endif
        invoke atexit, offset DeinitDC
		@strace	<"InitDC">
		ret
        align 4
InitDC endp

;--- create a DC for the DC cache

_CreateDC proc

        test g_bInit, 1
        jnz @F
       	or  g_bInit, 1
        invoke InitDC
@@:        
        invoke CreateDCA, CStr("DISPLAY"), 0, 0, 0
		@strace	<"_CreateDC">
		ret
        align 4
_CreateDC endp

SetDCOrgEx proto :DWORD, :DWORD, :DWORD

GetDC proc public uses ebx hWnd:DWORD

		mov ebx, offset g_dccache
        mov ecx, ?DCITEMS
        .while (ecx)
;			@strace	<"GetDC: cache entry ", ebx, " hdc=", [ebx].DCCACHEITEM.hDC, " hwnd=", [ebx].DCCACHEITEM.hwnd>
        	.if (![ebx].DCCACHEITEM.bUsed)
            	mov [ebx].DCCACHEITEM.bUsed, TRUE
ifdef _DEBUG
				sub ecx, ?DCITEMS
                neg ecx
endif
;				@strace	<"GetDC(", hWnd, "): cache entry ", ecx, " used">
                .if (![ebx].DCCACHEITEM.hDC)
                	invoke _CreateDC		;fill the cache
                    .if (!eax)
                    	mov [ebx].DCCACHEITEM.bUsed, FALSE
                        jmp exit
                    .endif
                    mov [ebx].DCCACHEITEM.hDC, eax
                .endif
                mov edx, hWnd
                mov [ebx].DCCACHEITEM.hwnd, edx
                mov eax, [ebx].DCCACHEITEM.hDC
                jmp found
            .endif
            add ebx, sizeof DCCACHEITEM
            dec ecx
        .endw
        invoke _CreateDC
        and eax, eax
        jz exit
found:
		mov ebx, eax
		mov ecx, hWnd
		.if (ecx && ([ecx].WNDOBJ.dwType == USER_TYPE_HWND) && (!([ecx].WNDOBJ.dwStyle & WS_MAXIMIZE)))
			mov eax, [ecx].WNDOBJ.rc.left
			mov edx, [ecx].WNDOBJ.rc.top
		.else
			xor eax, eax
			xor edx, edx
		.endif
		invoke SetDCOrgEx, ebx, eax, edx
        
		invoke SetViewportOrgEx, ebx, 0,0,0
		invoke SetWindowOrgEx, ebx, 0,0,0
        
		mov ecx, hWnd
		.if (ecx)
			mov eax,[ecx].WNDOBJ.pWndClass
			mov eax, [eax].WNDCLASSEX.hbrBackground
		.else
			invoke GetStockObject, WHITE_BRUSH
		.endif
		.if (eax)
			invoke SelectObject, ebx, eax
		.endif
        invoke SetSystemPaletteUse, ebx, SYSPAL_STATIC
        mov eax, ebx
exit:        
		@strace	<"GetDC(", hWnd, ")=", eax>
		ret
        align 4
GetDC endp

;--- there is currently no no-client area in hx's user32 emulation

GetWindowDC proc public hWnd:DWORD

		invoke GetDC, hWnd
		@strace	<"GetWindowDC(", hWnd, ")=", eax>
		ret
        align 4
GetWindowDC endp

ReleaseDC proc public uses ebx hWnd:DWORD, hdc:DWORD

		xor eax, eax
        mov edx, hWnd
        mov ecx, hdc
        and ecx, ecx
        jz exit
        and edx, edx
        jz @F
        cmp [edx].WNDOBJ.dwType, USER_TYPE_HWND
        jnz exit
@@:
		mov eax, ecx
		mov ebx, offset g_dccache
        mov ecx, ?DCITEMS
        .while (ecx)
        	.if (([ebx].DCCACHEITEM.bUsed) && (eax == [ebx].DCCACHEITEM.hDC))
            	mov [ebx].DCCACHEITEM.bUsed, FALSE
                mov [ebx].DCCACHEITEM.hwnd, 0
                @mov eax, 1
                jmp exit
            .endif
            add ebx, sizeof DCCACHEITEM
            dec ecx
        .endw
		invoke DeleteDC, eax
exit:        
		@strace	<"ReleaseDC(", hWnd, ", ", hdc, ")=", eax>
		ret
        align 4
ReleaseDC endp

FillRect proc public hdc:DWORD, prect:ptr RECT, hBrush:DWORD

        invoke SelectObject, hdc, hBrush
        push eax
        mov ecx, prect
        mov edx, [ecx].RECT.right
        sub edx, [ecx].RECT.left
        mov eax, [ecx].RECT.bottom
        sub eax, [ecx].RECT.top
        invoke PatBlt, hdc, [ecx].RECT.left, [ecx].RECT.top, edx, eax, PATCOPY
        pop eax
        invoke SelectObject, hdc, eax
        @mov eax, 1
exit:        
ifdef _DEBUG
		mov ecx, prect
endif
		@strace	<"FillRect(", hdc, ", ", prect, "[", [ecx].RECT.left, " ", [ecx].RECT.top, " ", [ecx].RECT.right, " ", [ecx].RECT.bottom, "], ", hBrush, ")=", eax>
		ret
        align 4
FillRect endp

DrawFocusRect proc public hDC:dword, lpRect:ptr RECT
		xor eax, eax
		@strace	<"DrawFocusRect(", hDC, ", ", lpRect, ")=", eax>
        ret
        align 4
DrawFocusRect endp

TabbedTextOutA proc public hDC:dword, X:dword, Y:dword, lpString:ptr BYTE,
		nCount:DWORD, nTabPositions:DWORD, lpnTabPositions:ptr DWORD, nTabOrigin:DWORD

local	size_:SIZE_

        mov edx, nTabPositions
		.if (edx < 2)
        	push ebx
            push esi
            push edi
            mov edi,X
        	mov ebx,8
        	.if (edx)
				mov ecx, lpnTabPositions
    	    	mov ebx, [ecx]
            .endif
            mov ecx, nCount
            mov esi, lpString
            mov edx, esi
            .while (ecx)
            	lodsb
                .if (al == 9)
                	push ecx
                    mov ecx, esi
                    sub ecx, edx
                    dec ecx
                    push edx
                    push ecx
                    invoke GetTextExtentPoint32A, hDC, edx, ecx, addr size_
                    pop ecx
                    pop edx
			 		invoke TextOutA, hDC, edi, Y, edx, ecx
                    add edi, size_.cx_
                    add edi, 8
                    mov eax, ebx
                    shl eax,3
                    add edi, eax
                    dec eax
                    not eax
                    and edi, eax
                    
                    pop ecx
                    mov edx, esi
                .endif
                dec ecx
            .endw
            mov ecx, esi
            sub ecx, edx
            .if (ecx)
		 		invoke TextOutA, hDC, edi, Y, edx, ecx
            .endif
            pop edi
            pop esi
            pop ebx
        .else
			invoke TextOutA, hDC, X, Y, lpString, nCount
        .endif
		@strace	<"TabbedTextOutA(", hDC, ", ", X, ", ", Y, ", ", lpString, ", ", nCount, ", ", nTabPositions, ", ", lpnTabPositions, ", ", nTabOrigin, ")=", eax>
        ret
        align 4
TabbedTextOutA endp

DrawTextA proc public uses ebx hdc:dword, lpString:ptr BYTE, nCount:dword, lpRect:ptr RECT, uFormat:dword

local	size_:SIZE_

		cmp nCount,-1
        jnz @F
        invoke lstrlen, lpString
        mov nCount, eax
@@:        
        test uFormat, DT_CENTER or DT_VCENTER
        jz @F
        invoke GetTextExtentPoint32A, hdc, lpString, nCount, addr size_
@@:     
		mov ebx, lpRect
        mov edx, [ebx].RECT.left
        test uFormat, DT_CENTER
        jz @F
        mov eax, [ebx].RECT.right
        sub eax, edx
        sub eax, size_.cx_
        and eax, eax
        js @F
        shr eax, 1
        add edx, eax
@@:        
        mov eax, [ebx].RECT.top
        test uFormat, DT_VCENTER
        jz @F
        mov ecx, [ebx].RECT.bottom
        sub ecx, eax
        sub ecx, size_.cy
        and ecx, ecx
        js @F
        shr ecx, 1
        add eax, ecx
@@:        
		invoke ExtTextOutA, hdc, edx, eax, 0, 0, lpString, nCount, 0
		@strace	<"DrawTextA(", hdc, ", ", lpString, ", ", nCount, ", ", lpRect, ", ", nCount, ", ", uFormat, ")=", eax>
		ret
        align 4
DrawTextA endp

GrayStringA proc public hdc:dword, hBrush:dword, lpOutputFunc:ptr, lpData:DWORD, nCount:dword, x:dword, y:dword, nWidth:dword, nHeight:dword
		xor eax, eax
		@strace	<"GrayStringA(", hdc, ", ", hBrush, ", ", lpOutputFunc, ", ", lpData, ", ", nCount, ", ", x, ", ", y, ", ", nWidth, ", ", nHeight, ")=", eax>
		ret
        align 4
GrayStringA endp

UserRealizePalette proc public hdc:dword

		push hdc
		call g_dwOldRealizePalette
        .if (edx)		;edx==number of entries which have changed
        	push eax
        	invoke WindowFromDC, hdc
            .if (eax)		;NULL is HWND_TOP
            	invoke SendMessage, HWND_BROADCAST, WM_PALETTECHANGED, eax, 0
            .endif
            pop eax
        .endif
		@strace	<"UserRealizePalette(", hdc, ")=", eax>
		ret
        align 4
        
UserRealizePalette endp

;--- get window

WindowFromDC proc public uses ebx hdc:DWORD

local	pt:POINT

        mov eax, hdc
        and eax, eax
        jz exit
		@serialize_enter
		mov ebx, offset g_dccache
        mov ecx, ?DCITEMS
        xor edx, edx
        .while (ecx)
        	.if (([ebx].DCCACHEITEM.bUsed) && (eax == [ebx].DCCACHEITEM.hDC))
                mov edx, [ebx].DCCACHEITEM.hwnd
                .break
            .endif
            add ebx, sizeof DCCACHEITEM
            dec ecx
        .endw
		mov eax, edx
        @serialize_exit
exit:        
		@strace	<"WindowFromDC(", hdc, ")=", eax>
		ret
        align 4
WindowFromDC endp

DrawIcon proc public hdc:dword, X:dword, Y:dword, hIcon:ptr
		xor eax, eax
		@strace	<"DrawIcon(", hdc, ", ", X, ", ", Y, ", ", hIcon, ")=", eax>
		ret
        align 4
DrawIcon endp

DrawIconEx proc public hdc:DWORD, nLeft:dword, nTop:dword, hIcon:DWORD, cxWidth:dword, cyWidth:dword, iStepIfAniCur:dword, hbrFlickerFreeDraw:DWORD, diFlags:DWORD
		xor eax, eax
		@strace	<"DrawIconEx(", hdc, ", ", nLeft, ", ", nTop, ", ", hIcon, ", ", cxWidth, ", ", cyWidth, " ...)=", eax, " *** unsupp ***">
		ret
        align 4
DrawIconEx endp

	end

