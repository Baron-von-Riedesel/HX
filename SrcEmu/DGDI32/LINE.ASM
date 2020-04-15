
;--- the line drawing code is a Bresenham algorithm

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

GetCurrentPositionEx proc public uses ebx hdc:DWORD, lpPoint:ptr POINT
		mov ecx, hdc
        mov ebx, lpPoint
       	mov eax, [ecx].DCOBJ.ptPos.x
       	mov edx, [ecx].DCOBJ.ptPos.y
        mov [ebx].POINT.x, eax
   	    mov [ebx].POINT.y, edx
        @mov eax, 1
		@strace <"GetCurrentPositionEx(", hdc, ", ", lpPoint, ")=", eax>
		ret
        align 4
GetCurrentPositionEx endp

MoveToEx proc public hdc:DWORD, nXPos:DWORD, nYPos:DWORD, lpPoint:ptr POINT

		mov ecx, hdc
        .if (lpPoint)
        	push ebx
	        mov ebx, lpPoint
        	mov eax, [ecx].DCOBJ.ptPos.x
        	mov edx, [ecx].DCOBJ.ptPos.y
	        mov [ebx].POINT.x, eax
    	    mov [ebx].POINT.y, edx
            pop ebx
        .endif
        mov eax, nXPos
        mov edx, nYPos
        mov [ecx].DCOBJ.ptPos.x, eax
        mov [ecx].DCOBJ.ptPos.y, edx
        @mov eax,1
		@strace <"MoveToEx(", hdc, ", ", nXPos, ", ", nYPos, ", ", lpPoint, ")=", eax>
        ret
        align 4
        
MoveToEx endp

_SetPixel proto :dword, :dword, :dword, :dword
prSetPixel typedef proto :dword, :dword, :dword, :dword
LPFNSETPIXEL typedef ptr prSetPixel

LineTo proc public uses ebx esi edi hdc:DWORD, nXEnd:DWORD, nYEnd:DWORD

local	dxabs:dword
local	dyabs:dword
local	count:dword
local	dwColor:dword
local	lpfnSetPixel:LPFNSETPIXEL

		invoke	HideMouse
		mov		ebx, hdc
        mov		eax, [ebx].DCOBJ.hPen
        .if ([eax].PENOBJ.dwStyle != PS_NULL)
	        invoke _GetNearestColor, hdc, [eax].PENOBJ.dwColor
            mov lpfnSetPixel, offset _SetPixel
	        mov	dwColor, eax
        .else
            mov lpfnSetPixel, offset SetPixelDummy
        .endif
        
        mov		ecx, nXEnd
        mov		edx, nYEnd
if 0; ?CLIPPING
		mov eax, [ebx].DCOBJ.rcClipping.right
        mov esi, [ebx].DCOBJ.rcClipping.left
        mov edi, [ebx].DCOBJ.rcClipping.bottom
		.if (sdword ptr ecx > sdword ptr eax)
        	mov ecx, eax
        .elseif (sdword ptr ecx < sdword ptr esi)
        	mov ecx, esi
        .endif
		mov eax, [ebx].DCOBJ.rcClipping.top
		.if (sdword ptr edx > sdword ptr edi)
        	mov edx, edi
        .elseif (sdword ptr edx < sdword ptr eax)
        	mov edx, eax
        .endif
endif
        mov     edi, 1
        mov     esi, 1
        sub     ecx, [ebx].DCOBJ.ptPos.x    ;ecx: dx = x2 - x1
        jge     @F
        neg     ecx
        neg     edi               			;&x = -1
@@:
        sub     edx, [ebx].DCOBJ.ptPos.y	;edx: dy = y2 - y1
        jge     @F
        neg     edx
        neg     esi               			;&y = -1
@@:
        mov     dxabs,ecx
        mov     dyabs,edx
        
        xor		eax, eax
        
        cmp     ecx,edx         ;dx - dy
        jl      lineto_1  		;dy > dx -> steep line

        mov     count,ecx
        jecxz	exit
nextitem:
		push	eax
        invoke	lpfnSetPixel, ebx, [ebx].DCOBJ.ptPos.x , [ebx].DCOBJ.ptPos.y, dwColor
        pop		eax
        add     [ebx].DCOBJ.ptPos.x, edi              ;inc/dec x
        add     eax, dyabs
        cmp     eax, dxabs
        jc      @F
        sub     eax, dxabs
        add     [ebx].DCOBJ.ptPos.y, esi
@@:
        dec     count
        jnz     nextitem
        jmp     exit
lineto_1:
        mov     count, edx
nextitem2:
		push	eax
        invoke	lpfnSetPixel, ebx, [ebx].DCOBJ.ptPos.x , [ebx].DCOBJ.ptPos.y, dwColor
        pop		eax
        add     [ebx].DCOBJ.ptPos.y,esi             ;inc/dec y
        add     eax, dxabs
        cmp     eax, dyabs
        jc      @F
        sub     eax, dyabs
        add     [ebx].DCOBJ.ptPos.x, edi            ;inc/dec x
@@:
        dec     count
        jnz     nextitem2
exit:
        @mov	eax,1
		invoke	ShowMouse
		@strace <"LineTo(", hdc, ", ", nXEnd, ", ", nYEnd, ")=", eax>
        ret
SetPixelDummy:
		retn 4*4
        align 4
LineTo endp

_polyline proc uses esi hdc:dword, lppt:ptr POINT, cCount:DWORD, bClose:dword

local	oldPos:POINT

        mov ecx, cCount
        mov esi, lppt
        .while (ecx)
        	push ecx
        	.if (ecx == cCount)
		        invoke MoveToEx, hdc, [esi].POINT.x, [esi].POINT.y, addr oldPos
            .else
		        invoke LineTo, hdc, [esi].POINT.x, [esi].POINT.y
            .endif
            add esi, sizeof POINT
            pop ecx
            dec ecx
        .endw
        .if (cCount)
	        .if (bClose)
    	    	mov esi, lppt
	    	    invoke LineTo, hdc, [esi].POINT.x, [esi].POINT.y
	        .endif
			invoke MoveToEx, hdc, oldPos.x, oldPos.y, NULL
        .endif
		ret
        align 4
_polyline endp

Polyline proc public hdc:dword, lppt:ptr POINT, cCount:DWORD

		invoke _polyline, hdc, lppt, cCount, 0
		@strace <"Polyline(", hdc, ", ", lppt, ", ", cCount, ")=", eax>
		ret
        align 4
Polyline endp

_FillPolygon proto :dword, :dword, :dword

Polygon proc public hdc:dword, lppt:ptr POINT, cCount:DWORD

;--- fill the polygon with the brush color

		invoke _FillPolygon, hdc, lppt, cCount

;--- draw the polygon with the pen color

		invoke _polyline, hdc, lppt, cCount, 1

		@strace <"Polygon(", hdc, ", ", lppt, ", ", cCount, ")=", eax>
		ret
        align 4
Polygon endp

PolyPolyline proc public hdc:dword, lppt:ptr POINT, lpdwPolyPoints: ptr DWORD, cCount:DWORD
		xor eax, eax
		@strace <"PolyPolyline(", hdc, ", ", lppt, ", ", lpdwPolyPoints, ", ", cCount, ")=", eax, " *** unsupp">
		ret
        align 4
PolyPolyline endp

Rectangle proc public uses ebx hdc:dword, nLeft:dword, nTop:dword, nRight:dword, nBottom:dword

local	points[4]:POINT

		mov ecx, nLeft
        mov edx, nTop
        mov eax, nRight
        dec eax
        mov ebx, nBottom
        dec ebx
        mov points[0*sizeof POINT].x, ecx
        mov points[0*sizeof POINT].y, edx
        mov points[1*sizeof POINT].x, eax
        mov points[1*sizeof POINT].y, edx
        mov points[2*sizeof POINT].x, eax
        mov points[2*sizeof POINT].y, ebx
        mov points[3*sizeof POINT].x, ecx
        mov points[3*sizeof POINT].y, ebx
        invoke Polygon, hdc, addr points, 4

		@strace <"Rectangle(", hdc, ", ", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ")=", eax>
		ret
        align 4
Rectangle endp

;--- GdiFlush is not supported in win9x

GdiFlush proc public
		@mov eax, 1
		@strace <"GdiFlush()=", eax>
		ret
        align 4
GdiFlush endp

;--- GdiSetBatchLimit

GdiSetBatchLimit proc public dwLimit:dword
		@mov eax, 1
		@strace <"GdiSetBatchLimit(", dwLimit, ")=", eax>
		ret
        align 4
GdiSetBatchLimit endp

		end
