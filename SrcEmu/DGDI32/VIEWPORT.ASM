
;--- set the viewport org and ext of a DC
;--- the viewport org/ext are in pixels units

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

GetViewportOrgEx proc public hdc:DWORD, lppt:ptr POINT
		mov ecx, hdc
        mov eax, [ecx].DCOBJ.ptViewportOrg.x
        mov edx, [ecx].DCOBJ.ptViewportOrg.y
        mov ecx, lppt
        mov [ecx].POINT.x, eax
        mov [ecx].POINT.y, edx
		@mov eax, 1
        @strace <"GetViewportOrgEx(", hdc, ", ", lppt, ")=", eax>
		ret
        align 4
GetViewportOrgEx endp

SetViewportOrgEx proc public hdc:DWORD, x:DWORD, y:DWORD, lppt:ptr POINT

		mov ecx, lppt
        jecxz @F
		invoke GetViewportOrgEx, hdc, ecx
@@:        
		mov ecx, hdc
        mov eax, x
        mov edx, y
        mov [ecx].DCOBJ.ptViewportOrg.x, eax
        mov [ecx].DCOBJ.ptViewportOrg.y, edx
		@mov eax, 1
        @strace <"SetViewportOrgEx(", hdc, ", ", x, ", ", y, ", ", lppt, ")=", eax>
		ret
        align 4
SetViewportOrgEx endp

OffsetViewportOrgEx proc public hdc:DWORD, nX:DWORD, nY:DWORD, lppt:ptr POINT

		mov ecx, lppt
        jecxz @F
		invoke GetViewportOrgEx, hdc, ecx
@@:        
		mov ecx, hdc
        mov eax, nX
        mov edx, nY
        add [ecx].DCOBJ.ptViewportOrg.x, eax
        add [ecx].DCOBJ.ptViewportOrg.y, edx
		@mov eax, 1
        @strace <"OffsetViewportOrgEx(", hdc, ", ", nX, ", ", nY, ", ", lppt, ")=", eax>
		ret
        align 4
OffsetViewportOrgEx endp

GetViewportExtEx proc public hdc:DWORD, lpsize:ptr SIZE_

		mov ecx, hdc
        mov eax, [ecx].DCOBJ.sViewportExt.cx_
        mov edx, [ecx].DCOBJ.sViewportExt.cy
		mov ecx, lpsize
        mov [ecx].SIZE_.cx_, eax
        mov [ecx].SIZE_.cy, edx
        @mov eax, 1
        @strace <"GetViewportExtEx(", hdc, ", ", lpsize, ")=", eax>
		ret
        align 4
GetViewportExtEx endp

SetViewportExtEx proc public hdc:DWORD, nX:dword, nY:dword, lpsize:ptr SIZE_

		mov ecx, lpsize
        jecxz @F
		invoke GetViewportExtEx, hdc, ecx
@@:        
		mov ecx, hdc
        mov [ecx].DCOBJ.sViewportExt.cx_, eax
        mov [ecx].DCOBJ.sViewportExt.cy, edx
        @mov eax, 1
        @strace <"SetViewportExtEx(", hdc, ", ", nX, ", ", nY, ", ", lpsize, ")=", eax>
		ret
        align 4
SetViewportExtEx endp

ScaleViewportExtEx proc public hdc:DWORD, Xnum:dword, Xdenom:dword, Ynum:dword, Ydenom:dword, lpsize:ptr SIZE_
		xor eax, eax
        @strace <"ScaleViewportExtEx(", hdc, ", ", Xnum, ", ", Xdenom, ", ", Ynum, ", ", Ydenom, ", ", lpsize, ")=", eax>
		ret
        align 4
ScaleViewportExtEx endp

		end
