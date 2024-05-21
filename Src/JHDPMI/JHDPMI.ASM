
;--- JHDPMI intercepts IRQ vectors 0-F and INT 1Ch
;--- and routes it to either VCPI client or v86 code.

;--- multiple hooks per IRQ are possible. However, the
;--- max # of hooks is 255.

	.386
	.model flat, stdcall
	option casemap:none
	option proc:private

	.nolist
	include jlm.inc
	.list

DEVICE_ID equ 4858h

STATUS equ 1
LOG equ 1	;add count

NUMHOOKS equ 16+1

cr equ 13
lf equ 10

DLL_PROCESS_ATTACH  equ 1
DLL_PROCESS_DETACH  equ 0

	.data

;--- the DDB must be make public. The linker will "export" this
;--- symbol. This is the simplest method to make JLoad know the
;--- device id.

	public ddb

ddb VxD_Desc_Block <0,0,DEVICE_ID,1,0,0,"JHDPMI",0,0, dispatch >

dwConns dd 0

hooks  db NUMHOOKS dup (-1)

hookprocs label dword
IRQ=0
repeat NUMHOOKS
	dd offset @CatStr(irq_,%IRQ)_hook_proc
IRQ=IRQ+1
endm

	.data?

HOOKSTR struct
dwCSIP dd ?	; it's either v86 CS:IP or linear address of a VCPI_V862PM struct
HOOKSTR ends

hookarray HOOKSTR 255 dup (<?>)
hooktype dd 8 dup (?)
hookchain db 255 dup (?)	;-1 = last item in chain
if LOG
dwCnt dd 255 dup (?)
endif

	.code

ifdef _DEBUG
	include dprintf.inc
else
@dprintf textequ <;>
endif

;--- callout handles both
;--- hooks for VCPI clients and v86 code.
;--- [ESP+0]: hook index

callout proc

	pop edx
	movzx edx, [edx+hooks]
if LOG
	inc [edx*4+dwCnt]
endif
	bt [hooktype], edx
	jc isvcpi
	movzx ecx, word ptr [ebp].Client_Reg_Struc.Client_SS
	shl ecx, 4
	sub word ptr [ebp].Client_Reg_Struc.Client_ESP, 3*2
	movzx eax, word ptr [ebp].Client_Reg_Struc.Client_ESP
	add ecx, eax
	mov eax, [edx*4+hookarray].dwCSIP
	xchg ax, word ptr [ebp].Client_Reg_Struc.Client_EIP
	mov [ecx+0], ax
	shr eax, 16
	xchg eax, [ebp].Client_Reg_Struc.Client_CS
	mov [ecx+2], ax
	mov eax, [ebp].Client_Reg_Struc.Client_EFlags
	mov [ecx+4], ax
	and byte ptr [ebp].Client_Reg_Struc.Client_EFlags+1, not 3	;reset IF & TF
	ret
isvcpi:
	mov esi, [edx*4+hookarray].dwCSIP
	VMMJmp V86ToPM

callout endp

IRQ=0
repeat NUMHOOKS
@CatStr(oldhook,%IRQ) dd 0
HookProc @CatStr(irq_,%IRQ)_hook_proc, @CatStr(oldhook,%IRQ)
	push IRQ
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
	jz connect
	cmp ax, 2
	jz disconnect
	cmp ax, 3
	jz hookivtV86
	cmp ax, 4
	jz unhookivt
	cmp ax, 5
	jz xchgivtV86
	cmp ax, 11h
	jz hookivtVCPI
if STATUS
	cmp ax, 12h
	jz dispstatus
endif
error::
	or [ebp].Client_Reg_Struc.Client_EFlags,1  ;set Carry flag
	ret
connect:
	inc [dwConns]
	ret
disconnect:
	cmp [dwConns],0
	jz @F
	dec [dwConns]
@@:
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

setupregs proc
	movzx eax, byte ptr [ebp].Client_Reg_Struc.Client_EBX
	mov ah, al
	sub ah, 8
	cmp al, 8
	jb fail
	cmp al, 10h
	jb ok
	cmp al, 1Ch
	jz is1C
	cmp al, 70h
	jb fail
	cmp al, 78h
	jnb fail
	sub ah, 60h
	jmp ok
is1C:
	mov ah, 16
ok:
;--- AL=int#, AH=index for hooks array
	movzx edx, ah
	ret
fail:
	pop eax		; skip return address
	jmp error
setupregs endp

;--- hook a v86 int chain
;--- in: BL=vector#
;--- CX:EDX: CS:EIP to call (will be copied to VCPIRM2PM)
;--- ESI: linear address VCPIRM2PM struct in 1. MB for callout
;--- EDI: linear address Client_Reg_Struc struct in 1. MB
;--- INTs supported are 08h-0Fh, 1Ch, 70h-77h

hookivtVCPI proc

	mov bh,0
hookivtBoth::
	call setupregs

;	cmp [edx+hooks], -1	; INT already hooked?
;	jnz error
	@dprintf "jhdpmi hookivt: irq=%u", edx

;--- find a free entry in hookarray

	push eax
	mov eax, 0
	mov edi, offset hookarray
	mov ecx, 255
	repnz scasd
	pop eax
	jnz error		; no free entry found
	sub edi, 4 + offset hookarray
	shr edi, 2		; edi=index for hookarray ( & hookchain )


;--- register hook proc if not yet done

	cmp [edx+hooks], -1	; INT already hooked?
	jnz @F
	push eax
	movzx esi, ah
	mov esi,[esi*4+hookprocs]
	movzx eax, bl
	@VMMCall Hook_V86_Int_Chain
	pop eax
	jc error
@@:

;--- set the new entry in hookarray (index edi) in hooks[eax].
;--- link to the old entry (index ecx) in hookarray via hookchain[edi]

	movzx eax, ah
	mov ecx, edi
	xchg cl, [eax+hooks]
	mov [edi+hookchain], cl

	@dprintf "jhdpmi hookivt: hook ok, array index=%u", edi

;--- clear log, set hooktype, set hookarray values

if LOG
	mov [edi*4+dwCnt], 0
endif
	btr [hooktype], edi
	cmp bh,1
	jz @F
	bts [hooktype], edi
@@:
	mov cx, word ptr [ebp].Client_Reg_Struc.Client_ECX
	shl ecx, 16
	mov cx, word ptr [ebp].Client_Reg_Struc.Client_EDX
	mov [edi*4+hookarray].HOOKSTR.dwCSIP, ecx
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

xchgivtV86 proc
	call setupregs
	cmp [edx+hooks], -1	; INT hooked?
	jz error
	movzx eax, [edx+hooks]
	bt [hooktype], eax	; VCPI hook?
	jc error
	mov cx, word ptr [ebp].Client_Reg_Struc.Client_ECX
	shl ecx, 16
	mov cx, word ptr [ebp].Client_Reg_Struc.Client_EDX
	xchg ecx, [eax*4+hookarray].HOOKSTR.dwCSIP
	mov word ptr [ebp].Client_Reg_Struc.Client_EDX, cx
	shr ecx, 16
	mov word ptr [ebp].Client_Reg_Struc.Client_ECX, cx
	ret
xchgivtV86 endp

unhookivt proc

	call setupregs
	@dprintf "jhdpmi unhookivt: irq=%u", edx
	cmp [edx+hooks], -1	; INT hooked?
	jz error

	movzx ecx, [edx+hooks]
	cmp [ecx+hookchain], -1	; last entry?
	jnz @F

;--- unhook if it's the last entry in the chain
	push edx
	movzx esi, ah
	mov esi,[esi*4+hookprocs]
	movzx eax, al
	@VMMCall Unhook_V86_Int_Chain
	pop edx
	jc error

@@:

;--- free the entry in hookarray

	movzx eax, [edx+hooks]
	mov [eax*4+hookarray], 0

;--- get the old index (hookchain[hooks[edx]]) and store in in hooks[edx]

	movsx ecx, [eax+hookchain]
	mov [eax+hookchain], -1
	mov [edx+hooks], cl

	@dprintf "jhdpmi unhookivt: array index=%u, next index=%d", eax, ecx

	ret

unhookivt endp

if STATUS

	include printf.inc

CStr macro text:vararg
local sym
	.const
sym db text,0
	.code
	exitm <offset sym>
endm

dispstatus proc
	invoke printf, CStr("JHDPMI status (%u connected):",13,10), dwConns
	xor esi, esi
nextitem:
	cmp [esi+hooks], -1
	jz @F
	movzx edx, [esi+hooks]
	movzx eax, word ptr [edx*4+hookarray].HOOKSTR.dwCSIP+2
	movzx ecx, word ptr [edx*4+hookarray].HOOKSTR.dwCSIP+0
	movsx ebx, [edx+hookchain]
 if LOG
	invoke printf, CStr("#%u: cs:ip=%X:%X cnt=%u [idx=%u, old=%d]",13,10), esi, eax, ecx, [edx*4+dwCnt], edx, ebx
 else
	invoke printf, CStr("#%u: cs:ip=%X:%X [idx=%u old=%d]",13,10), esi, eax, ecx, edx, ebx
 endif
@@:
	inc esi
	cmp esi, NUMHOOKS
	jnz nextitem
	ret
dispstatus endp
endif

install proc uses edi pcomm:ptr JLCOMM

	mov edi, offset hookarray
	mov ecx, 255+8
	xor eax, eax
	rep stosd
	mov cl, 255
	mov al, -1
	rep stosb
	mov al, 0
if LOG
	mov cl, 255
	rep stosd
endif
	mov eax,1
	ret
	align 4

install endp

;--- deinstall the JLM:

deinstall proc pcomm:ptr JLCOMM

	cmp [dwConns],0
	jnz failed
	xor esi, esi
@@:
	cmp [esi+hooks], -1
	jnz failed
	inc esi
	cmp esi, NUMHOOKS
	jnz @B
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
