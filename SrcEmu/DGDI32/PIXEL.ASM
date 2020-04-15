
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

GetPixel proc public uses edi ebx hdc:DWORD, nXPos:DWORD, nYPos:DWORD

        invoke HideMouse
        mov ebx, hdc
        mov eax, nYPos
        mov edi, [ebx].DCOBJ.pBMBits
if ?MAPPING
		add eax, [ebx].DCOBJ.ptViewportOrg.y
endif
        mov ecx, [ebx].DCOBJ.dwBpp
        mul [ebx].DCOBJ.lPitch
        add edi, eax
        mov eax, nXPos
if ?MAPPING
		add eax, [ebx].DCOBJ.ptViewportOrg.x
endif
        mul ecx
        shr eax, 3
        add edi, eax
		.if (cl == 8)
	        mov ebx,[ebx].DCOBJ.pColorTab
		  	movzx eax, byte ptr [edi]
            call _col8to24
        .elseif (cl == 15)
		  	movzx eax, word ptr [edi]
            call _col15to24
        .elseif (cl == 16)
		  	movzx eax, word ptr [edi]
            call _col16to24
        .elseif (cl == 24)
		  	movzx eax, byte ptr [edi+2]
        	shl eax, 16
	        mov ax, [edi]
        .elseif (cl == 32)
			mov eax, [edi]
        .else
	      	mov eax, CLR_INVALID
        .endif
exit:        
        invoke ShowMouse
		@strace <"GetPixel(", hdc, ", ", nXPos, ", ", nYPos, ")=", eax>
        ret
        align 4
        
GetPixel endp

;--- internal function, used by LineTo
;--- color already translated

_SetPixel proc public uses ebx edi hdc:DWORD, nXPos:DWORD, nYPos:DWORD, dwColor:DWORD

        mov ebx, hdc
        mov eax, nYPos
        mov edi, [ebx].DCOBJ.pBMBits
if ?MAPPING
		add eax, [ebx].DCOBJ.ptViewportOrg.y
endif
if ?CLIPPING
		cmp eax, [ebx].DCOBJ.rcClipping.top
        jl exit
		cmp eax, [ebx].DCOBJ.rcClipping.bottom
        jg exit
endif
        mov ecx, [ebx].DCOBJ.dwBpp
        mul [ebx].DCOBJ.lPitch
        add edi, eax
        mov eax, nXPos
if ?MAPPING
		add eax, [ebx].DCOBJ.ptViewportOrg.x
endif
if ?CLIPPING
		cmp eax, [ebx].DCOBJ.rcClipping.left
        jl exit
		cmp eax, [ebx].DCOBJ.rcClipping.right
        jg exit
endif
        mul ecx
        shr eax, 3
        add edi, eax
        mov eax, dwColor
		.if (cl == 8)
		  	mov [edi], al
        .elseif ((cl == 15) || (cl == 16))
		  	mov [edi], ax
        .elseif (cl == 24)
	        mov [edi], ax
        	shr eax, 16
		  	mov [edi+2],al
        .elseif (cl == 32)
			mov [edi], eax
        .endif
exit:   
        ret
        align 4
_SetPixel endp

;--- returns the RGB value or -1 in case of errors

SetPixel proc public hdc:DWORD, nXPos:DWORD, nYPos:DWORD, crColor:COLORREF

        invoke HideMouse
        invoke _GetNearestColor, hdc, crColor
        invoke _SetPixel, hdc, nXPos, nYPos, eax
        invoke ShowMouse
		@strace <"SetPixel(", hdc, ", ", nXPos, ", ", nYPos, ")=", eax>
        ret
        align 4
SetPixel endp

		end
