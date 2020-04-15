
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

?FONTEXTRA	equ 4	;extra bytes

RESTYPE	struct
wType   dw ?
wCnt	dw ?
dwHdlr	dd ?
RESTYPE ends

RESHDR	struct
wOfs	dw ?
wLength	dw ?
wFlags	dw ?
wID		dw ?
wHandle	dw ?
wCount	dw ?
RESHDR	ends

FONTRESHDR struct
pNext	dd ?
dwType	dd ?
FONTRESHDR ends

		.DATA
        
g_pFonts	dd 0
g_bDestAdded db 0

        .CODE

;--- delete all fonts which were added

_deleteallfontresource proc
		mov eax, g_pFonts
        .while (eax)
        	push dword ptr [eax].FONTRESHDR.pNext
            invoke _GDIfree, eax
            pop eax
        .endw
		ret
        align 4
_deleteallfontresource endp

;--- todo: check if a font is already installed

AddFontResourceA proc public uses ebx esi edi lpszFilename:ptr BYTE

local	rc:dword
local	dwOfs:dword
local	dwSize:dword
local	dwType:dword
local	dwResSize:dword
local	dwShift:dword
local	dwEsp:DWORD
local	header[64]:byte

        mov rc,0
        mov dwEsp, esp
        invoke _lopen, lpszFilename, OF_READ
        .if (eax != -1)
        	mov ebx, eax
            invoke _lread, ebx, addr header, 64
            .if (eax == 64)
            	.if (word ptr header == "ZM")
                	mov eax, dword ptr header+3Ch
                    mov dwOfs, eax
                    invoke _llseek, ebx, eax, FILE_BEGIN
                    invoke _lread, ebx, addr header, 64
                .endif
                .if (word ptr header == "EN")
                	movzx edx, word ptr header+36
                    movzx eax, word ptr header+38
                    sub eax, edx
                    jc done
                    jz done
                    mov dwResSize, eax
                    add dwOfs, edx
                    invoke _llseek, ebx, dwOfs, FILE_BEGIN
                    sub esp, dwResSize
                    mov edx, esp
                    invoke _lread, ebx, edx, dwResSize
                    mov esi, esp
                    lodsw
                    movzx eax,ax
                    mov dwShift, eax
                    .while (esi < dwEsp)
						movzx eax, [esi].RESTYPE.wType
                        movzx ecx, [esi].RESTYPE.wCnt
                        add esi, sizeof RESTYPE
                        mov dwType, eax
;--- is it a FONTDIR or FONT resource?
                    	.if ((ax == 7 + 8000h) || (ax == 8 + 8000h))
                            .while (ecx)
                                push ecx
                            	movzx eax, [esi].RESHDR.wLength
                                mov ecx, dwShift
                                shl eax, cl
                                mov dwSize, eax
                                add eax, sizeof FONTRESHDR
                                invoke _GDImalloc, eax
                                and eax, eax
                                jz done
                                mov ecx, dwType
                                mov [eax].FONTRESHDR.dwType, ecx
                                lea edi, [eax+sizeof FONTRESHDR]
                                movzx eax, [esi].RESHDR.wOfs
                                mov ecx, dwShift
                                shl eax, cl
                                invoke _llseek, ebx, eax, FILE_BEGIN
                                invoke _lread, ebx, edi, dwSize
                                lea eax, [edi-sizeof FONTRESHDR]
                                mov [eax].FONTRESHDR.pNext,NULL
                                lea edx, g_pFonts
                                .while (dword ptr [edx])
                                	mov edx, [edx]
                                .endw
                                mov [edx], eax
                                .if (!g_bDestAdded)
                                	mov g_bDestAdded, 1
                                    invoke atexit, offset _deleteallfontresource
                                .endif
                                .if (dwType == 7 + 8000h)
                                	inc rc
                                .endif
                            	add esi, sizeof RESHDR
                                pop ecx
                                dec ecx
                            .endw
                        .else
                            .while (ecx)
                            	add esi, sizeof RESHDR
                            	dec ecx
                            .endw
                        .endif
                    .endw
                .endif
            .endif
done:   
        	invoke _lclose, ebx
        .endif
        mov esp, dwEsp
        mov eax, rc
		@strace <"AddFontResourceA(", lpszFilename, ")=", eax>
        ret
        align 4

AddFontResourceA endp

;--- find a matching font resource 

_FindFontResource proc public uses ebx esi edi lpLogFont:ptr LOGFONTA

local	dwPixelHeight:DWORD
local	bNameMatch:BYTE


        mov esi, lpLogFont
ifdef _DEBUG
		lea ecx, [esi].LOGFONTA.lfFaceName
endif
		@strace <"_FindFontResource(", esi, " [height=", [esi].LOGFONTA.lfHeight, ", facename=", &ecx, ")">
		xor edi, edi
        mov bNameMatch, 0
    	mov ebx, g_pFonts
        mov eax, [esi].LOGFONTA.lfHeight
        and eax, eax
        jns @F
        neg eax
@@:        
        mov ecx, 72
        mul ecx
        mov ecx, 120			;120 = GetDeviceCaps(hdc, LOGPIXELSY)
        div ecx
        mov dwPixelHeight, eax
        .if (!eax)
        	mov dwPixelHeight, 16
        .endif

        @strace <"dwPixelHeight=", eax>
        
        .while (ebx)
        	.if ([ebx].FONTRESHDR.dwType != 7 + 8000h)
	        	mov ebx,[ebx].FONTRESHDR.pNext
                .continue
            .endif
			lea edx, [ebx+sizeof FONTRESHDR]
			mov ebx, [ebx].FONTRESHDR.pNext
			.if ([esi].LOGFONTA.lfFaceName)
;--- for some unknown reason there are 4 extra bytes  in the resource
;--- at the start
				add edx, ?FONTEXTRA
				lea edx, [edx+sizeof FONTDIRENTRY]
				.while (byte ptr [edx])
					inc edx
				.endw
				inc edx
				@strace <"found FontResource: ", &edx>
				invoke lstrcmpi, addr [esi].LOGFONTA.lfFaceName, edx
if 0                
				.continue .if (eax)
				lea edi, [ebx + sizeof FONTRESHDR]
                mov bNameMatch, TRUE
else
				.if (!eax)
	                mov bNameMatch, TRUE
					lea edi, [ebx + sizeof FONTRESHDR]
                .endif
endif
			.endif
			.if (dwPixelHeight)
				.if (edi)
					movzx edx, [edi].FONTDIRENTRY.dfPixHeight
				.else
					or edx,-1
				.endif
				sub edx, dwPixelHeight
				jnc @F
				neg edx
@@: 					   
				.while (ebx && ([ebx].FONTRESHDR.dwType == 8 + 8000h))
					movzx ecx, [ebx+sizeof FONTRESHDR].FONTDIRENTRY.dfPixHeight
					sub ecx, dwPixelHeight
					jnc @F
					neg ecx
@@: 						   
					.if (ecx < edx)
						mov edx, ecx
						lea edi, [ebx+sizeof FONTRESHDR]
					.endif
					mov ebx, [ebx].FONTRESHDR.pNext
				.endw
			.endif
			.break .if (bNameMatch)
        .endw
		mov eax, edi
		ret
        align 4
_FindFontResource endp

;--- fill a TEXTMETRICA/W structure from a FONTDIRENTRY

_FillTextMetric proc public uses esi ebx lpTM:ptr TEXTMETRICA, pFontRes:ptr FONTDIRENTRY

		mov esi, pFontRes
		mov ebx, lpTM
        


		invoke RtlZeroMemory, ebx, sizeof TEXTMETRICA
		movzx eax, [esi].FONTDIRENTRY.dfPixHeight

        mov ecx, 120
        mul ecx
        movzx ecx, [esi].FONTDIRENTRY.dfVertRes
        and ecx, ecx
        jnz @F
        mov ecx, 120
@@:        
        div ecx

		movzx ecx, [esi].FONTDIRENTRY.dfAvgWidth
		mov dl, [esi].FONTDIRENTRY.dfPitchAndFamily
		mov [ebx].TEXTMETRICA.tmHeight, eax
		mov [ebx].TEXTMETRICA.tmAveCharWidth, ecx
		mov [ebx].TEXTMETRICA.tmPitchAndFamily, dl
		mov al, [esi].FONTDIRENTRY.dfCharSet
		mov [ebx].TEXTMETRICA.tmCharSet, al
		movzx eax, [esi].FONTDIRENTRY.dfWeight
		mov [ebx].TEXTMETRICA.tmWeight, eax
		@mov eax, 1
		ret
        align 4
_FillTextMetric endp

;--- enum font resources

_EnumFontResource proc public uses ebx lpLogfont:ptr LOGFONTA, lpCallBack:ptr, lParam:DWORD

local	szFaceName[LF_FACESIZE]:byte
local	tm:TEXTMETRICA

		mov szFaceName,0
    	mov ebx, g_pFonts
        .while (ebx)
        	.if ([ebx].FONTRESHDR.dwType == 7 + 8000h)
				lea edx, [ebx+sizeof FONTRESHDR]
				add edx, ?FONTEXTRA
				lea edx, [edx+sizeof FONTDIRENTRY]
				.while (byte ptr [edx])
					inc edx
				.endw
				inc edx
				@strace <"found FontResource: ", &edx>
            	mov szFaceName,0
                mov ecx, lpLogfont
                xor eax, eax
                .if ([ecx].LOGFONTA.lfFaceName)
                	push edx
                	invoke lstrcmpi, addr [ecx].LOGFONTA.lfFaceName, edx
                    pop edx
                .endif
                .if (!eax)
					invoke RtlMoveMemory, addr szFaceName, edx, LF_FACESIZE
                .endif
        	.elseif ([ebx].FONTRESHDR.dwType == 8 + 8000h)
            	.if (szFaceName)
	            	lea ecx, [ebx+sizeof FONTRESHDR]
    	        	invoke _FillTextMetric, addr tm, ecx
        	        lea ecx, tm
            	    lea eax, szFaceName
	                push lParam
    	        	push ecx
        	        push eax
            	    call lpCallBack
	                .break .if (!eax)
	                mov ecx, lpLogfont
	                .if (![ecx].LOGFONTA.lfFaceName)
                    	mov szFaceName, 0
                    .endif
                .endif
            .endif
        	mov ebx,[ebx].FONTRESHDR.pNext
        .endw
        xor eax, eax
		ret
        align 4
        
_EnumFontResource endp

CreateFontIndirectA proc public lpLogFont:ptr LOGFONTA

		@strace <"CreateFontIndirectA(", lpLogFont, ") enter">
        invoke _FindFontResource, lpLogFont
        .if (eax)
        	push eax
            invoke _GDImalloc2, sizeof FONTOBJ
            pop ecx
            .if (eax)
            	mov [eax].GDIOBJ.dwType, GDI_TYPE_FONT
            	mov [eax].FONTOBJ.pFontRes, ecx
            .endif
        .endif
		@strace <"CreateFontIndirectA(", lpLogFont, ")=", eax>
		ret
        align 4

CreateFontIndirectA endp

CreateFontA proc public nHeight:DWORD, nWidth:DWORD, nEscapement:DWORD,
		nOrientation:DWORD, fnWeight:DWORD,
		fdwItalic:DWORD, fdwUnderline:DWORD, fdwStrikeOut:DWORD, fdwCharSet:DWORD,
        fdwOutputPrecision:dword, fdwClipPrecision:DWORD,
        fdwQuality:DWORD, fdwPaF:DWORD, lpszFace:LPSTR
        
local	logfont:LOGFONTA        

        xor eax, eax
        mov eax, nHeight
        mov ecx, nWidth
        mov edx, nEscapement
        mov logfont.lfHeight, eax
        mov logfont.lfWidth, ecx
        mov logfont.lfEscapement, edx
        mov eax, fnWeight
        mov ecx, nOrientation
        mov edx, fdwItalic
        mov logfont.lfOrientation, eax
        mov logfont.lfWeight, ecx
        mov logfont.lfItalic, dl
        mov eax, fdwUnderline
        mov ecx, fdwStrikeOut
        mov edx, fdwCharSet
        mov logfont.lfUnderline, al
        mov logfont.lfStrikeOut, cl
        mov logfont.lfCharSet, dl
        mov eax, fdwOutputPrecision
        mov ecx, fdwClipPrecision
        mov edx, fdwQuality
        mov logfont.lfOutPrecision, al
        mov logfont.lfClipPrecision, cl
        mov logfont.lfQuality, dl
        mov eax, fdwPaF
        mov ecx, lpszFace
        mov logfont.lfPitchAndFamily, al
        mov logfont.lfFaceName, 0
        jecxz @F
        invoke lstrcpyn, addr logfont.lfFaceName, ecx, LF_FACESIZE
@@:        
        invoke CreateFontIndirectA, addr logfont
		@strace <"CreateFontA(", nHeight, ", ", nWidth, ", ", nEscapement, ", ", nOrientation, ", ", fnWeight, ", ...)=", eax>
		ret
        align 4
CreateFontA endp

GetTextMetricsA proc public hdc:DWORD, lpTM:ptr TEXTMETRICA

		xor eax, eax
		mov ecx, hdc
       	mov edx, [ecx].DCOBJ.hFont
		.if (edx)
        	invoke _FillTextMetric, lpTM, [edx].FONTOBJ.pFontRes
        .endif
		@strace <"GetTextMetricsA(", hdc, ", ", lpTM, ")=", eax>
		ret
        align 4
GetTextMetricsA endp

GetOutlineTextMetricsA proc public uses esi ebx hdc:DWORD, cbData:DWORD, lpOTM:ptr OUTLINETEXTMETRICA
		xor eax, eax
		@strace <"GetOutlineTextMetricsA(", hdc, ", ", cbData, ", ", lpOTM, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetOutlineTextMetricsA endp

GetGlyphOutlineA proc public hdc:DWORD, uChar:dword, uFormat:dword, lpgm:ptr, cbBuffer:dword, lpvBuffer:ptr, lpmat2:ptr
		xor eax, eax
		@strace <"GetGlyphOutlineA(", hdc, ", ", uChar, ", ", uFormat, ", ", lpgm, ", ", cbBuffer, ", ", lpvBuffer, ", ", lpmat2, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetGlyphOutlineA endp

_FillEnumLogFont proc public uses esi ebx lpELF:ptr ENUMLOGFONTA, lpTM:ptr TEXTMETRICA

		mov esi, lpTM
		mov ebx, lpELF
		invoke RtlZeroMemory, ebx, sizeof ENUMLOGFONTA
		mov eax, [esi].TEXTMETRICA.tmHeight
		mov ecx, [esi].TEXTMETRICA.tmAveCharWidth
		movzx edx, [esi].TEXTMETRICA.tmCharSet
		mov [ebx].ENUMLOGFONTA.elfLogFont.lfHeight, eax
		mov [ebx].ENUMLOGFONTA.elfLogFont.lfWidth, ecx
		mov [ebx].ENUMLOGFONTA.elfLogFont.lfCharSet, dl
		movzx eax, [esi].TEXTMETRICA.tmPitchAndFamily
		mov ecx, [esi].TEXTMETRICA.tmWeight
		mov [ebx].ENUMLOGFONTA.elfLogFont.lfPitchAndFamily, al
		mov [ebx].ENUMLOGFONTA.elfLogFont.lfWeight, ecx
		mov [ebx].ENUMLOGFONTA.elfLogFont.lfQuality, DEFAULT_QUALITY
		@mov eax, 1
		ret
        align 4
_FillEnumLogFont endp

protoEnumFontFamProc typedef proto :dword, :dword, :dword, :dword
FONTENUMPROC typedef ptr protoEnumFontFamProc

EnumFontFamiliesA proc public uses esi hdc:DWORD, lpszFamily:ptr BYTE, lpEnumFontFamProc:FONTENUMPROC, lParam:DWORD

local	elf:ENUMLOGFONTA
local	tm:TEXTMETRICA

		xor eax, eax
		mov esi,g_pFonts
        .while (esi)
        	.if ([esi].FONTRESHDR.dwType == 7 + 8000h)
            	invoke RtlZeroMemory, addr elf, sizeof ENUMLOGFONTA
		  		lea edx, [esi+sizeof FONTRESHDR]
				add edx, ?FONTEXTRA
                invoke _FillTextMetric, addr tm, edx
                invoke _FillEnumLogFont, addr elf, addr tm
	        	invoke lpEnumFontFamProc, addr elf, addr tm, RASTER_FONTTYPE, lParam
            .endif
        	mov esi, [esi].FONTRESHDR.pNext
        .endw
		@strace <"EnumFontFamiliesA(", hdc, ", ", lpszFamily, ", ", lpEnumFontFamProc, ", ", lParam, ")=", eax>
		ret
        align 4
EnumFontFamiliesA endp

mycallback proc pszFaceName:ptr byte, ptm:ptr TEXTMETRICA, lParam:DWORD

local	elf:ENUMLOGFONTEXA
local	pLogFont:ptr LOGFONTA
local	pCallBack:FONTENUMPROC

		mov ecx, lParam
        mov edx, [ecx+0*4]
        mov eax, [ecx+1*4]
        mov lParam, edx
        mov pCallBack, eax
        
        invoke _FillEnumLogFont, addr elf, ptm
        invoke lstrcpy, addr elf.elfLogFont.lfFaceName, pszFaceName
        mov elf.elfFullName,0
        mov elf.elfScript,0
       	invoke pCallBack, addr elf, ptm, RASTER_FONTTYPE, lParam
        ret
        align 4
        
mycallback endp

;--- for raster fonts, the callback function
;--- will accept a TEXTMETRIC structure

EnumFontFamiliesExA proc public hdc:DWORD, lpLogfont:ptr LOGFONTA, lpEnumFontFamProc:FONTENUMPROC, lParam:DWORD, dwFlags:DWORD

local	mylparam[2]:DWORD

		mov ecx, lParam
        mov edx, lpEnumFontFamProc
        mov mylparam[0*4],ecx
        mov mylparam[1*4],edx
       	invoke _EnumFontResource, lpLogfont, offset mycallback, addr mylparam
        
ifdef _DEBUG
		mov edx, lpLogfont
        movzx ecx,[edx].LOGFONTA.lfCharSet
        .if ([edx].LOGFONTA.lfFaceName)
	        lea edx, [edx].LOGFONTA.lfFaceName
        .else
        	mov edx, CStr("NULL")
        .endif
endif
		@strace <"EnumFontFamiliesExA(", hdc, ", ", lpLogfont, "[chars=", ecx, " fn=", &edx, "], ", lpEnumFontFamProc, ", ", lParam, ", ", dwFlags, ")=", eax>
		ret
        align 4
EnumFontFamiliesExA endp

;--- get truetype font information

GetFontData proc public hdc:DWORD, dwTable:DWORD, dwOffset:DWORD, lpvBuffer:ptr, cbData:DWORD
		mov eax, GDI_ERROR
		@strace <"GetFontData(", hdc, ", ", dwTable, ", ", dwOffset, ", ", lpvBuffer, ", ", cbData, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetFontData endp

GetTextCharsetInfo proc public hdc:DWORD, lpSig:ptr FONTSIGNATURE, dwFlags:DWORD
		mov eax, DEFAULT_CHARSET
        mov ecx, hdc
        .if (ecx && [ecx].DCOBJ.hFont)
        	mov eax, lpSig
            .if (eax)
            	push ecx
            	invoke RtlZeroMemory, eax, sizeof FONTSIGNATURE
                pop ecx
            .endif
        	mov edx, [ecx].DCOBJ.hFont
            mov edx, [edx].FONTOBJ.pFontRes
            movzx eax, [edx].FONTDIRENTRY.dfCharSet
        .endif
		@strace <"GetTextCharsetInfo(", hdc, ", ", lpSig, ", ", dwFlags, ")=", eax>
		ret
        align 4
GetTextCharsetInfo endp

GetTextCharset proc public hdc:DWORD
		invoke GetTextCharsetInfo, hdc, NULL, 0
		@strace <"GetTextCharset(", hdc, ")=", eax>
		ret
        align 4
GetTextCharset endp

GetTextFaceA proc public hdc:DWORD, nCount:DWORD, lpFaceName:ptr BYTE

		xor eax, eax
        mov ecx, hdc
        .if (ecx && [ecx].DCOBJ.hFont)
        	mov edx, [ecx].DCOBJ.hFont
            mov edx, [edx].FONTOBJ.pFontRes
            lea eax, [edx+sizeof FONTDIRENTRY]
            .while (byte ptr [eax])
            	inc eax
            .endw
            push eax
           	invoke lstrlenA, eax
            pop ecx
            .if (lpFaceName && (nCount > eax))
            	push eax
            	invoke lstrcpyA, lpFaceName, ecx
                pop eax
            .endif
        .endif
		@strace <"GetTextFaceA(", hdc, ", ", nCount, ", ", lpFaceName, ")=", eax>
		ret
        align 4
GetTextFaceA endp

TranslateCharsetInfo proc public lpSrc:ptr, lpCs:ptr CHARSETINFO, dwFlags:dword
		xor eax, eax
		@strace <"TranslateCharsetInfo(", lpSrc, ", ", lpCs, ", ", dwFlags, ")=", eax, " *** unsupp ***">
		ret
        align 4
TranslateCharsetInfo endp

		end
