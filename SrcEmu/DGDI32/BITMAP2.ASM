
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

?USEDIRECTION equ 1

        .CODE

CreateBitmap proc public uses esi edi nWidth:DWORD, nHeight:DWORD,
			cPlanes:DWORD, cBitsPerPel:DWORD, lpvBits:ptr

local	dwSize:dword
local	dwColorTabSize:dword

        mov eax,nWidth
        mov edx,nHeight
        or edx, eax
        jnz @F
        mov eax, 1
        mov nWidth, eax
        mov nHeight, eax
        mov cBitsPerPel, eax
@@:        
        mov ecx, cBitsPerPel
        mul ecx
        mov cl,al
        shr eax, 3
        test cl,07
        jz @F
        inc eax
@@:     				;eax=bytes for 1 line
        inc eax
        and al,0FEh		;word align!
        
        mul nHeight
        mov dwSize, eax
        mov ecx, cBitsPerPel
        
        .if (ecx == 1)
        	mov edx, 2*4
        .elseif (ecx == 4)
        	mov edx, 16*4
        .elseif (ecx == 8)
        	mov edx, 256*4
        .elseif ((ecx == 15) || (ecx == 16))
        	mov edx, 3*4
        .else
        	xor edx, edx
        .endif
        mov dwColorTabSize, edx
        add eax, edx
        add eax, sizeof BITMAPINFOHEADER
        add eax, sizeof BITMAPOBJ
        
        invoke _GDImalloc, eax
        .if (!eax)
        	jmp exit
        .endif
        mov edi, eax
        push eax
        lea eax, [eax+sizeof BITMAPOBJ]
        mov [edi].BITMAPOBJ.dwType, GDI_TYPE_BITMAP
        mov [edi].BITMAPOBJ.pBitmap, eax
        mov edi, eax
        mov [edi].BITMAPINFOHEADER.biSize, sizeof BITMAPINFOHEADER
        mov ecx, nWidth
        mov edx, nHeight
        mov eax, cPlanes
        mov esi, cBitsPerPel
        mov [edi].BITMAPINFOHEADER.biWidth, ecx
if ?USEDIRECTION
		neg edx
endif
        mov [edi].BITMAPINFOHEADER.biHeight, edx
        mov [edi].BITMAPINFOHEADER.biPlanes, ax
        mov [edi].BITMAPINFOHEADER.biBitCount, si
        mov [edi].BITMAPINFOHEADER.biClrUsed, 0
        .if (dwColorTabSize == 3*4)
	        mov [edi].BITMAPINFOHEADER.biCompression, BI_BITFIELDS
            .if (si == 15)
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+0*4],07C00h
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+1*4],003E0h
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+2*4],0001Fh
            .else
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+0*4],0F800h
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+1*4],007E0h
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+2*4],0001Fh
            .endif
        .else
	        mov [edi].BITMAPINFOHEADER.biCompression, BI_RGB
	        .if (si == 1)
;--- monochrom bitmaps have the text and background colors,
;--- but currently there is no DC available, so set it to black and white
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+0*4],0h
	        	mov dword ptr [edi+sizeof BITMAPINFOHEADER+1*4],0FFFFFFh
            .endif
        .endif
        mov eax, dwColorTabSize
        lea edi, [edi+eax+sizeof BITMAPINFOHEADER]
        mov esi, lpvBits
        and esi, esi
        jz  @F
        mov ecx, dwSize
        rep movsb
@@:        
        pop eax
exit:        
ifdef _DEBUG
		mov edx, lpvBits
        .if (edx)
			@strace <"CreateBitmap(", nWidth, ", ", nHeight, ", ", cPlanes, ", ", cBitsPerPel, ", ", lpvBits, " [", [edx], " ", [edx+4], "])=", eax>
        .else
			@strace <"CreateBitmap(", nWidth, ", ", nHeight, ", ", cPlanes, ", ", cBitsPerPel, ", ", lpvBits, ")=", eax>
		.endif        
endif
        ret
        align 4

CreateBitmap endp

GetBitmapBits proc public uses esi hBitmap:DWORD, cbBuffer:DWORD, lpvBits:ptr

local	bmih:BITMAPINFOHEADER

		mov bmih.biSize, sizeof BITMAPINFOHEADER
        mov bmih.biBitCount, 0	;dont copy color table
		invoke GetDIBits, g_hdc, hBitmap, 0, 0, 0, addr bmih, 0
        .if (eax)
        	mov eax, bmih.biWidth
            movzx ecx, bmih.biBitCount
            mul ecx
            shr eax, 3		;eax=size of one scan line in bytes
            inc eax
            and al,0FEh		;word align
            mov ecx, eax
        	mov eax, cbBuffer
            cdq
            div ecx
if ?USEDIRECTION
			mov edx, bmih.biHeight
            and edx, 7FFFFFFFh
            .if (eax > edx)
            	mov eax, edx
            .endif
else
            .if (eax > bmih.biHeight)
            	mov eax, bmih.biHeight
            .endif
endif
            mov esi, eax
            mul ecx
            push eax
			invoke GetDIBits, g_hdc, hBitmap, 0, esi, lpvBits, addr bmih, 0
            pop eax
        .endif
		@strace <"GetBitmapBits(", hBitmap, ", ", cbBuffer, ", ", lpvBits, ")=", eax>
        ret
        align 4
GetBitmapBits endp

SetBitmapBits proc public uses esi hBitmap:DWORD, cbBuffer:DWORD, lpvBits:ptr

local	bmih:BITMAPINFOHEADER

		mov bmih.biSize, sizeof BITMAPINFOHEADER
        mov bmih.biBitCount, 0	;dont copy color table
		invoke GetDIBits, g_hdc, hBitmap, 0, 0, 0, addr bmih, 0
        .if (eax)
        	mov eax, bmih.biWidth
            movzx ecx, bmih.biBitCount
            mul ecx
            shr eax, 3		;eax=size of one scan line in bytes
            inc eax
            and al,0FEh		;word align
            mov ecx, eax
        	mov eax, cbBuffer
            cdq
            div ecx
if ?USEDIRECTION
			mov edx, bmih.biHeight
            and edx, 7FFFFFFFh
            .if (eax > edx)
            	mov eax, edx
            .endif
else
            .if (eax > bmih.biHeight)
            	mov eax, bmih.biHeight
            .endif
endif            
            mov esi, eax
            mul ecx
            push eax
			invoke SetDIBits, g_hdc, hBitmap, 0, esi, lpvBits, addr bmih, 0
            pop eax
        .endif
		@strace <"SetBitmapBits(", hBitmap, ", ", cbBuffer, ", ", lpvBits, ")=", eax>
        ret
        align 4
SetBitmapBits endp

		end
