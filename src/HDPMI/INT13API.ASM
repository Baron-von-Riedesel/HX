
;--- implements API translation for Int 13h

	.386

	include hdpmi.inc
	include external.inc

	option proc:private

@seg _TEXT32

@getdrvparms macro
	mov ah,08h
	call intr13_ok
	mov [ebp-2],cx	 ;cylinder + sectors
	mov [ebp-4],dx	 ;heads,
endm

_TEXT32 segment

;--- FD cannot read beyond track limit

addsecs proc
	mov ah,[ebp-2]
	and ah,3Fh
	mov al,cl
	and al,3Fh
	xchg ch,cl
	shr ch,6
	add al,?TLBSECS

	cmp al,ah
	jbe @F

	sub al,ah
	inc dh
	cmp dh,[ebp-4+1]
	jbe @F
	mov dh,0
	inc cx
@@:
	xchg ch,cl
	shl cl,6
	or cl,al
	ret
	align 4
addsecs endp

;*** read sectors to es:(e)bx, use TLB

_LTRACE_ = 0

intr1302 proc
	push eax
if ?32BIT
	test ebx,0FFFF0000h
	jnz @F
endif
	push es
	call getlinaddr
	jc @F
	test eax,0FFF00000h
	jnz @F					;address in conv mem?
	shr eax,4
	mov ss:[v86iret.rES],ax
	pop eax
	jmp intr13_xx
@@:
	pop eax

	pushad
	mov ebp,esp

	@strout <"i13: ax=%X,cx=%X,dx=%X call",lf>,ax,cx,dx
	sub esp,4
	pushad
	@getdrvparms		 ;get drive structure
	popad
if ?32BIT
	mov edi,[ebp.PUSHADS.rEBX]
else
	movzx edi,[ebp.PUSHADS.rBX]
endif
intr1302_0:				;<----
	push eax
	cmp al,?TLBSECS
	jbe @F
	mov al,?TLBSECS
@@:
	push ecx
	push eax
	call setesreg2tlb
	xor ebx,ebx
	call intr13_ok
	mov byte ptr [ebp.PUSHADS.rEAX+1],ah
	jc intr1302_ex
	pop ecx 		 ;sectors read (AL)
	movzx ecx,cl
	shl ecx,9		 ;transform sector to bytes (*512)

	@strout <"i13: copy to %lX:%lX from %X %X bytes",lf>,es,edi,ss:[wSegTLB],cx

	push es
	push edi
	add edi,ecx
	push ss:[dwSegTLB]
	call copy_flat_2_far32

	pop ecx

	call addsecs			;dx and cx update

	pop eax
	sub al,?TLBSECS
	ja intr1302_0
	clc
intr1302_ex:
	mov esp,ebp
	popad
	ret
	align 4
intr1302 endp

;*** write sectors from es:e/bx, use TLB

_LTRACE_ = 0

intr1303 proc
	pushad
	mov ebp,esp

	@strout <"i13: ax=%X,bx=%X,cx=%X,dx=%X call",lf>,ax,bx,cx,dx

	sub esp,4

	pushad
	@getdrvparms		;get drive structure
	popad

if ?32BIT
	mov edi,ebx
else
	movzx edi,bx
endif
intr1303_0:				;<----
	push eax
	cmp al,?TLBSECS
	jbe @F
	mov al,?TLBSECS
@@:
	push ecx

	push es
	push edi
	push ss:[dwSegTLB]
	movzx ecx,al
	shl ecx,9		 ;transform sectors to bytes (*512)
	@strout <"i13: copy from %lX:%lX to %X %X bytes",lf>,es,edi,ss:[wSegTLB],cx
	add edi,ecx
	call copy_far32_2_flat

	pop ecx

	call setesreg2tlb
	@strout <"i13: call with ax=%X,bx=%X,cx=%X,dx=%X",lf>,ax,bx,cx,dx
	xor ebx,ebx
	call intr13_ok
	mov byte ptr [ebp.PUSHADS.rEAX+1],ah
	jc intr1303_ex

	@strout <"i13: successfull call, ax=%X",lf>,ax

	call addsecs			 ;dx and cx update

	pop eax
	sub al,?TLBSECS
	ja intr1303_0		   ;---->
	clc
intr1303_ex:
	mov esp,ebp
	popad
	ret
	align 4
intr1303 endp

intr1308 proc
	test dl,80h
	jnz intr13_ok
	call intr13_ok
	call es_segm2sel
	ret
	align 4
intr1308 endp

_LTRACE_ = 0

intr13 proc public
	cld
	push offset iret_with_CF_mod
	cmp ah,02
	jb intr13_ok
	jz intr1302
	cmp ah,03
	jz intr1303
	cmp ah,05
	jbe intr13_notok	;ah=05+04 not supported
	cmp ah,08
	jz intr1308
intr13_ok::
intr13_xx::
	@strout <"i13: call ax=%X",lf>,ax

	@simrmint 13h

	@strout <"i13: return from rm",lf>
	ret

intr13_notok:
	@strout <"i13: unsupported call ax=%X",lf>,ax
	stc
	ret
	align 4
intr13 endp

_TEXT32 ends

end

