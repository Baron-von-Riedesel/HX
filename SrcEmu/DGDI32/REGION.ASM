
;--- implements REGIONs

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

;--- currently only rectangular regions are supported

CreateRectRgnIndirect proc public uses ebx pRC:ptr RECT

		invoke _GDImalloc, sizeof RGNOBJ
        .if (eax)
            mov [eax].GDIOBJ.dwType, GDI_TYPE_RGN
            mov [eax].RGNOBJ.dwRgnType, RGNTYPE_RECT
            mov ebx, pRC
            mov ecx, [ebx].RECT.left
            mov edx, [ebx].RECT.top
            mov [eax].RGNOBJ.rc.left, ecx
            mov [eax].RGNOBJ.rc.top, edx
            mov ecx, [ebx].RECT.right
            mov edx, [ebx].RECT.bottom
            mov [eax].RGNOBJ.rc.right, ecx
            mov [eax].RGNOBJ.rc.bottom, edx
        .endif
		@strace <"CreateRectRgnIndirect(", pRC, ")=", eax>
        ret
        align 4
CreateRectRgnIndirect endp

CreateRectRgn proc public nLeft:SDWORD, nTop:SDWORD, nRight:SDWORD, nBottom:SDWORD

		invoke CreateRectRgnIndirect, addr nLeft
		@strace <"CreateRectRgn(", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ")=", eax>
        ret
        align 4
CreateRectRgn endp

;--- ExtCreateRegion: works with simple rectangular region only

ExtCreateRegion proc public lpXform:ptr, nCount:dword, lpRgnData:ptr RGNDATA
		xor eax, eax
        .if (!lpXform)
        	mov ecx, lpRgnData
            .if (([ecx].RGNDATA.rdh.iType == RDH_RECTANGLES) && ([ecx].RGNDATA.rdh.nCount == 1))
            	invoke CreateRectRgnIndirect, addr [ecx+sizeof RGNDATAHEADER]
            .endif
        .endif
		@strace <"ExtCreateRegion(", lpXform, ", ", nCount, ", ", lpRgnData, ")=", eax>
        ret
        align 4
ExtCreateRegion endp

SetRectRgn proc public hRgn:HRGN, nLeft:SDWORD, nTop:SDWORD, nRight:SDWORD, nBottom:SDWORD

		mov ecx, hRgn
        xor eax, eax
        .if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_RGN))
        	mov eax, nLeft
        	mov edx, nTop
            mov [ecx].RGNOBJ.rc.left, eax
            mov [ecx].RGNOBJ.rc.top, edx
        	mov eax, nRight
        	mov edx, nBottom
            mov [ecx].RGNOBJ.rc.right, eax
            mov [ecx].RGNOBJ.rc.bottom, edx
            @mov eax, 1
        .endif
		@strace <"SetRectRgn(", hRgn, ", ", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ")=", eax>
        ret
        align 4
SetRectRgn endp

OffsetRgn proc public hrgn:ptr RGNOBJ, nXOffset:dword, nYOffset:dword
		mov ecx, hrgn
        xor eax, eax
        .if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_RGN))
        	mov edx, nXOffset
            mov eax, nYOffset
            add [ecx].RGNOBJ.rc.left, edx
            add [ecx].RGNOBJ.rc.top, eax
            add [ecx].RGNOBJ.rc.right, edx
            add [ecx].RGNOBJ.rc.bottom, eax
            mov eax, SIMPLEREGION
        .endif
		@strace <"OffsetRgn(", hrgn, ", ", nXOffset, ", ", nYOffset, ")=", eax>
        ret
        align 4
OffsetRgn endp

GetRegionData proc public uses ebx esi edi hrgn:HRGN, dwCount:DWORD, lpRgnData:ptr RGNDATA

		xor eax, eax
        mov ecx, hrgn
        .if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_RGN))
        	.if ([ecx].RGNOBJ.dwRgnType == RGNTYPE_RECT)
            	mov ebx, lpRgnData
                .if (!ebx)
                	mov eax, sizeof RGNDATAHEADER + sizeof RECT
                .elseif (dwCount >= sizeof RGNDATAHEADER + sizeof RECT)
                	mov [ebx].RGNDATA.rdh.dwSize, sizeof RGNDATAHEADER
                	mov [ebx].RGNDATA.rdh.iType, RDH_RECTANGLES
                	mov [ebx].RGNDATA.rdh.nCount, 1
                	mov [ebx].RGNDATA.rdh.nRgnSize, 0
                    mov eax, [ecx].RGNOBJ.rc.left
                    mov edx, [ecx].RGNOBJ.rc.top
                    mov esi, [ecx].RGNOBJ.rc.right
                    mov edi, [ecx].RGNOBJ.rc.bottom
                	mov [ebx].RGNDATA.rdh.rcBound.left, eax
                	mov [ebx].RGNDATA.rdh.rcBound.top, edx
                	mov [ebx].RGNDATA.rdh.rcBound.right, esi
                	mov [ebx].RGNDATA.rdh.rcBound.bottom, edi
	              	mov [ebx + sizeof RGNDATAHEADER].RECT.left, eax
       		      	mov [ebx + sizeof RGNDATAHEADER].RECT.top, edx
	              	mov [ebx + sizeof RGNDATAHEADER].RECT.right, esi
       		      	mov [ebx + sizeof RGNDATAHEADER].RECT.bottom, edi
	                mov eax, dwCount
                .endif
        	.endif
        .endif
		@strace <"GetRegionData(", hrgn, ", ", dwCount, ", ", lpRgnData, ")=", eax>
        ret
        align 4
GetRegionData endp

getrectrgntype proc                
		mov ecx, [edx].RECT.right
		mov eax, [edx].RECT.bottom
		.if ((ecx == [edx].RECT.left) && (eax == [edx].RECT.top))
			mov eax, NULLREGION
            ret
		.endif
		mov eax, SIMPLEREGION
		ret
        align 4
getrectrgntype endp

GetRgnBox proc public hrgn:ptr RGNOBJ, lprc:ptr RECT
		mov ecx, hrgn
        xor eax, eax
        .if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_RGN))
        	.if ([ecx].RGNOBJ.dwRgnType == RGNTYPE_RECT)
            	invoke RtlMoveMemory, lprc, addr [ecx].RGNOBJ.rc, sizeof RECT
                mov edx, lprc
                call getrectrgntype
            .endif
        .endif
		@strace <"GetRegionBox(", hrgn, ", ", lprc, ")=", eax>
        ret
        align 4
GetRgnBox endp

GetClipBox proc public hdc:ptr DCOBJ, lprc:ptr RECT
		mov ecx, hdc
        xor eax, eax
        .if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_DC))
           	invoke RtlMoveMemory, lprc, addr [ecx].DCOBJ.rcClipping, sizeof RECT
            mov edx, lprc
            call getrectrgntype
        .endif
		@strace <"GetClipBox(", hdc, ", ", lprc, ")=", eax>
        ret
        align 4
GetClipBox endp

PaintRgn proc public hdc:ptr DCOBJ, hrgn:ptr RGNOBJ
		xor eax, eax
        mov ecx, hrgn
        .if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_RGN))
        	.if ([ecx].RGNOBJ.dwRgnType == RGNTYPE_RECT)
		        mov edx, [ecx].RGNOBJ.rc.right
		        sub edx, [ecx].RGNOBJ.rc.left
		        mov eax, [ecx].RGNOBJ.rc.bottom
		        sub eax, [ecx].RGNOBJ.rc.top
		        invoke PatBlt, hdc, [ecx].RGNOBJ.rc.left, [ecx].RGNOBJ.rc.top, edx, eax, PATCOPY
            .endif
        .endif
		@strace <"PaintRgn(", hdc, ", ", hrgn, ")=", eax>
        ret
        align 4
PaintRgn endp

FillRgn proc public hdc:ptr DCOBJ, hrgn:ptr RGNOBJ, hbr:ptr BRUSHOBJ

		invoke SelectObject, hdc, hbr
        push eax
        invoke PaintRgn, hdc, hrgn
        xchg eax, [esp]
        invoke SelectObject, hdc, eax
        pop eax
		@strace <"FillRgn(", hdc, ", ", hrgn, ", ", hbr, ")=", eax>
        ret
        align 4
FillRgn endp

IsNullRegion proc
		mov eax, [ebx].RGNOBJ.rc.right
		mov ecx, [ebx].RGNOBJ.rc.bottom
        .if ((SDWORD ptr eax <= SDWORD ptr [ebx].RGNOBJ.rc.left) || (SDWORD ptr ecx <= SDWORD ptr [ebx].RGNOBJ.rc.top))
        	xor eax, eax
            mov [ebx].RGNOBJ.rc.left, eax
            mov [ebx].RGNOBJ.rc.top, eax
            mov [ebx].RGNOBJ.rc.right, eax
            mov [ebx].RGNOBJ.rc.bottom, eax
            mov eax, NULLREGION
        .endif
        mov eax, SIMPLEREGION
		ret
        align 4
        
IsNullRegion endp

;--- ebx = rgndst
;--- edx = rgnsrc1
;--- ecx = rgnsrc2

UnionRgn proc uses esi edi ebx

        lea esi, [edx].RGNOBJ.rc
        lea edi, [ebx].RGNOBJ.rc
        lea ebx, [ecx].RGNOBJ.rc
        mov ch,2
nextpair:
        mov cl,2
nextitem:
        lodsd
        mov edx, [ebx]
        add ebx, 4
        .if (SDWORD ptr eax > SDWORD ptr edx)
        	mov eax, edx
        .endif
        stosd
        dec cl
        jnz nextitem
        xchg esi, ebx
        dec ch
        jnz nextpair
		ret
        align 4
        
UnionRgn endp

;--- ebx = rgndst
;--- edx = rgnsrc1
;--- ecx = rgnsrc2

IntersectRgn proc uses esi edi ebx

        lea esi, [edx].RGNOBJ.rc
        lea edi, [ebx].RGNOBJ.rc
        lea ebx, [ecx].RGNOBJ.rc
        mov ch,2
nextpair:
        mov cl,2
nextitem:
        lodsd
        mov edx, [ebx]
        add ebx, 4
        .if (SDWORD ptr eax < SDWORD ptr edx)
        	mov eax, edx
        .endif
        stosd
        dec cl
        jnz nextitem
        xchg esi, ebx
        dec ch
        jnz nextpair
exit:   
		ret
        align 4
        
IntersectRgn endp

CombineRgn proc public uses ebx hrgnDest:ptr RGNOBJ, hrgnSrc1:ptr RGNOBJ, hrgnSrc2:ptr RGNOBJ, fnCombineMode:dword

		mov eax, ERROR
        mov edx, hrgnSrc1
        mov ebx, hrgnDest
        .if (edx && [edx].GDIOBJ.dwType == GDI_TYPE_RGN)
	        mov ecx, fnCombineMode
	        .if (ecx == RGN_COPY)
            	.if ([edx].RGNOBJ.dwRgnType == RGNTYPE_RECT)
                	invoke SetRectRgn, ebx, [edx].RGNOBJ.rc.left,\
                    	[edx].RGNOBJ.rc.top, [edx].RGNOBJ.rc.right, [edx].RGNOBJ.rc.bottom 
                .endif
    	    .elseif ((ecx == RGN_AND) || (ecx == RGN_OR))
            	.if ([edx].RGNOBJ.dwRgnType == RGNTYPE_RECT)
	            	mov ecx, hrgnSrc2
                	.if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_RGN) && ([ecx].RGNOBJ.dwRgnType == RGNTYPE_RECT))
                    	.if (fnCombineMode == RGN_AND)
                        	invoke IntersectRgn
                        .else
                        	invoke UnionRgn
                        .endif
                        invoke IsNullRegion
                    .endif
                .endif
	        .elseif (ecx == RGN_DIFF)
;--- todo            
	        .elseif (ecx == RGN_XOR)
;--- todo            
    	    .endif
        .endif
		@strace <"CombineRgn(", hrgnDest, ", ", hrgnSrc1, ", ", hrgnSrc2, ", ", fnCombineMode, ")=", eax>
        ret
        align 4
CombineRgn endp

		end
