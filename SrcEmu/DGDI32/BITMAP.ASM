
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

?SETDIRECTION	equ 1

        .CODE

@swapclr macro                    
        mov edx,eax
        shr eax, 8
        mov dh,ah
        mov ah,dl
   	    shl eax, 8
        mov al,dh
        endm

;--- if hdc is a memory bitmap (with the default bitmap selected)
;--- the bitmap created will be a monochrom bitmap

;--- usually CreateCompatibleBitmap is called with a "real" device context
;--- as hdc. then it will get the same color/palette as the hdc

CreateCompatibleBitmap proc public uses ebx hdc:DWORD, nWidth:dword, nHeight:dword

local	dwBpp:dword

        mov ebx, hdc
        mov eax, nWidth
        .if ([ebx].DCOBJ.hBitmap)
        	mov ecx, [ebx].DCOBJ.hBitmap
            mov ecx, [ecx].BITMAPOBJ.pBitmap
            movzx ecx, [ecx].BITMAPINFOHEADER.biBitCount
        .else
	        mov ecx, [ebx].DCOBJ.dwBpp
        .endif
        mul ecx
        shr eax, 3			;eax = bytes/scanline
        inc	eax				;should be WORD aligned
        and eax, -2
        jnz @F
        inc eax
        mov nWidth, eax
        inc eax
@@:        
        mov edx, nHeight
        and edx, edx
        jnz @F
        inc edx
        mov nHeight, edx
        mov ecx, edx		;create a monochrome bitmap
@@:     
        mul edx				;eax = size bitmapdata
        
		mov dwBpp, ecx
        .if (cl == 1)
        	mov edx,2
        .elseif (cl == 4)
        	mov edx,16
        .elseif (cl == 8)
        	mov edx,256
        .else
        	mov edx, 3		;assume we have 3 color entries (might be 0)
        .endif
		lea eax, [eax+edx*4+sizeof BITMAPINFOHEADER+sizeof BITMAPOBJ]
        invoke _GDImalloc2, eax
        .if (eax)
        	mov [eax].GDIOBJ.dwType, GDI_TYPE_BITMAP
            mov edx, nHeight
if ?SETDIRECTION            
            test [ebx].DCOBJ.dwFlags, DCF_BOTTOM_UP
            jnz @F
            neg edx
@@:            
endif            
            lea ecx, [eax+sizeof BITMAPOBJ]
            mov [eax].BITMAPOBJ.pBitmap, ecx
            mov ebx, eax
            mov eax, ecx
        	mov [eax].BITMAPINFOHEADER.biSize, sizeof BITMAPINFOHEADER
            mov ecx, nWidth
            mov [eax].BITMAPINFOHEADER.biWidth, ecx
            mov [eax].BITMAPINFOHEADER.biHeight, edx
            mov [eax].BITMAPINFOHEADER.biPlanes, 1
            mov ecx, dwBpp
            mov [eax].BITMAPINFOHEADER.biBitCount, cx
            .if ((cl == 15) || (cl == 16))
	            mov [eax].BITMAPINFOHEADER.biCompression, BI_BITFIELDS
                .if (cl == 15)
		        	mov dword ptr [eax+sizeof BITMAPINFOHEADER+0*4],07C00h
		        	mov dword ptr [eax+sizeof BITMAPINFOHEADER+1*4],003E0h
		        	mov dword ptr [eax+sizeof BITMAPINFOHEADER+2*4],0001Fh
                .else
		        	mov dword ptr [eax+sizeof BITMAPINFOHEADER+0*4],0F800h
		        	mov dword ptr [eax+sizeof BITMAPINFOHEADER+1*4],007E0h
		        	mov dword ptr [eax+sizeof BITMAPINFOHEADER+2*4],0001Fh
                .endif
            .else
	            mov [eax].BITMAPINFOHEADER.biCompression, BI_RGB
            .endif
            .if (cx == 1)
	        	mov dword ptr [eax+sizeof BITMAPINFOHEADER+4],0FFFFFFh
if 1                
            .elseif (cx == 8)
            
;--- setting the bitmap's color table with the values of the current
;--- palette is possibly not quite correct. Might be better to use
;--- the default palette instead (as it seems to be done by win9x)
            
  				mov edx, hdc
               	mov ecx, [edx].DCOBJ.hPalette
                .if (ecx)
                	push esi
                    push edi
		          	lea edi, [eax+sizeof BITMAPINFOHEADER]
                    lea esi, [ecx].PALETTEOBJ.ColorTab
                	mov ecx, [ecx].PALETTEOBJ.cntEntries
                    jecxz palempty
                    cld
if 1                    
	                .if ([edx].DCOBJ.bColMap)
                    	push ebp
    	            	mov ebp, [edx].DCOBJ.pColMap
                        push ebx
@@:                        
                       	lodsd
                        @swapclr
                        movzx ebx, byte ptr [ebp]
                        mov [edi+ebx*4],eax
                        inc edx
                        loop @B
                        pop ebx
                        pop ebp
        	        .else
@@:                    
                    	lodsd
                        @swapclr
	                    stosd
                        loop @B
	                .endif
else
@@:                    
                   	lodsd
                    @swapclr
                    stosd
                    loop @B
endif
palempty:
                    pop edi
                    pop esi
                .endif
endif                
            .endif
            mov eax, ebx
        .endif
		@strace	<"CreateCompatibleBitmap(", hdc, ", ", nWidth, ", ", nHeight, ")=", eax>
		ret
        align 4
CreateCompatibleBitmap endp

		end
