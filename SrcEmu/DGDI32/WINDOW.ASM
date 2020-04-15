
;--- sets window org and ext of a DC
;--- the window org/ext are in logical units

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

GetWindowOrgEx proc public hdc:DWORD, lppt:ptr POINT
		mov ecx, hdc
        mov eax, [ecx].DCOBJ.ptWindowOrg.x
        mov edx, [ecx].DCOBJ.ptWindowOrg.y
        mov ecx, lppt
        mov [ecx].POINT.x, eax
        mov [ecx].POINT.y, edx
		@mov eax, 1
        @strace <"GetWindowOrgEx(", hdc, ", ", lppt, ")=", eax>
		ret
        align 4
GetWindowOrgEx endp

SetWindowOrgEx proc public hdc:DWORD, x:dword, y:dword, lppt:ptr POINT

		mov ecx, lppt
        jecxz @F
		invoke GetWindowOrgEx, hdc, ecx
@@:        
		mov ecx, hdc
        mov eax, x
        mov edx, y
        mov [ecx].DCOBJ.ptWindowOrg.x, eax
        mov [ecx].DCOBJ.ptWindowOrg.y, edx
		@mov eax, 1
        @strace <"SetWindowOrgEx(", hdc, ", ", x, ", ", y, ", ", lppt, ")=", eax>
		ret
        align 4
SetWindowOrgEx endp

OffsetWindowOrgEx proc public hdc:DWORD, nX:dword, nY:dword, lppt:ptr POINT

		mov ecx, lppt
        jecxz @F
		invoke GetWindowOrgEx, hdc, ecx
@@:        
		mov ecx, hdc
        mov eax, nX
        mov edx, nY
        add [ecx].DCOBJ.ptWindowOrg.x, eax
        add [ecx].DCOBJ.ptWindowOrg.y, edx
		@mov eax, 1
        @strace <"OffsetWindowOrgEx(", hdc, ", ", nX, ", ", nY, ", ", lppt, ")=", eax>
		ret
        align 4
OffsetWindowOrgEx endp

GetWindowExtEx proc public hdc:DWORD, lpsize:ptr SIZE_
		mov ecx, hdc
        mov eax, [ecx].DCOBJ.sWindowExt.cx_
        mov edx, [ecx].DCOBJ.sWindowExt.cy
        mov ecx, lpsize
        mov [ecx].SIZE_.cx_, eax
        mov [ecx].SIZE_.cy, edx
		@mov eax, 1
        @strace <"GetWindowExtEx(", hdc, ", ", lpsize, ")=", eax>
		ret
        align 4
GetWindowExtEx endp

SetWindowExtEx proc public hdc:DWORD, nX:dword, nY:dword, lpsize:ptr SIZE_

		mov ecx, lpsize
        jecxz @F
		invoke GetWindowExtEx, hdc, ecx
@@:        
		mov ecx, hdc
        mov eax, nX
        mov edx, nY
        mov [ecx].DCOBJ.sWindowExt.cx_, eax
        mov [ecx].DCOBJ.sWindowExt.cy, edx
		@mov eax, 1
        @strace <"SetWindowExtEx(", hdc, ", ", nX, ", ", nY, ", ", lpsize, ")=", eax>
		ret
        align 4
SetWindowExtEx endp

ScaleWindowExtEx proc public hdc:DWORD, Xnum:dword, Xdenom:dword, Ynum:dword, Ydenom:dword, lpsize:ptr SIZE_
		xor eax, eax
        @strace <"ScaleWindowExtEx(", hdc, ", ", Xnum, ", ", Xdenom, ", ", Ynum, ", ", Ydenom, ", ", lpsize, ")=", eax>
		ret
        align 4
ScaleWindowExtEx endp

		end
