
;--- clipping is implemented, but is a simple rectangle only

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

getrecttype proc
		mov edx, [ecx].DCOBJ.rcClipping.left
        mov eax, [ecx].DCOBJ.rcClipping.top
        or eax, edx
        jnz isnotempty
		mov edx, [ecx].DCOBJ.rcClipping.right
        mov eax, [ecx].DCOBJ.rcClipping.bottom
if ?CLIPPING
        cmp edx, [ecx].DCOBJ.dwWidth
        jnz isnotempty
        cmp eax, [ecx].DCOBJ.dwHeight
        jnz isnotempty
else
		or eax, edx
        jnz isnotempty
endif
		mov eax, NULLREGION
		ret
isnotempty:
        mov eax, SIMPLEREGION
		ret
        align 4
getrecttype endp

setrectempty proc
		xor eax, eax
		mov [ecx].DCOBJ.rcClipping.left, eax
        mov [ecx].DCOBJ.rcClipping.top, eax
if ?CLIPPING
        mov edx, [ecx].DCOBJ.dwWidth
        mov eax, [ecx].DCOBJ.dwHeight
else
		xor edx, edx
endif
		mov [ecx].DCOBJ.rcClipping.right, edx
        mov [ecx].DCOBJ.rcClipping.bottom, eax
		ret
        align 4
setrectempty endp

SelectClipRgn proc public hdc:DWORD, hRgn:DWORD
		mov ecx, hdc
        mov edx, hRgn
        .if (edx && ([edx].RGNOBJ.dwRgnType == RGNTYPE_RECT))
        	mov eax, [edx].RGNOBJ.rc.left
            mov [ecx].DCOBJ.rcClipping.left,eax
	       	mov eax, [edx].RGNOBJ.rc.top
            mov [ecx].DCOBJ.rcClipping.top,eax
	       	mov eax, [edx].RGNOBJ.rc.right
            mov [ecx].DCOBJ.rcClipping.right,eax
	       	mov eax, [edx].RGNOBJ.rc.bottom
            mov [ecx].DCOBJ.rcClipping.bottom,eax
            call getrecttype
        .elseif (!edx)
        	xor eax, eax
            mov [ecx].DCOBJ.rcClipping.left,eax
            mov [ecx].DCOBJ.rcClipping.top,eax
if ?CLIPPING            
            mov eax, [ecx].DCOBJ.dwWidth
endif            
            mov [ecx].DCOBJ.rcClipping.right,eax
if ?CLIPPING            
            mov eax, [ecx].DCOBJ.dwHeight
endif            
            mov [ecx].DCOBJ.rcClipping.bottom,eax
            call getrecttype
        .else
        	mov eax, ERROR
        .endif
        @strace <"SelectClipRgn(", hdc, ", ", hRgn, ")=", eax>
		ret
        align 4
SelectClipRgn endp

GetClipRgn proc public uses ebx hdc:DWORD, hRgn:DWORD
		mov ecx, hdc
        mov ebx, hRgn
        xor edx, edx
        mov [ebx].RGNOBJ.dwRgnType, RGNTYPE_RECT
        mov eax, [ecx].DCOBJ.rcClipping.left
        and eax, eax
        setnz al
        add edx, eax
        mov [ebx].RGNOBJ.rc.left, eax
        mov eax, [ecx].DCOBJ.rcClipping.top
        and eax, eax
        setnz al
        add edx, eax
        mov [ebx].RGNOBJ.rc.top, eax
        mov eax, [ecx].DCOBJ.rcClipping.right
if ?CLIPPING
		cmp eax, [ecx].DCOBJ.dwWidth
endif
		setnz al
if ?CLIPPING        
        movzx eax,al
endif        
        add edx, eax
        mov [ebx].RGNOBJ.rc.right, eax
        mov eax, [ecx].DCOBJ.rcClipping.bottom
if ?CLIPPING
		cmp eax, [ecx].DCOBJ.dwHeight
endif
		setnz al
if ?CLIPPING        
        movzx eax,al
endif        
        add edx, eax
        mov [ebx].RGNOBJ.rc.bottom, eax
        mov eax, edx
        and eax, eax
        jz @F
        @mov eax, 1
@@:     
        @strace <"GetClipRgn(", hdc, ", ", hRgn, ")=", eax>
		ret
        align 4
GetClipRgn endp

OffsetClipRgn proc public hdc:dword, nX:dword, nY:dword
		mov ecx, hdc
        mov edx, nX
        mov eax, nY
        add [ecx].DCOBJ.rcClipping.left, edx
        add [ecx].DCOBJ.rcClipping.top, eax
        add [ecx].DCOBJ.rcClipping.right, edx
        add [ecx].DCOBJ.rcClipping.bottom, eax
        call getrecttype
        @strace <"OffsetClipRgn(", hdc, ", ", nX, ", ", nY, ")=", eax>
		ret
        align 4
OffsetClipRgn endp

ExcludeClipRect proc public hdc:dword, nLeft:dword, nTop:dword, nRight:dword, nBottom:dword 
		mov eax, ERROR
        @strace <"ExcludeClipRect(", hdc, ", ", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ")=", eax, " *** unsupp ***">
		ret
        align 4
ExcludeClipRect endp

_IntersectRect proc uses esi edi lprcDest:ptr RECT, lprc1:ptr RECT, lprc2:ptr RECT

        mov edx, lprc2
        mov esi, lprc1
		mov edi, lprcDest
        mov ecx, [edx].RECT.left
        lodsd
        .if (SDWORD ptr eax < SDWORD ptr ecx)
        	mov eax, ecx
        .endif
        stosd
        mov ecx, [edx].RECT.top
        lodsd
        .if (SDWORD ptr eax < SDWORD ptr ecx)
        	mov eax, ecx
        .endif
        stosd
        mov ecx, [edx].RECT.right
        lodsd
        .if (SDWORD ptr eax > SDWORD ptr ecx)
        	mov eax, ecx
        .endif
        cmp eax, [edi-8]
       	jl isempty
        stosd
        mov ecx, [edx].RECT.bottom
        lodsd
        .if (SDWORD ptr eax > SDWORD ptr ecx)
        	mov eax, ecx
        .endif
        cmp eax, [edi-8]
       	jl isempty
        stosd
        @mov eax,1
exit:   
		ret
isempty:
		call setrectempty
		xor eax, eax
        jmp exit
        align 4
        
_IntersectRect endp

IntersectClipRect proc public hdc:ptr DCOBJ, nLeft:dword, nTop:dword, nRight:dword, nBottom:dword
		mov eax, ERROR
		mov ecx, hdc
        .if (ecx && ([ecx].GDIOBJ.dwType == GDI_TYPE_DC))
			invoke _IntersectRect, addr [ecx].DCOBJ.rcClipping, addr [ecx].DCOBJ.rcClipping, addr nLeft
            mov ecx, hdc
            invoke getrecttype
        .endif
        @strace <"IntersectClipRect(", hdc, ", ", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ")=", eax>
		ret
        align 4
IntersectClipRect endp

PtVisible proc public hdc:ptr DCOBJ, X:dword, Y:dword
		xor eax, eax
        @strace <"PtVisible(", hdc, ", ", X, ", ", Y, ")=", eax>
		ret
        align 4
PtVisible endp

RectVisible proc public hdc:ptr DCOBJ, lprc:ptr RECT
		xor eax, eax
        @strace <"RectVisible(", hdc, ", ", lprc, ")=", eax>
		ret
        align 4
RectVisible endp

		end
