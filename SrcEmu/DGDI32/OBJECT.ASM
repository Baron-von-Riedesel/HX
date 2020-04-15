
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

		.DATA

externdef g_DefaultBM:DWORD        

        .CODE

;--- ebx = DC 

_SetDC proc uses edi
		mov edi, [eax].BITMAPOBJ.pBitmap
		mov eax, [edi].BITMAPINFOHEADER.biHeight
if 1
		or  byte ptr [ebx].DCOBJ.dwFlags, DCF_BOTTOM_UP
        test eax, 80000000h
        jz @F
        neg eax
        and byte ptr [ebx].DCOBJ.dwFlags, not DCF_BOTTOM_UP
@@:
endif
		mov [ebx].DCOBJ.dwHeight, eax
		mov eax, [edi].BITMAPINFOHEADER.biWidth
		movzx ecx,[edi].BITMAPINFOHEADER.biBitCount
		mov [ebx].DCOBJ.dwWidth, eax
		mov [ebx].DCOBJ.dwBpp, ecx
		mul ecx
		shr eax, 3
        .if (ecx == 1)
        	inc eax
            and al,0FEh
        .else
			add eax, 3
    	    and al,0FCh
        .endif
		mov [ebx].DCOBJ.lPitch, eax
		mov edx,[edi].BITMAPINFOHEADER.biClrUsed
		.if (!edx)
			mov edx, [ebx].DCOBJ.dwBpp
			.if (dl == 1)
				mov edx, 2
			.elseif (dl == 4)
				mov edx, 16
			.elseif (dl == 8)
				mov edx, 256
			.elseif ([edi].BITMAPINFOHEADER.biCompression == BI_BITFIELDS)
				mov edx, 3
			.else
				xor edx, edx
			.endif
		.endif
        mov eax,[edi].BITMAPINFOHEADER.biSize
   	    lea eax,[edi+eax]
       	mov [ebx].DCOBJ.pColorTab, eax
        lea eax,[eax+edx*4]
        mov [ebx].DCOBJ.pBMBits, eax
        @strace <"DC=", ebx, " pBMBits=", eax, "[", [eax], " ", [eax+4],"]">
		ret
        align 4
_SetDC endp

;--- a palette must be selected using SelectPalette()!
;--- bitmaps can be selected in memory contexts only

SelectObject proc public uses ebx hdc:DWORD, hObject:DWORD

        mov ebx, hdc
        mov eax, hObject
        .if (eax)
        	mov ecx, [eax].GDIOBJ.dwType
        	.if ((ecx == GDI_TYPE_BITMAP) && ([ebx].DCOBJ.hBitmap))
            	push [ebx].DCOBJ.hBitmap
				@strace	<"bitmap selected">
   	        	mov [ebx].DCOBJ.hBitmap, eax
       	        invoke _SetDC
           	    pop eax
        	.elseif (ecx == GDI_TYPE_BRUSH)
            	push [ebx].DCOBJ.hBrush
   	        	mov [ebx].DCOBJ.hBrush, eax
                .if ([eax].BRUSHOBJ.dwStyle == BS_SOLID)
					@strace	<"brush selected, new color=", [eax].BRUSHOBJ.dwColor>
	               	invoke _GetNearestColor, ebx, [eax].BRUSHOBJ.dwColor
        	        mov [ebx].DCOBJ._BrushColor, eax
                .else
					@strace	<"pattern brush selected, bitmap=", [eax].BRUSHOBJ.hBitmap>
        	        mov [ebx].DCOBJ._BrushColor, -1
                .endif
            	pop eax
        	.elseif (ecx == GDI_TYPE_PEN)
				@strace	<"pen selected">
            	xchg eax, [ebx].DCOBJ.hPen
        	.elseif (ecx == GDI_TYPE_FONT)
				@strace	<"font selected">
            	xchg eax, [ebx].DCOBJ.hFont
            .else
				@strace	<"unknown type ", ecx, " selected">
            	xor eax, eax
            .endif
        .endif
		@strace	<"SelectObject(", hdc, ", ", hObject, ")=", eax>
        ret
        align 4

SelectObject endp

DeleteObject proc public hObject:DWORD

        mov eax, hObject
        .if (eax)
        	mov ecx, [eax].GDIOBJ.dwType
if 0;def _DEBUG
			mov [eax].GDIOBJ.dwType, 0DEADBEEFh	;useless (HeapFree overwrites)
endif
        	.if (ecx == GDI_TYPE_BITMAP)
            	.if (eax == g_DefaultBM)
                	mov g_DefaultBM, NULL
                .endif
            	invoke _GDIfree, eax
            .elseif ((ecx == GDI_TYPE_BRUSH) || (ecx == GDI_TYPE_PEN))
            	invoke _GDIfree, eax
            .elseif (ecx == GDI_TYPE_FONT)
            	invoke _GDIfree, eax
            .elseif (ecx == GDI_TYPE_PALETTE)
            	invoke _GDIfree, eax
            .elseif (ecx == GDI_TYPE_RGN)
            	invoke _GDIfree, eax
            .else
            	xor eax, eax
            .endif
        .endif
		@strace	<"DeleteObject(", hObject, ")=", eax>
        ret
        align 4

DeleteObject endp

GetCurrentObject proc public hdc:dword, dwType:dword
		mov ecx, hdc
        mov edx, dwType
        xor eax, eax
        .if (edx == OBJ_PEN)
        	mov eax, [ecx].DCOBJ.hPen
        .elseif (edx == OBJ_BRUSH)
        	mov eax, [ecx].DCOBJ.hBrush
        .elseif (edx == OBJ_PAL)
        	mov eax, [ecx].DCOBJ.hPalette
        .elseif (edx == OBJ_FONT)
        	mov eax, [ecx].DCOBJ.hFont
        .elseif (edx == OBJ_BITMAP)
        	mov eax, [ecx].DCOBJ.hBitmap
        .endif
		@strace	<"GetCurrentObject(", hdc, ", ", dwType, ")=", eax>
		ret
        align 4
GetCurrentObject endp

_getclrtabsize proto

;--- get information about a GDI object
;--- currently supported types:
;---  BITMAP
;---  PALETTE
;---  BRUSH

GetObjectA proc public uses esi hObject:DWORD, cbBuffer:DWORD, pBuffer:ptr BYTE

		mov ecx, hObject
        xor eax, eax
        mov edx, [ecx].GDIOBJ.dwType
        mov esi, pBuffer
        .if (edx == GDI_TYPE_BITMAP)
        	mov edx, cbBuffer
        	.if ((edx == sizeof BITMAP) || (edx == sizeof DIBSECTION))
	           	mov edx, esi
                .if (edx)
					mov esi, [ecx].BITMAPOBJ.pBitmap
					mov [edx].BITMAP.bmType, 0
					mov eax, [esi].BITMAPINFOHEADER.biWidth
					mov [edx].BITMAP.bmWidth, eax
					mov eax, [esi].BITMAPINFOHEADER.biHeight
					mov [edx].BITMAP.bmHeight, eax
					mov eax, [esi].BITMAPINFOHEADER.biWidth
					push edx
					movzx edx,[esi].BITMAPINFOHEADER.biBitCount
					mul edx
					pop edx
					shr eax, 3
					inc eax
					and al,0FEh
					mov [edx].BITMAP.bmWidthBytes, eax
					mov ax, [esi].BITMAPINFOHEADER.biPlanes
					mov [edx].BITMAP.bmPlanes, ax
					mov ax, [esi].BITMAPINFOHEADER.biBitCount
					mov [edx].BITMAP.bmBitsPixel, ax
					invoke _getclrtabsize
					mov eax, [esi].BITMAPINFOHEADER.biSize
					lea eax, [eax+ecx*4]
                    add eax, esi
					mov [edx].BITMAP.bmBits, eax
					.if (cbBuffer == sizeof DIBSECTION)
                    	mov [edx].DIBSECTION.dshSection, NULL
                        push edi
                        lea edi, [edx].DIBSECTION.dsBmih
                        mov ecx, sizeof BITMAPINFOHEADER
                        rep movsb
                        mov cl, 3
                        .if ([esi - sizeof BITMAPINFOHEADER].BITMAPINFOHEADER.biCompression == BI_BITFIELDS)
                        	rep movsd
                        .else
                        	xor eax, eax
                            rep stosd
                        .endif
                        pop edi
                    .endif
                .endif
                mov eax, cbBuffer
            .endif
        .elseif (edx == GDI_TYPE_PALETTE)
        	.if (esi)
            	mov eax, [ecx].PALETTEOBJ.cntEntries
	        	mov [esi], ax
            .endif
        	mov eax, 2
        .elseif (edx == GDI_TYPE_BRUSH)
            mov edx, [ecx].BRUSHOBJ.dwStyle
        	mov [esi].LOGBRUSH.lbStyle, edx
            .if (edx == BS_SOLID)
	            mov eax, [ecx].BRUSHOBJ.dwColor
                mov [esi].LOGBRUSH.lbColor, eax
            .elseif (edx == BS_PATTERN)
            	mov eax, [ecx].BRUSHOBJ.hBitmap
                mov [esi].LOGBRUSH.lbHatch, eax
            .endif
            mov eax, sizeof LOGBRUSH
        .endif
		@strace <"GetObjectA(", hObject, ", ", cbBuffer, ", ", pBuffer, ")=", eax>
        ret
        align 4

GetObjectA endp

GetObjectW proc public hObject:DWORD, cbBuffer:DWORD, pBuffer:ptr BYTE
		invoke GetObjectA, hObject, cbBuffer, pBuffer
		@strace <"GetObjectW(", hObject, ", ", cbBuffer, ", ", pBuffer, ")=", eax>
        ret
        align 4
GetObjectW endp

GetObjectType proc public hObject:DWORD
		xor eax, eax
        mov ecx, hObject
        mov edx, [ecx].GDIOBJ.dwType
        .if (edx == GDI_TYPE_DC)
        	.if ([ecx].DCOBJ.hBitmap)
	        	mov eax, OBJ_MEMDC
            .else
	        	mov eax, OBJ_DC
            .endif
        .elseif (edx == GDI_TYPE_BITMAP)
        	mov eax, OBJ_BITMAP
        .elseif (edx == GDI_TYPE_BRUSH)
        	mov eax, OBJ_BRUSH
        .elseif (edx == GDI_TYPE_FONT)
        	mov eax, OBJ_FONT
        .elseif (edx == GDI_TYPE_PALETTE)
        	mov eax, OBJ_PAL
        .elseif (edx == GDI_TYPE_PEN)
        	mov eax, OBJ_PEN
        .elseif (edx == GDI_TYPE_RGN)
        	mov eax, OBJ_REGION
        .endif
		@strace <"GetObjectType(", hObject, ")=", eax>
        ret
        align 4
GetObjectType endp

UnrealizeObject proc public hObject:dword
		mov ecx, hObject
        xor eax, eax
        mov edx, [ecx].GDIOBJ.dwType
        .if (edx == GDI_TYPE_BRUSH)
        	inc eax
        .elseif (edx == GDI_TYPE_PALETTE)
        	inc eax
        .endif
		@strace <"UnrealizeObject(", hObject, ")=", eax>
		ret
        align 4
UnrealizeObject endp

		end
