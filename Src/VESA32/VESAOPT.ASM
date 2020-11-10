
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

g_Vesa32Options VESA32OPTIONS <0,0,0>

if ?USEPMPROCS
g_lpfnSetPalette		dd 0
endif

		.CODE

if ?USEPMPROCS

PMTABLE struct
dwOfs05	dw ?	;offset for function 05
dwOfs07 dw ?	;offset for function 07 (set display start)
dwOfs09 dw ?	;offset for function 09 (set palette)
dwIOTab dw ?	;offset for io port table
PMTABLE ends

;--- int 10h, ax=4f0ah returns
;--- ES:DI -> protected mode table
;--- CX = size of table

_GetPMTable proc uses ebx edi

local	lppmTab:dword
local	rmcs:RMCS

		xor ecx, ecx
		mov rmcs.rSSSP,ecx
		mov rmcs.rAX, 4F0Ah
		mov rmcs.rBX, cx
		mov rmcs.rFlags, cx
		lea edi, rmcs
		mov bx,0010h
		mov ax,0300h
		int 31h
		cmp rmcs.rAX, 004Fh
		jnz exit
		movzx eax, rmcs.rES
		shl eax, 4
		movzx edx, rmcs.rDI
		add eax, edx
		mov edi, eax
		movzx eax, @flat:[edi].PMTABLE.dwOfs07
		movzx ecx, @flat:[edi].PMTABLE.dwOfs09
		lea eax, [eax+edi]
		lea ecx, [ecx+edi]
ife ?FLAT
externdef __baseadd:dword
		add eax, __baseadd
		add ecx, __baseadd
endif
		push ecx
		invoke _SetDisplayStartProc, eax
		pop ecx
		invoke _SetPaletteProc, ecx
exit:
		ret
		align 4
_GetPMTable endp

endif


SetVesa32Options proc public pOptions:ptr VESA32OPTIONS

		pushad
		mov esi, pOptions
		movzx ecx, [esi].VESA32OPTIONS.wSize
		mov edi, offset g_Vesa32Options
		rep movsb
if ?USEPMPROCS
		.if (g_Vesa32Options.bUsePMTable)
			invoke _GetPMTable
		.else
			invoke _SetDisplayStartProc, 0
			invoke _SetPaletteProc, 0
		.endif
endif
		popad
		ret
		align 4
SetVesa32Options endp

		END
