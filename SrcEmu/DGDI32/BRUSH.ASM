
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include macros.inc

        .CODE

CreateSolidBrush proc public crColor:COLORREF

        invoke _GDImalloc, sizeof BRUSHOBJ
        .if (eax)
            mov [eax].GDIOBJ.dwType, GDI_TYPE_BRUSH
            mov [eax].BRUSHOBJ.dwStyle, BS_SOLID
        	mov ecx, crColor
            mov [eax].BRUSHOBJ.dwColor, ecx
        .endif
		@strace <"CreateSolidBrush(", crColor, ")=", eax>
        ret
        align 4

CreateSolidBrush endp

CreatePatternBrush proc public hBitmap:DWORD

		xor eax, eax
		mov ecx, hBitmap
        .if ([ecx].GDIOBJ.dwType == GDI_TYPE_BITMAP)
	        invoke _GDImalloc, sizeof BRUSHOBJ
    	    .if (eax)
        	    mov [eax].GDIOBJ.dwType, GDI_TYPE_BRUSH
	            mov [eax].BRUSHOBJ.dwStyle, BS_PATTERN
    	    	mov ecx, hBitmap
        	    mov [eax].BRUSHOBJ.hBitmap, ecx
ifdef _DEBUG
				mov ecx, [ecx].BITMAPOBJ.pBitmap
                @strace <"bitmap width=", [ecx].BITMAPINFOHEADER.biWidth, ", height=", [ecx].BITMAPINFOHEADER.biHeight>
                movzx edx,[ecx].BITMAPINFOHEADER.biBitCount
                @strace <"bitmap bpp=", edx>
endif
	        .endif
        .endif
		@strace <"CreatePatternBrush(", hBitmap, ")=", eax>
        ret
        align 4

CreatePatternBrush endp

CreateBrushIndirect proc public uses ebx lplb:ptr LOGBRUSH

       	mov ebx, lplb
        xor eax, eax
        mov ecx, [ebx].LOGBRUSH.lbStyle
        .if (ecx == BS_SOLID)
        	invoke CreateSolidBrush, [ebx].LOGBRUSH.lbColor
        .elseif (ecx == BS_PATTERN)
        	invoke CreatePatternBrush, [ebx].LOGBRUSH.lbHatch
        .elseif ((ecx == BS_NULL) || (ecx == BS_HOLLOW))
	        invoke _GDImalloc, sizeof BRUSHOBJ
    	    .if (eax)
        	    mov [eax].GDIOBJ.dwType, GDI_TYPE_BRUSH
	            mov [eax].BRUSHOBJ.dwStyle, BS_NULL
            .endif
        .endif
		@strace <"CreateBrushIndirect(", lplb, ")=", eax>
        ret
        align 4

CreateBrushIndirect endp

;--- SetDCxxx/GetDCxxx is not implemented in win9x!

SetDCBrushColor proc public uses ebx hdc:DWORD, crBrush:COLORREF

		mov ebx, hdc
        xor eax, eax
        mov edx, [ebx].DCOBJ.hBrush
        .if (edx && ([edx].BRUSHOBJ.dwStyle == BS_SOLID))
        	mov eax, crBrush
        	xchg eax, [edx].BRUSHOBJ.dwColor
            push eax
           	invoke _GetNearestColor, ebx, [edx].BRUSHOBJ.dwColor
            mov [ebx].DCOBJ._BrushColor, eax
            pop eax
        .endif
		@strace <"SetDCBrushColor(", hdc, ", ", crBrush, ")=", eax>
        ret
        align 4
        
SetDCBrushColor endp

GetDCBrushColor proc public hdc:DWORD

		mov ecx, hdc
        xor eax, eax
        mov edx, [ecx].DCOBJ.hBrush
        .if (edx && ([edx].BRUSHOBJ.dwStyle == BS_SOLID))
        	mov eax, [edx].BRUSHOBJ.dwColor
        .endif
		@strace <"GetDCBrushColor(", hdc, ")=", eax>
        ret
        align 4
        
GetDCBrushColor endp

		end
