
;--- LoadBitmap

		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
ifndef __POASM__        
        option proc:private
endif        

		include winbase.inc
		include winuser.inc
        include wingdi.inc
        include duser32.inc
        include macros.inc

		.CODE

_CreateBitmapFromMemory proc public uses ebx esi pBM:ptr BITMAPINFOHEADER                
			invoke GetDC, NULL
            mov esi, eax
			mov ebx, pBM
			mov edx, [ebx].BITMAPINFOHEADER.biClrUsed
			.if (!edx)
				movzx edx, [ebx].BITMAPINFOHEADER.biBitCount
				.if (edx == 1)
					mov edx, 2
				.elseif (edx == 4)
					mov edx, 16
				.elseif (edx == 8)
					mov edx, 256
				.elseif ([ebx].BITMAPINFOHEADER.biCompression == BI_BITFIELDS)
					mov edx, 3
				.else
					xor edx, edx
				.endif
			.endif
			mov ecx, [ebx].BITMAPINFOHEADER.biSize
			lea edx, [ecx+edx*4]
			add edx, ebx
			invoke CreateDIBitmap, esi, ebx, CBM_INIT, edx, ebx, DIB_RGB_COLORS
            push eax
            invoke ReleaseDC, NULL, esi
            pop eax
			ret
			align 4
_CreateBitmapFromMemory endp                

;--- LoadBitmap creates a DDB

LoadBitmapA proc public hInstance:HINSTANCE, lpBitmapName:ptr BYTE

		@strace	<"LoadBitmapA(", hInstance, ", ", lpBitmapName, ")">
        .if (!hInstance)
        	mov ecx, g_hInstance
            mov hInstance, ecx
            mov edx, lpBitmapName
            test edx, 0FFFF0000h
            .if (ZERO?)
            	sub lpBitmapName, 32512 - 52
            .endif
        .endif
        invoke FindResource, hInstance, lpBitmapName, RT_BITMAP
        .if (eax)
        	invoke LoadResource, hInstance, eax
            .if (eax)
            	invoke _CreateBitmapFromMemory, eax
            .endif
        .endif
		ret
        align 4
LoadBitmapA endp

		end

