
		.486
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include function.inc
		include macros.inc
		include dpmi.inc
		include vesa32.inc
		include equates.inc

;--- the vesa palette functions expects palette entries
;--- in format:
;--- red, green, blue, alpha/align
;--- this is the same as windows PALETTEENTRY format

?XCHANGERB	equ 1	;xchange red and blue values

		.DATA
        
if ?USEPMPROCS
g_lpfnSetPalette dd 0
endif

;--- bswap requires a 486. for a 386 change the "if 1" to "if 0"

@bswap macro x
local rh, rl
if 1
	bswap x
else
rh textequ @CatStr(@SubStr(x,2,1),h)
rl textequ @CatStr(@SubStr(x,2,1),l)
	xchg rh,rl
    ror x,10h
    xchg rh,rl
endif    
    endm

		.CODE

;--- translate palette before calling VESA

translatepal proc
ife ?FLAT
		push es
		push @flat
		pop es
endif
ife ?XCHANGERB
		rep movsd
else
@@:
		lodsd
		shl eax,8
		@bswap eax
		stosd
		dec ecx
		jnz @B

endif
ife ?FLAT
		pop es
endif
		ret
		align 4
translatepal endp

;--- translate palette after calling VESA

translatepal2 proc
ife ?FLAT
		push ds
		push @flat
		pop ds
endif
ife ?XCHANGERB
		rep movsd
else
@@:
		lodsd
		shl eax, 8
		@bswap eax
		stosd
		dec ecx
		jnz @B
endif
ife ?FLAT
		pop ds
endif
		ret
		align 4
translatepal2 endp        

;--- doesn't assume SS==FLAT

_GetSetVesaPaletteEntries proc uses ebx esi edi dwStart:dword, nEntries:DWORD, pEntries:ptr, dwFlags:DWORD

local   rmcs:RMCS

		cmp g_Vesa32Options.bHandleDAC,0
		jnz failed2
		mov ebx, nEntries
		and ebx, ebx
		jz exit
		shr ebx, 2
		inc ebx
		mov ax,0100h
		int 31h
		jc failed2
		mov ebx,edx
		mov rmcs.rES,ax		;ES:DI->palette entries (R,G,B,A)
		mov rmcs.rAX,4F09h
		xor ecx,ecx
		mov rmcs.rDI,cx
		mov rmcs.rFlags,cx
		mov rmcs.rSSSP,ecx
		mov ecx, nEntries
		mov rmcs.rCX,cx		;CX=number of entries
		test dwFlags,1
		jnz getpal_1
		movzx eax, ax
		shl eax, 4
		mov edi, eax
		mov esi, pEntries
		call translatepal
getpal_1:
		mov eax, dwFlags
		mov rmcs.rBX,ax		;BL=0: set primary palette, BL=1: get palette
		mov edx, dwStart
		mov rmcs.rDX,dx		;DX=start index
		push ebx
		lea edi,rmcs
		push es
		push ss		;don't assume SS==FLAT!
		pop es
		mov bx,0010h
		mov cx,0000h
		mov ax,0300h
		int 31h
		pop es
		pop ebx
		jc failed
		cmp rmcs.rAX,004Fh
		jnz failed
		test dwFlags, 1
		jz getpal_2
		movzx esi, rmcs.rES
		shl esi, 4
		mov edi, pEntries
		mov ecx, nEntries
		call translatepal2
getpal_2:
		mov edx, ebx
		mov ax,0101h
		int 31h
exit:
		@mov eax, 1
		ret
failed:
		mov edx, ebx
		mov ax,0101h
		int 31h
failed2:
		mov ecx, nEntries
		mov ebx, dwStart
		mov dh, 3h
		test byte ptr g_vesainfo.Capabilities, VESACAP_DAC8
		jz use6bit
		.if (dwFlags & 1)
			mov dl,0C7h
			mov edi, pEntries
			mov al, bl
			out dx, al	;set the index just once
			inc edx
			inc edx
			.while (ecx)
				in al,dx
				mov bh,al
				in al,dx
				mov ah,al
				in al,dx
				movzx eax,ax
				xchg al,ah
				shl eax, 8
				mov al,bl
				stosd
				dec ecx
				inc bl
			.endw
		.else
			mov dl,0C8h
			mov esi, pEntries
			mov al, bl
			out dx, al	;set the index just once
			inc edx
			.while (ecx)
				lodsd
				out dx, al
				shr eax, 8
				out dx, al
				shr eax, 8
				out dx, al
				dec ecx
				inc bl
			.endw
		.endif
		jmp exit
use6bit:
		.if (dwFlags & 1)
			mov dl,0C7h
			mov edi, pEntries
			mov al, bl
			out dx, al	;set the index just once
			inc edx
			inc edx
			.while (ecx)
				in al,dx
				shl al,2
				mov bh,al
				in al,dx
				shl al,2
				mov ah,al
				in al,dx
				shl al,2
				movzx eax,ax
				xchg al,ah
				shl eax, 8
				mov al,bl
				stosd
				dec ecx
				inc bl
			.endw
		.else
			mov dl,0C8h
			mov esi, pEntries
			mov al, bl
			out dx, al	;set the index just once
			inc edx
			.while (ecx)
				lodsd
				shr al,2
				out dx, al
				shr eax, 8
				shr al,2
				out dx, al
				shr eax, 8
				shr al,2
				out dx, al
				dec ecx
				inc bl
			.endw
		.endif
		jmp exit
		align 4

_GetSetVesaPaletteEntries endp

;--- doesn't assume SS==FLAT

SetVesaPaletteEntries proc public uses edi dwStart:dword, nEntries:DWORD, pEntries:ptr

		mov edi, pEntries
		mov ecx, nEntries
		mov edx, dwStart
if ?USEPMPROCS
		mov eax,g_lpfnSetPalette
		and eax, eax
		jz @F
		push esi
		sub esp, 256*4
		mov esi, edi
		mov edi, esp
		call translatepal
		mov edi, esp
		mov ecx, nEntries
		call g_lpfnSetPalette
		add esp, 256*4
		pop esi
		ret
@@:
endif
		invoke _GetSetVesaPaletteEntries, edx, ecx, edi, eax
		ret
		align 4

SetVesaPaletteEntries endp

GetVesaPaletteEntries proc public dwStart:dword, nEntries:DWORD, pEntries:ptr

		invoke _GetSetVesaPaletteEntries, dwStart, nEntries, pEntries, 1
		ret
		align 4

GetVesaPaletteEntries endp

if ?USEPMPROCS
_SetPaletteProc proc public lpfnProc:dword
		mov eax, lpfnProc
		mov g_lpfnSetPalette, eax
		ret
		align 4
_SetPaletteProc endp
endif

		end

