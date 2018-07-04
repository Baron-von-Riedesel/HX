
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
	@strout <"try to alloc %X paragraphs DOS memory",lf>,bx
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
	call selector_alloc
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
;	xor bx,bx		;no DOS memory available
	mov ax,8011h
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

	@ResetTrace

clientDS equ <[esp + sizeof PUSHADS + 4]>	;where client's DS is saved

freedos proc public
	pushad
	@strout <"i31: enter dos free memory, DS=%X",lf>, <word ptr clientDS>
	lar eax,edx
	jnz freedos_err			;invalid selector
	mov ebx,edx
	call bx_sel2segm
	jc freedos_err			;it's not a DOS selector
	mov ss:v86iret.rES, bx
	mov ah,49h
	call rmdos				;es=segment
	@strout <"i31: rc from DOS: %X",lf>,ax
	jc freedos_err2
	call selector_free
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
freedos_err:
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
	jnz resizedos_err		;selector is invalid
	@strout <"resize dos: selector %X seems ok",lf>, dx
	mov ebx,edx
	call bx_sel2segm
	jc resizedos_err2		;it's not a DOS selector
	@strout <"resize dos: memory is dos memory (%X)",lf>,bx
	mov ss:v86iret.rES, bx
ife ?32BIT
	movzx ebx,[esp].PUSHADS.rBX
	shl ebx,4
	call selector_avail		;test if there are enough free descriptors
	jc resizedos_err4
endif
	mov bx,[esp].PUSHADS.rBX
	mov ah,4Ah
	call rmdos				;es=segment,bx=req. size
	jc resizedos_err3
	@strout <"resize dos: DOS has resized memory",lf>
	movzx eax,word ptr [esp].PUSHADS.rBX
	shl eax,4
	call selector_resize		;resize selector DX, new size EAX
	jc resizedos_err4		;might fail for 16-bit clients
	@strout <"resize dos: selectors adjusted",lf>
ife ?32BIT
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
	@strout <"resize dos: error 8011",lf>
	ret
resizedos_err3:
;--- due to a bug in many DOSes even if the call failed the block has been
;--- resized to the max size possible. It might be good to reset it now to
;--- its original size, but this is NOT done by other hosts (Win9x).
	@strout <"resize dos: error %X, BX=%X",lf>,ax,bx
	mov [esp].PUSHADS.rBX, bx
	mov [esp].PUSHADS.rAX, ax
	popad
	ret
resizedos_err2:
resizedos_err:
	@strout <"resize dos: error 8022",lf>
	popad
	mov ax,8022h
	stc
	ret
	align 4
resizedos endp

_TEXT32  ends

	end

