
;--- translation services for int 33h

	.386
        
	include hdpmi.inc
	include external.inc

	option proc:private
	option casemap:none
        
?SAVERESTORE	equ 1	;std 1, 1=support save/restore driver state        

@seg VDATA16
@seg CDATA32
@seg _TEXT32
@seg _TEXT16

;--- mouse flags
MF_RMEVTSET equ 1	;real-mode init happened for int 33, eventproc functions 
MF_RMEVTSETB equ 0	;bit number

VDATA16	segment
;oldrmproc dd 0		;int 33h, old real mode event proc value
oldrmmask dw 0		;int 33h, old real mode event mask
fMouse    db 0		;mouse flags (global)
VDATA16	ends

CDATA32	segment
mevntvec R3PROC <0,0>	;mouse event proc
moumask	dw 0			;mouse event mask
CDATA32 ends

_TEXT32 segment

;*** Int 33h API translation

	@ResetTrace

intr33 proc public

	@strout <"I33: ax=%X bx=%X cx=%X es:edx=%lX:%lX",lf>,ax,bx,cx,es,edx

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
	mov eax, es
if ?32BIT
	movzx eax, ax
	or eax, edx
else
	or ax, dx
endif
	mov ax, ?RMCBMOUSE
	jz resetrm

	bts [wStdRmCb], ax
	mov ax, [wHostSeg]		  
	mov dx,offset mouintrm
	mov [v86iret.rES], ax
	jmp setresetproc
resetrm:
	btr [wStdRmCb], ax
	xor edx, edx
	mov [v86iret.rES], dx
setresetproc:
	@strout <"I33: set real mode event proc to %X:%X, mask=%X [stdrmcbbits=%lX]",lf>,v86iret.rES,dx,cx,\
			<dword ptr wStdRmCb>
	mov ax,0014h			;instead of set -> xchg
	@simrmint 33h
	@strout <"I33: previous values es:dx=%X:%X, cx=%X",lf>,v86iret.rES,dx,cx
	bts dword ptr [fMouse], MF_RMEVTSETB
	jc exit
	mov ax,[v86iret.rES]
	@strout <"I33: original values (%X:%X, %X) stored in STDRMCB",lf>, ax, dx, cx
	mov [oldrmmask],cx
	mov word ptr [stdrmcbs + ?RMCBMOUSE * sizeof STDRMCB].rm_vec+0,dx
	mov word ptr [stdrmcbs + ?RMCBMOUSE * sizeof STDRMCB].rm_vec+2,ax
exit:
	popad
	ret
	align 4

mouse_setrmcb endp

;--- this proc is called
;--- 1. when a client terminates
;---    then mevntvec contains the values for the previous client
;--- 2. when HDPMI host terminates
;--- DS=GROUP16
;--- modifies E/DX, CX, AX

	@ResetTrace

	assume ds:GROUP16

mouse33_reset proc public

	test [fMouse], MF_RMEVTSET
	jz @F
	@strout <"mouse33_reset enter, ss=%lX ds=%lX es=%lX, rmsp=%lX",lf>, ss, ds, es, [tskstate.rmSSSP]
	cmp [cApps],0
	jz mouse33_exit
	push es
	mov cx, cs:[moumask]
  if ?32BIT
	les edx, fword ptr cs:[mevntvec._Eip]
	@strout <"mouse33_reset: calling mouse_setproc, cx=%X es:edx=%lX:%lX",lf>, cx, es, edx
  else
	les dx, dword ptr cs:[mevntvec._Eip]
	@strout <"mouse33_reset: calling mouse_setproc, cx=%X es:dx=%lX:%X",lf>, cx, es, dx
  endif
	mov al, 0Ch
	call mouse_setproc
	pop es
	@strout <"mouse33_reset exit",lf>
@@:
	ret
	align 4

mouse33_reset endp

;--- host terminates
;--- DS=GROUP16, ES=FLAT

	@ResetTrace

	assume ds:GROUP16

mouse33_exit proc
;	@strout <"I33: mouse33_exit enter, ss=%lX ds=%lX es=%lX",lf>, ss, ds, es
	btr dword ptr [fMouse], MF_RMEVTSETB
	jnc @F
	mov ax,word ptr [stdrmcbs + ?RMCBMOUSE * sizeof STDRMCB].rm_vec+2
	mov dx,word ptr [stdrmcbs + ?RMCBMOUSE * sizeof STDRMCB].rm_vec+0
	mov [v86iret.rES],ax
	mov cx,[oldrmmask]
	@strout <"I33: int 33, ax=0014, es:dx=%X:%X cx=%X",lf>,ax,dx,cx
	mov ax,0014h	;use ax=000Ch instead?
	@simrmint 33h
	@strout <"I33: mouse33_exit exit, ss=%lX ds=%lX es=%lX",lf>, ss, ds, es
@@:
	ret
	align 4

mouse33_exit endp

_TEXT32 ends

_TEXT16 segment

	@ResetTrace

;--- int 33h mouse event proc real-mode
;--- in Win9x and DPMIONE the event proc is called with ints enabled!

mouintrm proc
	@stroutrm <"I33 mouse event in rm, ss:sp=%X:%X",lf>,ss,sp
;--- create an IRET frame
	pushf
	push cs
	call meventr
	@stroutrm <"I33 exit from mouse event in rm, ss:sp=%X:%X",lf>,ss,sp
	retf
mouintrm endp

_TEXT16 ends

end

