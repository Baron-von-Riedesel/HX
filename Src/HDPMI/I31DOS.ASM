
;--- implements int 31h, ax=01xxh (dos memory)

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

_TEXT32  segment

	assume DS:nothing

;*** function 0x0100: alloc BX paragraphs DOS memory
;--- return selector in DX, segment in AX
;--- on error BX contains paragraphs of largest block

	@ResetTrace

allocdos proc public
	pushad
	@dprintf "allocdos: try to alloc %X paragraphs DOS memory",bx
	mov ah,48h
	call rmdos
	jc allocdos_err1
	movzx eax,ax		;segment
	movzx ebx,bx		;size
	mov esi,eax			;save segment value in ESI
	shl eax,4			;eax == linear address
	shl ebx,4			;ebx == size in bytes
	push ebx
	push eax
	call desc_alloc
	jc allocdos_err2
	mov [esp].PUSHADS.rDX,ax
	mov [esp].PUSHADS.rAX,si
	popad
	ret
allocdos_err2:
	mov ss:v86iret.rES, si
	mov ah,49h
	call rmdos
	popad
	mov ax,8011h	;no descriptors available
	stc
	ret
allocdos_err1:
	mov [esp].PUSHADS.rBX, bx
	mov [esp].PUSHADS.rAX, ax
	popad
	stc
	ret
	align 4
allocdos endp

;*** function 0x0101: free dos memory block
;*** in: DX=selector of block

	@ResetTrace

clientDS equ <[esp + sizeof PUSHADS + 4]>	;where client's DS is saved

freedos proc public
	pushad
	@dprintf "freedos: enter dos free memory, DS=%X", word ptr clientDS
	lar eax,edx
	jnz freedos_err1		;invalid selector (i.e. beyond LDT limit)
	mov ebx,edx
	call bx_sel2segm
	jc freedos_err1			;it's not a DOS selector
	mov ss:v86iret.rES, bx
	mov ah,49h
	call rmdos				;es=segment
	@dprintf "freedos: rc from DOS: %X",ax
	jc freedos_err2
	call desc_free
	lar eax, clientDS
	jz @F
	xor eax,eax
	mov clientDS, eax
@@:
	popad
	clc
	ret
freedos_err2:
	mov [esp].PUSHADS.rAX,ax
	popad
	stc
	ret
freedos_err1:
	popad
	mov ax,8022h
	stc
	ret
	align 4
freedos endp

;*** function 0x0102: resize dos memory block
;*** dx=selector, bx=new size (paragraphs)
;*** out: 
;--- NC no error, 
;--- C on errors, then ax (+bx) modified
;--- this function is also called by int 21h, ah=4Ah if block address
;--- is in first MB

	@ResetTrace

resizedos proc public
	pushad
	lar eax,edx
	jnz resizedos_err1		;invalid selector (i.e. beyond LDT limit)
	@dprintf "resizedos: selector %X seems ok", dx
	mov ebx,edx
	call bx_sel2segm
	jc resizedos_err2		;it's not a DOS selector
	@dprintf "resizedos: memory is dos memory (%X)",bx
	mov ss:v86iret.rES, bx
ife ?32BIT
	movzx ebx,[esp].PUSHADS.rBX
	shl ebx,4
	call desc_avail			;enough free LDT descriptors available?
	jc resizedos_err4
endif
	mov bx,[esp].PUSHADS.rBX
	mov ah,4Ah
	call rmdos				;es=segment,bx=req. size
	jc resizedos_err3
	@dprintf "resizedos: DOS has resized memory"
	movzx eax,word ptr [esp].PUSHADS.rBX
	shl eax,4
	call desc_resize		;resize selector DX, new size EAX
	jc resizedos_err4		;might fail for 16-bit clients
	@dprintf "resizedos: selectors adjusted"
ife ?32BIT
;--- if the block has shrinked, the selector in DS may have become invalid!
	lar eax, clientDS
	jz @F
	xor eax,eax
	mov clientDS, eax
@@:
endif
	popad
	clc
	ret
resizedos_err4:
	popad
	mov ax,8011h			;"descriptor unavailable"
	@dprintf "resizedos: error 8011"
	ret
resizedos_err3:
;--- due to a bug in many DOSes even if the call failed the block has been
;--- resized to the max size possible. It might be good to reset it now to
;--- its original size, but this is NOT done by other hosts (Win9x).
	@dprintf "resizedos: error %X, BX=%X",ax,bx
	mov [esp].PUSHADS.rBX, bx
	mov [esp].PUSHADS.rAX, ax
	popad
	ret
resizedos_err2:
resizedos_err1:
	@dprintf "resizedos: dx=%X, error 8022", dx
	popad
	mov ax,8022h
	stc
	ret
	align 4
resizedos endp

_TEXT32 ends

	end

