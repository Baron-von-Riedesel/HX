
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
        include vesa32.inc
        include dgdi32.inc
        include macros.inc

if ?FLAT
?VESADLL	equ 1	;1=use VESA32.DLL, 0=link vesa code statically
else
?VESADLL	equ 0	;1 not possible
endif

ife ?VESADLL
		includelib vesa32s.lib
endif

		.DATA
        
g_hdc		LPDCOBJ 0        
g_dwMode    DWORD -1
g_dwScanLine DWORD -1
g_hVesa		DWORD 0
g_bCharHeight db -1
g_bMouse	DB 0
g_bInit		db 0
		align 4

protoGetVesaMode typedef proto 
LPFNGETVESAMODE typedef ptr protoGetVesaMode
protoGetVesaModeInfo typedef proto :DWORD, :ptr SVGAINFO
LPFNGETVESAMODEINFO typedef ptr protoGetVesaModeInfo
protoGetVesaDisplayStart typedef proto
LPFNGETVESADISPLAYSTART typedef ptr protoGetVesaDisplayStart

g_lpfnGetVesaMode			LPFNGETVESAMODE 0
g_lpfnGetVesaModeInfo		LPFNGETVESAMODEINFO 0
g_lpfnGetVesaPaletteEntries	LPFNGETVESAPALETTEENTRIES 0
g_lpfnSetVesaPaletteEntries	LPFNSETVESAPALETTEENTRIES 0
g_lpfnGetVesaDisplayStart   LPFNGETVESADISPLAYSTART 0

_initsyspal proto

        .CODE

_ClearFontStock proto

if ?VESADLL
deleteVesaLib proc
		invoke FreeLibrary, g_hVesa
		ret
        align 4
deleteVesaLib endp
endif   

GetVesaProcs proc public uses esi

if ?VESADLL
		.if (!g_hVesa)
	       	invoke LoadLibrary, CStr("VESA32")
    	    .if (eax)
	           	mov esi, eax
                mov g_hVesa, eax
		        invoke atexit, offset deleteVesaLib
    	       	invoke GetProcAddress, esi, CStr("VesaMouseInit")
                .if (eax)
                	call eax
                    mov g_bMouse, al
                .endif
    	       	invoke GetProcAddress, esi, CStr("GetVesaMode")
	           	mov g_lpfnGetVesaMode, eax
    	        .if (eax)
	    	       	invoke GetProcAddress, esi, CStr("GetVesaModeInfo")
	    	       	mov g_lpfnGetVesaModeInfo, eax
                    .if (eax)
		            	invoke GetProcAddress, esi, CStr("SetVesaPaletteEntries")
	                	mov g_lpfnSetVesaPaletteEntries, eax
	                    .if (eax)
			            	invoke GetProcAddress, esi, CStr("GetVesaPaletteEntries")
	    	            	mov g_lpfnGetVesaPaletteEntries, eax
	                        .if (eax)
		   	    		      	invoke GetProcAddress, esi, CStr("GetVesaDisplayStart")
	    		              	mov g_lpfnGetVesaDisplayStart, eax
		           	        .endif
	        	        .endif
	                .endif
    	        .endif
   	        .endif
        .endif
else        
		.if (!g_hVesa)
        	mov g_hVesa, 1
            invoke VesaMouseInit
            mov g_bMouse, al
        .endif
        mov g_lpfnGetVesaMode, offset GetVesaMode
       	mov g_lpfnGetVesaModeInfo, offset GetVesaModeInfo
       	mov g_lpfnSetVesaPaletteEntries, offset SetVesaPaletteEntries
       	mov g_lpfnGetVesaPaletteEntries, offset GetVesaPaletteEntries
       	mov g_lpfnGetVesaDisplayStart, offset GetVesaDisplayStart
        @mov eax, 1
endif            
		ret
        align 4
GetVesaProcs endp

getdisplaydc proc public uses ebx

local	svgainfo:SVGAINFO
local	palentry[255]:PALETTEENTRY
local	logpal:LOGPALETTE

		invoke GetVesaProcs
if 1        
		invoke g_lpfnGetVesaDisplayStart
        mov ebx, eax
        .if (ebx == -1)	;did call succeed?
        	inc ebx		;no, then use scanline 0
        .endif
else
		xor ebx, ebx
endif
		invoke g_lpfnGetVesaMode
		.if ((eax != g_dwMode) || (ebx != g_dwScanLine))
			mov g_dwMode, eax
            mov g_dwScanLine, ebx
			mov ebx, g_hdc
            .if (!ebx)
				invoke _GDImalloc2, sizeof DCOBJ
                and eax, eax
                jz exit
                mov ebx, eax
            .endif
			invoke g_lpfnGetVesaModeInfo, g_dwMode, addr svgainfo
            .if (!eax || (svgainfo.MemoryModel < 4))
;--- currently a text mode (or unsupported gfx mode) is active.
;--- assume a "safe" VESA mode: 640x480x16
				invoke g_lpfnGetVesaModeInfo, 111h + 4000h, addr svgainfo
                and eax, eax
                jz exit
                mov g_dwMode, 111h
                mov g_dwScanLine, 0
			.endif
			mov [ebx].DCOBJ.dwType, GDI_TYPE_DC
			movzx eax, svgainfo.XResolution
			movzx ecx, svgainfo.BytesPerScanLine
			mov [ebx].DCOBJ.dwWidth,eax
if ?CLIPPING
			mov [ebx].DCOBJ.rcClipping.right,eax
endif
			mov [ebx].DCOBJ.lPitch,ecx
			movzx eax, svgainfo.YResolution
			mov [ebx].DCOBJ.dwHeight,eax
if ?CLIPPING					
			mov [ebx].DCOBJ.rcClipping.bottom, eax
endif					 
			mov al, svgainfo.YCharSize
			and al,al
			jz @F
if 1
			test svgainfo.ModeAttributes, VESAATTR_BIOS_OUTPUT
            jz @F
endif
			mov ah, svgainfo.XCharSize
			.if (ah > 9)
				shl al,1
			.endif
			.if (al != g_bCharHeight)
				push eax
				invoke _ClearFontStock
				pop eax
			.endif
			mov g_bCharHeight, al
@@: 				   
			@strace <"getdisplaydc: g_bCharHeight=", eax>
			mov eax, g_dwScanLine
			mul ecx
			add eax, svgainfo.PhysBasePtr
			mov [ebx].DCOBJ.pBMBits, eax
			mov [ebx].DCOBJ.pOrigin, eax
			movzx eax, svgainfo.BitsPerPixel
			mov [ebx].DCOBJ.dwBpp,eax
            mov cl, svgainfo.MemoryModel
			.if (cl == 4)  
;				mov [ebx].DCOBJ.bSysPalUse, SYSPAL_NOSTATIC
				mov [ebx].DCOBJ.bSysPalUse, SYSPAL_STATIC
				.if (!g_bInit)
					mov g_bInit, 1
					call _initsyspal
;;					invoke RealizePalette, ebx
				.endif
			.else
				mov [ebx].DCOBJ.bSysPalUse, SYSPAL_ERROR
			.endif
            mov [ebx].DCOBJ.dwFlags, DCF_SCREEN
;--- as default there should *always* be a palette in a DC
			invoke GetStockObject, DEFAULT_PALETTE
			invoke SelectPalette, ebx, eax, 0
			invoke GetStockObject, WHITE_BRUSH
			invoke SelectObject, ebx, eax
			mov [ebx].DCOBJ.bBkMode, OPAQUE
			invoke SetBkColor, ebx, 0FFFFFFh
			invoke GetStockObject, BLACK_PEN
			mov [ebx].DCOBJ.hPen, eax
			invoke SetTextColor, ebx, 0
			invoke GetStockObject, SYSTEM_FONT
			.if (!eax)
			   invoke GetStockObject, OEM_FIXED_FONT
			.endif
			mov [ebx].DCOBJ.hFont, eax
			mov [ebx].DCOBJ.bMapMode, MM_TEXT
			mov [ebx].DCOBJ.bROP2, R2_COPYPEN
			mov [ebx].DCOBJ.bGraphicsMode, GM_COMPATIBLE
			mov g_hdc, ebx
			mov eax, ebx
		.else
			mov eax, g_hdc
		.endif
exit:        
ifdef _DEBUG        
		.if (eax)
	        @strace <"getdisplaydc: ", eax, ", ", [eax].DCOBJ.dwWidth, "x", [eax].DCOBJ.dwHeight, "x", [eax].DCOBJ.dwBpp, ", ", [eax].DCOBJ.pBMBits>
        .else
	        @strace <"getdisplaydc()=0">
        .endif
endif        
		ret
        align 4
getdisplaydc endp

		end
