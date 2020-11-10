
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include function.inc
	include vesa32.inc
	include dpmi.inc
	include equates.inc

;--- set max video memory to be mapped in bytes ( or 0 if all )

?MAXVIDEOMEM equ 0
?SAFEBUFF    equ 0	;alloc a 4 MB uncommitted buffer before LFB is mapped.  

	.DATA

if ?VESAVDD
externdef	g_hVesaVDD:dword
endif

externdef	g_bVesaInfo:byte

	public g_dwLinearBasePtr

g_dwPhysBasePtr		dd 0	;physical address of LFB
g_dwLinearBasePtr	dd 0	;linear address of LFB
g_dwXMax			dd -1
g_dwYMax			dd -1
g_dwFrequencyMax	dd -1


IsModeSupported proto :ptr SVGAINFO

	.CODE

IsModeSupported proc public pSvga:ptr SVGAINFO
	mov edx, pSvga
	mov eax, g_dwXMax
	mov ecx, g_dwYMax
	cmp ax, [edx].SVGAINFO.XResolution
	jc @F
	cmp cx, [edx].SVGAINFO.YResolution
	jnc isok
@@:
	and byte ptr [edx].SVGAINFO.ModeAttributes, not VESAATTR_SUPPORTED
isok:
	ret
	align 4
IsModeSupported endp

;--- most likely this function is called just once
;--- because the physical LFB start address will not change across modes

GetVesaVideoMemorySize proc public

	movzx eax, g_bVesaInfo
	.if (eax)
		cmp byte ptr g_vesainfo.VESAVersion+1,2
		jb error
		movzx eax, g_vesainfo.TotalMemory
		shl eax,16
		ret
	.endif
error:
	xor eax, eax
	ret
	align 4
GetVesaVideoMemorySize endp

;*** get informations about special svga mode
;*** returns: eax=0 on error,eax<>0 on success
;*** pInfo -> SVGAINFO struct
;*** phys. addr of LFB is transfered to linear addr.

;--- dont assume SS=FLAT! This function may be called 
;--- during interrupts when SS=LPMS

GetVesaModeInfo proc public uses ebx esi edi dwMode:dword,pInfo:ptr SVGAINFO

local	linmem:dword
local	dosmemsel:dword
local	rmcs:RMCS

	xor eax,eax
	mov dosmemsel,eax
	mov ax,0100h				  ;alloc DOS memory
	mov bx,10h					  ;256 bytes (sizeof SVGAINFO)
	int 31h
	jc getvesainfo_er
	mov dosmemsel,edx
	xor ecx,ecx
	mov rmcs.rSSSP,ecx
	mov rmcs.rDI,cx
	mov rmcs.rFlags,cx
	mov rmcs.rES,ax
	mov rmcs.rAX,4F01h
	mov ecx,dwMode
	and ch,03Fh
	mov rmcs.rCX,cx
	movzx eax,ax
	shl eax,4
	mov linmem,eax
	mov edi,eax
	mov ecx,sizeof SVGAINFO/4
	xor eax,eax
if ?FLAT eq 0
	push es
	push gs
	pop es
	rep stosd
	pop es
else
	rep stosd
endif
	lea edi,rmcs
	push es
	push ss
	pop es
	mov bx,0010h
	mov cx,0000h
	mov ax,0300h
	int 31h
	pop es
;	jc getvesainfo_er       ;copy the buffer content in any case!
;	cmp rmcs.rAX,004Fh
;	jnz getvesainfo_er
	mov edi,pInfo
	mov esi,linmem
	mov ecx,sizeof SVGAINFO/4
if ?FLAT eq 0
	push ds
	push gs
	pop ds
	rep movsd
	pop ds
else
	rep movsd
endif
	jc getvesainfo_er
	cmp rmcs.rAX,004Fh
	jnz getvesainfo_er
	mov edi,pInfo
	invoke IsModeSupported, edi
	test [edi].SVGAINFO.ModeAttributes, VESAATTR_LFB_SUPPORTED
	jz noLFB
	mov ecx,[edi].SVGAINFO.PhysBasePtr
	jecxz noLFB
if ?VESAVDD
	cmp g_hVesaVDD,0	;is VesaVDD installed?
	jnz getvesainfo_ex
endif
	mov eax, g_dwLinearBasePtr
	cmp ecx, g_dwPhysBasePtr
	jz mapped_already
	invoke GetVesaVideoMemorySize
	and eax, eax
	jz noLFB
if ?SAFEBUFF
;--- this is mainly for debugging purposes.
;--- thus if the video buffer is written with a "negative" offset,
;--- it might cause an access violation instead of memory corruption
	push eax
	xor ebx, ebx
	xor edx, edx	;uncommitted memory
	mov ecx, 400000h
	mov ax,0504h
	int 31h
	pop eax
endif
	mov cx, word ptr [edi].SVGAINFO.PhysBasePtr+0
	mov bx, word ptr [edi].SVGAINFO.PhysBasePtr+2
if ?MAXVIDEOMEM
	cmp eax, ?MAXVIDEOMEM
	jb @F
	mov eax, ?MAXVIDEOMEM
@@:
endif
	push edi
	push eax
	pop di
	pop si
	mov ax,0800h	;BX:CX=phys addr, SI:DI=size in bytes
	int 31h
	pop edi
	jc noLFB
	push bx
	push cx
	pop eax
	mov g_dwLinearBasePtr, eax
mapped_already:
	mov [edi].SVGAINFO.PhysBasePtr,eax
	jmp getvesainfo_ex
noLFB:
	test byte ptr dwMode+1,40h	 ;linear frame buffer obligatory?
	jz getvesainfo_ex
getvesainfo_er:
	xor eax,eax
getvesainfo_ex:
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
GetVesaModeInfo endp

SetMaxVideoResolution proc public xres:dword, yres:dword, dwFreqency:dword
	mov ecx, xres
	mov edx, yres
	mov eax, dwFreqency
	xchg ecx, g_dwXMax
	xchg edx, g_dwYMax
	xchg eax, g_dwFrequencyMax
	ret
	align 4
SetMaxVideoResolution endp

	end
