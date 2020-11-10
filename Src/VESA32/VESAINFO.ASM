
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
		include equates.inc
		include dpmi.inc

		.DATA

		public g_bVesaInfo

g_vesainfo VESAINFO <>
g_bVesaInfo DB 0

		.CODE

;--- uses vesa calls:
;--- int 10h, ax=4F00h, ES:E/DI=buffer for supervga info
;--- doesn't assume SS==FLAT

;--- this call might need more than 200h bytes stack!

_GetVesaInfo proc public uses edi esi ebx

local	dosmemsel:dword
local	linDosMem:dword
local	rcptr:dword
local	rmcs:RMCS

		xor eax,eax
		mov dosmemsel,eax
		mov ax,0100h		;alloc DOS memory
		mov bx,60h			;512 bytes VESAINFO + 1024 bytes stack!
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
		mov esi, eax

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

;		mov eax,"ASEV"
		mov eax,"2EBV"
		mov @flat:[esi],eax
		lea edi,rmcs
if 1  ; don't assume SS==FLAT!
		push es
		push ss
		pop es
endif
		mov bx,0010h
		mov cx,0000h
		mov ax,0300h
		int 31h
if 1
		pop es
endif
		jc svmx_er
		cmp rmcs.rAX,004Fh
		jnz svmx_er
		mov edi,offset g_vesainfo
		mov ecx,sizeof VESAINFO
ife ?FLAT
		push ds
		push gs
		pop ds
endif
		rep movsb
ife ?FLAT
		pop ds
endif
		mov eax,1
		jmp svmx_ex
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
		mov g_bVesaInfo,al
		ret
		align 4
_GetVesaInfo endp

GetVesaInfo proc public uses edi esi pVesaInfo:ptr VESAINFO
		.if (g_bVesaInfo)
			mov esi, offset g_vesainfo
			mov edi, pVesaInfo
			mov ecx, sizeof VESAINFO/4
			rep movsd
		.endif
		movzx eax, g_bVesaInfo
		ret
		align 4
GetVesaInfo endp

		END
