
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

GetMapMode proc public hdc:DWORD
		mov ecx, hdc
        movzx eax, [ecx].DCOBJ.bMapMode
        @strace <"GetMapMode(", hdc, ")=", eax>
		ret
        align 4
GetMapMode endp

SetMapMode proc public hdc:DWORD, fMode:DWORD
		mov ecx, hdc
        mov eax, fMode
        xchg al, [ecx].DCOBJ.bMapMode
        @strace <"SetMapMode(", hdc, ", ", fMode, ")=", eax, " *** unsupp">
		ret
        align 4
SetMapMode endp

GetGraphicsMode proc public hdc:DWORD
		mov ecx, hdc
        movzx eax, [ecx].DCOBJ.bGraphicsMode
        @strace <"GetGraphicsMode(", hdc, ")=", eax>
		ret
        align 4
GetGraphicsMode endp

SetGraphicsMode proc public hdc:DWORD, fMode:DWORD
		mov ecx, hdc
        mov eax, fMode
        xchg al, [ecx].DCOBJ.bGraphicsMode
        @strace <"SetGraphicsMode(", hdc, ", ", fMode, ")=", eax>
		ret
        align 4
SetGraphicsMode endp

;--- this is no win32 function (unlike GetDCOrgEx)
;--- but somehow user32 has to tell gdi32 the window coordinates
;--- furthermore, it is used by DirectDraw to create HDCs for
;--- back buffers.

SetDCOrgEx proc public uses ebx esi hdc:DWORD, x:DWORD, y:DWORD
		mov ebx, hdc
   	    mov ecx, [ebx].DCOBJ.lPitch
   	    mov esi, [ebx].DCOBJ.dwBpp
        mov eax, y
        mul ecx
        mov ecx, eax
        mov eax, x
        mul esi
        shr eax, 3
        add eax, ecx
        add eax, [ebx].DCOBJ.pOrigin
        mov [ebx].DCOBJ.pBMBits, eax
        @mov eax, 1
        @strace <"SetDCOrgEx(", hdc, ", ", x, ", ", y, ")=", eax, " [origin=", [ebx].DCOBJ.pOrigin, " pitch=", [ebx].DCOBJ.lPitch, " bpp=", [ebx].DCOBJ.dwBpp, "]">
		ret
        align 4
SetDCOrgEx endp

;--- used by directDraw to set a GDI DC for an off-screen surface

_SetDCBitPtr proc public hdc:DWORD, lpSurfaceMem:dword
		mov edx, hdc
        mov ecx, lpSurfaceMem
        mov [edx].DCOBJ.pBMBits, ecx
        mov [edx].DCOBJ.pOrigin, ecx
        @strace <"_SetDCBitPtr(", hdc, ", ", lpSurfaceMem, ")">
		ret
        align 4
_SetDCBitPtr endp

GetDCOrgEx proc public uses ebx esi edi hdc:DWORD, lppt:ptr POINT
		mov ebx, hdc
        mov eax, [ebx].DCOBJ.pBMBits
        xor edx, edx
        .if (eax)
            sub eax, [ebx].DCOBJ.pOrigin
            mov edi, eax
    	    mov ecx, [ebx].DCOBJ.lPitch
    	    mov esi, [ebx].DCOBJ.dwBpp
            cdq
            div ecx
            push eax
            mul ecx
            mov edx, eax
            mov eax, edi
            sub eax, edx
            shl eax, 3
            cdq
			div esi  
			mov edx, eax
            pop eax
        .endif
        mov ecx, lppt
        mov [ecx].POINT.x,edx
        mov [ecx].POINT.y,eax
        @mov eax, 1
        @strace <"GetDCOrgEx(", hdc, ", ", lppt, ")=", eax>
		ret
        align 4
GetDCOrgEx endp

;--- Get/Set/ModifyWorldTransform not supported by win9x!

GetWorldTransform proc public hdc:DWORD, lpXForm:ptr XFORM

		invoke SetLastError, ERROR_CALL_NOT_IMPLEMENTED
		xor eax, eax
        @strace <"GetWorldTransform(", hdc, ", ", lpXForm, ")=", eax, " *** unsupp">
		ret
        align 4
GetWorldTransform endp

SetWorldTransform proc public hdc:DWORD, lpXForm:ptr XFORM

		invoke SetLastError, ERROR_CALL_NOT_IMPLEMENTED
		xor eax, eax
        @strace <"SetWorldTransform(", hdc, ", ", lpXForm, ")=", eax, " *** unsupp">
		ret
        align 4
SetWorldTransform endp

ModifyWorldTransform proc public hdc:DWORD, lpXForm:ptr XFORM, iMode:DWORD

		invoke SetLastError, ERROR_CALL_NOT_IMPLEMENTED
		xor eax, eax
        @strace <"ModifyWorldTransform(", hdc, ", ", lpXForm, ", ", iMode, ")=", eax, " *** unsupp">
		ret
        align 4
ModifyWorldTransform endp

DPtoLP proc public hdc:dword, lpPoints:ptr POINT, nCount:dword
		xor eax, eax
        @strace <"DPtoLP(", hdc, ", ", lpPoints, ", ", nCount, ")=", eax, " *** unsupp">
		ret
        align 4
DPtoLP endp

LPtoDP proc public hdc:dword, lpPoints:ptr POINT, nCount:dword
		xor eax, eax
        @strace <"LPtoDP(", hdc, ", ", lpPoints, ", ", nCount, ")=", eax, " *** unsupp">
		ret
        align 4
LPtoDP endp

		end
