
;--- implements GetDeviceCaps()

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

GetDeviceCaps proc public hdc:DWORD, nIdx:DWORD
		mov ecx, hdc
		mov edx, nIdx
		xor eax, eax
		.if ([ecx].DCOBJ.dwType == GDI_TYPE_DC)
			.if (edx == TECHNOLOGY)
            	call gettechnology
			.elseif (edx == HORZRES)
				mov eax, [ecx].DCOBJ.dwWidth
			.elseif (edx == VERTRES)
				mov eax, [ecx].DCOBJ.dwHeight
			.elseif (edx == BITSPIXEL)	;should return 16 for 15 bpp!
				mov eax, [ecx].DCOBJ.dwBpp
			.elseif (edx == PLANES)
				@mov eax, 1
			.elseif (edx == RASTERCAPS)
;--- RC_DI_BITMAP: device supports GetDIBits
;--- RC_DIBTODEV: device supports SetDIBitsToDevice
            	mov eax, RC_BITBLT or RC_BITMAP64 or RC_GDI20_OUTPUT or RC_GDI20_STATE or RC_DI_BITMAP or RC_OP_DX_OUTPUT or RC_DEVBITS or RC_DIBTODEV
                .if ([ecx].DCOBJ.dwBpp <= 8)
                	or eax, RC_PALETTE
                .endif
			.elseif ((edx == LOGPIXELSX) || (edx == LOGPIXELSY))
            	mov eax,120
			.else
            	.if ([ecx].DCOBJ.dwBpp <= 8)
            		call palettevalues
                .else
                	call nopalettevalues
                .endif
			.endif
		.endif
		@strace <"GetDeviceCaps(", hdc, ", ", nIdx, ")=", eax>
		ret
        align 4
gettechnology:                
		mov eax, DT_RASDISPLAY
        retn
        align 4
palettevalues:
		.if (edx == NUMCOLORS)
           	mov eax, 20				;entries in default palette
		.elseif (edx == NUMRESERVED)
           	.if ([ecx].DCOBJ.bSysPalUse == SYSPAL_STATIC)
	           	mov eax, 20				;reserved entries in system palette
            .elseif ([ecx].DCOBJ.bSysPalUse == SYSPAL_NOSTATIC)
	           	mov eax, 2				;reserved entries in system palette
            .endif
		.elseif (edx == SIZEPALETTE)
           	mov eax, 256			;max size of a palette
		.elseif (edx == COLORRES)
           	mov eax, 3*8			;color resolution (3*8 or 3*6)
        .endif
		retn
        align 4
nopalettevalues:
		.if (edx == NUMCOLORS)
           	mov eax, -1
        .endif
		retn
        align 4
        
GetDeviceCaps endp

		end
