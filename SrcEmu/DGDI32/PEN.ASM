
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

;--- currently only solid pens with 1 bit width are supported!

CreatePen proc public fnPenStyle:DWORD, nWidth:DWORD, crColor:COLORREF

       	invoke _GDImalloc, sizeof PENOBJ
        .if (eax)
            mov [eax].GDIOBJ.dwType, GDI_TYPE_PEN
            mov ecx, fnPenStyle
            mov [eax].PENOBJ.dwStyle, ecx
           	mov ecx, crColor
           	mov edx, nWidth
            mov [eax].PENOBJ.dwColor, ecx
            mov [eax].PENOBJ.dwWidth, edx
        .endif
		@strace <"CreatePen(", fnPenStyle, ", ", nWidth, ", ", crColor, ")=", eax>
        ret
        align 4
CreatePen endp

;--- ExtCreatePen(): most things not implemented

ExtCreatePen proc public fnPenStyle:Dword, nWidth:DWORD, lplb:ptr LOGBRUSH, dwStyleCount:dword, lpStyle:ptr DWORD
		mov ecx, lplb
		invoke CreatePen, fnPenStyle, nWidth, [ecx].LOGBRUSH.lbColor
		@strace <"ExtCreatePen(", fnPenStyle, ", ", nWidth, ", ", lplb, ", ", dwStyleCount, ", ", lpStyle, ")=", eax>
        ret
        align 4
ExtCreatePen endp

;--- SetDCxxx/GetDCxxx is not implemented in win9x

SetDCPenColor proc public hdc:DWORD, crPen:COLORREF

		mov ecx, hdc
        xor eax, eax
        mov edx, [ecx].DCOBJ.hPen
        .if (edx)
        	mov eax, crPen
        	xchg eax, [edx].PENOBJ.dwColor
        .endif
		@strace <"SetDCPenColor(", hdc, ", ", crPen, ")=", eax>
        ret
        align 4
        
SetDCPenColor endp

GetDCPenColor proc public hdc:DWORD

		mov ecx, hdc
        xor eax, eax
        mov edx, [ecx].DCOBJ.hPen
        .if (edx)
        	mov eax, [edx].PENOBJ.dwColor
        .endif
		@strace <"GetDCPenColor(", hdc, ")=", eax>
        ret
        align 4
        
GetDCPenColor endp

GetROP2 proc public hdc:DWORD
		mov ecx, hdc
        movzx eax, [ecx].DCOBJ.bROP2
		@strace <"GetROP2(", hdc, ")=", eax>
        ret
        align 4
GetROP2 endp

SetROP2 proc public hdc:DWORD, fnDrawMode:DWORD
		mov ecx, hdc
        mov eax, fnDrawMode
        xchg al, [ecx].DCOBJ.bROP2
		@strace <"SetROP2(", hdc, ", ", fnDrawMode, ")=", eax>
        ret
        align 4
SetROP2 endp

		end
