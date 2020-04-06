
;--- validate/invalidate update region of a window
;--- todo: add InvalidateRgn/ValidateRgn

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

		.DATA

		.CODE

InvalidateRect proc public hwnd:DWORD, prect:ptr RECT, bErase:DWORD

		mov ecx, hwnd
		mov [ecx].WNDOBJ.bUpdate, 1
        mov eax, bErase
        mov [ecx].WNDOBJ.bErase, al
		invoke PostMessage, hwnd, WM_PAINT, 0, 0
		@strace	<"InvalidateRect(", hwnd, ", ", prect, ", ", bErase, ")=", eax>
		ret
        align 4
InvalidateRect endp

ValidateRect proc public hwnd:DWORD, lpRect:ptr RECT

		mov ecx, hwnd
        mov edx, lpRect
        @mov eax, 1
        .if (ecx)
        	.if ([ecx].WNDOBJ.dwType != USER_TYPE_HWND)
            	xor eax, eax
                jmp exit
            .endif
        	.if (!edx)
		  		mov [ecx].WNDOBJ.bUpdate, 0
		      	mov [ecx].WNDOBJ.bErase, 0
            .endif
        .else
;--- this invalidates and redraws all windows        
			
        .endif
exit:   
		@strace	<"ValidateRect(", hwnd, ", ", lpRect, ")=", eax>
		ret
        align 4
ValidateRect endp

InvalidateRgn proc public hwnd:DWORD, hrgn:DWORD, bErase:DWORD

		mov ecx, hwnd
		mov [ecx].WNDOBJ.bUpdate, 1
        mov eax, bErase
        mov [ecx].WNDOBJ.bErase, al
		invoke PostMessage, hwnd, WM_PAINT, 0, 0
		@strace	<"InvalidateRgn(", hwnd, ", ", hrgn, ", ", bErase, ")=", eax>
		ret
        align 4
InvalidateRgn endp

ValidateRgn proc public hwnd:DWORD, hrgn:DWORD

		mov ecx, hwnd
       	xor eax, eax
        .if (ecx && ([ecx].WNDOBJ.dwType == USER_TYPE_HWND))
		  	mov [ecx].WNDOBJ.bUpdate, 0
		    mov [ecx].WNDOBJ.bErase, 0
	        @mov eax, 1
        .endif
exit:   
		@strace	<"ValidateRgn(", hwnd, ", ", hrgn, ")=", eax>
		ret
        align 4
ValidateRgn endp

GetUpdateRgn proc public uses ebx hwnd:DWORD, hrgn:DWORD, bErase:DWORD

		mov ebx, hwnd
       	mov eax, ERROR
        .if (ebx && ([ebx].WNDOBJ.dwType == USER_TYPE_HWND))
           	.if ([ebx].WNDOBJ.bUpdate)
               	invoke SetRectRgn, hrgn, [ebx].WNDOBJ.rc.left, [ebx].WNDOBJ.rc.top,\
   	               	[ebx].WNDOBJ.rc.right, [ebx].WNDOBJ.rc.bottom
            	mov eax, SIMPLEREGION
            .else
               	invoke SetRectRgn, hrgn, 0, 0, 0, 0
            	mov eax, NULLREGION
            .endif
        .endif
exit:   
		@strace	<"GetUpdateRgn(", hwnd, ", ", hrgn, ")=", eax>
		ret
        align 4
GetUpdateRgn endp

	end

