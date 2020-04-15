
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

PatBlt proc public uses esi edi ebx hdc:DWORD, nXLeft:DWORD, nYLeft:DWORD,
			nWidth:DWORD, nHeight:DWORD, dwRop:DWORD

local	lpfnClrProc:DWORD
local	dwPitch:DWORD
local	dwWidth:DWORD
local	dwHeight:DWORD

		@strace <"PatBlt(", hdc, ", ", nXLeft, ", ", nYLeft, ", ", nWidth, ", ", nHeight, ", ", dwRop, ")">
        mov ebx, hdc
        test byte ptr [ebx].DCOBJ.dwFlags, DCF_SCREEN
        jz @F
        invoke HideMouse
@@:        
        .if (dwRop == PATCOPY)
            mov edi, [ebx].DCOBJ.pBMBits
            mov eax, nYLeft
if ?MAPPING
			add eax, [ebx].DCOBJ.ptViewportOrg.y
endif
if ?CLIPPING
			cmp eax, [ebx].DCOBJ.rcClipping.top
            jge @F
            mov eax, [ebx].DCOBJ.rcClipping.top
@@:            
endif
            mov edx, [ebx].DCOBJ.lPitch
            mov dwPitch, edx
            mul edx
            add edi, eax
            mov eax, nXLeft
if ?MAPPING
			add eax, [ebx].DCOBJ.ptViewportOrg.x
endif
if ?CLIPPING
			cmp eax, [ebx].DCOBJ.rcClipping.left
            jge @F
            mov eax, [ebx].DCOBJ.rcClipping.left
@@:            
endif
            mov edx, [ebx].DCOBJ.dwBpp
            mul edx
            shr eax, 3
            add edi, eax
            mov eax, [ebx].DCOBJ.dwBpp
            shr eax, 3
            cmp eax, 5
            jnc error
            mov edx, [eax*4 + offset bltprocs]
            mov lpfnClrProc, edx
            mov eax,[ebx].DCOBJ._BrushColor
            .if (eax == -1)
	            mov eax,[ebx].DCOBJ.hBrush
            	.if ([eax].BRUSHOBJ.dwStyle == BS_PATTERN)
                	call fillpattern
                    jmp done
                .endif
            .endif
if ?CLIPPING
			mov ecx, nYLeft
if ?MAPPING
			add ecx, [ebx].DCOBJ.ptViewportOrg.y
endif
            add ecx, nHeight
            cmp ecx, [ebx].DCOBJ.rcClipping.top
            jl done
            cmp ecx, [ebx].DCOBJ.rcClipping.bottom
            jle @F
            sub ecx, [ebx].DCOBJ.rcClipping.bottom
            sub nHeight, ecx
@@:         
			mov ecx, nXLeft
if ?MAPPING
			add ecx, [ebx].DCOBJ.ptViewportOrg.x
endif
            add ecx, nWidth
            cmp ecx, [ebx].DCOBJ.rcClipping.left
            jl done
            cmp ecx, [ebx].DCOBJ.rcClipping.right
            jle @F
            sub ecx, [ebx].DCOBJ.rcClipping.right
            sub nWidth, ecx
@@:         
endif
            mov ebx,[ebx].DCOBJ.pColorTab
            .while (nHeight)
            	push edi
                mov ecx, nWidth
                call lpfnClrProc
                pop edi
                add edi, dwPitch
            	dec nHeight
            .endw
done:            
            mov eax, 1
		.else
error:        
        	xor eax, eax
        .endif
        mov ebx, hdc
        test byte ptr [ebx].DCOBJ.dwFlags, DCF_SCREEN
        jz @F
        invoke ShowMouse
@@:        
        ret
        align 4
fill08:
        mov ah,al
        mov dx,ax
        shl eax,16
        mov ax,dx
        mov lpfnClrProc, offset fill08_1
fill08_1:        
		mov dl,cl
        shr ecx, 2
        rep stosd
        mov cl,dl
        and cl,3
		rep stosb
fill00: 
        retn
        align 4
fill16:
		mov dx,ax
        shl eax,16
        mov ax,dx
        mov lpfnClrProc, offset fill16_1
fill16_1:
		shr ecx, 1
		rep stosd
        adc cl,cl
        rep stosw
        retn
        align 4
fill24:
		mov edx, eax
        shr edx, 16
        mov lpfnClrProc, offset fill24_1
fill24_1:        
@@:                	
		mov [edi+0],ax
        mov [edi+2],dl
        add edi, 3
        dec ecx
        jnz @B
        retn
        align 4
fill32:        
		rep stosd
        retn
        align 4
fillpattern:
		invoke CreateCompatibleDC, hdc
        .if (eax)
        	mov esi, eax
            mov eax, [ebx].DCOBJ.hBrush
            mov ebx, [eax].BRUSHOBJ.hBitmap
            invoke SelectObject, esi, ebx
            push eax
            mov ebx, [ebx].BITMAPOBJ.pBitmap
            mov ecx, [ebx].BITMAPINFOHEADER.biHeight
            mov eax, [ebx].BITMAPINFOHEADER.biWidth
            and ecx, ecx
            jns @F
            neg ecx
@@:            
            mov dwHeight, ecx
            mov dwWidth, eax
            mov ebx, nHeight
            .while (ebx)
	            mov edi, nWidth
                mov ecx, nXLeft
            	.while (edi)
                	push ecx
                    mov edx, dwWidth
                    .if (edi < edx)
                    	mov edx, edi
                    .endif
                    mov eax, dwHeight
                    .if (ebx < eax)
                    	mov eax, ebx
                    .endif
		            invoke BitBlt, hdc, ecx, nYLeft, edx, eax, esi, 0, 0, SRCCOPY
                    pop ecx
                    add ecx, dwWidth
    	            sub edi, dwWidth
                    .break .if (CARRY?)
                    .break .if (ZERO?)
                .endw
                mov eax, dwHeight
                add nYLeft, eax
                sub ebx, eax
                .break .if (CARRY?)
                .break .if (ZERO?)
            .endw
            pop eax
            invoke SelectObject, esi, eax
        	invoke DeleteDC, esi
        .endif
		retn
        align 4

bltprocs label dword
		dd offset fill00
        dd offset fill08
        dd offset fill16
        dd offset fill24
        dd offset fill32

PatBlt endp


		end
