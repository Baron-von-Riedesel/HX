
;--- JHDPMI intercepts IRQ vectors 0-F
;--- and routes it to either VCPI client or v86 code.

	.386
	.model flat, stdcall

	.nolist
	include jlm.inc
	.list

DEVICE_ID equ 4858h

NUMHOOKS equ 16+1

cr equ 13
lf equ 10

DLL_PROCESS_ATTACH  equ 1
DLL_PROCESS_DETACH  equ 0

;--- structure for VCPI function DE0C (switch to protected mode)

VCPI_V862PM struct
_cr3	dd ?	;value for cr3
_gdtr	dd ?	;linear address of pseudo descriptor for GDTR
_idtr	dd ?	;linear address of pseudo descriptor for IDTR
_LDTR	dw ?	;value for LDTR
_TR		dw ?	;value for TR
_Eip	dd ?	;value for Eip
_Cs		dd ?	;value for CS
VCPI_V862PM ends

	.data

;--- the DDB must be make public. The linker will "export" this
;--- symbol. This is the simplest method to make JLoad know the
;--- device id.

	public ddb

ddb VxD_Desc_Block <0,0,DEVICE_ID,1,0,0,"JHDPMI",0,0, dispatch >

HOOKSTR struct
	VCPI_V862PM <>
HOOKSTR ends

hooks HOOKSTR NUMHOOKS dup (<<0>>)
hookprocs label dword
IRQ=0
repeat NUMHOOKS
	dd offset @CatStr(irq_,%IRQ)_hook_proc
IRQ=IRQ+1
endm

	.code

;--- callout handles both
;--- hooks for VCPI clients and v86 code.

callout proc

	pop edx
	add edx, offset hooks
	cmp [edx].HOOKSTR._cr3, 0
	jnz isvcpi
	movzx ecx, word ptr [ebp].Client_Reg_Struc.Client_SS
	shl ecx, 4
	sub [ebp].Client_Reg_Struc.Client_ESP, 3*sizeof WORD
	add ecx, [ebp].Client_Reg_Struc.Client_ESP
	mov eax, [edx].HOOKSTR._Eip
	xchg eax, [ebp].Client_Reg_Struc.Client_EIP
	mov [ecx], ax
	mov eax, [edx].HOOKSTR._Cs
	xchg eax, [ebp].Client_Reg_Struc.Client_CS
	mov [ecx+2], ax
	mov eax, [ebp].Client_Reg_Struc.Client_EFlags
	mov [ecx+4], ax
	and byte ptr [ebp].Client_Reg_Struc.Client_EFlags+1, not 3	;reset IF & TF
	ret
isvcpi:
	mov esi, edx
	VMMJmp V86ToPM

callout endp

IRQ=0
repeat NUMHOOKS
@CatStr(oldhook,%IRQ) dd 0
HookProc @CatStr(irq_,%IRQ)_hook_proc, @CatStr(oldhook,%IRQ)
	push IRQ*sizeof HOOKSTR
	jmp callout
@CatStr(irq_,%IRQ)_hook_proc endp
	IRQ=IRQ+1
endm

;--- dispatcher for v86 services

dispatch proc

	@VMMCall Simulate_Far_Ret	;emulate a RETF in v86

	and [ebp].Client_Reg_Struc.Client_EFlags,not 1  ;clear Carry flag
	movzx eax, word ptr [ebp].Client_Reg_Struc.Client_EAX
	cmp ax, 0
	jz getversion
	cmp ax, 1
	jz hookivtV86
	cmp ax, 2
	jz hookivtVCPI
	cmp ax, 3
	jz unhookivt
ifdef _DEBUG 
	cmp ax, 4
	jz dispstatus
endif
error::
	or [ebp].Client_Reg_Struc.Client_EFlags,1  ;set Carry flag
	ret
	align 4

dispatch endp

getversion proc

	mov word ptr [ebp].Client_Reg_Struc.Client_EAX, 0100h
	ret
	align 4

getversion endp

;--- in: AL=INT
;--- out: AH=index for HOOKSTR table (0-15 are for IRQs)

GetIndex proc
	mov ah, al
	sub ah, 8
	cmp al, 8
	jb err
	cmp al, 10h
	jb @F
	cmp al, 1Ch
	jz is1C
	cmp al, 70h
	jb err
	cmp al, 78h
	jnb err
	sub ah, 60h
@@:
	clc
	ret
is1C:
	mov ah, 16
	ret
err:
	stc
	ret
GetIndex endp

;--- hook a v86 int chain
;--- in: BL=vector#
;--- CX:EDX: CS:EIP to call (will be copied to VCPIRM2PM)
;--- ESI: linear address VCPIRM2PM struct in 1. MB for callout
;--- EDI: linear address Client_Reg_Struc struct in 1. MB
;--- INTs supported are 08h-0Fh, 1Ch, 70h-77h

hookivtVCPI proc

	mov bh,0
hookivtBoth::
	movzx eax, byte ptr [ebp].Client_Reg_Struc.Client_EBX
	call GetIndex
	jc error
;--- AL=int#, AH=index for hooks array
	movzx edx, ah
	mov ecx, sizeof HOOKSTR
	imul edx, ecx
	add edx, offset hooks
	cmp [edx].HOOKSTR._Cs, 0	; INT already hooked?
	jnz error
	push edx
	movzx esi, ah
	mov esi,[esi*4+hookprocs]
	movzx eax, al
	@VMMCall Hook_V86_Int_Chain
	pop edx
	jc error
	cmp bh,1
	jz isv86
	pushad
	mov esi, [ebp].Client_Reg_Struc.Client_ESI
	mov edi, edx
	mov ecx, sizeof VCPI_V862PM / 4
	rep movsd
	popad
	ret
isv86:
	movzx ecx, word ptr [ebp].Client_reg_Struc.Client_EDX
	mov [edx].HOOKSTR._Eip, ecx
	movzx ecx, word ptr [ebp].Client_reg_Struc.Client_ECX
	mov [edx].HOOKSTR._Cs, ecx
	xor ecx, ecx
	mov [edx].HOOKSTR._cr3, ecx
	ret
hookivtVCPI endp

;--- hook a v86 int chain
;--- in:  BL=vector#
;---   CX:DX=CS:IP to call
;--- INTs supported are 08h-0Fh, 1Ch, 70h-77h

hookivtV86 proc

	mov bh,1
	jmp hookivtBoth

hookivtV86 endp

unhookivt proc

	movzx eax, byte ptr [ebp].Client_Reg_Struc.Client_EBX
	call GetIndex
	jc error
;--- AL=int#, AH=index for hooks array
	movzx edx, ah
	mov ecx, sizeof HOOKSTR
	imul edx, ecx
	add edx, offset hooks
	cmp [edx].HOOKSTR._Cs, 0	; is the INT hooked?
	jz error
	push edx
	movzx esi, ah
	mov esi,[esi*4+hookprocs]
	movzx eax, al
	@VMMCall Unhook_V86_Int_Chain
	pop edx
	jc error
	mov [edx].HOOKSTR._Cs, 0
	ret

unhookivt endp

ifdef _DEBUG

	include printf.inc

CStr macro text:vararg
local sym
	.const
sym db text,0
	.code
	exitm <offset sym>
endm

dispstatus proc
	invoke printf, CStr("JHDPMI status:",13,10)
	mov ecx, NUMHOOKS
	mov esi, offset hooks
nextitem:
	cmp [esi].HOOKSTR._Cs, 0
	jz @F
	mov eax, ecx
	sub eax, NUMHOOKS
	neg eax
	invoke printf, CStr("#%u: cs:ip=%X:%X",13,10), eax, [esi].HOOKSTR._Cs, [esi].HOOKSTR._Eip
@@:
	add esi, sizeof HOOKSTR
	loop nextitem
	ret
dispstatus endp
endif

install proc uses esi pcomm:ptr JLCOMM

	mov eax,1
	ret
	align 4

install endp

;--- deinstall the JLM:

deinstall proc pcomm:ptr JLCOMM

	mov ecx, 16
	mov esi, offset hooks
@@:
	cmp [esi].HOOKSTR._Cs,0
	jnz failed
	add esi, sizeof HOOKSTR
	loop @B
	mov eax, 1
	ret
failed:
	xor eax, eax
	ret
	align 4

deinstall endp

DllMain proc stdcall public hModule:dword, dwReason:dword, dwRes:dword

	mov eax,dwReason
	cmp eax,DLL_PROCESS_ATTACH
	jnz @F
	invoke install, dwRes
	jmp exit
@@:
	cmp eax,DLL_PROCESS_DETACH
	jnz @F
	invoke deinstall, dwRes
@@:
exit:
	ret
	align 4

DllMain endp

	end DllMain
