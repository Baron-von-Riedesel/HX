
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

Ellipse proc public uses esi edi ebx hdc:DWORD, nLeft:DWORD, nTop:DWORD, nRight:DWORD, nBottom:DWORD
            
        invoke HideMouse
        @mov eax, 1
        invoke ShowMouse
		@strace <"Ellipse(", hdc, ", ", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ")=", eax>
        ret
        align 4
Ellipse endp

Arc proc public uses esi edi ebx hdc:DWORD, nLeft:DWORD, nTop:DWORD, nRight:DWORD, nBottom:DWORD,
            nXStart:DWORD, nYStart:DWORD, nXEnd:DWORD, nYEnd:DWORD

        invoke HideMouse
        @mov eax, 1
        invoke ShowMouse
		@strace <"Arc(", hdc, ", ", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ", ", nXStart, ", ", nYStart, ", ", nXEnd, ", ", nYEnd, ")=", eax>
        ret
        align 4
        
Arc endp

Pie proc public uses esi edi ebx hdc:DWORD, nLeft:DWORD, nTop:DWORD, nRight:DWORD, nBottom:DWORD,
            nXRad1:DWORD, nYRad1:DWORD, nXRad2:DWORD, nYRad2:DWORD
            
        invoke HideMouse
        @mov eax, 1
        invoke ShowMouse
		@strace <"Pie(", hdc, ", ", nLeft, ", ", nTop, ", ", nRight, ", ", nBottom, ", ", nXRad1, ", ", nYRad1, ", ", nXRad2, ", ", nYRad2, ")=", eax>
        ret
        align 4
Pie endp

		end
