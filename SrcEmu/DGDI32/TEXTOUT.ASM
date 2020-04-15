
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

SetBkMode proc public hdc:DWORD, iMode:DWORD
		mov ecx, hdc
		mov eax, iMode
        xchg al, [ecx].DCOBJ.bBkMode
        @strace <"SetBkMode(", hdc, ", ", iMode, ")=", eax>
		ret
        align 4
SetBkMode endp

GetBkColor proc public hdc:DWORD
		mov ecx, hdc
        mov eax, [ecx].DCOBJ.dwBkColor
        @strace <"GetBkColor(", hdc, ")=", eax>
		ret
        align 4
GetBkColor endp

SetBkColor proc public hdc:DWORD, iColor:COLORREF

		invoke _GetNearestColor, hdc, iColor
		mov ecx, hdc
        mov [ecx].DCOBJ._BkColor, eax
        mov eax, iColor
        xchg eax, [ecx].DCOBJ.dwBkColor
        @strace <"SetBkColor(", hdc, ", ", iColor, ")=", eax, " intClr=", [ecx].DCOBJ._BkColor>
		ret
        align 4
SetBkColor endp

GetTextColor proc public hdc:DWORD
		mov ecx, hdc
        mov eax, [ecx].DCOBJ.dwTextColor
        @strace <"GetTextColor(", hdc, ")=", eax>
		ret
        align 4
GetTextColor endp

SetTextColor proc public hdc:DWORD, iColor:COLORREF

		invoke _GetNearestColor, hdc, iColor
		mov ecx, hdc
        mov [ecx].DCOBJ._TextColor, eax
        mov eax, iColor
        xchg eax, [ecx].DCOBJ.dwTextColor
        @strace <"SetTextColor(", hdc, ", ", iColor, ")=", eax, " intClr=", [ecx].DCOBJ._TextColor>
		ret
        align 4
SetTextColor endp

GetTextAlign proc public hdc:DWORD
		mov ecx, hdc
        mov eax, [ecx].DCOBJ.dwTextAlign
        @strace <"GetTextAlign(", hdc, ")=", eax>
		ret
        align 4
GetTextAlign endp

SetTextAlign proc public hdc:DWORD, fMode:DWORD
		mov ecx, hdc
        mov eax, fMode
        xchg eax, [ecx].DCOBJ.dwTextAlign
        @strace <"SetTextAlign(", hdc, ", ", fMode, ")=", eax>
		ret
        align 4
SetTextAlign endp

GetCharWidth32A proc public uses edi hdc:DWORD, iFirstChar:dword, iLastChar:dword, lpBuffer:ptr SDWORD
GetCharWidth32A endp

GetCharWidthA proc public uses edi hdc:DWORD, iFirstChar:dword, iLastChar:dword, lpBuffer:ptr SDWORD
        mov		edx, hdc
		mov		edx, [edx].DCOBJ.hFont
        mov     edx, [edx].FONTOBJ.pFontRes
        mov		ecx, iFirstChar
        mov		edi, lpBuffer
        .while (ecx <= iLastChar)
        	mov		eax, ecx
	        sub		al, [edx].FONTDIRENTRY.dfFirstChar
    	    jnc		@F
	        mov		al, [edx].FONTDIRENTRY.dfDefaultChar
@@:        
    	    movzx   eax, byte ptr [edx+eax*4+sizeof FONTDIRENTRY+5]
            stosd
            inc		ecx
        .endw
        @mov eax, 1
        @strace <"GetCharWidthA(", hdc, ", ", iFirstChar, ", ", iLastChar, ", ", lpBuffer, ")=", eax>
		ret
        align 4
GetCharWidthA endp

GetCharWidth32W proc public hdc:DWORD, iFirstChar:dword, iLastChar:dword, lpBuffer:ptr SDWORD
GetCharWidth32W endp

GetCharWidthW proc public hdc:DWORD, iFirstChar:dword, iLastChar:dword, lpBuffer:ptr SDWORD
		invoke GetCharWidthA, hdc, iFirstChar, iLastChar, lpBuffer
        @strace <"GetCharWidthW(", hdc, ", ", iFirstChar, ", ", iLastChar, ", ", lpBuffer, ")=", eax>
		ret
        align 4
GetCharWidthW endp


;--- GetCharABCWidths() is valid for TrueType fonts only (which aren't supported yet)

GetCharABCWidthsA proc public hdc:DWORD, iFirstChar:dword, iLastChar:dword, lpBuffer:ptr SDWORD
		xor eax, eax
        @strace <"GetCharABCWidthsA(", hdc, ", ", iFirstChar, ", ", iLastChar, ", ", lpBuffer, ")=", eax, " *** unsupp">
		ret
        align 4
GetCharABCWidthsA endp

GetCharABCWidthsW proc public hdc:DWORD, iFirstChar:dword, iLastChar:dword, lpBuffer:ptr SDWORD
		xor eax, eax
        @strace <"GetCharABCWidthsW(", hdc, ", ", iFirstChar, ", ", iLastChar, ", ", lpBuffer, ")=", eax, " *** unsupp">
		ret
        align 4
GetCharABCWidthsW endp

GetTextExtentPointA proc public hdc:DWORD, lpString:ptr BYTE, cbString:DWORD, lpSize:ptr SIZE_
GetTextExtentPointA endp

GetTextExtentPoint32A proc public uses esi edi ebx hdc:DWORD, lpString:ptr BYTE, cbString:DWORD, lpSize:ptr SIZE_

		mov ecx, cbString
        .if (ecx == -1)
        	invoke lstrlen, lpString
            mov ecx, eax
        .endif
        mov		edx, hdc
		mov		edx, [edx].DCOBJ.hFont
        mov     edx, [edx].FONTOBJ.pFontRes
        mov		esi, lpString
        xor		ebx, ebx
        mov		edi, ebx
        mov		eax, ebx
        .while (ecx)
			lodsb
	        sub		al, [edx].FONTDIRENTRY.dfFirstChar
    	    jnc		@F
	        mov		al, [edx].FONTDIRENTRY.dfDefaultChar
@@:        
    	    mov     bl, [edx+eax*4+sizeof FONTDIRENTRY+5]
            add		edi, ebx
        	dec ecx
        .endw
        movzx eax,[edx].FONTDIRENTRY.dfPixHeight
        mov ecx, lpSize
        mov [ecx].SIZE_.cx_, edi
        mov [ecx].SIZE_.cy, eax
        @mov eax, 1
        @strace <"GetTextExtentPoint32A(", hdc, ", ", lpString, ", ", cbString, ", ", lpSize, ")=", eax>
		ret
        align 4

GetTextExtentPoint32A endp

GetTextExtentPointW proc public hdc:DWORD, lpString:ptr WORD, cbString:DWORD, lpSize:ptr SIZE_
GetTextExtentPointW endp

GetTextExtentPoint32W proc public hdc:DWORD, lpString:ptr WORD, cbString:DWORD, lpSize:ptr SIZE_
		mov eax, lpString
        mov ecx, cbString
        call ConvertWStr
        invoke GetTextExtentPoint32A, hdc, eax, cbString, lpSize
        @strace <"GetTextExtentPoint32W(", hdc, ", ", lpString, ", ", cbString, ", ", lpSize, ")=", eax>
		ret
        align 4
GetTextExtentPoint32W endp

GetCharacterPlacementA proc public hdc:DWORD, lpString:ptr WORD, nCount:DWORD, nMaxExtent:DWORD, lpResults:ptr, dwFlags:DWORD
		xor eax, eax
        @strace <"GetCharacterPlacementA(", hdc, ", ", lpString, ", ", nCount, ", ", nMaxExtent, ", ", lpResults, ", ", dwFlags, ")=", eax>
		ret
        align 4
GetCharacterPlacementA endp

GetCharacterPlacementW proc public hdc:DWORD, lpString:ptr WORD, nCount:DWORD, nMaxExtent:DWORD, lpResults:ptr, dwFlags:DWORD
		xor eax, eax
        @strace <"GetCharacterPlacementW(", hdc, ", ", lpString, ", ", nCount, ", ", nMaxExtent, ", ", lpResults, ", ", dwFlags, ")=", eax>
		ret
        align 4
GetCharacterPlacementW endp

TextOutA proc public uses ebx esi edi hdc:DWORD, nXStart:DWORD, nYStart:DWORD,
		lpString:ptr BYTE, cbString:DWORD

local	dwPitch:dword
local	dwBpp:dword
local	dwBkColor:dword
local	dwBkMode:dword
local	dwTextColor:dword
local	lpfnSetColor:dword
local	dwPixelWidth:dword
local	bHeight:byte
local	bWidth:byte

        mov		esi, hdc
        mov		eax, [esi].DCOBJ.lPitch
        mov		dwPitch, eax
        mov		ecx, nYStart
if ?MAPPING
		add		ecx, [esi].DCOBJ.ptViewportOrg.y
endif
        mul		ecx
        
        mov		edi, [esi].DCOBJ.pBMBits
        add		edi, eax
        mov		eax, [esi].DCOBJ.dwBpp
        .if (al == 8)
        	mov lpfnSetColor, offset setcolor8
	        mov	dwPixelWidth, 1
        .elseif ((al == 16) || (al == 15))
        	mov lpfnSetColor, offset setcolor16
	        mov	dwPixelWidth, 2
        .elseif (al == 24)
        	mov lpfnSetColor, offset setcolor24
	        mov	dwPixelWidth, 3
        .elseif (al == 32)
        	mov lpfnSetColor, offset setcolor32
	        mov	dwPixelWidth, 4
        .else
	        xor eax, eax
        	jmp exit
        .endif
        mov		dwBpp, eax

        mov		ecx, nXStart
if ?MAPPING
		add		ecx, [esi].DCOBJ.ptViewportOrg.x
endif
        mul		ecx
        shr		eax, 3              ;works for bpp >= 8 only currently
        add		edi, eax
        mov		eax, [esi].DCOBJ._BkColor
        mov		edx, [esi].DCOBJ._TextColor
        movzx	ecx, [esi].DCOBJ.bBkMode
        mov		dwBkColor, eax
        mov		dwTextColor, edx
        mov		dwBkMode, ecx
        
        test	byte ptr [esi].DCOBJ.dwFlags, DCF_SCREEN
        jz		@F
        invoke	HideMouse
@@:        
		mov		ecx,[esi].DCOBJ.hFont
        mov     esi,[ecx].FONTOBJ.pFontRes
        mov     ax,[esi].FONTDIRENTRY.dfPixHeight
        mov		bHeight,al
        mov		ebx, lpString
nextchar:
		cmp		cbString,0
        jz		done
        dec		cbString
        movzx   eax,byte ptr [ebx]
        inc		ebx
        sub		al, [esi].FONTDIRENTRY.dfFirstChar
        jnc		@F
        mov		al, [esi].FONTDIRENTRY.dfDefaultChar
@@:        
        mov     dl, [esi+eax*4+sizeof FONTDIRENTRY+5]
        mov     bWidth, dl
        movzx   eax, word ptr [esi+eax*4+2+sizeof FONTDIRENTRY+5]
        push    esi
        add		esi, eax
nextrow:        
        push	edi
        mov     ch,bHeight
nextline:
        push    edi
        lodsb
        mov     dh,al
        mov     cl,80h
nextpixel:
		mov		eax,dwTextColor
        test    dh,cl
        jnz     @F
		cmp		dwBkMode, TRANSPARENT
        jz		nopixel
		mov		eax,dwBkColor
@@:
        call	lpfnSetColor
nopixel:
        add 	edi, dwPixelWidth
        shr     cl,1
        jnz     nextpixel
        
        pop		edi
        add		edi, dwPitch
        dec     ch
        jnz     nextline
        pop		edi
        mov		al, byte ptr dwPixelWidth
        mov     dl, 8
        cmp     dl, bWidth
        jnc     @F
        sub		bWidth,dl
        mul     dl
        movzx	eax, ax
        add		edi, eax
        jmp     nextrow
@@:
		mov		dl, bWidth
        mul     dl
        movzx	eax, ax
        add		edi, eax
        
        pop     esi
        jmp     nextchar
done:
		mov		ecx, hdc
        test	byte ptr [ecx].DCOBJ.dwFlags, DCF_SCREEN
		jz		@F
        invoke	ShowMouse
@@:        
		@mov	eax, 1
exit:  
		@strace <"TextOutA(", hdc, ", ", nXStart, ", ", nYStart, ", ", lpString, ", ", cbString, ")=", eax>
        ret
        align 4
setcolor8:
        mov [edi],al
        retn
        align 4
setcolor16:
        mov [edi],ax
        retn
        align 4
setcolor24:
        mov [edi],ax
        shr eax, 16
        mov [edi+2],al
        retn
        align 4
setcolor32:
        mov  [edi],eax
        retn
        align 4

TextOutA endp

TextOutW proc public uses ebx esi edi hdc:DWORD, nXStart:DWORD, nYStart:DWORD,
			lpString:ptr WORD, cbString:DWORD
            
		mov eax, lpString
        mov ecx, cbString
        call ConvertWStr
        invoke TextOutA, hdc, nXStart, nYStart, eax, cbString
		@strace <"TextOutW(", hdc, ", ", nXStart, ", ", nYStart, ", ", lpString, ", ", cbString, ")=", eax>
        ret
        align 4
TextOutW endp

ExtTextOutA proc public hdc:DWORD, nXStart:DWORD, nYStart:DWORD,
			fuOptions:DWORD, lprc:ptr RECT, lpString:ptr BYTE, cbString:DWORD,
            lpDX:ptr DWORD

		invoke TextOutA, hdc, nXStart, nYStart, lpString, cbString
		@strace <"ExtTextOutA(", hdc, ", ", nXStart, ", ", nYStart, ", ", fuOptions, ", ", lprc, ", ", lpString, ", ", cbString, ", ", lpDX, ")=", eax>
		ret
        align 4
        
ExtTextOutA endp

ExtTextOutW proc public hdc:DWORD, nXStart:DWORD, nYStart:DWORD,
			fuOptions:DWORD, lprc:ptr RECT, lpString:ptr WORD, cbString:DWORD,
            lpDX:ptr DWORD

		mov eax, lpString
        mov ecx, cbString
        call ConvertWStr
        invoke ExtTextOutA, hdc, nXStart, nYStart, fuOptions, lprc, eax, cbString, lpDX
		@strace <"ExtTextOutW(", hdc, ", ", nXStart, ", ", nYStart, ", ", fuOptions, ", ", lprc, ", ", lpString, ", ", cbString, ", ", lpDX, ")=", eax>
		ret
        align 4
        
ExtTextOutW endp

		end
