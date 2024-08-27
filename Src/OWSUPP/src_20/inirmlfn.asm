
	.386
	.model small

DGROUP group _DATA, CONST, XI, YI

	externdef __fatal_runtime_error_:near

	public ___lfn_rm_tb_linear
	public ___lfn_rm_tb_segment

CONST segment dword public 'DATA'	; using .const would assign class 'CONST', but OW needs 'DATA'
msg db "Unable to allocate LFN real mode transfer buffer",0
CONST ends

	.data

___lfn_rm_tb_linear dd 0
___lfn_rm_tb_segment dw 0
___lfn_rm_tb_selector dw 0

XI segment word public 'DATA'
___anon98:
	db 00h, 0ah
	dd offset init_
XI ends
YI segment word public 'DATA'
___anon99:
	db 00h, 0ah
	dd offset fini_
YI ends

	.code

init_:
	push EBX
	push ECX
	push EDX
	mov ECX,offset ___lfn_rm_tb_segment
	mov EBX,41h
	mov AX,100h
	int 31h
	jb L1F
	mov [ECX],AX
	xor EAX,EAX
	mov AX,DX
	jmp L21
L1F:
	xor EAX,EAX
L21:
	mov ___lfn_rm_tb_selector,AX
	test AX,AX
	je L4A
	mov BX,AX
	mov AX,6
	int 31h
	push cx
	push dx
	pop eax
	mov ___lfn_rm_tb_linear,EAX
	pop EDX
	pop ECX
	pop EBX
	ret
L4A:
	mov EDX,-1
	mov EAX,offset msg
	jmp __fatal_runtime_error_
	align 4
fini_:
	push EDX
	mov DX,___lfn_rm_tb_selector
	mov AX,101h
	int 31h
	sbb EAX,EAX
	pop EDX
	ret

	end
