
;--- fonts functions, WIDE versions

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

_FillTextMetric proto lpTM:ptr TEXTMETRICW, pFontRes:ptr FONTDIRENTRY

CreateFontIndirectW proc public uses ebx lpLogFont:ptr LOGFONTW

local	logfont:LOGFONTA

		mov ebx, lpLogFont
		invoke RtlMoveMemory, addr logfont, ebx, LOGFONTA.lfFaceName
        invoke WideCharToMultiByte, 0, 0, addr [ebx].LOGFONTW.lfFaceName, \
        	length LOGFONTW.lfFaceName, addr logfont.lfFaceName, \
            length logfont.lfFaceName, 0, 0
        invoke CreateFontIndirectA, addr logfont
		@strace <"CreateFontIndirectW(", lpLogFont, ")=", eax>
		ret
        align 4

CreateFontIndirectW endp

CreateFontW proc public nHeight:DWORD, nWidth:DWORD, nEscapement:DWORD,
		nOrientation:DWORD, fnWeight:DWORD,
		fdwItalic:DWORD, fdwUnderline:DWORD, fdwStrikeOut:DWORD, fdwCharSet:DWORD,
        fdwOutputPrecision:dword, fdwClipPrecision:DWORD,
        fdwQuality:DWORD, fdwPaF:DWORD, lpszFace:ptr WORD
        
local	logfont:LOGFONTW

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
        invoke lstrcpynW, addr logfont.lfFaceName, ecx, LF_FACESIZE
@@:
        invoke CreateFontIndirectW, addr logfont
		@strace <"CreateFontW(", nHeight, ", ", nWidth, ", ", nEscapement, ", ", nOrientation, ", ", fnWeight, ", ...)=", eax>
		ret
        align 4
CreateFontW endp

GetTextMetricsW proc public hdc:DWORD, lpTM:ptr TEXTMETRICW

		xor eax, eax
		mov ecx, hdc
       	mov edx, [ecx].DCOBJ.hFont
		.if (edx)
        	invoke _FillTextMetric, lpTM, [edx].FONTOBJ.pFontRes
        .endif
		@strace <"GetTextMetricsW(", hdc, ", ", lpTM, ")=", eax>
		ret
        align 4
GetTextMetricsW endp

GetOutlineTextMetricsW proc public uses esi ebx hdc:DWORD, cbData:DWORD, lpOTM:ptr OUTLINETEXTMETRICA
		xor eax, eax
		@strace <"GetOutlineTextMetricsW(", hdc, ", ", cbData, ", ", lpOTM, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetOutlineTextMetricsW endp

GetGlyphOutlineW proc public hdc:DWORD, uChar:dword, uFormat:dword, lpgm:ptr, cbBuffer:dword, lpvBuffer:ptr, lpmat2:ptr
		xor eax, eax
		@strace <"GetGlyphOutlineW(", hdc, ", ", uChar, ", ", uFormat, ", ", lpgm, ", ", cbBuffer, ", ", lpvBuffer, ", ", lpmat2, ")=", eax, " *** unsupp ***">
		ret
        align 4
GetGlyphOutlineW endp

GetTextFaceW proc public hdc:DWORD, nCount:DWORD, lpFaceName:ptr WORD
		xor eax, eax
		.if (lpFaceName)
		  	sub esp, nCount
            mov eax, esp
        .endif
		invoke GetTextFaceA, hdc, nCount, eax
        .if (eax && lpFaceName)
        	mov edx, esp
            pushad
            mov esi, edx
            mov edi, lpFaceName
            mov ecx, eax
            xor eax, eax
            .while (ecx)
            	lodsb
                stosw
                dec ecx
            .endw
            popad
        .endif
		@strace <"GetTextFaceW(", hdc, ", ", nCount, ", ", lpFaceName, ")=", eax>
		ret
        align 4
GetTextFaceW endp

protoEnumFontFamProc typedef proto :dword, :dword, :dword, :dword
FONTENUMPROC typedef ptr protoEnumFontFamProc

EnumFontFamiliesW proc public uses esi hdc:DWORD, lpszFamily:ptr WORD, lpEnumFontFamProc:FONTENUMPROC, lParam:DWORD

		xor eax, eax
		@strace <"EnumFontFamiliesW(", hdc, ", ", lpszFamily, ", ", lpEnumFontFamProc, ", ", lParam, ")=", eax>
		ret
        align 4
EnumFontFamiliesW endp

EnumFontFamiliesExW proc public hdc:DWORD, lpLogfont:ptr LOGFONTW, lpEnumFontFamProc:FONTENUMPROC, lParam:DWORD, dwFlags:DWORD

		xor eax, eax
		@strace <"EnumFontFamiliesExW(", hdc, ", ", lpLogfont, ", ", lpEnumFontFamProc, ", ", lParam, ", ", dwFlags, ")=", eax>
		ret
        align 4
EnumFontFamiliesExW endp

		end
