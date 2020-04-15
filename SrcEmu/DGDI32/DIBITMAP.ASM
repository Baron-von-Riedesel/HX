
;--- DIB functions:
;--- GetDIBits, SetDIBits, SetDIBitsToDevice
;--- CreateDIBitmap
;--- CreateDIBSection
;--- GetDIBColorTable, SetDIBColorTable

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

		.CODE

_getclrtabsize proc public
		mov ecx, [esi].BITMAPINFOHEADER.biClrUsed
		and ecx, ecx
		jnz @F
		movzx ecx,[esi].BITMAPINFOHEADER.biBitCount
		.if (cl == 1)
			mov cx, 2
		.elseif (cl == 4)
			mov cx, 16
		.elseif (cl == 8)
			mov cx, 256
		.elseif (cl == 24)
			xor ecx, ecx
		.elseif ([esi].BITMAPINFOHEADER.biCompression == BI_BITFIELDS)
			mov cx, 3
		.else
			xor ecx, ecx
		.endif
@@:
		ret
		align 4
_getclrtabsize endp

;--- get the bits of a bitmap. transforms a DDB to a DIB
;--- (which means the colortable of the bitmap should be ignored!)
;--- two cases
;--- 1. lpvBits == NULL
;--- lpbi.BITMAPINFO is filled. if lpbi.BITMAPINFO.bmBitCount is also null,
;--- only lpbi.BITMAPINFOHEADER is filled, the color table is untouched 

;--- if lpvBits is <> NULL, the first 6 members of lpbi.BITMAPINFOHEADER
;--- must be initialized

;--- hdc might be NULL (if uUsage is DIB_RGB_COLORS its not used)

;--- the bitcount member (and the color data) is compatible with the 
;--- format in the DC, it's not just the actual values of the bitmap

GetDIBits proc public uses esi edi hdc:DWORD, hBitmap:DWORD, uStartScan:DWORD,
		cScanLines:DWORD, lpvBits:ptr BYTE, lpbi:ptr BITMAPINFO, uUsage:DWORD

local	dwLineSize:DWORD
local	dwSrcPitch:DWORD

		xor eax, eax
		mov edx, hBitmap
		.if ([edx].GDIOBJ.dwType == GDI_TYPE_BITMAP)
			mov esi, [edx].BITMAPOBJ.pBitmap
			mov edi, lpbi
			movzx eax, [edi].BITMAPINFOHEADER.biBitCount
			.if (eax)
;--- copy the color table if bpp is <= 8 or BI_BITFIELDS?
;--- the correct handling is to synthesize a color table!
				call _getclrtabsize
				push esi
				push edi
				add esi, [esi].BITMAPINFOHEADER.biSize
				add edi, [edi].BITMAPINFOHEADER.biSize
				rep movsd
				pop edi
				pop esi
			.endif
			.if (!lpvBits)
				mov edx, [edi].BITMAPINFOHEADER.biSize
				.if (edx >= sizeof BITMAPINFOHEADER)
					mov eax, [edi].BITMAPINFOHEADER.biHeight
					mov ecx, sizeof BITMAPINFOHEADER
					rep movsb
					and eax, eax
					jns done
					neg eax
				.endif
			.else
				mov edi, lpvBits
				mov eax, [esi].BITMAPINFOHEADER.biWidth
				movzx ecx, [esi].BITMAPINFOHEADER.biBitCount
				mul ecx
				shr eax, 3
				mov dwLineSize, eax
				mov edx, lpbi
				mov edx, [edx].BITMAPINFOHEADER.biHeight
				xor edx, [esi].BITMAPINFOHEADER.biHeight
				and edx, edx
				.if (!SIGN?)
					mov dwSrcPitch, eax
					mul uStartScan
				.else				;switch line order (top-down <-> bottom-up)
					neg eax
					mov dwSrcPitch, eax   ;pitch negative
					mov eax, [esi].BITMAPINFOHEADER.biHeight
					and eax, eax
					jns @F
					neg eax
@@:
					sub eax, uStartScan
					jbe error
					dec eax
					mul dwLineSize
				.endif
				call _getclrtabsize
				lea eax, [eax+ecx*4]
				add eax, [esi].BITMAPINFOHEADER.biSize
				add esi, eax
				mov ecx, cScanLines
				.while (ecx)
					push ecx
					push esi
					mov ecx, dwLineSize
					rep movsb
					pop esi
					add esi, dwSrcPitch
					pop ecx
					dec ecx
				.endw
				mov eax, cScanLines
			.endif
		.endif
done:
		@strace <"GetDIBits(", hdc, ", ", hBitmap, ", ", uStartScan, ", ", cScanLines, ", ", lpvBits, ", ", lpbi, ", ", uUsage, ")=", eax>
		ret
error:
		xor eax,eax
		jmp done

		align 4

GetDIBits endp

;--- set color data in DDB hBitmap
;--- this translates DIB bitmap bits to DDB bitmap bits
;--- lpbmi and lpvBits describe source DIB
;--- uStartScan + cScanlines refer to the data in lpvBits
;--- uUsage specifies what format the bmiColors of lpbi has
;--- the hdc parameter is only used if fuColorUse is DIB_PAL_COLORS,
;--- it might be NULL otherwise

SetDIBits proc public uses ebx esi edi hdc:DWORD, hBitmap:DWORD, uStartScan:DWORD,
		cScanLines:DWORD, lpvBits:ptr, lpbmi:ptr BITMAPINFO, uUsage:DWORD

local	dwHeight:DWORD
local	dcDst:DCOBJ
local	dcSrc:DCOBJ

		xor eax, eax
		mov edx, hBitmap
		.if ([edx].GDIOBJ.dwType == GDI_TYPE_BITMAP)
			mov esi, [edx].BITMAPOBJ.pBitmap
			invoke RtlZeroMemory, addr dcSrc, sizeof DCOBJ * 2
			mov dcDst.dwFlags, DCF_BOTTOM_UP
			mov dcSrc.dwFlags, DCF_BOTTOM_UP
			mov edi, lpvBits
			mov ebx, lpbmi
			mov dcSrc.pBMBits, edi
			mov ecx,[esi].BITMAPINFOHEADER.biHeight
			and ecx,ecx
			jns @F
			neg ecx
			mov dcDst.dwFlags, 0
@@:
			mov dwHeight, ecx
			mov dcDst.dwHeight, ecx
			mov eax, [esi].BITMAPINFOHEADER.biWidth
			movzx ecx, [esi].BITMAPINFOHEADER.biBitCount
			mov dcDst.dwWidth, eax
			mov dcDst.dwBpp, ecx
			mul ecx
			shr eax, 3
			mov dcDst.lPitch, eax
			mov eax,[ebx].BITMAPINFOHEADER.biHeight
			and eax,eax
			jns @F
			neg eax
			mov dcSrc.dwFlags, 0
@@:
			mov dcSrc.dwHeight, eax
			mov eax,[ebx].BITMAPINFOHEADER.biWidth
			mov dcSrc.dwWidth, eax
			movzx ecx,[ebx].BITMAPINFOHEADER.biBitCount
			mov dcSrc.dwBpp, ecx
			mul ecx
			shr eax,3

			cmp ecx,1		;required by Bochs!
			jz @F
			add eax,3
			and al,0FCh
@@:

			mov dcSrc.lPitch,eax

			mov eax,ebx
			add eax,[ebx].BITMAPINFOHEADER.biSize
			mov dcSrc.pColorTab, eax

			call _getclrtabsize

			lea eax, [esi+ecx*4]
			add eax, [esi].BITMAPINFOHEADER.biSize
			mov dcDst.pBMBits, eax

			mov eax, esi
			add eax, [esi].BITMAPINFOHEADER.biSize
			mov dcDst.pColorTab, eax

			invoke BitBlt, addr dcDst, 0, 0, [esi].BITMAPINFOHEADER.biWidth, dwHeight, addr dcSrc, uStartScan, 0, SRCCOPY

			mov eax, cScanLines
ifdef _DEBUG
			mov edx, hBitmap
			mov edx, [edx].BITMAPOBJ.pBitmap
			movzx ecx, [edx].BITMAPINFOHEADER.biBitCount
			@strace <"SetDIBits: dst xyz=", [edx].BITMAPINFOHEADER.biWidth, "x", [edx].BITMAPINFOHEADER.biHeight, "x",ecx>
			mov edx, lpbmi
			movzx ecx, [edx].BITMAPINFOHEADER.biBitCount
			@strace <"SetDIBits: lpbi xyz=", [edx].BITMAPINFOHEADER.biWidth, "x", [edx].BITMAPINFOHEADER.biHeight, "x",ecx>
endif
		.endif
		@strace <"SetDIBits(", hdc, ", ", hBitmap, ", ", uStartScan, ", ", cScanLines, ", ", lpvBits, ", ", lpbmi, ", ", uUsage, ")=", eax>
		ret
		align 4

SetDIBits endp

;--- set a rectangle in a hdc
;--- source is a DIB, described by lpbmi and lpvBits
;--- uStartScan: start line for lpvBits array
;--- cScanLines: number of lines in lpvBits array

SetDIBitsToDevice proc public uses ebx hdc:DWORD, XDest:dword, YDest:dword,
		dwWidth:DWORD, dwHeight:DWORD, XSrc:dword, YSrc:dword, uStartScan:dword,
		cScanLines:DWORD, lpvBits:ptr, lpbmi:ptr BITMAPINFO, fuColorUse:DWORD

local	dcSrc:DCOBJ

		@strace <"SetDIBitsToDevice(", hdc, ", XYdst=", XDest, ", ", YDest, ", ", dwWidth, ", ", dwHeight, ", XYsrc", XSrc, ", ", YSrc, ", ", uStartScan, ", ", cScanLines, ", ", lpvBits, ", ", lpbmi, ", ", fuColorUse, ") enter">
		invoke RtlZeroMemory, addr dcSrc, sizeof DCOBJ
		mov dcSrc.dwFlags, DCF_BOTTOM_UP

		mov eax, lpvBits
		mov ebx, lpbmi
		mov dcSrc.pBMBits, eax
if 0
		mov eax,[ebx].BITMAPINFOHEADER.biHeight
		and eax,eax
		jns @F
		neg eax
		mov dcSrc.dwFlags, 0
@@:
else
		mov eax, cScanLines
endif
		mov dcSrc.dwHeight, eax
		mov eax,[ebx].BITMAPINFOHEADER.biWidth
		mov dcSrc.dwWidth, eax
		movzx ecx,[ebx].BITMAPINFOHEADER.biBitCount
		mov dcSrc.dwBpp, ecx
		mul ecx
		shr eax,3

		add eax,3
		and al,0FCh

		mov dcSrc.lPitch,eax
		@strace <"SetDIBitsToDevice: bmi x=", [ebx].BITMAPINFOHEADER.biWidth, " y=", [ebx].BITMAPINFOHEADER.biHeight, " bpp=", ecx, " pitch=", eax>

		mov eax,ebx
		add eax,[ebx].BITMAPINFOHEADER.biSize
		mov dcSrc.pColorTab, eax

		invoke BitBlt, hdc, XDest, YDest, dwWidth, dwHeight, addr dcSrc, XSrc, YSrc, SRCCOPY
exit:
		@strace <"SetDIBitsToDevice(", hdc, ", ", XDest, ", ", YDest, ", ", dwWidth, ", ", dwHeight, ", ", uStartScan, ", ", cScanLines, ", ", lpvBits, ", ", lpbmi, ", ", fuColorUse, ")=", eax, " esp=", esp>
		ret
		align 4

SetDIBitsToDevice endp

;--- create a DDB from a DIB
;--- equivalent to 
;--- 1. CreateCompatibleBitmap
;--- 2. SetDIBits

;--- if CBM_INIT is not set in fdwInit,
;--- parameters lpbInit and lpbmi are ignored

CreateDIBitmap proc public uses esi hdc:DWORD, lpbmih: ptr BITMAPINFOHEADER,
				fdwInit:DWORD, lpbInit:ptr, lpbmi: ptr BITMAPINFO, fuUsage:SDWORD

		mov esi, lpbmih
		mov ecx, [esi].BITMAPINFOHEADER.biHeight
		and ecx, ecx
		jns @F
		neg ecx
@@:
		invoke CreateCompatibleBitmap, hdc, [esi].BITMAPINFOHEADER.biWidth, ecx
		.if (eax)
			.if (fdwInit & CBM_INIT)
				xor edx, edx
				mov ecx, [esi].BITMAPINFOHEADER.biHeight
				and ecx,ecx
				jns @F
				neg ecx
@@:
				push eax
				invoke SetDIBits, hdc, eax, edx, ecx, lpbInit, lpbmi, fuUsage
				pop eax
			.endif
		.endif
		@strace <"CreateDIBitmap(", hdc, ", ", lpbmih, ", ", fdwInit, ", ", lpbInit, ", ", lpbmi, ", ", fuUsage, ")=", eax>
		ret
		align 4

CreateDIBitmap endp

;---
;--- inp hdc: if iUsage is DIB_PAL_COLORS, the current palette is used
;---          to initialize the bitmap's colors.
;--- inp pbmi: 
;--- inp iUsage: DIB_RGB_COLORS | DIB_PAL_COLORS
;--- out ppvBits: pointer to receive a pointer to the bitmap bits
;--- inp hSection: handle to a file mapping object or NULL
;--- inp dwOffset: used if hSection is <> NULL

;--- the file mapping object thing is not implemented yet!

CreateDIBSection proc public uses esi hdc:DWORD, pbmi: ptr BITMAPINFO,
				iUsage:DWORD, ppvBits:ptr ptr, hSection:DWORD, dwOffset:DWORD

ifdef _DEBUG
local	dwSize:DWORD
endif

		xor eax, eax
		mov ecx, ppvBits
		jecxz @F
		mov [ecx], eax
@@:
		cmp hSection, eax	; .if ((!hSection))
		jnz exit
		mov esi, pbmi
		mov eax, [esi].BITMAPINFOHEADER.biWidth
		movzx edx, [esi].BITMAPINFOHEADER.biBitCount
		mul edx
		add eax, 8-1
		shr eax, 3
		add eax, 4-1
		and al, not 3	;size must be dword aligned

		mov edx, [esi].BITMAPINFOHEADER.biHeight
		test edx, 80000000h
		jz @F
		neg edx
@@:
		mul edx
ifdef _DEBUG
		mov dwSize, eax
endif
		call _getclrtabsize
		push ecx
		mov edx, [esi].BITMAPINFOHEADER.biSize
		lea edx, [edx+ecx*4]
		lea eax, [eax+edx+sizeof BITMAPOBJ]
		invoke _GDImalloc2, eax
		pop edx
		.if (eax)
			pushad
			lea edi, [eax+sizeof BITMAPOBJ]
			mov [eax].BITMAPOBJ.dwType, GDI_TYPE_BITMAP
			mov [eax].BITMAPOBJ.pBitmap, edi
			mov ecx, [esi].BITMAPINFOHEADER.biSize
			rep movsb
			mov ecx, edx
			.if (iUsage == DIB_RGB_COLORS)
				rep movsd
			.else
				@strace	<"CreateDIBSection: DIB_PAL_COLORS">
				mov ebx, hdc
				mov ebx, [ebx].DCOBJ.pColorTab
				.while (ecx)
					lodsw
					movzx eax, ax
					mov eax, [ebx+eax*4]
if 1
					bswap eax
					shr eax, 8
endif
					stosd
					dec ecx
				.endw
			.endif
			mov ecx, ppvBits
			jecxz @F
			mov [ecx], edi
@@:
			popad
		.endif
exit:
ifdef _DEBUG
		mov ecx, ppvBits
		jecxz @F
		mov edx, [ecx]
@@:
		mov ecx, pbmi
		assume ecx:ptr BITMAPINFOHEADER
		push esi
		movzx esi, [ecx].biBitCount
		@strace <"CreateDIBSection(", hdc, ", ", pbmi, ", ", iUsage, ", ", ppvBits, ", ", hSection, ", ", dwOffset, ")=", eax, " pBits=", edx, " siz=", dwSize, " dim=", [ecx].biWidth, "x", [ecx].biHeight, "x", esi>
		assume ecx:nothing
		pop esi
endif
		ret
		align 4

CreateDIBSection endp

;--- set color table of currently selected bitmap

SetDIBColorTable proc public uses esi edi hdc:DWORD, uStartIndex:DWORD, 
				cEntries:DWORD, pColors:ptr RGBQUAD
		mov ecx, hdc
		xor eax, eax
		mov edx, [ecx].DCOBJ.hBitmap
		.if (edx)
			mov edx, [edx].BITMAPOBJ.pBitmap
			.if ([edx].BITMAPINFOHEADER.biBitCount < 12)
				mov edi, [edx].BITMAPINFOHEADER.biSize
				lea edi, [edi+edx]
				mov esi, pColors
				mov ecx, cEntries
				mov edx, uStartIndex
				lea edi, [edi+edx*4]
				rep movsd
				mov eax, cEntries
			.endif
		.endif
		@strace <"SetDIBColorTable(", hdc, ", ", uStartIndex, ", ", cEntries, ", ", pColors, ")=", eax>
		ret
		align 4
SetDIBColorTable endp

;--- get color table of currently selected bitmap

GetDIBColorTable proc public uses esi edi hdc:DWORD, uStartIndex:DWORD, 
				cEntries:DWORD, pColors:ptr RGBQUAD
		mov ecx, hdc
		xor eax, eax
		mov edx, [ecx].DCOBJ.hBitmap
		.if (edx)
			mov edx, [edx].BITMAPOBJ.pBitmap
			.if ([edx].BITMAPINFOHEADER.biBitCount < 12)
				mov edi, [edx].BITMAPINFOHEADER.biSize
				lea edi, [edi+edx]
				mov esi, pColors
				mov ecx, cEntries
				cmp ecx, [edx].BITMAPINFOHEADER.biClrUsed
				jb	@F
				mov ecx, [edx].BITMAPINFOHEADER.biClrUsed
@@:
				push ecx
				mov edx, uStartIndex
				lea edi, [edi+edx*4]
				xchg esi, edi
				rep movsd
				pop eax
			.endif
		.endif
		@strace <"GetDIBColorTable(", hdc, ", ", uStartIndex, ", ", cEntries, ", ", pColors, ")=", eax>
		ret
		align 4
GetDIBColorTable endp

		end
