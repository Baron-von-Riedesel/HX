
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include function.inc
		include vesa32.inc
		include dpmi.inc

		.CODE

IsModeSupported proto :ptr SVGAINFO

;--- uses vesa calls:
;--- int 10h, ax=4F00h, ES:E/DI=buffer for supervga info
;--- int 10h, ax=4F01h

EnumVesaModes proc public uses edi esi ebx pCallback:dword,parm:dword

local	dosmemsel:dword
local	linDosMem:dword
local	rcptr:dword
local	rmcs:RMCS

		xor eax,eax
		mov dosmemsel,eax
		mov ax,0100h		;alloc DOS memory
		mov bx,20h+40h		;VESAINFO + 1024 bytes stack
		int 31h
		jc svmx_er
		mov dosmemsel,edx
		mov rmcs.rES,ax
		mov rmcs.rAX,4F00h
		xor ecx,ecx
		mov rmcs.rDI,cx
		mov rmcs.rFlags,cx
		mov rmcs.rSS,ax
		mov rmcs.rSP,600h

								;clear the VESA info buffer			
		movzx eax,ax
		shl eax,4
		mov linDosMem, eax

ife ?FLAT
		push es
		push gs
		pop es
endif
		mov edi,eax
		mov ecx,200h/4
		xor eax,eax
		rep stosd
ife ?FLAT
		pop es
endif

		mov ebx, linDosMem
		mov eax,"ASEV"
;		 mov eax,"2EBV"
		mov @flat:[ebx],eax
		push ebx
		mov bx,0010h
		mov cx,0000h
		lea edi,rmcs
		mov ax,0300h
		int 31h
		pop ebx
		jc svmx_er
		cmp rmcs.rAX,004Fh
		jnz svmx_er
		movzx eax,word ptr @flat:[ebx.VESAINFO.VideoModePtr+0]
		movzx ecx,word ptr @flat:[ebx.VESAINFO.VideoModePtr+2]
		shl ecx,4
		add eax,ecx
		mov esi,eax
		mov rmcs.rDI,0100h
		add ebx,100h
svmx_1:
		mov ax,@flat:[esi]
		cmp ax,-1
		jz svmx_er
		push ebx
		mov rmcs.rAX,4F01h
		mov rmcs.rCX,ax
		mov rmcs.rSSSP,0
		mov ax,0300h
		mov bx,0010h
		mov cx,0000h
		int 31h
		pop ebx
		jc svmx_er
		cmp rmcs.rAX,004Fh
		jnz svmx_er
		invoke IsModeSupported, ebx

		movzx eax,word ptr @flat:[esi]
		push parm
		push ebx
		push eax
		call pCallback
		and eax,eax
		jnz svmx_ex

		inc esi
		inc esi
		jmp svmx_1
svmx_er:
		xor eax,eax
svmx_ex:
		mov edx,dosmemsel
		and edx,edx
		jz @F
		push eax
		mov ax,0101h
		int 31h
		pop eax
@@:
		ret
		align 4
EnumVesaModes endp

;--- some VESA bioses seem to return 16 bpp for modes
;--- which are in fact 15 bpp. So continue search in some cases
;--- and if a second mode is found, decide which one suits

MODEDESC struct
dwMode	dd ?
bGBits	db ?
MODEDESC ends

MODESEARCH struct
dwXres	dd ?
dwYres	dd ?
dwBpp	dd ?
md		MODEDESC <>
MODESEARCH ends


myselproc proc stdcall uses esi edi vmode:dword, pSVGA:ptr SVGAINFO, pParm:ptr MODESEARCH

		mov esi,pSVGA
		mov edi,pParm
		mov eax,[edi].MODESEARCH.dwXres
		mov ecx,[edi].MODESEARCH.dwYres
		mov dl, byte ptr [edi].MODESEARCH.dwBpp
		mov dh, @flat:[esi].SVGAINFO.BitsPerPixel
		cmp ax,@flat:[esi].SVGAINFO.XResolution
		jnz myselproc_er
		cmp cx,@flat:[esi].SVGAINFO.YResolution
		jnz myselproc_er
		cmp dl, 15
		jz special15
		cmp dl, 16
		jz special16
		cmp dl, dh
		jnz myselproc_er
found:
		mov eax,vmode
exit:
		ret
myselproc_er:
		xor eax,eax
		ret
special15:
		cmp dh, dl
		jz found
special16:
		cmp dh, 16
		jnz myselproc_er
		mov eax, vmode
		mov cl, @flat:[esi].SVGAINFO.GreenMaskSize
		.if ([edi].MODESEARCH.md.dwMode == -1)
			mov [edi].MODESEARCH.md.dwMode, eax
			mov [edi].MODESEARCH.md.bGBits, cl
			jmp myselproc_er
		.endif
;--- now 2 modes with 16 bpp are here. check which one is the best
		.if (dl == 16)
			cmp cl,6
			jz found
		.else
			cmp cl,5
			jz found
		.endif
		mov eax, [edi].MODESEARCH.md.dwMode	;the previous one!
		jmp exit
		align 4
myselproc endp


SearchVesaMode proc public uses edi xres:dword,yres:dword,bitsperpixel:dword

local   ms:MODESEARCH

		lea edi,ms
		mov eax,xres
		mov ecx,yres
		mov edx,bitsperpixel
		mov [edi].MODESEARCH.dwXres, eax
		mov [edi].MODESEARCH.dwYres, ecx
		mov [edi].MODESEARCH.dwBpp, edx
		mov [edi].MODESEARCH.md.dwMode,-1
		invoke EnumVesaModes, offset myselproc, edi
		.if ((!eax) && ([edi].MODESEARCH.md.dwMode != -1))
			.if ((bitsperpixel == 15) && ([edi].MODESEARCH.md.bGBits == 6)) 
				; we didn't get a true 15 bpp mode
			.else
				mov eax, [edi].MODESEARCH.md.dwMode
			.endif
		.endif
		ret
		align 4
SearchVesaMode endp

		END
