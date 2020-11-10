
;--- Save/Restore VESA video state

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

?PLANESIZ	equ 8000h
?EXTRASIZ	equ 4*4
?CURRPAGE	equ 0		;1=save current text page only

	.CODE

GetVesaMemoryBufferSize proc public dwMode:dword

local	svi:SVGAINFO

	invoke GetVesaModeInfo, dwMode, addr svi
	.if (eax)
		.if (svi.MemoryModel == 0)	;text mode?
istextmode:
if ?CURRPAGE
			movzx ecx, byte ptr @flat:[44Ah]
			movzx eax, byte ptr @flat:[484h]
			inc eax
			mul ecx
			shl eax, 1
else
			mov eax, 8000h		;save all test pages (32kB)
endif
			add eax, ?PLANESIZ
		.else
			movzx eax, svi.YResolution
			movzx ecx, svi.BytesPerScanLine
			mul ecx
			movzx ecx, svi.NumberOfPlanes
			mul ecx
		.endif
		add eax, ?EXTRASIZ	;some extra bytes for vesa info
	.else
		mov eax, dwMode
		and ah,3Fh
		.if (!ah)
			mov dx, 3CEh
			mov al, 6
			out dx, al
			inc dx
			in al,dx
			test al,1
			jz istextmode
		.endif
		xor eax, eax
	.endif
	ret
	align 4
GetVesaMemoryBufferSize endp

;--- save some VGA registers

savetab label word
	dw 3c4h
	db 2, 4, -1
	dw 3ceh
	db 1, 4, 5, 6, 8, -1
	dw -1
	align 4

savevgaregs proc uses esi edi pSaveBuff:ptr
	lea esi, savetab
	mov edi, pSaveBuff
nextitem:
	lodsw
	mov edx, eax
	cmp ax,-1
	jz done
nextitem2:
	lodsb
	cmp al,-1
	jz nextitem
	out dx,al
	inc edx
	in al,dx
	stosb
	dec edx
	jmp nextitem2
done:
	ret
	align 4
savevgaregs endp

loadvgaregs proc uses esi edi pSaveBuff:ptr
	lea esi, savetab
	mov edi, pSaveBuff
nextitem:
	lodsw
	mov edx, eax
	cmp ax,-1
	jz done
nextitem2:
	lodsb
	cmp al,-1
	jz nextitem
	mov ah, [edi]
	out dx,ax
	inc edi
	jmp nextitem2
done:
	ret
	align 4
loadvgaregs endp

;--- set VGA planes: changes eax edx
;--- set register: 3CE: 4
;--- set register: 3C4: 2

setplane2 proc
	mov ah,2
	mov dx,3ceh
	mov al,4		;"read map select"
	out dx,ax
	mov dl,0c4h
	mov cl,ah
	mov ah,1
	shl ah,cl
	mov al,2		;"map mask" register:select map to write to
	out dx,ax
	ret
	align 4
setplane2 endp

;--- setevenmode: changes edx, eax
;--- sets register: 3CE: 1, 5, 6, 8
;--- sets register: 3C4: 4

setevenmode proc
	mov dx,3ceh
	mov ax,1		;"enable set/reset" register
	out dx,ax

	mov al,5		;"graphics mode" register
	out dx,al
	inc edx
	in al,dx
	and al,084h 	;reset "odd/even mode", set "read mode 0"
	out dx,al		;set "write mode" 0

	mov dl,0ceh
	mov al,6		;"miscellaneous" register
	out dx,al
	inc edx
	in al,dx
	and al,0F0h 	;reset "odd/even"
	or al,5		;set addr=A0000h,64K, graphics mode
	out dx,al

	mov dl,0ceh
	mov al,8		;"bit mask" register: all bits to change 
	mov ah,0FFh
	out dx,ax

	mov dl,0c4h
	mov al,4
	out dx,al
	inc edx
	in al,dx
	and al,not 8	;reset "chain 4"
	or al,4+2		;set odd/even=4, set extended memory=2	
	out dx,al
	ret
	align 4
setevenmode endp

getscreenptr proc
	mov eax, 0B8000h
	cmp byte ptr @flat:[463h],0D4h
	jz @F
	mov ax,0
@@:
if ?CURRPAGE
	movzx edx, word ptr @flat:[44eh]
	add eax, edx
endif
	ret
	align 4
getscreenptr endp


;--- save debuggee's video memory
;--- inp: EDI = save buffer

savevidmem proc uses esi

ife ?FLAT
	push ds
	push gs
	pop ds
endif
if ?CURRPAGE
	movzx ecx, byte ptr @flat:[44ah]
	movzx eax, byte ptr @flat:[484h]
	inc eax
	mul ecx
else
	mov eax, 8000h/2
endif
	mov ecx, eax
	stosd
	call getscreenptr
	mov esi, eax
	rep movsw
	call setevenmode
	call setplane2				;charset plane
	mov esi,0A0000h
	mov ecx,?PLANESIZ/4
	rep movsd
ife ?FLAT
	pop ds
endif
	ret
	align 4
savevidmem endp


loadvidmem proc uses edi

ife ?FLAT
	push es
	push gs
	pop es
endif
	lodsd
	mov ecx, eax
	call getscreenptr
	mov edi, eax
	rep movsw
	call setevenmode
	call setplane2
	mov edi,0A0000h
	mov ecx,?PLANESIZ/4
	rep movsd
ife ?FLAT
	pop es
endif
	ret
	align 4
loadvidmem endp

SaveVesaVideoMemory proc public uses esi edi ebx pSaveBuffer:ptr, dwSize:dword

local	dwMode:dword
local	savereg[24]:byte
local	svi:SVGAINFO

	mov edi, pSaveBuffer
	mov eax, dwSize
	stosd
	invoke GetVesaMode
	mov dwMode, eax
	stosd
	invoke GetVesaModeInfo, dwMode, addr svi
	movzx eax, svi.MemoryModel
	stosd
	.if (al == 0)
		invoke savevgaregs, addr savereg
		call savevidmem
		invoke loadvgaregs, addr savereg
		mov eax, 1
	.else
		mov eax, svi.PhysBasePtr
		stosd
		mov esi, eax
		xor ebx, ebx
		.if (esi)
			inc ebx
			mov ecx, dwSize
			sub ecx, ?EXTRASIZ
ife ?FLAT
			push ds
			push gs
			pop ds
endif
			rep movsb
ife ?FLAT
			pop ds
endif
		.endif
		mov eax, ebx
	.endif
@exit:
	ret
	align 4
SaveVesaVideoMemory endp

RestoreVesaVideoMemory proc public uses esi edi ebx pSaveBuffer:ptr

local	dwSize:dword
local	dwMode:dword
local	savereg[24]:byte
local	svi:SVGAINFO

	mov esi, pSaveBuffer
	lodsd
	mov dwSize, eax
	lodsd
	mov dwMode, eax
	lodsd
	.if (al == 0)
		invoke savevgaregs, addr savereg
		call loadvidmem
		invoke loadvgaregs,addr savereg
		mov eax, 1
	.else
		lodsd
		xor ebx, ebx
		mov edi, eax
		.if (edi)
			inc ebx
			mov ecx, dwSize
			sub ecx, ?EXTRASIZ
ife ?FLAT
			push es
			push gs
			pop es
endif
			rep movsb
ife ?FLAT
			pop es
endif
		.endif
		mov eax, ebx
	.endif
@exit:
	ret
	align 4
RestoreVesaVideoMemory endp

		END
