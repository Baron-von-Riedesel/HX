
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
?PUSHCSEIP	equ 0	;std=0, 0=store CS:EIP in global var

	.data

ife ?PUSHCSEIP
g_dfCsEip	df 0
endif
;g_dfSsEsp	df 0

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
ife ?PUSHCSEIP
	mov eax, [edi].rEip
	mov ebp, [edi].SegCs
	push [edi].SegSs
	push [edi].rEsp
	mov dword ptr [g_dfCsEip+0],eax
	mov word ptr [g_dfCsEip+4],bp
	mov eax, [edi].EFlags
if 1
	and ah, not 2			;clear IF
endif
	mov esi, [edi].rEsi
	mov ebx, [edi].rEbx
	mov edx, [edi].rEdx
	mov ecx, [edi].rEcx
	push eax
	mov eax, [edi].rEax
	mov ebp, [edi].rEbp

	mov gs, [edi].SegGs
	mov fs, [edi].SegFs
	mov es, [edi].SegEs

	test byte ptr [edi].EFlags+1,2
	mov ds, [edi].SegDs
	mov edi, cs:[edi].rEdi
	jz @F
	popfd
	lss esp, [esp]
	sti
	jmp cs:[g_dfCsEip]
@@:
	popfd
	lss esp, [esp]
	jmp cs:[g_dfCsEip]
else
	lss esp, fword ptr [edi].rEsp
	push [edi].EFlags
	push [edi].SegCs
	push [edi].rEip

	mov esi, [edi].rEsi
	mov ebx, [edi].rEbx
	mov edx, [edi].rEdx
	mov ecx, [edi].rEcx
	mov eax, [edi].rEax
	mov ebp, [edi].rEbp

	mov gs, [edi].SegGs
	mov fs, [edi].SegFs
	mov es, [edi].SegEs
	mov ds, [edi].SegDs
	mov edi, cs:[edi].rEdi

	test byte ptr [esp+2*4+1],2
	jz @F
	sti
@@:
	iretd
endif
	assume edi:nothing
	align 4

;_LoadContext endp

	end
