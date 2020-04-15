
        .486
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

externdef g_syspal:PALETTEOBJ

;--- eax contains color
;--- ebx -> color table

        .CODE

_col16to8 proc public
if 1
		pushad
        call _col16to24
        jmp _col24to8_1
else
		ret
endif
		align 4
_col16to8 endp

_col24to8 proc public
		pushad
_col24to8_1::
        xor esi, esi
        or edi, -1
        mov dl,al
        shr eax, 8
		.repeat
			mov cx,[ebx+esi*4+0]       ;RED+GREEN
			mov dh,[ebx+esi*4+2]       ;BLUE
			sub cl,dl
			jnc @F
			neg cl
@@:
			sub ch,al
			jnc @F
			neg ch
@@:
			sub dh,ah
			jnc @F
			neg dh
@@:
            movzx ebp, cl
            movzx ecx, ch
            add ebp, ecx
            mov cl, dh
            add ebp, ecx
			cmp ebp, edi
			jnc @F
			mov edi, ebp
			mov [esp+1Ch], esi	;=EAX
            and ebp,ebp
            jz done
@@:
			inc esi
		.until (esi >= 256)
done:        
        popad
        ret
        align 4
_col24to8 endp

_col8to24 proc public
		movzx eax, al
		mov eax, [ebx+eax]
        ret
        align 4
_col8to24 endp

_col24to15 proc public
		mov edx, eax
        shr eax, 3			;0000FF -> 00001F
        and eax, 01Fh
        push eax
        mov eax, edx
        shr eax, 3+3		;00FF00 -> 0003FC
        and eax, 03E0h		;0003FC -> 0003E0
        push eax
        mov eax, edx
        shr eax, 3+3+3		;FF0000 -> 007F80
        and eax, 07C00h		;007F80 -> 007C00
        pop edx
        or eax, edx
        pop edx
        or eax, edx
        ret
        align 4
_col24to15 endp

_col15to24 proc public
		mov edx, eax
        shl eax, 3
        add al, 4
        and eax, 0FFh
        push eax
        mov eax, edx
        shl eax, 3+3
        add ah, 4
        and eax, 0FF00h
        push eax
        mov eax, edx
        shl eax, 3+3+3
        add eax, 40000h
        and eax, 0FF0000h
        pop edx
        or eax, edx
        pop edx
        or eax, edx
        ret
        align 4
_col15to24 endp

_col24to16 proc public
		mov edx, eax
        shr eax, 3
        and eax, 01Fh
        push eax
        mov eax, edx
        shr eax, 3+2
        and eax, 07E0h
        push eax
        mov eax, edx
        shr eax, 3+2+3
        and eax, 0F800h
        pop edx
        or eax, edx
        pop edx
        or eax, edx
        ret
        align 4
_col24to16 endp

;--- RRRRRGGGGGGBBBBB -> RRRRR100GGGGGG10BBBBB100

_col16to24 proc public
		mov edx,eax
        shl eax,8		;EAL=RRRRRGGG
        and eax, 0F80000h ;EAL=RRRRR000 (0-F8)
        mov ax,dx		;AH=RRRRRGGG
        shl ax,5		;AH=GGGGGGBB
        and ah, 0FCh	;AH=GGGGGG00 (0-FC)
        mov al,dl
        and al,01Fh 	;AL=000BBBBB
        shl al,3		;AL=BBBBB000 (0-F8)
        add eax, 040204h
        ret
        align 4
_col16to24 endp

;--- returns a color suitable for current color mode
;--- (8 bpp palette index, 15/16/24/32 bpp)

;--- dont confuse the PALETTEINDEX flag with the PC_RESERVED flag.
;--- the second is for PALETTEENTRYs only, the first is set in
;--- a COLORREF to indicate that the real color should be retrieved
;--- from the current (logical) palette.

_GetNearestColor proc public hdc:dword, colorref:COLORREF

		mov eax, colorref		;format 00BBGGRR or 0100iiii
		mov ecx, hdc
		jecxz error
		.if (eax & 01000000h)	;is is a PALETTEINDEX?
			movzx eax,al
			mov edx, [ecx].DCOBJ.pColorTab
			mov eax, [edx+eax*4]
			test eax, PC_EXPLICIT shl 24
			jz @F
			movzx eax, al
			mov eax, [offset g_syspal.ColorTab + eax*4]
@@: 		   
			and eax, 0FFFFFFh
		.endif
		mov edx, [ecx].DCOBJ.dwBpp
		.if (edx <= 8)
			invoke GetNearestPaletteIndex, offset g_syspal, eax
		.elseif (edx == 15)
			shl eax, 8
			bswap eax
			call _col24to15
		.elseif (edx == 16)
			shl eax, 8
			bswap eax
			call _col24to16
		.endif
		ret
error:
		xor eax,eax
		ret
		align 4
_GetNearestColor endp

		end
