
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

SetStretchBltMode proc public hdc:dword, bMode:dword
		mov ecx, hdc
        mov eax, bMode
      	xchg al, [ecx].DCOBJ.bStretch
        movzx eax, al
        @strace <"SetStretchBltMode(", hdc, ", ", bMode, ")=", eax>
		ret
        align 4
SetStretchBltMode endp

;--- implemented partly
;--- there is no stretch in size implemented as of yet

StretchBlt proc public hdcDst:dword, nXOriginDst:dword, nYOriginDst:dword, 
				nWidthDst:dword, nHeightDst:dword,
                hdcSrc:dword, nXOriginSrc:dword, nYOriginSrc:dword, 
				nWidthSrc:dword, nHeightSrc:dword,
                dwRop:dword
                
		invoke BitBlt, hdcDst, nXOriginDst, nYOriginDst, nWidthDst, nHeightDst,\
        	hdcSrc, nXOriginSrc, nYOriginSrc, dwRop
        @strace <"StretchBlt(", hdcDst, ", ", nXOriginDst, ", ", nYOriginDst, ", ", nWidthDst, ", ", nHeightDst, ", ", hdcSrc, ", ", nXOriginSrc, ", ", nYOriginSrc, ", ", nWidthSrc, ", ", nHeightSrc, ", ", dwRop, ")=", eax>
		ret
        align 4
StretchBlt endp

;--- implemented partly
;--- there is no stretch in size implemented as of yet

StretchDIBits proc public uses esi hdcDst:dword, nXDst:dword, nYDst:dword, 
				nWidthDst:dword, nHeightDst:dword,
                nXSrc:dword, nYSrc:dword, nWidthSrc:dword, nHeightSrc:dword,
				lpBits:ptr, lpBitsInfo:ptr BITMAPINFO, iUsage:dword, dwRop:dword

		invoke CreateCompatibleDC, hdcDst
        .if (eax)
        	mov esi, eax

;--- adjust the DC so it matches the bitmap structure
;--- this is kind of a hack, but works fast. BitBlt()
;--- will provide any color transformation needed
            
        	mov ecx, lpBitsInfo
            movzx eax, [ecx].BITMAPINFOHEADER.biBitCount
            mov [esi].DCOBJ.dwBpp, eax
            mov eax, [ecx].BITMAPINFOHEADER.biWidth
            mul [ecx].BITMAPINFOHEADER.biBitCount
            shr eax, 3
            mov [esi].DCOBJ.lPitch, eax
            mov eax, lpBits
            mov [esi].DCOBJ.pBMBits, eax
            mov [esi].DCOBJ.pOrigin, eax

			lea eax, [ecx+sizeof BITMAPINFOHEADER]            
            mov [esi].DCOBJ.pColorTab, eax
            
			invoke BitBlt, hdcDst, nXDst, nYDst, nWidthDst, nHeightDst, esi, nXSrc, nYSrc, dwRop
            
            invoke DeleteDC, esi
        .endif
        @strace <"StretchDIBits(", hdcDst, ", ", nXDst, ", ", nYDst, ", ", nWidthDst, ", ", nHeightDst, ", ", nXSrc, ", ", nYSrc, ", ", nWidthSrc, ", ", nHeightSrc, ", ", lpBits, ", ", lpBitsInfo, ", ", iUsage, ", ", dwRop, ")=", eax>
		ret
        align 4
StretchDIBits endp

		end
