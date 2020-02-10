
;--- alloc/free dos memory
;--- if dos is not in use, use dpmi ax=0300h to alloc/free memory
;--- else alloc/free the block by directly modifying the mcb chain 

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc
	include dpmi.inc
	include dkrnl32.inc

	.data

g_pMCB	dd 0

	.code

_initdosmem proc uses edi ebx

local	rmcs:RMCS

	xor ecx,ecx
	mov rmcs.rSSSP,ecx
	mov rmcs.rFlags,cx
	mov byte ptr rmcs.rEAX+1,52h	;get DOS List of Lists
	mov bx,0021h
	mov ax,0300h
	lea edi, rmcs
	push es
	push ss
	pop es
	int 31h
	pop es
	movzx eax,rmcs.rES				;returned in ES:BX
	movzx ecx,rmcs.rBX
	shl eax,4
	add eax,ecx
	movzx eax, word ptr @flat:[eax-2]	;get the start of MCB chain
	shl eax,4
	mov g_pMCB,eax
	ret
	align 4
_initdosmem endp

;--- get DOS mem in BX
;--- return segment in AX
;--- or Carry on errors
;--- SS may be LPMS!
;--- ebx destroyed

_allocdosmem proc public uses edi

local	rmcs:RMCS

	mov edx,g_indosaddr
	cmp byte ptr @flat:[edx],0
	jz dos_is_free
	@noints
	mov edi, g_pMCB
	and edi,edi
	jnz scanblock
notfound:
	@restoreints
	stc
	ret
nextmcb:
	shl eax,4
	lea edi,[edi+eax+10h]
scanblock:
	mov cl,@flat:[edi]
	cmp cl,'M'
	jz @F
	cmp cl,'Z'
	jnz notfound
@@:
	movzx eax,word ptr @flat:[edi+3]
	cmp word ptr @flat:[edi+1],0
	jnz nextmcb
	cmp ax,bx
	jb nextmcb
	jz suitsexact
	mov byte ptr @flat:[edi],'M'
	mov word ptr @flat:[edi+3],bx	;size
	movzx ebx,bx
	sub ax,bx
	dec ax
	shl ebx, 4
	mov byte ptr @flat:[edi+ebx+10h],cl
	mov word ptr @flat:[edi+ebx+11h],0	;PSP
	mov word ptr @flat:[edi+ebx+13h],ax	;size
suitsexact:
	mov word ptr @flat:[edi+1],8	;temporary
	@restoreints
	xor ecx,ecx
	mov rmcs.rSSSP,ecx
	mov rmcs.rFlags,cx
	mov byte ptr rmcs.rEAX+1,51h
	mov bx,0021h
	mov ax,0300h
	push edi
	lea edi, rmcs
	push es
	push ss
	pop es
	int 31h
	pop es
	pop edi
	mov ax,rmcs.rBX
	mov word ptr @flat:[edi+1],ax	;PSP
	lea eax,[edi+10h]
	shr eax,4
	clc
	ret
	align 4

dos_is_free:
	cmp g_pMCB,0
	jnz @F
	call _initdosmem
@@:
	mov rmcs.rBX, bx
	xor ecx,ecx
	mov rmcs.rSSSP,ecx
	mov rmcs.rFlags,cx
	mov byte ptr rmcs.rEAX+1,48h
	mov bx,0021h
	mov ax,0300h
	lea edi, rmcs
	push es
	push ss
	pop es
	int 31h
	pop es
	mov ax,rmcs.rAX
	shr byte ptr rmcs.rFlags,1
	ret
	align 4

_allocdosmem endp

;--- free dos segment in AX
;--- SS may be LPMS!

_freedosmem proc public

local	rmcs:RMCS

	mov edx,g_indosaddr
	cmp byte ptr @flat:[edx],0
	jz dos_is_free
	dec eax
	shl eax, 4
	mov word ptr @flat:[eax+1],0
	.if (byte ptr @flat:[eax] == 'M')
		movzx ecx, word ptr @flat:[eax+3]
		inc ecx
		shl ecx, 4
		add ecx, eax
		.if (word ptr @flat:[ecx+1] == 0)
			mov dx,@flat:[ecx+3]
			inc dx
			add @flat:[eax+3],dx
			mov dl,@flat:[ecx]
			mov @flat:[eax],dl
		.endif
	.endif
	clc
	ret
	align 4
dos_is_free:
	mov rmcs.rES, ax
	xor ecx,ecx
	mov rmcs.rSSSP,ecx
	mov rmcs.rFlags,cx
	mov byte ptr rmcs.rEAX+1,49h
	push edi
	push ebx
	mov bx,0021h
	mov ax,0300h
	lea edi, rmcs
	push es
	push ss
	pop es
	int 31h
	pop es
	pop ebx
	pop edi
	shr byte ptr rmcs.rFlags,1
	ret
	align 4
_freedosmem endp

	end

