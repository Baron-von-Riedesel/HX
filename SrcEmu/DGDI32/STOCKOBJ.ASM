
        .386
if ?FLAT
        .MODEL FLAT, stdcall
else
        .MODEL SMALL, stdcall
endif
		option casemap:none
        option proc:private

?PREFERINT43	equ 1	;prefer int 43 charset for OEM fixed font
?ALIGN8			equ 1	;align charset character height to 8 lines
?USE101130		equ 1

		.nolist
        .nocref
        include winbase.inc
        include wingdi.inc
        include dgdi32.inc
        include dpmi.inc
        include macros.inc
        .cref
        .list

		.DATA

hBrWhite	BRUSHOBJ <<GDI_TYPE_BRUSH>, BS_SOLID, <0FFFFFFh>>
hBrLtGray	BRUSHOBJ <<GDI_TYPE_BRUSH>, BS_SOLID, <0C0C0C0h>>
hBrGray		BRUSHOBJ <<GDI_TYPE_BRUSH>, BS_SOLID, <0808080h>>
hBrDkGray	BRUSHOBJ <<GDI_TYPE_BRUSH>, BS_SOLID, <0404040h>>
hBrBlack 	BRUSHOBJ <<GDI_TYPE_BRUSH>, BS_SOLID, <0000000h>>
hPenBlack 	PENOBJ   <<GDI_TYPE_PEN>, PS_SOLID, 0000000h>
hPenWhite 	PENOBJ   <<GDI_TYPE_PEN>, PS_SOLID, 0FFFFFFh>
hPenNull 	PENOBJ   <<GDI_TYPE_PEN>, PS_NULL, 0000000h>
hFontOemFix FONTOBJ  <<GDI_TYPE_FONT>,  0000000h>
hFontSystem FONTOBJ  <<GDI_TYPE_FONT>,  0000000h>
hSysPalette label PALETTEOBJ
			GDIOBJ <GDI_TYPE_PALETTE>
            dd 0
            dd 20
            dd 0
            COLORREF RGB(  0h,  0h,  0h)	;0 black
            COLORREF RGB( 80h,  0h,  0h)	;1 red 
	        COLORREF RGB(  0h, 80h,  0h)	;2 green
            COLORREF RGB( 80h, 80h,  0h)	;3 yellow
            COLORREF RGB(  0h,  0h, 80h)	;4 blue
            COLORREF RGB( 80h,  0h, 80h)	;5 magenta
            COLORREF RGB(  0h, 80h, 80h)	;6 cyan   
            COLORREF RGB(0C0h,0C0h,0C0h)	;7 light gray
            COLORREF RGB(0C0h,0DCh,0C0h)	;8 
            COLORREF RGB(0A6h,0CAh,0F0h)	;9
            
	        COLORREF RGB(0E0h,0E0h,0E0h)	;246
            COLORREF RGB(0A0h,0A0h,0A4h)	;247
            COLORREF RGB( 80h, 80h, 80h)	;248 dark gray
            COLORREF RGB(0ffh,  0h,  0h)	;249 red
	        COLORREF RGB(  0h,0ffh,  0h)	;250 green
            COLORREF RGB(0ffh,0ffh,  0h)	;251 yellow
            COLORREF RGB(  0h,  0h,0ffh)	;252 blue
            COLORREF RGB(0ffh,  0h,0ffh)	;253 magenta
            COLORREF RGB(  0h,0ffh,0ffh)	;254 cyan
            COLORREF RGB(0ffh,0ffh,0ffh)	;255 white


        .CODE

deleteOEMfixfont proc
		invoke _GDIfree, hFontOemFix.pFontRes
		ret
        align 4
deleteOEMfixfont endp

;--- the OEM fixed font is created by using the bitmaps at INT 43h!
;--- this is the only font which will work in DOS without AddFontResource()

createOEMfixfont proc uses ebx esi edi

local	dwHeight:dword
local	dwCharsetHeight:dword
local	dwSize:dword
ife ?PREFERINT43
local	logfont:LOGFONTA
endif

ife ?PREFERINT43
		invoke RtlZeroMemory, addr logfont, sizeof LOGFONTA
        mov logfont.lfCharSet, OEM_CHARSET
        mov logfont.lfPitchAndFamily, FIXED_PITCH
        invoke lstrcpy, addr logfont.lfFaceName, CStr("terminal")
		invoke _FindFontResource, addr logfont
       	mov hFontOemFix.pFontRes, eax
        and eax, eax
        jnz exit
endif
if 0
		movzx ecx, byte ptr @flat:[485h]
else
		movzx ecx, g_bCharHeight
        .if (cl == -1)
if ?USE101130
			mov ecx,16
else
			movzx ecx, byte ptr @flat:[485h]
endif            
        .endif
endif
		@strace <"createOEMFixedFont enter, charheight=", ecx>
		mov dwHeight, ecx
if ?ALIGN8
        mov dl,cl
        and cl,0F8h
        test dl,7
        jz @F
        add cl, 8
@@:
endif
		mov dwCharsetHeight,ecx
		@strace <"dwHeight=", dwHeight, ", dwCharsetHeight=", dwCharsetHeight>
        shl ecx, 8			;*256
        add ecx, 4*256
        add ecx, sizeof FONTDIRENTRY+5
        invoke _GDImalloc2, ecx
        and eax, eax
        jz exit
		mov hFontOemFix.pFontRes, eax
        mov ecx, dwHeight
        mov [eax].FONTDIRENTRY.dfPixHeight, cx
        mov [eax].FONTDIRENTRY.dfAvgWidth, 8
        mov [eax].FONTDIRENTRY.dfCharSet, OEM_CHARSET
        mov [eax].FONTDIRENTRY.dfLastChar, -1
        lea edi, [eax+sizeof FONTDIRENTRY + 5]
        mov edx, sizeof FONTDIRENTRY + 5 + 256*4
        mov ecx, 256
        .while (ecx)
            mov ax, dx
            shl eax, 16
        	mov ax,8
            stosd
            add edx, dwCharsetHeight
            dec ecx
        .endw
if ?USE101130
		cmp g_bCharHeight,-1
        jnz @F
		push edi
		sub esp,34h
        mov edi, esp
        mov [edi].RMCS.rSSSP,0
        mov [edi].RMCS.rFlags,0
        mov [edi].RMCS.rBX, 0600h	;bh=6 (8x16 font)
        mov [edi].RMCS.rAX, 1130h
        mov bx,0010h
        xor cx,cx
        mov ax,0300h
        int 31h
        movzx edx,[edi].RMCS.rBP
        movzx ecx,[edi].RMCS.rES
        shl ecx,4
        add ecx, edx
        add esp,34h
        pop edi
        jmp gotcharset
@@:        
endif        
		mov bl,43h
		mov ax,0200h
		int 31h
		movzx ecx,cx
		shl ecx,4
		movzx edx,dx
		add ecx, edx
		@strace <"int 43h pointer=", ecx, " dst=", edi>
gotcharset:        
        mov esi, ecx
        mov ecx, dwHeight
        shl ecx, 8-2            ;* 64
ife ?FLAT
		push ds
        push @flat
        pop ds
endif
		rep movsd
ife ?FLAT
		pop ds
endif
        invoke atexit, offset deleteOEMfixfont
exit:        
		ret
        align 4
createOEMfixfont endp

;--- the system font 

createSystemfont proc

local	logfont:LOGFONTA

		invoke RtlZeroMemory, addr logfont, sizeof LOGFONTA
        mov logfont.lfCharSet, DEFAULT_CHARSET
        mov logfont.lfPitchAndFamily, DEFAULT_PITCH
        invoke lstrcpy, addr logfont.lfFaceName, CStr("system")
		invoke _FindFontResource, addr logfont
       	mov hFontSystem.pFontRes, eax
		@strace <"createSystemfont()=", eax>
		ret
        align 4
createSystemfont endp

GetStockObject proc public fnObj:DWORD

        mov ecx, fnObj
        .if (ecx == WHITE_BRUSH)
        	mov eax, offset hBrWhite
        .elseif (ecx == LTGRAY_BRUSH)
        	mov eax, offset hBrLtGray
        .elseif (ecx == GRAY_BRUSH)
        	mov eax, offset hBrGray
        .elseif (ecx == DKGRAY_BRUSH)
        	mov eax, offset hBrDkGray
        .elseif (ecx == BLACK_BRUSH)
        	mov eax, offset hBrBlack
        .elseif (ecx == BLACK_PEN)
        	mov eax, offset hPenBlack
        .elseif (ecx == WHITE_PEN)
        	mov eax, offset hPenWhite
        .elseif (ecx == NULL_PEN)
        	mov eax, offset hPenNull
        .elseif (ecx == OEM_FIXED_FONT)
getoemfixed:        
            .if (!hFontOemFix.pFontRes)
            	call createOEMfixfont
            .endif
        	mov eax, offset hFontOemFix
        .elseif (ecx == SYSTEM_FONT)
            .if (!hFontSystem.pFontRes)
            	call createSystemfont
            .endif
;--- creating the system font may fail
;--- because there is no such font in dos/vga.
;--- it may only work if a font has been added with AddFontResource()!
            .if (hFontSystem.pFontRes)
	        	mov eax, offset hFontSystem
            .else
            	jmp getoemfixed
            .endif
        .elseif (ecx == DEFAULT_PALETTE)
        	mov eax, offset hSysPalette
        .else
        	xor eax, eax
        .endif
		@strace <"GetStockObject(", fnObj, ")=", eax>
        ret
        align 4

GetStockObject endp

_ClearFontStock proc public
        .if (hFontOemFix.pFontRes)
			invoke _GDIfree, hFontOemFix.pFontRes
            mov hFontOemFix.pFontRes, 0
        .endif
        .if (hFontSystem.pFontRes)
			invoke _GDIfree, hFontSystem.pFontRes
            mov hFontSystem.pFontRes, 0
        .endif
		ret
        align 4
_ClearFontStock endp

		end
