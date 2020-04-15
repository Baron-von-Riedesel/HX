
;--- MaskBlt: just calls BitBlt

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

MaskBlt proc public hdcDest:DWORD, dwXDest:DWORD, dwYDest:DWORD, nWidth:DWORD, nHeight:DWORD,
				hdcSrc:DWORD, dwXSrc:DWORD, dwYSrc:DWORD, hbmMask:DWORD, 
                xMask:dword, yMask:dword, dwRop:DWORD

		invoke BitBlt, hdcDest, dwXDest, dwYDest, nWidth, nHeight,\
        	hdcSrc, dwXSrc, dwYSrc, dwRop
		@strace	<"MaskBlt(", hdcDest, ", ", dwXDest, ", ", dwYDest, ", ", nWidth, ", ", nHeight, ", ", hdcSrc, ", ", dwXSrc, ", ", dwYSrc, ", ", hbmMask, ", ", xMask, ", ", yMask, ", ", dwRop, ")=", eax>
		ret
        
MaskBlt endp

		end
