
;--- translation services for int 33h

	.386
        
	include hdpmi.inc
	include external.inc

	option proc:private
	option casemap:none
        
?SAVERESTORE	equ 1	;std 1, 1=support save/restore driver state        

;--- mouse flags
MF_RMEVTSET equ 1	;real-mode init happened for int 33, eventproc functions 
MF_RMEVTSETB equ 0	;bit number

_DATA16V segment
;oldrmproc dd 0		;int 33h, old real mode event proc value
oldrmmask dw 0		;int 33h, old real mode event mask
fMouse    db 0		;mouse flags (global)
_DATA16V ends

_DATA32C segment
mevntvec R3PROC <0,0>	;mouse event proc
moumask dw 0			;mouse event mask
_DATA32C ends

intrmcb_rm_retf proto near16

_TEXT32 segment

;*** Int 33h API translation

	@ResetTrace

intr33 proc public

	@dprintf "intr33: ax=%X bx=%X cx=%X es:edx=%lX:%lX",ax,bx,cx,es,edx

	cmp ah,00
	jnz @F
	cmp al,09h			;define graphics cursor
	jz intr3309
	cmp al,0Ch			;set interrupt routine
	jz intr330C
	cmp al,12h			;define large graphics cursor
	jz intr3312
	cmp al,14h			;xchange interrupt routine
	jz intr3314
if ?SAVERESTORE 	   
	cmp al,16h			;save state
	jz intr3316
	cmp al,17h			;restore state
	jz intr3317
endif
	cmp al,18h			;set alternate handler
	jz intr3318
@@:
	@callrmsint 33h
intr33 endp

mouseprocs proc near

if ?SAVERESTORE
intr3316::				;save state to es:E/DX
	push edx
	call setesreg2tlb
	xor edx,edx
	@simrmint 33h
	pop edx

	push ecx
	mov ecx,ebx			;bx=size of buffer
	and ch,1Fh			;just make sure that CX is < 2000h
	push es
if ?32BIT
	push edx
else
	push word ptr 0
	push dx
endif
	push ss:[dwSegTLB]
	call copy_flat_2_far32
	pop ecx
;	jmp retf2exit
	iretd
intr3317::				;restore state from es:E/DX
	push edx
	push ecx
	mov ecx,ebx			;bx=size of buffer
	and ch,1Fh			;just make sure that CX is < 2000h
	jmp docopy33
endif

intr3312::				;set large graphic cursor
if 0
	push edx
	push ecx
	push eax
	mov al,bh			;width in words
	mul ch				;rows
	shl ax,2			;words -> bytes + 2 maps
	mov cx,ax
	pop eax
	jmp docopy33
endif
intr3309::				;graphic cursor (copy 20h bytes ES:E/DX)
	push edx			;NOT implemented in win9x
	push ecx			;but it costs only 5 bytes
	mov cx,20h*2		;20h words!!!
docopy33:
	push es
if ?32BIT
	push edx
else
	push word ptr 0
	push dx
endif
	push ss:[dwSegTLB]
	call copy_far32_2_flat
	call setesreg2tlb
	pop ecx
	xor edx,edx
	@simrmint 33h
	pop edx
;	jmp retf2exit
	iretd

intr3318::
intr3314::
intr330C::
	push ds
	push ss
	pop ds
	assume ds:GROUP16
	call mouse_setproc
	pop ds
;	jmp retf2exit
	iretd
	align 4
mouseprocs endp

	@ResetTrace

;--- set client mouse event proc ES:E/DX, mask in CX
;--- used by functions 000C, 0014 and 0018
;--- may modify ES!

	assume ds:GROUP16

mouse_setproc proc

	@dprintf "mouse_setproc: enter, ax=%X cx=%X es:edx=%lX:%lX",ax,cx,es,edx
	call mouse_setrmcb	;set real mode event proc
	push ds

	push byte ptr _CSALIAS_
	pop ds
	assume ds:GROUP32

	cmp al,0Ch			;000C set the proc only
	jnz @F
if ?32BIT
	mov mevntvec._Eip, edx
else
	mov mevntvec._Eip, dx
endif
	mov mevntvec._Cs, es
	mov [moumask],cx
	pop ds
	ret
@@:						;function 0014 + 0018 return old value
if ?32BIT
	xchg edx, mevntvec._Eip
else
	xchg dx, mevntvec._Eip
endif
	push eax
	mov eax,es
if ?32BIT
	xchg eax, mevntvec._Cs
else
	xchg ax, mevntvec._Cs
endif
	mov es,eax
	pop eax
	xchg cx,[moumask]
	pop ds
	ret
	align 4
mouse_setproc endp

;--- set real-mode mouse event proc
;--- and save old values 
;--- inp: cx=mask, es:(e)dx = mouse event proc
;--- DS=GROUP16

	@ResetTrace

	assume  ds:GROUP16
        
mouse_setrmcb proc
	pushad
	@dprintf "mouse_setrmcb: enter"
	mov eax, es
if ?32BIT
	movzx eax, ax
	or eax, edx
else
	or ax, dx
endif
	mov ax, ?RMCBMOUSE
	jz resetrm
	bts [wIntRmCb], ax
	add ax, wHostSeg
	mov dx, offset intrmcb_rm_retf
	sub dx, ?RMCBMOUSE shl 4
	@dprintf "mouse_setrmcb: internal callback addr=%X:%X, true ofs=%X", ax, dx, offset intrmcb_rm_retf
	mov v86iret.rES, ax
	jmp setresetproc
resetrm:
	btr [wIntRmCb], ax
	xor edx, edx
	mov v86iret.rES, dx
setresetproc:
	@dprintf "mouse_setrmcb: set real mode event proc to %X:%X, mask=%X [wIntRmCb=%lX]",v86iret.rES, dx, cx, dword ptr wIntRmCb
	mov ax,0014h			;instead of set -> xchg
	@simrmint 33h
	@dprintf "mouse_setrmcb: previous values es:dx=%X:%X, cx=%X",v86iret.rES,dx,cx
	bts dword ptr [fMouse], MF_RMEVTSETB
	jc exit
	mov ax,v86iret.rES
	@dprintf "mouse_setrmcb: original values (%X:%X, %X) stored in INTRMCBr", ax, dx, cx
	mov [oldrmmask],cx
	mov word ptr [intrmcbrs + ?RMCBMOUSE * sizeof INTRMCBr].rm_vec+0,dx
	mov word ptr [intrmcbrs + ?RMCBMOUSE * sizeof INTRMCBr].rm_vec+2,ax
exit:
	popad
	ret
	align 4

mouse_setrmcb endp

;--- this proc is called
;--- 1. when a client terminates
;---    then mevntvec contains the values for the previous client
;--- 2. when a vm (=host instance) terminates
;--- DS=GROUP16
;--- modifies E/DX, CX, AX

	@ResetTrace

	assume ds:GROUP16

mouse33_reset proc public

	test [fMouse], MF_RMEVTSET
	jz exit
	@dprintf "mouse33_reset enter, ss=%lX ds=%lX es=%lX, rms=%X:%X", ss, ds, es, v86iret.rSS, v86iret.rSP
	cmp [cApps],0
	jz vm_exit
	push es
	mov cx, cs:[moumask]
  if ?32BIT
	les edx, fword ptr cs:[mevntvec._Eip]
	@dprintf "mouse33_reset: calling mouse_setproc, cx=%X es:edx=%lX:%lX", cx, es, edx
  else
	les dx, dword ptr cs:[mevntvec._Eip]
	@dprintf "mouse33_reset: calling mouse_setproc, cx=%X es:dx=%lX:%X", cx, es, dx
  endif
	mov al, 0Ch
	call mouse_setproc
	pop es
	@dprintf "mouse33_reset exit"
exit:
	ret
vm_exit:
;--- vm terminates
	btr dword ptr [fMouse], MF_RMEVTSETB
	jnc exit2
	mov dx,word ptr [intrmcbrs + ?RMCBMOUSE * sizeof INTRMCBr].rm_vec+0
	mov ax,word ptr [intrmcbrs + ?RMCBMOUSE * sizeof INTRMCBr].rm_vec+2
	mov v86iret.rES,ax
	mov cx,[oldrmmask]
	@dprintf "mouse33_reset: calling int 33h, ax=000C, es:dx=%X:%X cx=%X",ax,dx,cx
	mov ax,000Ch
	@simrmint 33h
	@dprintf "mouse33_reset: exit"
exit2:
	ret
	align 4

mouse33_reset endp

_TEXT32 ends

end

