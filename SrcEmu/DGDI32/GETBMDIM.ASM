
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

GetBitmapDimensionEx proc public hBitmap:DWORD, lpDimension:ptr SIZE_

		xor eax, eax
		@strace	<"GetBitmapDimensionEx(", hBitmap, ", ", lpDimension, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetBitmapDimensionEx endp

SetBitmapDimensionEx proc public hBitmap:DWORD, nWidth:dword, nHeight:dword, lpSize:ptr SIZE_

		xor eax, eax
		@strace	<"SetBitmapDimensionEx(", hBitmap, ", ", nWidth, ", ", nHeight, ", ", lpSize, ")=", eax, " *** unsupp ***">
		ret
        align 4
SetBitmapDimensionEx endp

		end
