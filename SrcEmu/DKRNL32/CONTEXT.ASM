
;--- helper functions to save/restore thread contexts

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
DGROUP group _TEXT
endif
	option casemap:none

	.nolist
	include winbase.inc
	include dkrnl32.inc
	include macros.inc
	.list

?FLOATREGS	equ 1	;std=1, 1=save FPU status in context
?USEIRET	equ 0	;std=0, 0=use RETD, 1=use IRETD

	.data

externdef g_bFPUPresent:byte

	.code

_SaveContext proc public hThread:dword, CC:CONTEXT_CTRL

	push edi
	push ds
	push es
	push fs
	mov edi, hThread
	mov ds, cs:[g_csalias]
	mov fs, [edi].THREAD.dwTibSel
	mov edi, [edi].THREAD.pContext
	mov es, [g_csalias]
	assume edi:ptr CONTEXT
	mov [edi].SegGs,gs
	pop [edi].SegFs
	pop [edi].SegEs
	pop [edi].SegDs
	pop [edi].rEdi
	mov [edi].rEsi, esi
	mov [edi].rEbx, ebx
	mov [edi].rEdx, edx
	mov [edi].rEcx, ecx
	mov [edi].rEax, eax
	mov ecx, CC.rEbp
	mov edx, CC.rEip
	mov ebx, CC.SegCs
	mov eax, CC.EFlags
	mov esi, CC.rEsp
	mov [edi].rEbp, ecx
	mov [edi].rEip, edx
	mov [edi].SegCs, ebx
	mov [edi].EFlags, eax
	mov [edi].rEsp, esi
	mov ecx, CC.SegSs
	mov [edi].SegSs, ecx

	mov [edi].ContextFlags,CONTEXT_FULL
if ?FLOATREGS        
	cmp g_bFPUPresent,0
	jz @F
	fnsave [edi].FloatSave
;	  fninit
	or byte ptr [edi].ContextFlags, 8	;=CONTEXT_FLOATING_POINT
@@:
endif
	ret
	assume edi:nothing
	align 4

_SaveContext endp

;--- v3.8.0: the previously implemented code tried to avoid to modify
;--- memory below ESP ( used a global var to temporarily store CS:EIP ).
;--- this caused problems if running with IOPL 0 and hence was removed. 

externdef stdcall _LoadContext@4:near

_LoadContext@4::

;_LoadContext proc public hThread:dword

	lea esp, [esp+4]
	pop eax				;hThread->eax
	mov edi, [eax].THREAD.pContext
	assume edi:ptr CONTEXT
ifdef _DEBUG
	lar ecx, [edi].SegSs
	jz @F
	int 3
@@:
endif
if ?FLOATREGS
	test [edi].ContextFlags, CONTEXT_FLOATING_POINT
	jz @F
	frstor [edi].FloatSave
@@:
endif
	mov esi, [edi].rEsi
	mov ebx, [edi].rEbx
	mov edx, [edi].rEdx
	mov ecx, [edi].rEcx
	mov eax, [edi].rEax
	mov ebp, [edi].rEbp
	mov gs, [edi].SegGs
	mov fs, [edi].SegFs
	mov es, [edi].SegEs
	lss esp, fword ptr [edi].rEsp
ife ?USEIRET
	push [edi].SegCs
	push [edi].rEip
	push [edi].EFlags
else
	push [edi].EFlags
	push [edi].SegCs
	push [edi].rEip
endif
	mov ds, [edi].SegDs
	mov edi, cs:[edi].rEdi
ife ?USEIRET
	test byte ptr [esp+1], 2
	jz @F
	popfd
	sti
	retd
@@:
	popfd
	retd
else
	test byte ptr [esp+2*4+1], 2
	jz @F
	sti
@@:
	iretd
endif
	assume edi:nothing
	align 4

;_LoadContext endp

	end
